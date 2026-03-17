/**
 * GET /api/seo/keyword-targets/:id/volatility-breakdown -- SIL-8 A1
 *
 * Exposes which URLs contribute most to rank volatility for a single KeywordTarget.
 * Pure compute-on-read. No writes. No EventLog.
 *
 * Algorithm:
 *   1. Load SERPSnapshots for (projectId, query, locale, device) ordered
 *      capturedAt ASC, id ASC (deterministic). Apply windowDays at DB level.
 *   2. Compute N-1 consecutive pairs.
 *   3. For each URL observed across all pairs:
 *        appearances    -- pairs where URL is in at least one snapshot with non-null rank
 *        totalAbsShift  -- sum of abs rank shifts for pairs where URL is in BOTH with non-null ranks
 *        averageShift   -- totalAbsShift / pairsBothPresent (0 if pairsBothPresent=0)
 *        firstSeen      -- earliest capturedAt where URL had non-null rank
 *        lastSeen       -- most recent capturedAt where URL had non-null rank
 *   4. Sort: totalAbsShift DESC, url ASC. Slice topN.
 *
 * Spec invariants (SIL-8 A1, binding):
 *   - appearances counts entry/exit pairs (URL in only one snapshot still counts).
 *   - totalAbsShift only accumulates from pairs where URL is in both with non-null ranks.
 *   - url uniqueness per result set makes the two-field sort complete.
 *   - windowDays absent = null (all history), consistent with /volatility.
 *   - topN applied after sort, not before.
 *   - extractOrganicResults reused from serp-extraction.ts (no reimplementation).
 *
 * Isolation: resolveProjectId() + keywordTarget.projectId !== projectId -> 404.
 * Determinism: same snapshot set + same params = identical response (excluding computedAt).
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
import { extractOrganicResults } from "@/lib/seo/serp-extraction";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================


const WINDOW_DAYS_MIN = 1;
const WINDOW_DAYS_MAX = 365;
const TOP_N_MIN       = 1;
const TOP_N_MAX       = 50;
const TOP_N_DEFAULT   = 20;

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
// URL accumulator type (internal only)
// =============================================================================

interface UrlStats {
  url:              string;
  appearances:      number;   // pairs where URL in >=1 snapshot with non-null rank
  totalAbsShift:    number;   // sum of abs shifts for pairs where in BOTH with non-null ranks
  pairsBothPresent: number;   // pairs contributing to totalAbsShift
  firstSeen:        Date;
  lastSeen:         Date;
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
      select: { id: true, capturedAt: true, rawPayload: true },
    });

    // < 2 snapshots = no pairs = empty breakdown
    if (snapshots.length < 2) {
      return successResponse({
        keywordTargetId: id,
        query,
        locale,
        device,
        windowDays,
        sampleSize: 0,
        urlCount: 0,
        urls: [],
        computedAt: requestTime.toISOString(),
      });
    }

    // -- Accumulate URL stats across N-1 consecutive pairs --------------------
    const urlMap = new Map<string, UrlStats>();

    for (let i = 0; i < snapshots.length - 1; i++) {
      const fromSnap = snapshots[i];
      const toSnap   = snapshots[i + 1];

      const fromExtraction = extractOrganicResults(fromSnap.rawPayload);
      const toExtraction   = extractOrganicResults(toSnap.rawPayload);

      // Build rank maps: url -> rank|null (first-wins; extractor already sorted rank asc)
      const fromMap = new Map<string, number | null>();
      for (const r of fromExtraction.results) {
        if (!fromMap.has(r.url)) fromMap.set(r.url, r.rank);
      }

      const toMap = new Map<string, number | null>();
      for (const r of toExtraction.results) {
        if (!toMap.has(r.url)) toMap.set(r.url, r.rank);
      }

      // All URLs present in at least one snapshot of this pair
      const pairUrls = new Set<string>([...fromMap.keys(), ...toMap.keys()]);

      for (const url of pairUrls) {
        const fromRank = fromMap.has(url) ? fromMap.get(url)! : null;
        const toRank   = toMap.has(url)   ? toMap.get(url)!   : null;

        const inFrom = fromMap.has(url) && fromRank !== null;
        const inTo   = toMap.has(url)   && toRank   !== null;

        // Must be in at least one snapshot with non-null rank to count appearances
        if (!inFrom && !inTo) continue;

        let stats = urlMap.get(url);
        if (!stats) {
          // Initialize firstSeen/lastSeen from whichever side this URL first appears on
          const firstCapture = inFrom ? fromSnap.capturedAt : toSnap.capturedAt;
          const lastCapture  = inTo   ? toSnap.capturedAt   : fromSnap.capturedAt;
          stats = {
            url,
            appearances:      0,
            totalAbsShift:    0,
            pairsBothPresent: 0,
            firstSeen:        firstCapture,
            lastSeen:         lastCapture,
          };
          urlMap.set(url, stats);
        }

        stats.appearances++;

        // Track firstSeen/lastSeen based on capturedAt of snapshots where URL had non-null rank
        if (inFrom && fromSnap.capturedAt < stats.firstSeen) stats.firstSeen = fromSnap.capturedAt;
        if (inTo   && toSnap.capturedAt   < stats.firstSeen) stats.firstSeen = toSnap.capturedAt;
        if (inFrom && fromSnap.capturedAt > stats.lastSeen)  stats.lastSeen  = fromSnap.capturedAt;
        if (inTo   && toSnap.capturedAt   > stats.lastSeen)  stats.lastSeen  = toSnap.capturedAt;

        // totalAbsShift: only when URL is in BOTH snapshots with non-null ranks
        if (inFrom && inTo) {
          stats.totalAbsShift    += Math.abs(fromRank! - toRank!);
          stats.pairsBothPresent++;
        }
      }
    }

    // -- Build result array, round, sort, slice --------------------------------
    const sampleSize = snapshots.length - 1;

    const allUrls = Array.from(urlMap.values()).map((s) => {
      const totalAbsShift = Math.round(s.totalAbsShift * 100) / 100;
      const averageShift  = s.pairsBothPresent > 0
        ? Math.round((s.totalAbsShift / s.pairsBothPresent) * 100) / 100
        : 0;
      return {
        url:           s.url,
        appearances:   s.appearances,
        totalAbsShift,
        averageShift,
        firstSeen:     s.firstSeen.toISOString(),
        lastSeen:      s.lastSeen.toISOString(),
      };
    });

    // Deterministic sort: totalAbsShift DESC, url ASC (complete: url is unique per set)
    allUrls.sort((a, b) => {
      if (b.totalAbsShift !== a.totalAbsShift) return b.totalAbsShift - a.totalAbsShift;
      return a.url.localeCompare(b.url);
    });

    const urlCount = allUrls.length;
    const urls     = allUrls.slice(0, topN);

    return successResponse({
      keywordTargetId: id,
      query,
      locale,
      device,
      windowDays,
      sampleSize,
      urlCount,
      urls,
      computedAt: requestTime.toISOString(),
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/volatility-breakdown error:", err);
    return serverError();
  }
}
