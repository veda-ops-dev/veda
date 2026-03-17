/**
 * keyword-overview.ts -- SIL-15 Keyword Overview Surface (pure library)
 *
 * Pure function. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Accepts pre-fetched snapshots (ordered capturedAt ASC, id ASC) and keyword
 * metadata. Delegates to existing SIL sensors. Returns a composite overview
 * payload suitable for operators, VS Code extension, and LLM reasoning.
 *
 * Caller responsibilities:
 *   - Provide snapshots ordered capturedAt ASC, id ASC (invariant).
 *   - rawPayload must be included on each snapshot.
 *   - latestSnapshot is derived from the LAST element of the sorted input.
 */

import { computeVolatility, classifyRegime, classifyMaturity } from "@/lib/seo/volatility-service";
import type { SnapshotForVolatility } from "@/lib/seo/volatility-service";
import { computeChangeClassification } from "@/lib/seo/change-classification";
import type { ChangeClassificationInput, ChangeClassificationResult } from "@/lib/seo/change-classification";
import { computeEventTimeline } from "@/lib/seo/event-timeline";
import type { TimelineEvent, TimelineSnapshotInput } from "@/lib/seo/event-timeline";
import { computeEventCausality } from "@/lib/seo/event-causality";
import type { EventCausalityPattern } from "@/lib/seo/event-causality";
import { computeIntentDrift } from "@/lib/seo/intent-drift";
import type { IntentDriftResult } from "@/lib/seo/intent-drift";
import { computeFeatureVolatility } from "@/lib/seo/feature-volatility";
import type { FeatureVolatilitySummary } from "@/lib/seo/feature-volatility";
import { computeDomainDominance } from "@/lib/seo/domain-dominance";
import type { DomainDominanceSummary } from "@/lib/seo/domain-dominance";
import { computeSerpSimilarity } from "@/lib/seo/serp-similarity";
import type { SerpSimilarityResult } from "@/lib/seo/serp-similarity";
import { extractFeatureSignals } from "@/lib/seo/serp-extraction";
import type { FeatureSignals } from "@/lib/seo/serp-extraction";

// =============================================================================
// Input types
// =============================================================================

export interface OverviewSnapshot {
  id:               string;
  capturedAt:       Date;
  aiOverviewStatus: string;
  rawPayload:       unknown;
}

export interface KeywordOverviewInput {
  keywordTargetId: string;
  query:           string;
  locale:          string;
  device:          string;
  snapshots:       OverviewSnapshot[]; // MUST be sorted capturedAt ASC, id ASC
}

// =============================================================================
// Output types
// =============================================================================

export interface LatestSnapshotSummary {
  id:                string;
  capturedAt:        string;
  rank:              number | null;
  aiOverviewPresent: boolean;
  featureFamilies:   string[];
  topDomains:        { domain: string; count: number }[];
}

export interface VolatilityOverview {
  score:     number;
  regime:    string;
  maturity:  string;
  sampleSize: number;
  components: {
    rank:       number;
    aiOverview: number;
    feature:    number;
  };
}

export interface KeywordOverviewResult {
  keywordTargetId:   string;
  query:             string;
  locale:            string;
  device:            string;
  snapshotCount:     number;
  latestSnapshot:    LatestSnapshotSummary | null;
  volatility:        VolatilityOverview;
  classification:    ChangeClassificationResult;
  timeline:          TimelineEvent[];
  causality:         EventCausalityPattern[];
  intentDrift:       IntentDriftResult;
  featureVolatility: FeatureVolatilitySummary;
  domainDominance:   DomainDominanceSummary;
  serpSimilarity:    SerpSimilarityResult;
}

// =============================================================================
// Internal helpers
// =============================================================================

function extractRankFromPayload(rawPayload: unknown): number | null {
  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return null;
  }
  const p = rawPayload as Record<string, unknown>;

  // DataForSEO: first organic item by rank_absolute
  if (Array.isArray(p.items)) {
    const organics = (p.items as unknown[])
      .filter(
        (item): item is Record<string, unknown> =>
          item !== null &&
          typeof item === "object" &&
          !Array.isArray(item) &&
          (item as Record<string, unknown>).type === "organic" &&
          typeof (item as Record<string, unknown>).rank_absolute === "number"
      )
      .sort((a, b) => (a.rank_absolute as number) - (b.rank_absolute as number));
    if (organics.length > 0) return organics[0].rank_absolute as number;
  }

  // Simple results[] with rank field
  if (Array.isArray(p.results)) {
    const ranked = (p.results as unknown[])
      .filter(
        (item): item is Record<string, unknown> =>
          item !== null &&
          typeof item === "object" &&
          !Array.isArray(item) &&
          typeof (item as Record<string, unknown>).rank === "number"
      )
      .sort((a, b) => (a.rank as number) - (b.rank as number));
    if (ranked.length > 0) return ranked[0].rank as number;
  }

  return null;
}

