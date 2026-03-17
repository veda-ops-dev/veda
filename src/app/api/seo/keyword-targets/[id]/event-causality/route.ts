/**
 * GET /api/seo/keyword-targets/:id/event-causality
 *
 * SIL-14: Detects deterministic adjacent event transition patterns from
 * the SIL-13 event timeline for a KeywordTarget.
 *
 * Read-only. No writes, no mutations, no EventLog, no transactions.
 * Uses pure library calls only (no internal HTTP calls).
 *
 * Isolation:  resolveProjectId() -- headers only; cross-project KT -> 404.
 * Determinism: identical params + snapshot set -> identical response.
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
import { computeEventTimeline, type TimelineSnapshotInput } from "@/lib/seo/event-timeline";
import { computeEventCausality } from "@/lib/seo/event-causality";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================


// =============================================================================
// Helpers
// =============================================================================

type RouteParams = { id: string };

function isPromise<T>(v: unknown): v is Promise<T> {
  return !!v && typeof (v as Record<string, unknown>).then === "function";
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
      where: { projectId, query, locale, device },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      select: {
        id:               true,
        capturedAt:       true,
        aiOverviewStatus: true,
        rawPayload:       true,
      },
    });

    if (rawSnaps.length === 0) {
      return successResponse({
        keywordTargetId: id,
        query,
        locale,
        device,
        timelineCount:  0,
        patternCount:   0,
        patterns:       [],
      });
    }

    // ── Compute per-snapshot signals for timeline (identical to SIL-13 route) ─
    const timelineInputs: TimelineSnapshotInput[] = [];

    for (let i = 0; i < rawSnaps.length; i++) {
      const window = rawSnaps.slice(0, i + 1);
      const snap = rawSnaps[i];

      // volatility + aiChurn
      const volSnaps: SnapshotForVolatility[] = window.map((s) => ({
        id:               s.id,
        capturedAt:       s.capturedAt,
        aiOverviewStatus: s.aiOverviewStatus,
        rawPayload:       s.rawPayload,
      }));
      const volProfile = computeVolatility(volSnaps);

      // featureTransitions
      const featSnaps: FeatureSnapshot[] = window.map((s) => ({
        snapshotId:     s.id,
        capturedAt:     s.capturedAt,
        familiesSorted: extractFeatureSignals(s.rawPayload).familiesSorted,
      }));
      const { summary: featSummary } = computeFeatureVolatility(featSnaps);

      // intentDriftEvents
      const intentInput = window.map((s) => ({
        snapshotId: s.id,
        capturedAt: s.capturedAt,
        signals:    extractFeatureSignals(s.rawPayload),
      }));
      const { transitions: intentTransitions } = computeIntentDrift(intentInput);

      // serpSimilarity -- mean combinedSimilarity
      const simInput = window.map((s) => ({
        snapshotId: s.id,
        capturedAt: s.capturedAt,
        rawPayload: s.rawPayload,
        signals:    extractFeatureSignals(s.rawPayload),
      }));
      const { pairs: simPairs } = computeSerpSimilarity(simInput);
      const serpSimilaritySum = simPairs.reduce((sum, p) => sum + p.combinedSimilarity, 0);
      const averageSimilarity = simPairs.length > 0 ? serpSimilaritySum / simPairs.length : 1.0;

      // dominanceDelta -- |last - first|
      let dominanceDelta = 0;
      if (window.length >= 2) {
        const first = computeDomainDominance(window[0].rawPayload);
        const last  = computeDomainDominance(window[window.length - 1].rawPayload);
        const di0   = first.dominanceIndex ?? 0;
        const di1   = last.dominanceIndex  ?? 0;
        dominanceDelta = Math.abs(di1 - di0);
      }

      timelineInputs.push({
        snapshotId:             snap.id,
        capturedAt:             snap.capturedAt.toISOString(),
        volatilityScore:        volProfile.volatilityScore,
        averageSimilarity,
        intentDriftEventCount:  intentTransitions.length,
        featureTransitionCount: featSummary.transitionCount,
        dominanceDelta,
        aiOverviewChurnCount:   volProfile.aiOverviewChurn,
      });
    }

    // ── SIL-13: event timeline ────────────────────────────────────────────────
    const timeline = computeEventTimeline(timelineInputs);

    // ── SIL-14: causality detection ───────────────────────────────────────────
    const patterns = computeEventCausality(timeline);

    return successResponse({
      keywordTargetId: id,
      query,
      locale,
      device,
      timelineCount:  timeline.length,
      patternCount:   patterns.length,
      patterns,
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/event-causality error:", err);
    return serverError();
  }
}
