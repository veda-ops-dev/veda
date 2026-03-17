/**
 * GET /api/seo/keyword-targets/:id/volatility — SIL-3 Keyword Volatility Aggregation
 *
 * Computes a rolling volatility profile for a KeywordTarget from its historical
 * SERPSnapshot deltas. This is a compute-on-read, read-only surface.
 *
 * Algorithm:
 *   1. Load SERPSnapshots for (projectId, query, locale, device), ordered
 *      capturedAt ASC, id ASC (deterministic).
 *   2. If windowDays is provided, filter to capturedAt >= windowStart before
 *      passing to computeVolatility. The DB WHERE clause does the filtering,
 *      not in-memory, so the index is used.
 *   3. Compute pairwise deltas between each consecutive snapshot pair (N-1 pairs).
 *   4. Aggregate into volatility metrics.
 *
 * windowDays:
 *   Optional integer query param (1–365). When supplied:
 *   - windowStart is computed as: new Date(requestTime - windowDays * 86400000)
 *   - requestTime is fixed once at the start of the request (not re-sampled).
 *   - Only snapshots with capturedAt >= windowStart are included.
 *   - windowDays and windowStartAt are echoed in the response.
 *   - computedAt and windowStartAt are excluded from hammer determinism checks
 *     because they carry wall-clock timestamps.
 *
 * Constraints:
 *   - No DB writes. No EventLog. Read-only surface.
 *   - Project-scoped (404 non-disclosure on cross-project access).
 *   - Deterministic: same snapshot set + same windowDays always produces
 *     identical score fields (wall-clock fields excluded from determinism).
 *   - 400 for invalid UUID, invalid windowDays.
 *   - 404 for missing or cross-project keywordTarget.
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
import { computeVolatility, classifyMaturity, classifyRegime } from "@/lib/seo/volatility-service";
import { UUID_RE } from "@/lib/constants";


const WINDOW_DAYS_MIN = 1;
const WINDOW_DAYS_MAX = 365;

const ALERT_THRESHOLD_DEFAULT = 60;
const ALERT_THRESHOLD_MIN     = 0;
const ALERT_THRESHOLD_MAX     = 100;

type RouteParams = { id: string };

function isPromise<T>(v: unknown): v is Promise<T> {
  return !!v && typeof (v as Record<string, unknown>).then === "function";
}

/**
 * Parse and validate the optional alertThreshold query param.
 * Returns { alertThreshold: number } always on success (defaulting to 60 when absent).
 * Returns { error: string } on invalid input.
 */
function parseAlertThreshold(
  searchParams: URLSearchParams
): { alertThreshold: number; error?: never } | { alertThreshold?: never; error: string } {
  const raw = searchParams.get("alertThreshold");
  if (raw === null) return { alertThreshold: ALERT_THRESHOLD_DEFAULT };
  if (!/^-?\d+$/.test(raw)) return { error: "alertThreshold must be an integer" };
  const n = parseInt(raw, 10);
  if (n < ALERT_THRESHOLD_MIN) return { error: `alertThreshold must be >= ${ALERT_THRESHOLD_MIN}` };
  if (n > ALERT_THRESHOLD_MAX) return { error: `alertThreshold must be <= ${ALERT_THRESHOLD_MAX}` };
  return { alertThreshold: n };
}

/**
 * Parse and validate the optional windowDays query param.
 * Returns { windowDays: number } on success, { error: string } on failure,
 * or { windowDays: null } when the param is absent.
 */
function parseWindowDays(
  searchParams: URLSearchParams
): { windowDays: number | null; error?: never } | { windowDays?: never; error: string } {
  const raw = searchParams.get("windowDays");
  if (raw === null) return { windowDays: null };

  // Must be a string that looks like a non-negative integer (no decimals, no signs other than nothing)
  if (!/^\d+$/.test(raw)) {
    return { error: "windowDays must be an integer" };
  }
  const n = parseInt(raw, 10);
  if (n < WINDOW_DAYS_MIN) {
    return { error: `windowDays must be >= ${WINDOW_DAYS_MIN}` };
  }
  if (n > WINDOW_DAYS_MAX) {
    return { error: `windowDays must be <= ${WINDOW_DAYS_MAX}` };
  }
  return { windowDays: n };
}

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

    // --- Parse query params before any DB work ---
    const searchParams = new URL(request.url).searchParams;
    const windowResult = parseWindowDays(searchParams);
    if (windowResult.error) return badRequest(windowResult.error);
    const windowDays = windowResult.windowDays ?? null;

    const alertResult = parseAlertThreshold(searchParams);
    if (alertResult.error) return badRequest(alertResult.error);
    const alertThreshold = alertResult.alertThreshold!;

    // Fix requestTime once so windowStart is stable for this request.
    const requestTime = new Date();
    const windowStart: Date | null = windowDays !== null
      ? new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000)
      : null;

    // --- Resolve KeywordTarget (project-scoped, 404 non-disclosure) ---
    const keywordTarget = await prisma.keywordTarget.findUnique({
      where: { id },
      select: {
        id: true,
        projectId: true,
        query: true,
        locale: true,
        device: true,
      },
    });

    if (!keywordTarget || keywordTarget.projectId !== projectId) {
      return notFound("KeywordTarget not found");
    }

    const { query, locale, device } = keywordTarget;

    // --- Load snapshots, applying window filter at the DB level ---
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
        id: true,
        capturedAt: true,
        aiOverviewStatus: true,
        rawPayload: true,
      },
    });

    const volatility = computeVolatility(snapshots);

    // sampleSize=0 means no evidence at all — force false regardless of threshold
    const exceedsThreshold = volatility.sampleSize > 0
      && volatility.volatilityScore >= alertThreshold;

    return successResponse({
      keywordTargetId: id,
      query,
      locale,
      device,
      windowDays,
      windowStartAt: windowStart !== null ? windowStart.toISOString() : null,
      alertThreshold,
      exceedsThreshold,
      sampleSize: volatility.sampleSize,
      snapshotCount: snapshots.length,
      averageRankShift: volatility.averageRankShift,
      maxRankShift: volatility.maxRankShift,
      featureVolatility: volatility.featureVolatility,
      aiOverviewChurn: volatility.aiOverviewChurn,
      volatilityScore: volatility.volatilityScore,
      rankVolatilityComponent: volatility.rankVolatilityComponent,
      aiOverviewComponent: volatility.aiOverviewComponent,
      featureVolatilityComponent: volatility.featureVolatilityComponent,
      maturity: classifyMaturity(volatility.sampleSize),
      volatilityRegime: classifyRegime(volatility.volatilityScore),
      computedAt: requestTime.toISOString(),
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/volatility error:", err);
    return serverError();
  }
}
