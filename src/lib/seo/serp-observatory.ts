/**
 * serp-observatory.ts — SERP Observatory Layer (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Derives the `serpObservatory` section of the Page Command Center response
 * from pre-fetched, pre-grouped snapshot data. All computation is performed
 * on the same snapshot map already loaded for the volatility pass.
 *
 * Signals computed:
 *   volatilityLevel     — stable | moderate | elevated | high
 *   recentRankTurbulence — boolean (any turbulence event across all keywords)
 *   aiOverviewActivity  — none | present | increasing | volatile
 *   dominantSerpFeatures — top-3 feature families (frequency DESC, family ASC)
 *   recentEvents        — top-3 change-classification events (capturedAt DESC)
 */

import {
  computeVolatility,
  type SnapshotForVolatility,
} from "@/lib/seo/volatility-service";
import { computeChangeClassification } from "@/lib/seo/change-classification";
import { extractFeatureSignals } from "@/lib/seo/serp-extraction";

// ─────────────────────────────────────────────────────────────────────────────
// Input / Output Types
// ─────────────────────────────────────────────────────────────────────────────

/** Minimal snapshot shape needed by this module. */
export interface ObservatorySnapshot {
  id: string;
  capturedAt: Date;
  aiOverviewStatus: string;
  rawPayload: unknown;
}

export type VolatilityLevel = "stable" | "moderate" | "elevated" | "high";

export type AiOverviewActivity = "none" | "present" | "increasing" | "volatile";

export interface ObservatoryRecentEvent {
  classification: string;
  capturedAt: string; // ISO
}

