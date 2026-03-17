/**
 * serp-event-attribution.ts -- SIL-17: SERP Event Attribution (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Correlates SIL-16 disturbance signals with SIL-15 observatory signals and
 * per-keyword intent / dominance signals to identify the most likely cause
 * of a detected search ecosystem event.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * ATTRIBUTION CATEGORIES
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   ai_overview_expansion      AI Overviews expanding across informational queries
 *   feature_regime_shift       Structural SERP format change (non-AI Overview)
 *   competitor_dominance_shift One or more domains capturing position at scale
 *   intent_reclassification    Google re-categorising query intent across cluster
 *   algorithm_shift            Broad rank movement without clear structural cause
 *   unknown                    Signals conflict or insufficient data
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DETERMINISTIC RULE PRIORITY (evaluated in order; first match wins)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   1. ai_overview_expansion
 *      aiOverviewActivity ∈ {increasing, volatile}
 *      AND dominantNewFeatures includes "ai_overview" OR aiOverviewActivity=volatile
 *      AND volatilityCluster = true
 *      Confidence base: 55  +10 per supporting signal (max 3 extras)
 *
 *   2. intent_reclassification
 *      intentDriftCount >= intentDriftThreshold (>= 30% of active keywords)
 *      AND volatilityCluster = true
 *      Confidence base: 50  +10 per supporting signal
 *
 *   3. competitor_dominance_shift
 *      dominanceShiftCount >= dominanceShiftThreshold (>= 30% of active keywords)
 *      AND rankingTurbulence = true
 *      Confidence base: 50  +10 per supporting signal
 *
 *   4. feature_regime_shift
 *      featureShiftDetected = true
 *      AND "ai_overview" NOT in dominantNewFeatures
 *      Confidence base: 55  +10 per supporting signal
 *
 *   5. algorithm_shift
 *      volatilityCluster = true
 *      AND rankingTurbulence = true
 *      AND featureShiftDetected = false
 *      AND intentDriftCount < intentDriftThreshold
 *      Confidence base: 45  +10 per supporting signal
 *
 *   fallback: unknown (confidence 0, no supporting signals)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * CONFIDENCE CALCULATION
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   confidence = base + (10 × number_of_supporting_signals_beyond_primary)
 *   Capped at 95. Minimum for any named cause is 45.
 *   "unknown" always returns confidence 0.
 *
 *   Supporting signal tokens are deterministic string keys included in the
 *   supportingSignals[] array — always sorted ASC for stable output.
 */

import type { SerpDisturbanceResult } from "@/lib/seo/serp-disturbance";
import type { SerpObservatoryResult } from "@/lib/seo/serp-observatory";

// ─────────────────────────────────────────────────────────────────────────────
// Input types
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Per-keyword signals derived from existing observatory computations.
 * Callers assemble this from intent-drift and domain-dominance passes
 * that are already performed in the route.
 */
