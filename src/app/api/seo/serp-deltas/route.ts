/**
 * GET /api/seo/serp-deltas — SIL-2 Delta + Volatility Intelligence
 *
 * Computes SERP rank deltas between two snapshots for a given KeywordTarget.
 *
 * Resolution:
 *   - keywordTargetId (required) → resolves (query, locale, device) for the target
 *   - fromSnapshotId + toSnapshotId (optional) → explicit snapshot pair
 *   - If omitted → auto-select latest two snapshots for the target
 *     (deterministic: capturedAt desc, id desc)
 *
 * Compute-on-read:
 *   - Rank extraction from rawPayload is best-effort (defensive parsing)
 *   - payloadParseWarning: true if extraction failed on either snapshot
 *   - No DB writes, no EventLog (read-only surface)
 *
 * Project isolation:
 *   - keywordTarget.projectId must match resolvedProjectId (404 if not)
 *   - Both snapshots must belong to the same project (404 if not)
 *   - Snapshots must match the keywordTarget's (query, locale, device) (400)
 *
 * Edge cases:
 *   - < 2 snapshots → 200 with delta: null, metadata.insufficient_snapshots: true
 *   - Identical capturedAt → 200 with metadata.same_timestamp: true
 *   - rawPayload malformed → delta computed but payloadParseWarning: true
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, notFound, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { extractOrganicResults, type ExtractedResult } from "@/lib/seo/serp-extraction";
import { UUID_RE } from "@/lib/constants";


// =============================================================================
// Delta computation
// =============================================================================

interface RankEntry {
  url: string;
  domain: string | null;
  rank: number | null;
  title: string | null;
}

interface DeltaEntry {
  url: string;
  domain: string | null;
  rank_from: number | null;
  rank_to: number | null;
  /** Positive = improved (moved up). Negative = declined. null if either rank is null. */
  rank_delta: number | null;
  title_to: string | null;
}

interface DeltaResult {
  moved: DeltaEntry[];
  entered: RankEntry[];
  exited: RankEntry[];
}

/**
 * Build a URL-keyed map from an array of extracted results.
 * Duplicate URLs: first occurrence wins (deterministic; results are pre-sorted
 * by rank asc so the lowest-rank entry is already first).
 */
function buildResultMap(results: ExtractedResult[]): Map<string, ExtractedResult> {
  const map = new Map<string, ExtractedResult>();
  for (const r of results) {
    if (!map.has(r.url)) map.set(r.url, r);
  }
  return map;
}

function computeRankDelta(
  fromResults: ExtractedResult[],
  toResults: ExtractedResult[]
): DeltaResult {
  const fromMap = buildResultMap(fromResults);
  const toMap   = buildResultMap(toResults);

  const fromUrls = new Set(fromMap.keys());
  const toUrls = new Set(toMap.keys());

  // Entered: in toResults but not fromResults
  const entered: RankEntry[] = [];
  for (const url of toUrls) {
    if (!fromUrls.has(url)) {
      const r = toMap.get(url)!;
      entered.push({ url: r.url, domain: r.domain, rank: r.rank, title: r.title });
    }
  }
  // Deterministic: rank asc (nulls last), then url asc
  entered.sort((a, b) => {
    if (a.rank === null && b.rank === null) return a.url.localeCompare(b.url);
    if (a.rank === null) return 1;
    if (b.rank === null) return -1;
    if (a.rank !== b.rank) return a.rank - b.rank;
    return a.url.localeCompare(b.url);
  });

  // Exited: in fromResults but not toResults
  const exited: RankEntry[] = [];
  for (const url of fromUrls) {
    if (!toUrls.has(url)) {
      const r = fromMap.get(url)!;
      exited.push({ url: r.url, domain: r.domain, rank: r.rank, title: r.title });
    }
  }
  exited.sort((a, b) => {
    if (a.rank === null && b.rank === null) return a.url.localeCompare(b.url);
    if (a.rank === null) return 1;
    if (b.rank === null) return -1;
    if (a.rank !== b.rank) return a.rank - b.rank;
    return a.url.localeCompare(b.url);
  });

  // Moved: in both, rank changed (or rank comparison meaningful)
  const moved: DeltaEntry[] = [];
  for (const url of fromUrls) {
    if (!toUrls.has(url)) continue;
    const from = fromMap.get(url)!;
    const to = toMap.get(url)!;
    const rank_delta =
      from.rank !== null && to.rank !== null ? from.rank - to.rank : null;
    moved.push({
      url,
      domain: to.domain ?? from.domain,
      rank_from: from.rank,
      rank_to: to.rank,
      rank_delta,
      title_to: to.title,
    });
  }
  // Deterministic: sort by rank_delta desc (biggest improvement first), then url asc
  moved.sort((a, b) => {
    if (a.rank_delta === null && b.rank_delta === null) return a.url.localeCompare(b.url);
    if (a.rank_delta === null) return 1;
    if (b.rank_delta === null) return -1;
    if (a.rank_delta !== b.rank_delta) return b.rank_delta - a.rank_delta;
    return a.url.localeCompare(b.url);
  });

  return { moved, entered, exited };
}

