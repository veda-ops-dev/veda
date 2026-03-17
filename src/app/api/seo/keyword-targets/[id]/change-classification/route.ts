/**
 * GET /api/seo/keyword-targets/:id/change-classification
 *
 * SIL-12: Classifies the type of SERP event occurring for a KeywordTarget by
 * combining signals from existing sensors. All computation is on-read; no
 * writes, no mutations, no EventLog.
 *
 * Signal derivation (all computed inline from the snapshot set):
 *   volatilityScore    -- computeVolatility().volatilityScore
 *   aiChurn            -- computeVolatility().aiOverviewChurn
 *   featureTransitions -- computeFeatureVolatility().summary.transitionCount
 *   intentDriftEvents  -- computeIntentDrift().transitions.length
 *   serpSimilarity     -- mean combinedSimilarity across all consecutive pairs
 *                         (computeSerpSimilarity().pairs)
 *   dominanceDelta     -- |dominanceIndex(last snap) - dominanceIndex(first snap)|
 *                         (computeDomainDominance() on first and last snapshot)
 *
 * Isolation:  resolveProjectId() -- headers only; cross-project KT -> 404.
 * Determinism: identical params + snapshot set -> identical response.
 *              No wall-clock fields in response body.
 *
 * Query params:
 *   windowDays  optional int 1-365
 */
import { NextRequest } from "next/server";
import { prisma }          from "@/lib/prisma";
import { badRequest, notFound, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { computeVolatility, type SnapshotForVolatility } from "@/lib/seo/volatility-service";
import { extractFeatureSignals }  from "@/lib/seo/serp-extraction";
import { computeFeatureVolatility, type FeatureSnapshot } from "@/lib/seo/feature-volatility";
import { computeIntentDrift }     from "@/lib/seo/intent-drift";
import { computeSerpSimilarity }  from "@/lib/seo/serp-similarity";
import { computeDomainDominance } from "@/lib/seo/domain-dominance";
import { computeChangeClassification } from "@/lib/seo/change-classification";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================

const WINDOW_MIN = 1;
const WINDOW_MAX = 365;

// =============================================================================
// Helpers
// =============================================================================

type RouteParams = { id: string };

function isPromise<T>(v: unknown): v is Promise<T> {
  return !!v && typeof (v as Record<string, unknown>).then === "function";
}

function parseWindowDays(sp: URLSearchParams): { windowDays: number | null } | { error: string } {
  const raw = sp.get("windowDays");
  if (raw === null) return { windowDays: null };
  if (!/^\d+$/.test(raw)) return { error: "windowDays must be an integer" };
  const n = parseInt(raw, 10);
  if (n < WINDOW_MIN) return { error: `windowDays must be >= ${WINDOW_MIN}` };
  if (n > WINDOW_MAX) return { error: `windowDays must be <= ${WINDOW_MAX}` };
  return { windowDays: n };
}

// =============================================================================
// GET handler
// =============================================================================

export async function GET(
  request: NextRequest,
  context: { params: RouteParams | Promise<RouteParams> }
) {
  try {
    const { projectId, error: projectError } = await resolveProjectId(request);
    if (projectError) return badRequest(projectError);

    const params = isPromise(context.params) ? await context.params : context.params;
    const { id } = params;

    if (!UUID_RE.test(id)) return badRequest("id must be a valid UUID");

    const sp = new URL(request.url).searchParams;
    const windowResult = parseWindowDays(sp);
    if ("error" in windowResult) return badRequest(windowResult.error);
    const windowDays = windowResult.windowDays;

    // Single requestTime anchor
    const requestTime = new Date();
    const windowStart: Date | null =
      windowDays !== null
        ? new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000)
        : null;

    // Resolve KeywordTarget -- 404 non-disclosure on cross-project
    const keywordTarget = await prisma.keywordTarget.findUnique({
      where:  { id },
      select: { id: true, projectId: true, query: true, locale: true, device: true },
    });
    if (!keywordTarget || keywordTarget.projectId !== projectId) {
      return notFound("KeywordTarget not found");
    }

    const { query, locale, device } = keywordTarget;

    // Load snapshots once -- capturedAt ASC, id ASC (deterministic)
    const rawSnaps = await prisma.sERPSnapshot.findMany({
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

    // ── Signal 1: volatility + aiChurn (computeVolatility) ───────────────────
    const volSnaps: SnapshotForVolatility[] = rawSnaps.map((s) => ({
      id:               s.id,
      capturedAt:       s.capturedAt,
      aiOverviewStatus: s.aiOverviewStatus,
      rawPayload:       s.rawPayload,
    }));
    const volProfile = computeVolatility(volSnaps);

    // ── Signal 2: featureTransitions (computeFeatureVolatility) ──────────────
    const featSnaps: FeatureSnapshot[] = rawSnaps.map((s) => ({
      snapshotId:     s.id,
      capturedAt:     s.capturedAt,
      familiesSorted: extractFeatureSignals(s.rawPayload).familiesSorted,
    }));
    const { summary: featSummary } = computeFeatureVolatility(featSnaps);

    // ── Signal 3: intentDriftEvents (computeIntentDrift) ─────────────────────
    const intentInput = rawSnaps.map((s) => ({
      snapshotId: s.id,
      capturedAt: s.capturedAt,
      signals:    extractFeatureSignals(s.rawPayload),
    }));
    const { transitions: intentTransitions } = computeIntentDrift(intentInput);

    // ── Signal 4: serpSimilarity -- mean combinedSimilarity across all pairs ──
    const simInput = rawSnaps.map((s) => ({
      snapshotId: s.id,
      capturedAt: s.capturedAt,
      rawPayload: s.rawPayload,
      signals:    extractFeatureSignals(s.rawPayload),
    }));
    const { pairs: simPairs } = computeSerpSimilarity(simInput);

    // ── Signal 5: dominanceDelta -- |last - first| dominanceIndex ────────────
    let dominanceDelta = 0;
    if (rawSnaps.length >= 2) {
      const first = computeDomainDominance(rawSnaps[0].rawPayload);
      const last  = computeDomainDominance(rawSnaps[rawSnaps.length - 1].rawPayload);
      const di0   = first.dominanceIndex ?? 0;
      const di1   = last.dominanceIndex  ?? 0;
      dominanceDelta = Math.abs(di1 - di0);
    }

    // ── Classify ──────────────────────────────────────────────────────────────
    // averageSimilarity: sum over pairs first, divide once -- no midstream rounding.
    const serpSimilaritySum = simPairs.reduce((sum, p) => sum + p.combinedSimilarity, 0);
    const averageSimilarity = simPairs.length > 0 ? serpSimilaritySum / simPairs.length : 1.0;

    const result = computeChangeClassification({
      volatilityScore:        volProfile.volatilityScore,
      averageSimilarity,
      intentDriftEventCount:  intentTransitions.length,
      featureTransitionCount: featSummary.transitionCount,
      dominanceDelta,
      aiOverviewChurnCount:   volProfile.aiOverviewChurn,
    });

    return successResponse({
      keywordTargetId: id,
      query,
      locale,
      device,
      windowDays,
      snapshotCount:  rawSnaps.length,
      classification: result.classification,
      confidence:     result.confidence,
      signals:        result.signals,
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/change-classification error:", err);
    return serverError();
  }
}