// =============================================================================
// Public entry point
// =============================================================================

/**
 * buildKeywordOverview -- pure, deterministic composite overview.
 *
 * Input snapshots MUST be ordered capturedAt ASC, id ASC.
 * Returns a fully populated KeywordOverviewResult.
 * All sensor calls are delegated — no logic is duplicated here.
 */
export function buildKeywordOverview(input: KeywordOverviewInput): KeywordOverviewResult {
  const { keywordTargetId, query, locale, device, snapshots } = input;

  // ── Shared signal extraction ───────────────────────────────────────────────
  // Extract feature signals once per snapshot; reused by multiple sensors.
  const signalsPerSnapshot: FeatureSignals[] = snapshots.map((s) =>
    extractFeatureSignals(s.rawPayload)
  );

  // ── 1. Volatility (SIL-3) ─────────────────────────────────────────────────
  const volSnapshots: SnapshotForVolatility[] = snapshots.map((s) => ({
    id:               s.id,
    capturedAt:       s.capturedAt,
    aiOverviewStatus: s.aiOverviewStatus,
    rawPayload:       s.rawPayload,
  }));
  const volProfile = computeVolatility(volSnapshots);

  const volatility: VolatilityOverview = {
    score:     volProfile.volatilityScore,
    regime:    classifyRegime(volProfile.volatilityScore),
    maturity:  classifyMaturity(volProfile.sampleSize),
    sampleSize: volProfile.sampleSize,
    components: {
      rank:       volProfile.rankVolatilityComponent,
      aiOverview: volProfile.aiOverviewComponent,
      feature:    volProfile.featureVolatilityComponent,
    },
  };

  // ── 2. SERP Similarity (SIL sensor) ───────────────────────────────────────
  const serpSimilarity = computeSerpSimilarity(
    snapshots.map((s, i) => ({
      snapshotId: s.id,
      capturedAt: s.capturedAt,
      rawPayload: s.rawPayload,
      signals:    signalsPerSnapshot[i],
    }))
  );

  // ── 3. Domain Dominance (latest snapshot, point-in-time) ───────────────────
  // NOTE: domainDominance in the response reflects the LATEST snapshot only.
  // It is not an aggregate across all snapshots. The dominanceDelta used for
  // change classification (first vs. last dominanceIndex) is a separate scalar
  // computed below and is not surfaced as its own response field.
  const domainDominance: DomainDominanceSummary =
    snapshots.length > 0
      ? computeDomainDominance(snapshots[snapshots.length - 1].rawPayload)
      : { totalResults: 0, uniqueDomains: 0, dominanceIndex: null, topDomains: [] };

  // ── 4. Intent Drift ───────────────────────────────────────────────────────
  const intentDrift = computeIntentDrift(
    snapshots.map((s, i) => ({
      snapshotId: s.id,
      capturedAt: s.capturedAt,
      signals:    signalsPerSnapshot[i],
    }))
  );

  // ── 5. Feature Volatility ─────────────────────────────────────────────────
  const featureVolResult = computeFeatureVolatility(
    snapshots.map((s, i) => ({
      snapshotId:     s.id,
      capturedAt:     s.capturedAt,
      familiesSorted: signalsPerSnapshot[i].familiesSorted,
    }))
  );
  const featureVolatility = featureVolResult.summary;

  // ── 6. Change Classification (SIL-12) ─────────────────────────────────────
  // Derive aggregate signals across all pairs for classification input.
  const averageSimilarity =
    serpSimilarity.pairCount > 0
      ? serpSimilarity.pairs.reduce((sum, p) => sum + p.combinedSimilarity, 0) /
        serpSimilarity.pairCount
      : 1.0;

  const dominanceDelta = (() => {
    if (snapshots.length < 2) return 0;
    const first = computeDomainDominance(snapshots[0].rawPayload);
    const last  = computeDomainDominance(snapshots[snapshots.length - 1].rawPayload);
    const fi = first.dominanceIndex ?? 0;
    const li = last.dominanceIndex  ?? 0;
    return Math.abs(li - fi);
  })();

  const classificationInput: ChangeClassificationInput = {
    volatilityScore:        volProfile.volatilityScore,
    averageSimilarity,
    intentDriftEventCount:  intentDrift.transitions.length,
    featureTransitionCount: featureVolatility.transitionCount,
    dominanceDelta,
    aiOverviewChurnCount:   volProfile.aiOverviewChurn,
  };
  const classification = computeChangeClassification(classificationInput);

  // ── 7. Event Timeline (SIL-13) ────────────────────────────────────────────
  // Build per-snapshot signal inputs for timeline.
  // For timeline, each snapshot needs its own local pair signals.
  // We compute rolling metrics from available pair data.
  const timelineInputs: TimelineSnapshotInput[] = snapshots.map((snap, idx) => {
    // Derive per-snapshot approximation from available pair data at that index.
    // Use cumulative pairs up to and including this snapshot for a rolling view.
    const pairsUpTo = serpSimilarity.pairs.slice(0, Math.max(0, idx));
    const localSimilarity =
      pairsUpTo.length > 0
        ? pairsUpTo.reduce((s, p) => s + p.combinedSimilarity, 0) / pairsUpTo.length
        : 1.0;

    const localFeatTrans = featureVolResult.transitions
      .filter((t) => new Date(t.capturedAt) <= snap.capturedAt)
      .length;

    const localIntentTrans = intentDrift.transitions
      .filter((t) => new Date(t.capturedAt) <= snap.capturedAt)
      .length;

    const localDomDelta = (() => {
      if (idx === 0) return 0;
      const first = computeDomainDominance(snapshots[0].rawPayload);
      const curr  = computeDomainDominance(snap.rawPayload);
      const fi = first.dominanceIndex ?? 0;
      const ci = curr.dominanceIndex  ?? 0;
      return Math.abs(ci - fi);
    })();

    // Cumulative volatility up to this snapshot
    const snapSubset = snapshots.slice(0, idx + 1);
    const subVol = computeVolatility(
      snapSubset.map((s) => ({
        id: s.id,
        capturedAt: s.capturedAt,
        aiOverviewStatus: s.aiOverviewStatus,
        rawPayload: s.rawPayload,
      }))
    );

    const aiChurnUpTo = subVol.aiOverviewChurn;

    return {
      snapshotId:             snap.id,
      capturedAt:             snap.capturedAt.toISOString(),
      volatilityScore:        subVol.volatilityScore,
      averageSimilarity:      localSimilarity,
      intentDriftEventCount:  localIntentTrans,
      featureTransitionCount: localFeatTrans,
      dominanceDelta:         localDomDelta,
      aiOverviewChurnCount:   aiChurnUpTo,
    };
  });

  const timeline = computeEventTimeline(timelineInputs);

  // ── 8. Event Causality (SIL-14) ───────────────────────────────────────────
  const causality = computeEventCausality(timeline);

  // ── 9. Latest Snapshot Summary (compact) ──────────────────────────────────
  let latestSnapshot: LatestSnapshotSummary | null = null;
  if (snapshots.length > 0) {
    const last = snapshots[snapshots.length - 1];
    const lastSignals = signalsPerSnapshot[signalsPerSnapshot.length - 1];
    const lastDominance = computeDomainDominance(last.rawPayload);

    latestSnapshot = {
      id:                last.id,
      capturedAt:        last.capturedAt.toISOString(),
      rank:              extractRankFromPayload(last.rawPayload),
      aiOverviewPresent: last.aiOverviewStatus === "present",
      featureFamilies:   lastSignals.familiesSorted, // already sorted ASC
      // topDomains: deterministic (count DESC, domain ASC) from domainDominance on latest
      topDomains: lastDominance.topDomains.slice(0, 5), // compact: top 5 only
    };
  }

  return {
    keywordTargetId,
    query,
    locale,
    device,
    snapshotCount: snapshots.length,
    latestSnapshot,
    volatility,
    classification,
    timeline,
    causality,
    intentDrift,
    featureVolatility,
    domainDominance,
    serpSimilarity,
  };
}