export interface SerpObservatoryResult {
  volatilityLevel: VolatilityLevel;
  recentRankTurbulence: boolean;
  aiOverviewActivity: AiOverviewActivity;
  dominantSerpFeatures: string[];
  recentEvents: ObservatoryRecentEvent[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Map a weighted project volatility score (0–100) to a VolatilityLevel label.
 *
 * Boundaries mirror the regime classification thresholds from classifyRegime(),
 * but use a coarser operator-facing vocabulary:
 *   stable:   0–20   (calm regime)
 *   moderate: 20–40  (lower half of shifting)
 *   elevated: 40–65  (upper half of shifting + lower unstable)
 *   high:     > 65   (upper unstable + chaotic)
 */
function mapVolatilityLevel(weightedScore: number): VolatilityLevel {
  if (weightedScore <= 20) return "stable";
  if (weightedScore <= 40) return "moderate";
  if (weightedScore <= 65) return "elevated";
  return "high";
}

/**
 * Derive AI Overview activity signal from a single keyword's snapshot bucket.
 *
 * Rules (evaluated in order; first match wins):
 *   volatile  — aiOverviewChurn >= 3 in the profile
 *   increasing — more "present" statuses in the second half than first half
 *   present   — any snapshot has aiOverviewStatus === "present"
 *   none      — no "present" statuses observed
 */
function classifyAiActivity(
  snapshots: SnapshotForVolatility[],
  profile: ReturnType<typeof computeVolatility>
): AiOverviewActivity {
  if (snapshots.length === 0) return "none";

  if (profile.aiOverviewChurn >= 3) return "volatile";

  const half = Math.floor(snapshots.length / 2);
  const firstHalf = snapshots.slice(0, half);
  const secondHalf = snapshots.slice(half);

  const countPresent = (arr: SnapshotForVolatility[]) =>
    arr.filter((s) => s.aiOverviewStatus === "present").length;

  if (secondHalf.length > 0 && firstHalf.length > 0) {
    const firstRatio = countPresent(firstHalf) / firstHalf.length;
    const secondRatio = countPresent(secondHalf) / secondHalf.length;
    if (secondRatio > firstRatio) return "increasing";
  }

  const hasPresent = snapshots.some((s) => s.aiOverviewStatus === "present");
  return hasPresent ? "present" : "none";
}

/**
 * Derive an AI Overview activity signal across all keyword buckets.
 *
 * Priority order: volatile > increasing > present > none.
 */
function mergeAiActivity(activities: AiOverviewActivity[]): AiOverviewActivity {
  if (activities.includes("volatile")) return "volatile";
  if (activities.includes("increasing")) return "increasing";
  if (activities.includes("present")) return "present";
  return "none";
}

/**
 * Derive turbulence boolean from a VolatilityProfile.
 *
 * True when:
 *   - aiOverviewChurn >= 1 (any AI Overview flip), OR
 *   - maxRankShift > 5 (any single rank movement > 5 positions), OR
 *   - featureVolatility >= 2 (at least 2 feature type changes across pairs)
 */
function hasTurbulence(
  profile: ReturnType<typeof computeVolatility>
): boolean {
  return (
    profile.aiOverviewChurn >= 1 ||
    profile.maxRankShift > 5 ||
    profile.featureVolatility >= 2
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeSerpObservatory — derive all observatory signals from snapshot buckets.
 *
 * @param snapshotBuckets  Map of naturalKey → snapshots[] pre-sorted capturedAt ASC, id ASC.
 *                         Same map already computed in the PCC route for volatility.
 *
 * Returns a fully-populated SerpObservatoryResult.
 * Returns a zero-signal result when the map is empty.
 */
export function computeSerpObservatory(
  snapshotBuckets: Map<string, ObservatorySnapshot[]>
): SerpObservatoryResult {
  const ZERO: SerpObservatoryResult = {
    volatilityLevel: "stable",
    recentRankTurbulence: false,
    aiOverviewActivity: "none",
    dominantSerpFeatures: [],
    recentEvents: [],
  };

  if (snapshotBuckets.size === 0) return ZERO;

  // ── Per-bucket signals ────────────────────────────────────────────────────
  const allScores: number[] = [];
  const allActivities: AiOverviewActivity[] = [];
  let anyTurbulence = false;

  // Feature frequency accumulator: family -> appearance count across all snapshots
  const featureFreq = new Map<string, number>();

  // Event accumulator: { classification, capturedAt (Date) }
  interface RawEvent {
    classification: string;
    capturedAt: Date;
  }
  const allEvents: RawEvent[] = [];

  for (const [, snapshots] of snapshotBuckets) {
    if (snapshots.length === 0) continue;

    // Cast to SnapshotForVolatility (same shape)
    const forVol: SnapshotForVolatility[] = snapshots.map((s) => ({
      id: s.id,
      capturedAt: s.capturedAt,
      aiOverviewStatus: s.aiOverviewStatus,
      rawPayload: s.rawPayload,
    }));

    const profile = computeVolatility(forVol);

    // Volatility score accumulation
    if (profile.sampleSize >= 1) {
      allScores.push(profile.volatilityScore);
    }

    // AI Overview activity
    allActivities.push(classifyAiActivity(forVol, profile));

    // Turbulence
    if (profile.sampleSize >= 1 && hasTurbulence(profile)) {
      anyTurbulence = true;
    }

    // ── Feature frequency ───────────────────────────────────────────────────
    // Count each feature family observed in any snapshot in this bucket
    for (const snap of snapshots) {
      const signals = extractFeatureSignals(snap.rawPayload);
      for (const family of signals.familiesSorted) {
        featureFreq.set(family, (featureFreq.get(family) ?? 0) + 1);
      }
    }

    // ── Change classification events ────────────────────────────────────────
    // Run classifier over each consecutive pair and emit transitions (de-dup consecutive same)
    if (forVol.length >= 2) {
      let lastClassification: string | null = null;

      for (let i = 1; i < forVol.length; i++) {
        const from = forVol[i - 1];
        const to = forVol[i];

        // Compute pairwise signals for the classifier
        // We reuse the profile's averaged values as proxies for per-pair invocation.
        // For event classification we compute a simplified per-pair view:
        //   aiOverviewChurnCount = 1 if status flipped, else 0
        //   featureTransitionCount = feature symmetric difference size
        //   volatilityScore = keyword-level score (stable proxy)
        const aiFlipped = from.aiOverviewStatus !== to.aiOverviewStatus ? 1 : 0;

        const fromFeats = extractFeatureSignals(from.rawPayload).familiesSorted;
        const toFeats = extractFeatureSignals(to.rawPayload).familiesSorted;
        const fromSet = new Set(fromFeats);
        const toSet = new Set(toFeats);
        let featureDiff = 0;
        for (const f of fromFeats) { if (!toSet.has(f)) featureDiff++; }
        for (const f of toFeats) { if (!fromSet.has(f)) featureDiff++; }

        const cls = computeChangeClassification({
          volatilityScore: profile.volatilityScore,
          averageSimilarity: 0.5, // neutral similarity — we don't load full similarity here
          intentDriftEventCount: 0, // not available at this layer
          featureTransitionCount: featureDiff,
          dominanceDelta: 0, // not available at this layer
          aiOverviewChurnCount: aiFlipped,
        });

        // Only emit on transition (de-dup consecutive same classification)
        if (cls.classification !== lastClassification) {
          allEvents.push({
            classification: cls.classification,
            capturedAt: to.capturedAt,
          });
          lastClassification = cls.classification;
        }
      }
    }
  }

  // ── Aggregate volatilityLevel ─────────────────────────────────────────────
  let weightedScore = 0;
  if (allScores.length > 0) {
    weightedScore = allScores.reduce((s, v) => s + v, 0) / allScores.length;
  }
  const volatilityLevel = mapVolatilityLevel(weightedScore);

  // ── Dominant SERP features ────────────────────────────────────────────────
  // Sort: frequency DESC, family ASC; top 3; exclude "other"
  const dominantSerpFeatures = Array.from(featureFreq.entries())
    .filter(([family]) => family !== "other")
    .sort(([familyA, freqA], [familyB, freqB]) => {
      if (freqB !== freqA) return freqB - freqA;
      return familyA.localeCompare(familyB);
    })
    .slice(0, 3)
    .map(([family]) => family);

  // ── Recent events ─────────────────────────────────────────────────────────
  // Sort: capturedAt DESC (newest first), id would be ideal tie-breaker but we
  // only have Date objects here; use ISO string DESC + classification ASC as
  // deterministic tie-breaker.
  allEvents.sort((a, b) => {
    const tA = a.capturedAt.getTime();
    const tB = b.capturedAt.getTime();
    if (tB !== tA) return tB - tA;
    return a.classification.localeCompare(b.classification);
  });

  // Exclude "stable" events from the recent-events list — they are not signal events.
  const recentEvents = allEvents
    .filter((e) => e.classification !== "stable")
    .slice(0, 3)
    .map((e) => ({
      classification: e.classification,
      capturedAt: e.capturedAt.toISOString(),
    }));

  return {
    volatilityLevel,
    recentRankTurbulence: anyTurbulence,
    aiOverviewActivity: mergeAiActivity(allActivities),
    dominantSerpFeatures,
    recentEvents,
  };
}
