/**
 * serp-keyword-impact.ts -- SIL-22 + SIL-23: Keyword Impact Ranking and
 * Alert-Affected Keyword Set (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * SIL-22: Ranks project keywords by strength of impact from the current
 * SERP climate disturbance using a weighted signal model.
 *
 * SIL-23: Derives the subset of keywords most likely driving the active
 * alert packet from the impact ranking.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SIL-22 IMPACT SCORING MODEL
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Base score (0–100) = weighted sum of four normalized signals:
 *
 *   volatility      0.30 × volatilityScore / 100
 *   rank_shift      0.30 × min(averageRankShift, 20) / 20
 *   ai_overview     0.20 × min(aiOverviewChurn, 10) / 10  (count of flips)
 *   feature_vol     0.20 × min(featureVolatility, 20) / 20
 *
 * Driver-specific multipliers (applied after base score):
 *
 *   ai_overview_expansion      → w(ai_overview)=0.40, w(feature_vol)=0.30, w(volatility)=0.20, w(rank_shift)=0.10
 *   competitor_dominance_shift → w(rank_shift)=0.40,  w(dominance)=0.30,   w(volatility)=0.20, w(ai_overview)=0.10
 *   intent_reclassification    → w(intent_drift)=0.40, w(volatility)=0.30, w(rank_shift)=0.20, w(ai_overview)=0.10
 *   feature_regime_shift       → w(feature_vol)=0.40, w(ai_overview)=0.30, w(volatility)=0.20, w(rank_shift)=0.10
 *   algorithm_shift            → w(volatility)=0.40,  w(rank_shift)=0.40,  w(feature_vol)=0.10, w(ai_overview)=0.10
 *   unknown                    → uniform weights (base score unchanged)
 *
 * Final score: Math.round(driverWeightedScore * 100), clamped to [0, 100].
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SIL-23 SELECTION RULES
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   Take top-N keywords (up to 5) from impact ranking.
 *   Filter to those whose supportingSignals align with the active driver.
 *   If fewer than 2 pass the filter, fall back to top-5 by impactScore.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SORT ORDERS
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   Impact ranking: impactScore DESC, query ASC, keywordTargetId ASC
 *   Affected keywords: impactScore DESC, query ASC, keywordTargetId ASC
 */

import type { SerpEventAttribution, AttributionCause } from "@/lib/seo/serp-event-attribution";
import type { SerpWeatherAlertResult } from "@/lib/seo/serp-weather-alerts";

// ─────────────────────────────────────────────────────────────────────────────
// Input type
// ─────────────────────────────────────────────────────────────────────────────