export interface KeywordSignalSet {
  keywordTargetId: string;
  /** True when intent drift produced >= 1 transition for this keyword. */
  hasIntentDrift: boolean;
  /**
   * True when the top domain's dominanceIndex changed by >= 0.20 between
   * the oldest and newest snapshot for this keyword.
   */
  hasDominanceShift: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// Output types
// ─────────────────────────────────────────────────────────────────────────────

export type AttributionCause =
  | "ai_overview_expansion"
  | "feature_regime_shift"
  | "competitor_dominance_shift"
  | "intent_reclassification"
  | "algorithm_shift"
  | "unknown";

export interface SerpEventAttribution {
  cause: AttributionCause;
  /** Weighted heuristic confidence 0–95. Always 0 for "unknown". */
  confidence: number;
  /** Deterministic string tokens that supported this classification, sorted ASC. */
  supportingSignals: string[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Thresholds
// ─────────────────────────────────────────────────────────────────────────────

/** Fraction of active keywords required to declare intent drift cluster. */
const INTENT_DRIFT_FRACTION = 0.30;

/** Fraction of active keywords required to declare dominance shift cluster. */
const DOMINANCE_SHIFT_FRACTION = 0.30;

/** Confidence base scores per cause (before supporting-signal bonus). */
const CONFIDENCE_BASE: Record<AttributionCause, number> = {
  ai_overview_expansion:     55,
  feature_regime_shift:      55,
  competitor_dominance_shift: 50,
  intent_reclassification:   50,
  algorithm_shift:           45,
  unknown:                   0,
};

/** Points added per additional supporting signal (beyond the required minimum). */
const SIGNAL_BONUS = 10;

/** Maximum confidence for any non-unknown cause. */
const CONFIDENCE_MAX = 95;

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

function calcConfidence(cause: AttributionCause, bonusSignalCount: number): number {
  if (cause === "unknown") return 0;
  const raw = CONFIDENCE_BASE[cause] + bonusSignalCount * SIGNAL_BONUS;
  return Math.min(raw, CONFIDENCE_MAX);
}

function sortedSignals(signals: string[]): string[] {
  return signals.slice().sort((a, b) => a.localeCompare(b));
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeSerpEventAttribution
 *
 * All three inputs are required but may carry zero-signal values.
 * Returns a deterministic SerpEventAttribution for any given input set.
 *
 * @param disturbance   Output of computeSerpDisturbances()
 * @param observatory   Output of computeSerpObservatory()
 * @param keywordSignals  Per-keyword intent-drift and dominance-shift signals
 */
export function computeSerpEventAttribution(
  disturbance: SerpDisturbanceResult,
  observatory: SerpObservatoryResult,
  keywordSignals: KeywordSignalSet[]
): SerpEventAttribution {
  const UNKNOWN: SerpEventAttribution = {
    cause: "unknown",
    confidence: 0,
    supportingSignals: [],
  };

  // ── Pre-compute cluster metrics ─────────────────────────────────────────
  const activeCount = keywordSignals.length;

  const intentDriftCount = keywordSignals.filter((k) => k.hasIntentDrift).length;
  const dominanceShiftCount = keywordSignals.filter((k) => k.hasDominanceShift).length;

  const intentDriftActive =
    activeCount > 0 && intentDriftCount / activeCount >= INTENT_DRIFT_FRACTION;
  const dominanceShiftActive =
    activeCount > 0 && dominanceShiftCount / activeCount >= DOMINANCE_SHIFT_FRACTION;

  const aiOverviewRising =
    observatory.aiOverviewActivity === "increasing" ||
    observatory.aiOverviewActivity === "volatile";

  const aiInNewFeatures = disturbance.dominantNewFeatures.some(
    (f) => f === "ai_overview"
  );

  // ── Rule 1: AI Overview Expansion ──────────────────────────────────────
  if (
    aiOverviewRising &&
    (aiInNewFeatures || observatory.aiOverviewActivity === "volatile") &&
    disturbance.volatilityCluster
  ) {
    const signals: string[] = ["volatility_cluster"];

    if (observatory.aiOverviewActivity === "increasing") {
      signals.push("ai_overview_activity_increasing");
    } else {
      signals.push("ai_overview_activity_volatile");
    }
    if (disturbance.featureShiftDetected) signals.push("feature_shift_detected");
    if (aiInNewFeatures)                  signals.push("ai_overview_in_new_features");
    if (disturbance.rankingTurbulence)    signals.push("ranking_turbulence");
    if (intentDriftActive)                signals.push("intent_drift_cluster");

    // Primary signals required: volatility_cluster + one ai_overview signal
    // Everything beyond those 2 is a bonus
    const bonusCount = Math.max(0, signals.length - 2);

    return {
      cause: "ai_overview_expansion",
      confidence: calcConfidence("ai_overview_expansion", bonusCount),
      supportingSignals: sortedSignals(signals),
    };
  }

  // ── Rule 2: Intent Reclassification ────────────────────────────────────
  if (intentDriftActive && disturbance.volatilityCluster) {
    const signals: string[] = ["intent_drift_cluster", "volatility_cluster"];

    if (disturbance.featureShiftDetected) signals.push("feature_shift_detected");
    if (disturbance.rankingTurbulence)    signals.push("ranking_turbulence");
    if (dominanceShiftActive)             signals.push("dominance_shift_cluster");

    const bonusCount = Math.max(0, signals.length - 2);

    return {
      cause: "intent_reclassification",
      confidence: calcConfidence("intent_reclassification", bonusCount),
      supportingSignals: sortedSignals(signals),
    };
  }

  // ── Rule 3: Competitor Dominance Shift ─────────────────────────────────
  if (dominanceShiftActive && disturbance.rankingTurbulence) {
    const signals: string[] = ["dominance_shift_cluster", "ranking_turbulence"];

    if (disturbance.volatilityCluster)    signals.push("volatility_cluster");
    if (disturbance.featureShiftDetected) signals.push("feature_shift_detected");

    const bonusCount = Math.max(0, signals.length - 2);

    return {
      cause: "competitor_dominance_shift",
      confidence: calcConfidence("competitor_dominance_shift", bonusCount),
      supportingSignals: sortedSignals(signals),
    };
  }

  // ── Rule 4: Feature Regime Shift ───────────────────────────────────────
  if (disturbance.featureShiftDetected && !aiInNewFeatures) {
    const signals: string[] = ["feature_shift_detected"];

    if (disturbance.dominantNewFeatures.length > 0) {
      signals.push("dominant_new_features_present");
    }
    if (disturbance.volatilityCluster)    signals.push("volatility_cluster");
    if (disturbance.rankingTurbulence)    signals.push("ranking_turbulence");
    if (intentDriftActive)                signals.push("intent_drift_cluster");

    const bonusCount = Math.max(0, signals.length - 1);

    return {
      cause: "feature_regime_shift",
      confidence: calcConfidence("feature_regime_shift", bonusCount),
      supportingSignals: sortedSignals(signals),
    };
  }

  // ── Rule 5: Algorithm Shift ─────────────────────────────────────────────
  if (
    disturbance.volatilityCluster &&
    disturbance.rankingTurbulence &&
    !disturbance.featureShiftDetected &&
    !intentDriftActive
  ) {
    const signals: string[] = ["ranking_turbulence", "volatility_cluster"];

    if (observatory.recentRankTurbulence) signals.push("observatory_rank_turbulence");
    if (dominanceShiftActive)             signals.push("dominance_shift_cluster");

    const bonusCount = Math.max(0, signals.length - 2);

    return {
      cause: "algorithm_shift",
      confidence: calcConfidence("algorithm_shift", bonusCount),
      supportingSignals: sortedSignals(signals),
    };
  }

  // ── Fallback: Unknown ───────────────────────────────────────────────────
  return UNKNOWN;
}
