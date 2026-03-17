/**
 * GET /api/seo/keyword-targets/:id/feature-transitions -- SIL-8 A3
 *
 * For a single KeywordTarget, computes how SERP feature sets transition between
 * consecutive snapshots. Pure compute-on-read. No writes. No EventLog.
 *
 * Algorithm:
 *   1. Load SERPSnapshots for (projectId, query, locale, device) ordered
 *      capturedAt ASC, id ASC. Apply windowDays filter at DB level.
 *   2. Compute N-1 consecutive pairs.
 *   3. For each pair extract feature sets using extractFeatureSortedArray
 *      (canonical, shared, deterministic -- from serp-extraction.ts).
 *   4. Build transitionKey = fromKey + "\u2192" + toKey where:
 *        fromKey = fromFeaturesSorted.join(",")  (empty set => "")
 *        toKey   = toFeaturesSorted.join(",")    (empty set => "")
 *   5. Aggregate count per transitionKey.
 *   6. Sort: count DESC, fromKey ASC, toKey ASC.
 *
 * Sum-check invariant (binding):
 *   SUM(count across all transitions) === sampleSize (number of pairs).
 *   Every pair is classified exactly once.
 *
 * Spec response fields (SIL-8-PLAN.md A3):
 *   fromFeatureSet (sorted string[]), toFeatureSet (sorted string[]), count.
 *   Top-level: keywordTargetId, query, windowDays, sampleSize,
 *               totalTransitions, distinctTransitionCount, transitions.
 *
 * Isolation: resolveProjectId() + keywordTarget.projectId !== projectId -> 404.
 * Determinism: identical snapshot set + params = identical transitions array.
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
import { extractFeatureSortedArray } from "@/lib/seo/serp-extraction";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================


const WINDOW_DAYS_MIN = 1;
const WINDOW_DAYS_MAX = 365;

// U+2192 RIGHT ARROW -- canonical separator per spec. Does not appear in DataForSEO type strings.
const TRANSITION_SEP = "\u2192";

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

    // < 2 snapshots = no pairs
    if (snapshots.length < 2) {
      return successResponse({
        keywordTargetId:         id,
        query,
        locale,
        device,
        windowDays,
        sampleSize:              0,
        totalTransitions:        0,
        distinctTransitionCount: 0,
        transitions:             [],
        computedAt:              requestTime.toISOString(),
      });
    }

    const sampleSize = snapshots.length - 1;

    // -- Accumulate transition counts -----------------------------------------
    // key: transitionKey (fromKey + ARROW + toKey)
    // value: { fromFeatureSet, toFeatureSet, count }
    interface TransitionEntry {
      fromFeatureSet: string[];
      toFeatureSet:   string[];
      fromKey:        string;
      toKey:          string;
      count:          number;
    }

    const transitionMap = new Map<string, TransitionEntry>();

    for (let i = 0; i < snapshots.length - 1; i++) {
      const fromSnap = snapshots[i];
      const toSnap   = snapshots[i + 1];

      const fromFeatureSet = extractFeatureSortedArray(fromSnap.rawPayload);
      const toFeatureSet   = extractFeatureSortedArray(toSnap.rawPayload);

      // Canonical key construction (spec-binding):
      //   fromKey = sorted features joined by comma (empty => "")
      //   toKey   = sorted features joined by comma (empty => "")
      //   transitionKey = fromKey + U+2192 + toKey
      const fromKey       = fromFeatureSet.join(",");
      const toKey         = toFeatureSet.join(",");
      const transitionKey = fromKey + TRANSITION_SEP + toKey;

      const existing = transitionMap.get(transitionKey);
      if (existing) {
        existing.count++;
      } else {
        transitionMap.set(transitionKey, {
          fromFeatureSet,
          toFeatureSet,
          fromKey,
          toKey,
          count: 1,
        });
      }
    }

    // -- Sort: count DESC, fromKey ASC, toKey ASC ------------------------------
    const transitions = Array.from(transitionMap.values());

    transitions.sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      if (a.fromKey !== b.fromKey) return a.fromKey.localeCompare(b.fromKey);
      return a.toKey.localeCompare(b.toKey);
    });

    // -- Emit spec-canonical shape (fromFeatureSet / toFeatureSet arrays) ------
    const transitionsOut = transitions.map(({ fromFeatureSet, toFeatureSet, count }) => ({
      fromFeatureSet,
      toFeatureSet,
      count,
    }));

    return successResponse({
      keywordTargetId:         id,
      query,
      locale,
      device,
      windowDays,
      sampleSize,
      totalTransitions:        sampleSize,         // invariant: sum(count) === sampleSize
      distinctTransitionCount: transitions.length,
      transitions:             transitionsOut,
      computedAt:              requestTime.toISOString(),
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/feature-transitions error:", err);
    return serverError();
  }
}