/** Per-keyword enriched signal set assembled by the route. */
export interface KeywordImpactInput {
  keywordTargetId: string;
  query: string;
  /** From computeVolatility().volatilityScore */
  volatilityScore: number;
  /** From computeVolatility().averageRankShift */
  averageRankShift: number;
  /** From computeVolatility().aiOverviewChurn */
  aiOverviewChurn: number;
  /** From computeVolatility().featureVolatility */
  featureVolatility: number;
  /** True when computeIntentDrift() produced >= 1 transition */
  hasIntentDrift: boolean;
  /** True when dominanceIndex shifted >= 0.20 between oldest and newest snapshot */
  hasDominanceShift: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// Output types
// ─────────────────────────────────────────────────────────────────────────────

export type ImpactDriver =
  | "ai_overview_expansion"
  | "feature_regime_shift"
  | "competitor_dominance_shift"
  | "intent_reclassification"
  | "algorithm_shift"
  | "unknown";

export interface SerpKeywordImpactResult {
  keywordTargetId: string;
  query: string;
  impactScore: number;
  primaryDriver: ImpactDriver;
  supportingSignals: string[];
}

export interface AlertAffectedKeyword {
  keywordTargetId: string;
  query: string;
  impactScore: number;
  reason: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver weight tables
// ─────────────────────────────────────────────────────────────────────────────

interface SignalWeights {
  volatility:    number;
  rank_shift:    number;
  ai_overview:   number;
  feature_vol:   number;
  intent_drift:  number;
  dominance:     number;
}

const DRIVER_WEIGHTS: Record<AttributionCause, SignalWeights> = {
  ai_overview_expansion: {
    volatility:   0.20,
    rank_shift:   0.10,
    ai_overview:  0.40,
    feature_vol:  0.30,
    intent_drift: 0.00,
    dominance:    0.00,
  },
  competitor_dominance_shift: {
    volatility:   0.20,
    rank_shift:   0.40,
    ai_overview:  0.10,
    feature_vol:  0.00,
    intent_drift: 0.00,
    dominance:    0.30,
  },
  intent_reclassification: {
    volatility:   0.30,
    rank_shift:   0.20,
    ai_overview:  0.10,
    feature_vol:  0.00,
    intent_drift: 0.40,
    dominance:    0.00,
  },
  feature_regime_shift: {
    volatility:   0.20,
    rank_shift:   0.10,
    ai_overview:  0.30,
    feature_vol:  0.40,
    intent_drift: 0.00,
    dominance:    0.00,
  },
  algorithm_shift: {
    volatility:   0.40,
    rank_shift:   0.40,
    ai_overview:  0.10,
    feature_vol:  0.10,
    intent_drift: 0.00,
    dominance:    0.00,
  },
  unknown: {
    volatility:   0.25,
    rank_shift:   0.25,
    ai_overview:  0.25,
    feature_vol:  0.25,
    intent_drift: 0.00,
    dominance:    0.00,
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Reason strings (deterministic lookup table)
// ─────────────────────────────────────────────────────────────────────────────

const REASON_TABLE: Record<AttributionCause, Record<string, string>> = {
  ai_overview_expansion: {
    ai_overview_churn: "High AI overview churn during active AI overview surge.",
    feature_volatility: "Elevated feature volatility during AI overview expansion.",
    default: "Elevated volatility during AI overview expansion.",
  },
  competitor_dominance_shift: {
    rank_shift: "Strong rank shift during competitor dominance disturbance.",
    dominance_shift: "Domain dominance change during competitor shift event.",
    default: "Elevated rank turbulence during competitor dominance shift.",
  },
  intent_reclassification: {
    intent_drift: "Intent drift detected during active reclassification event.",
    classification: "Elevated classification signal during intent reclassification.",
    default: "Elevated volatility during intent reclassification.",
  },
  feature_regime_shift: {
    feature_volatility: "High feature volatility during active feature regime shift.",
    ai_overview_churn: "AI overview churn during feature regime shift event.",
    default: "Elevated volatility during feature regime shift.",
  },
  algorithm_shift: {
    rank_shift: "Elevated volatility during algorithm-shift pattern.",
    volatility: "Elevated volatility during algorithm-shift pattern.",
    default: "Elevated volatility during algorithm-shift pattern.",
  },
  unknown: {
    default: "Elevated volatility during mixed SERP disturbance.",
  },
};

function buildReason(
  cause: AttributionCause,
  supportingSignals: string[],
): string {
  const table = REASON_TABLE[cause];
  for (const sig of supportingSignals) {
    if (table[sig]) return table[sig];
  }
  return table.default;
}

// ─────────────────────────────────────────────────────────────────────────────
// Normalization helpers
// ─────────────────────────────────────────────────────────────────────────────

function norm(value: number, cap: number): number {
  if (cap === 0) return 0;
  return Math.min(value, cap) / cap;
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-keyword signal normalization and scoring
// ─────────────────────────────────────────────────────────────────────────────

function buildSupportingSignals(
  kw: KeywordImpactInput,
  cause: AttributionCause,
): string[] {
  const signals = new Set<string>();

  if (kw.volatilityScore >= 30)    signals.add("volatility");
  if (kw.averageRankShift >= 3)    signals.add("rank_shift");
  if (kw.aiOverviewChurn >= 1)     signals.add("ai_overview_churn");
  if (kw.featureVolatility >= 2)   signals.add("feature_volatility");
  if (kw.hasIntentDrift)           signals.add("intent_drift");
  if (kw.hasDominanceShift)        signals.add("dominance_shift");

  // Promote classification/event signal for intent and feature drivers
  if (
    (cause === "intent_reclassification" && kw.hasIntentDrift) ||
    (cause === "feature_regime_shift" && kw.featureVolatility >= 2)
  ) {
    signals.add("classification");
  }

  return Array.from(signals).sort((a, b) => a.localeCompare(b));
}

function computeImpactScore(kw: KeywordImpactInput, cause: AttributionCause): number {
  const w = DRIVER_WEIGHTS[cause];

  const nVolatility  = norm(kw.volatilityScore, 100);
  const nRankShift   = norm(kw.averageRankShift, 20);
  const nAiOverview  = norm(kw.aiOverviewChurn, 10);
  const nFeatureVol  = norm(kw.featureVolatility, 20);
  const nIntentDrift = kw.hasIntentDrift ? 1 : 0;
  const nDominance   = kw.hasDominanceShift ? 1 : 0;

  const raw =
    w.volatility   * nVolatility  +
    w.rank_shift   * nRankShift   +
    w.ai_overview  * nAiOverview  +
    w.feature_vol  * nFeatureVol  +
    w.intent_drift * nIntentDrift +
    w.dominance    * nDominance;

  return Math.min(100, Math.max(0, Math.round(raw * 100)));
}

// ─────────────────────────────────────────────────────────────────────────────
// SIL-22: Keyword Impact Ranking
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeSerpKeywordImpactRanking -- rank keywords by SERP climate impact.
 *
 * Pure function. Deterministic. No side effects.
 *
 * Returns top 10 results sorted: impactScore DESC, query ASC, keywordTargetId ASC.
 *
 * @param inputs       Per-keyword enriched signal sets
 * @param attribution  Output of computeSerpEventAttribution()
 */
export function computeSerpKeywordImpactRanking(
  inputs: KeywordImpactInput[],
  attribution: SerpEventAttribution,
): SerpKeywordImpactResult[] {
  const cause = attribution.cause;

  const ranked: SerpKeywordImpactResult[] = inputs.map((kw) => {
    const impactScore      = computeImpactScore(kw, cause);
    const supportingSignals = buildSupportingSignals(kw, cause);

    return {
      keywordTargetId: kw.keywordTargetId,
      query:           kw.query,
      impactScore,
      primaryDriver:   cause as ImpactDriver,
      supportingSignals,
    };
  });

  // Deterministic sort: impactScore DESC, query ASC, id ASC
  ranked.sort((a, b) => {
    if (b.impactScore !== a.impactScore) return b.impactScore - a.impactScore;
    if (a.query !== b.query) return a.query.localeCompare(b.query);
    return a.keywordTargetId.localeCompare(b.keywordTargetId);
  });

  return ranked.slice(0, 10);
}

// ─────────────────────────────────────────────────────────────────────────────
// SIL-23: Alert-Affected Keyword Set
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Signal alignment rules per driver: which supportingSignals make a keyword
 * relevant to the active alert packet.
 */
const DRIVER_PREFERRED_SIGNALS: Record<AttributionCause, string[]> = {
  ai_overview_expansion:      ["ai_overview_churn", "feature_volatility"],
  competitor_dominance_shift: ["rank_shift", "dominance_shift"],
  intent_reclassification:    ["intent_drift", "classification"],
  feature_regime_shift:       ["feature_volatility", "ai_overview_churn"],
  algorithm_shift:            ["rank_shift", "volatility"],
  unknown:                    [],
};

/**
 * selectAlertAffectedKeywords -- derive the keyword subset most likely
 * driving the current alert packet.
 *
 * Pure function. Deterministic. No side effects.
 *
 * Returns up to 5 results sorted: impactScore DESC, query ASC, keywordTargetId ASC.
 *
 * @param rankedKeywords  Output of computeSerpKeywordImpactRanking()
 * @param alerts          Output of computeSerpWeatherAlerts() (pre-sorted)
 * @param attribution     Output of computeSerpEventAttribution()
 */
export function selectAlertAffectedKeywords(
  rankedKeywords: SerpKeywordImpactResult[],
  alerts: SerpWeatherAlertResult[],
  attribution: SerpEventAttribution,
): AlertAffectedKeyword[] {
  void alerts; // alerts accepted for future enrichment; driver resolved from attribution

  const cause = attribution.cause;
  const preferred = DRIVER_PREFERRED_SIGNALS[cause];

  // Filter: keywords whose supportingSignals overlap with preferred set
  let filtered = rankedKeywords.filter((kw) =>
    preferred.length === 0 ||
    kw.supportingSignals.some((s) => preferred.includes(s))
  );

  // Fallback to top-5 by impactScore when fewer than 2 pass the filter
  if (filtered.length < 2) {
    filtered = rankedKeywords.slice(0, 5);
  }

  const top5 = filtered.slice(0, 5);

  // Already sorted by ranking; re-sort for stability (impactScore DESC, query ASC, id ASC)
  top5.sort((a, b) => {
    if (b.impactScore !== a.impactScore) return b.impactScore - a.impactScore;
    if (a.query !== b.query) return a.query.localeCompare(b.query);
    return a.keywordTargetId.localeCompare(b.keywordTargetId);
  });

  return top5.map((kw) => ({
    keywordTargetId: kw.keywordTargetId,
    query:           kw.query,
    impactScore:     kw.impactScore,
    reason:          buildReason(cause, kw.supportingSignals),
  }));
}