// =============================================================================
// GET /api/seo/serp-deltas
// =============================================================================

type SnapshotRow = {
  id: string;
  projectId: string;
  query: string;
  locale: string;
  device: string;
  capturedAt: Date;
  aiOverviewStatus: string;
  aiOverviewText: string | null;
  rawPayload: unknown;
  source: string;
};

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) {
      return badRequest(error);
    }

    const searchParams = request.nextUrl.searchParams;

    // --- keywordTargetId (required) ---
    const keywordTargetId = searchParams.get("keywordTargetId");
    if (!keywordTargetId) {
      return badRequest("keywordTargetId is required");
    }
    if (!UUID_RE.test(keywordTargetId)) {
      return badRequest("keywordTargetId must be a valid UUID");
    }

    // Resolve keywordTarget — project-scoped (404 non-disclosure on cross-project)
    const keywordTarget = await prisma.keywordTarget.findUnique({
      where: { id: keywordTargetId },
      select: { id: true, projectId: true, query: true, locale: true, device: true },
    });

    if (!keywordTarget || keywordTarget.projectId !== projectId) {
      return notFound("KeywordTarget not found");
    }

    const { query, locale, device } = keywordTarget;

    // --- Optional explicit snapshot pair ---
    const fromSnapshotId = searchParams.get("fromSnapshotId");
    const toSnapshotId = searchParams.get("toSnapshotId");

    if (fromSnapshotId && !UUID_RE.test(fromSnapshotId)) {
      return badRequest("fromSnapshotId must be a valid UUID");
    }
    if (toSnapshotId && !UUID_RE.test(toSnapshotId)) {
      return badRequest("toSnapshotId must be a valid UUID");
    }
    // Either both explicit or neither
    if ((fromSnapshotId && !toSnapshotId) || (!fromSnapshotId && toSnapshotId)) {
      return badRequest("fromSnapshotId and toSnapshotId must both be provided, or both omitted");
    }

    let fromSnapshot: SnapshotRow | null = null;
    let toSnapshot: SnapshotRow | null = null;

    if (fromSnapshotId && toSnapshotId) {
      // Explicit pair — validate project scoping and target match
      const [fs, ts] = await Promise.all([
        prisma.sERPSnapshot.findUnique({
          where: { id: fromSnapshotId },
          select: {
            id: true,
            projectId: true,
            query: true,
            locale: true,
            device: true,
            capturedAt: true,
            aiOverviewStatus: true,
            aiOverviewText: true,
            rawPayload: true,
            source: true,
          },
        }),
        prisma.sERPSnapshot.findUnique({
          where: { id: toSnapshotId },
          select: {
            id: true,
            projectId: true,
            query: true,
            locale: true,
            device: true,
            capturedAt: true,
            aiOverviewStatus: true,
            aiOverviewText: true,
            rawPayload: true,
            source: true,
          },
        }),
      ]);

      // 404 non-disclosure on cross-project
      if (!fs || fs.projectId !== projectId) {
        return notFound("fromSnapshotId not found");
      }
      if (!ts || ts.projectId !== projectId) {
        return notFound("toSnapshotId not found");
      }

      // 400 if snapshots don't match the keywordTarget's natural key
      if (fs.query !== query || fs.locale !== locale || fs.device !== device) {
        return badRequest("fromSnapshotId does not match the keywordTarget's query/locale/device");
      }
      if (ts.query !== query || ts.locale !== locale || ts.device !== device) {
        return badRequest("toSnapshotId does not match the keywordTarget's query/locale/device");
      }

      fromSnapshot = fs;
      toSnapshot = ts;
    } else {
      // Auto-select latest two snapshots for this keywordTarget
      const snapshots = await prisma.sERPSnapshot.findMany({
        where: { projectId, query, locale, device },
        orderBy: [{ capturedAt: "desc" }, { id: "desc" }],
        take: 2,
        select: {
          id: true,
          projectId: true,
          query: true,
          locale: true,
          device: true,
          capturedAt: true,
          aiOverviewStatus: true,
          aiOverviewText: true,
          rawPayload: true,
          source: true,
        },
      });

      if (snapshots.length < 2) {
        return successResponse({
          delta: null,
          metadata: {
            keywordTargetId,
            query,
            locale,
            device,
            insufficient_snapshots: true,
            snapshot_count: snapshots.length,
            from_snapshot: snapshots[0]
              ? {
                  id: snapshots[0].id,
                  capturedAt: snapshots[0].capturedAt.toISOString(),
                  aiOverviewStatus: snapshots[0].aiOverviewStatus,
                  source: snapshots[0].source,
                }
              : null,
            to_snapshot: null,
          },
        });
      }

      // snapshots[0] is most recent (to), snapshots[1] is older (from)
      toSnapshot = snapshots[0];
      fromSnapshot = snapshots[1];
    }

    if (!fromSnapshot || !toSnapshot) {
      // Defensive: should be unreachable given the branches above.
      return serverError();
    }

    // ==========================================================================
    // Compute delta
    // ==========================================================================

    const { results: fromResults, parseWarning: fromWarn } = extractOrganicResults(
      fromSnapshot.rawPayload
    );
    const { results: toResults, parseWarning: toWarn } = extractOrganicResults(
      toSnapshot.rawPayload
    );

    const { moved, entered, exited } = computeRankDelta(fromResults, toResults);

    const sameTimestamp =
      fromSnapshot.capturedAt.getTime() === toSnapshot.capturedAt.getTime();

    // AI Overview state change
    const aiOverviewChange =
      fromSnapshot.aiOverviewStatus !== toSnapshot.aiOverviewStatus
        ? {
            changed: true,
            from: fromSnapshot.aiOverviewStatus,
            to: toSnapshot.aiOverviewStatus,
          }
        : {
            changed: false,
            from: fromSnapshot.aiOverviewStatus,
            to: toSnapshot.aiOverviewStatus,
          };

    return successResponse({
      delta: {
        moved,
        entered,
        exited,
        ai_overview: aiOverviewChange,
        summary: {
          moved_count: moved.length,
          entered_count: entered.length,
          exited_count: exited.length,
          improved_count: moved.filter((m) => m.rank_delta !== null && m.rank_delta > 0).length,
          declined_count: moved.filter((m) => m.rank_delta !== null && m.rank_delta < 0).length,
          unchanged_count: moved.filter((m) => m.rank_delta === 0).length,
        },
      },
      metadata: {
        keywordTargetId,
        query,
        locale,
        device,
        insufficient_snapshots: false,
        snapshot_count: 2,
        same_timestamp: sameTimestamp,
        payload_parse_warning: fromWarn || toWarn,
        from_snapshot: {
          id: fromSnapshot.id,
          capturedAt: fromSnapshot.capturedAt.toISOString(),
          aiOverviewStatus: fromSnapshot.aiOverviewStatus,
          source: fromSnapshot.source,
        },
        to_snapshot: {
          id: toSnapshot.id,
          capturedAt: toSnapshot.capturedAt.toISOString(),
          aiOverviewStatus: toSnapshot.aiOverviewStatus,
          source: toSnapshot.source,
        },
      },
    });
  } catch (err) {
    console.error("GET /api/seo/serp-deltas error:", err);
    return serverError();
  }
}
