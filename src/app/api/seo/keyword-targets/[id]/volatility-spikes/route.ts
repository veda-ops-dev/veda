/**
 * GET /api/seo/keyword-targets/:id/volatility-spikes -- SIL-8 A2
 *
 * Returns the top-N highest-volatility consecutive snapshot pairs ("spikes")
 * for a single KeywordTarget. Pure compute-on-read. No writes. No EventLog.
 *
 * Algorithm:
 *   1. Load SERPSnapshots for (projectId, query, locale, device) ordered
 *      capturedAt ASC, id ASC. Apply windowDays filter at DB level.
 *   2. Compute N-1 consecutive pairs (same ordering as /volatility).
 *   3. For each pair, compute pairVolatilityScore = computeVolatility([A, B]).volatilityScore.
 *      No new math -- exact reuse of existing formula, weights, and rounding.
 *   4. Sort all pairs by: pairVolatilityScore DESC, toCapturedAt DESC, toSnapshotId DESC.
 *   5. Return min(topN, sampleSize) spikes.
 *
 * Non-empty rule (binding):
 *   If sampleSize >= 1, spikes is never empty.
 *   spikes: [] only when sampleSize = 0.
 *
 * Isolation: resolveProjectId() + keywordTarget.projectId !== projectId -> 404.
 * Determinism: identical snapshot set + params = identical spike array.
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  badRequest,
  notFound,
  serverError,
  successResponse,
} from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { computeVolatility } from "@/lib/seo/volatility-service";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================


const WINDOW_DAYS_MIN = 1;
const WINDOW_DAYS_MAX = 365;
const TOP_N_MIN       = 1;
const TOP_N_MAX       = 10;
const TOP_N_DEFAULT   = 3;

type RouteParams = { id: string };

function isPromise<T>(v: unknown): v is Promise<T> {
  return !!v && typeof (v as Record<string, unknown>).then === "function";
}

// =============================================================================
// Param parsers
// =============================================================================

function parseWindowDays(
  sp: URLSearchParams
): { windowDays: number | null } | { error: string } {
  const raw = sp.get("windowDays");
  if (raw === null) return { windowDays: null };
  if (!/^\d+$/.test(raw)) return { error: "windowDays must be an integer" };
  const n = parseInt(raw, 10);
  if (n < WINDOW_DAYS_MIN) return { error: `windowDays must be >= ${WINDOW_DAYS_MIN}` };
  if (n > WINDOW_DAYS_MAX) return { error: `windowDays must be <= ${WINDOW_DAYS_MAX}` };
  return { windowDays: n };
}

function parseTopN(
  sp: URLSearchParams
): { topN: number } | { error: string } {
  const raw = sp.get("topN");
  if (raw === null) return { topN: TOP_N_DEFAULT };
  if (!/^\d+$/.test(raw)) return { error: "topN must be an integer" };
  const n = parseInt(raw, 10);
  if (n < TOP_N_MIN) return { error: `topN must be >= ${TOP_N_MIN}` };
  if (n > TOP_N_MAX) return { error: `topN must be <= ${TOP_N_MAX}` };
  return { topN: n };
}

// =============================================================================
// GET handler
// =============================================================================

export async function GET(
  request: NextRequest,
  { params }: { params: RouteParams | Promise<RouteParams> }
) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const resolvedParams = isPromise<RouteParams>(params) ? await params : params;
    const id = resolvedParams?.id;

    if (!id || !UUID_RE.test(id)) {
      return badRequest("id must be a valid UUID");
    }

    const sp = new URL(request.url).searchParams;

    const windowResult = parseWindowDays(sp);
    if ("error" in windowResult) return badRequest(windowResult.error);
    const windowDays = windowResult.windowDays;

    const topNResult = parseTopN(sp);
    if ("error" in topNResult) return badRequest(topNResult.error);
    const topN = topNResult.topN;

    // Single requestTime anchor -- spec section 2.3
    const requestTime = new Date();
    const windowStart: Date | null = windowDays !== null
      ? new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000)
      : null;

    // -- Resolve KeywordTarget (404 non-disclosure on cross-project) -----------
    const keywordTarget = await prisma.keywordTarget.findUnique({
      where: { id },
      select: { id: true, projectId: true, query: true, locale: true, device: true },
    });

    if (!keywordTarget || keywordTarget.projectId !== projectId) {
      return notFound("KeywordTarget not found");
    }

    const { query, locale, device } = keywordTarget;

    // -- Load snapshots: projectId + natural key + optional window at DB -------
    const snapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        query,
        locale,
        device,
        ...(windowStart !== null ? { capturedAt: { gte: windowStart } } : {}),
      },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      select: {
        id:               true,
        capturedAt:       true,
        aiOverviewStatus: true,
        rawPayload:       true,
      },
    });

    // < 2 snapshots = no pairs
    if (snapshots.length < 2) {
      return successResponse({
        keywordTargetId: id,
        query,
        locale,
        device,
        windowDays,
        sampleSize:  0,
        totalPairs:  0,
        topN,
        spikes:      [],
        computedAt:  requestTime.toISOString(),
      });
    }

    // -- Compute all N-1 consecutive pairs ------------------------------------
    const sampleSize = snapshots.length - 1;

    interface SpikeCandidate {
      fromSnapshotId:        string;
      toSnapshotId:          string;
      fromCapturedAt:        string; // ISO
      toCapturedAt:          string; // ISO
      toCapturedAtRaw:       Date;   // for sort (not emitted)
      pairVolatilityScore:   number;
      pairRankShift:         number;
      pairMaxShift:          number;
      pairFeatureChangeCount: number;
      aiFlipped:             boolean;
    }

    const candidates: SpikeCandidate[] = [];

    for (let i = 0; i < snapshots.length - 1; i++) {
      const A = snapshots[i];
      const B = snapshots[i + 1];

      // pairVolatilityScore = computeVolatility([A, B]).volatilityScore -- no new math
      const profile = computeVolatility([A, B]);

      candidates.push({
        fromSnapshotId:         A.id,
        toSnapshotId:           B.id,
        fromCapturedAt:         A.capturedAt.toISOString(),
        toCapturedAt:           B.capturedAt.toISOString(),
        toCapturedAtRaw:        B.capturedAt,
        pairVolatilityScore:    profile.volatilityScore,
        pairRankShift:          profile.averageRankShift,   // per spec: averageRankShift for this pair
        pairMaxShift:           profile.maxRankShift,
        pairFeatureChangeCount: profile.featureVolatility,  // symmetric diff count for this pair
        aiFlipped:              profile.aiOverviewChurn === 1,
      });
    }

    // -- Sort: pairVolatilityScore DESC, toCapturedAt DESC, toSnapshotId DESC --
    candidates.sort((a, b) => {
      if (b.pairVolatilityScore !== a.pairVolatilityScore) {
        return b.pairVolatilityScore - a.pairVolatilityScore;
      }
      const tDiff = b.toCapturedAtRaw.getTime() - a.toCapturedAtRaw.getTime();
      if (tDiff !== 0) return tDiff;
      // toSnapshotId DESC (lexicographic descending -- UUID sort is arbitrary but stable)
      if (b.toSnapshotId > a.toSnapshotId) return 1;
      if (b.toSnapshotId < a.toSnapshotId) return -1;
      return 0;
    });

    // -- Slice to min(topN, sampleSize) ----------------------------------------
    const spikes = candidates
      .slice(0, Math.min(topN, sampleSize))
      .map(({ toCapturedAtRaw: _raw, ...rest }) => rest); // strip sort-only field

    return successResponse({
      keywordTargetId: id,
      query,
      locale,
      device,
      windowDays,
      sampleSize,
      totalPairs: sampleSize,
      topN,
      spikes,
      computedAt: requestTime.toISOString(),
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/volatility-spikes error:", err);
    return serverError();
  }
}
