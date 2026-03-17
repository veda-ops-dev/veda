/**
 * change-classification.ts -- SIL-12 SERP Change Classification (pure library)
 *
 * Pure function. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Combines signals from existing sensors to classify the type of SERP event
 * occurring for a keyword. Produces a single classification + confidence score
 * for operator consumption.
 *
 * Classification rules (evaluated in priority order; highest confidence wins
 * when multiple rules match; tie-break by classification name ASC):
 *
 *   algorithm_shift        volatilityScore >= 60   AND averageSimilarity <= 0.45
 *   competitor_surge       dominanceDelta  >= 0.30 AND volatilityScore >= 40
 *   intent_shift           intentDriftEventCount >= 2  AND averageSimilarity <= 0.60
 *   feature_turbulence     featureTransitionCount >= 3 AND volatilityScore >= 30
 *   ai_overview_disruption aiOverviewChurnCount >= 2   AND volatilityScore >= 35
 *   stable                 none of the above
 *
 * Confidence scaling:
 *   For each matching rule, confidence = 50 + 50 * mean(overage ratios per condition),
 *   where overage ratio = how far the input exceeds the threshold, capped at 1.
 *   Caps per signal:
 *     volatilityScore: cap at 100 (natural max)
 *     averageSimilarity below threshold: cap at threshold (0 similarity = max overage)
 *     dominanceDelta: cap at 1.0
 *     intentDriftEventCount: cap at 10
 *     featureTransitionCount: cap at 15
 *     aiOverviewChurnCount: cap at 10
 *   Result rounded to nearest integer, clamped to [50, 100] when a rule fires.
 *   "stable" confidence = 100 - max(signal values normalized to 0-100), min 0.
 */

// =============================================================================
// Types
// =============================================================================

export type ChangeClassificationLabel =
  | "algorithm_shift"
  | "competitor_surge"
  | "intent_shift"
  | "feature_turbulence"
  | "ai_overview_disruption"
  | "stable";

export interface ChangeClassificationSignals {
  volatility:        number;  // volatilityScore 0-100
  similarity:        number;  // mean combined Jaccard 0-1
  intentDrift:       number;  // count of intent transitions
  featureVolatility: number;  // count of feature transitions
  dominanceChange:   number;  // |last dominanceIndex - first dominanceIndex| 0-1
  aiOverviewChurn:   number;  // count of consecutive AI Overview status flips
}

export interface ChangeClassificationResult {
  classification: ChangeClassificationLabel;
  confidence:     number;  // 0-100 integer
  signals:        ChangeClassificationSignals;
}

export interface ChangeClassificationInput {
  volatilityScore:       number;
  averageSimilarity:     number;
  intentDriftEventCount: number;
  featureTransitionCount: number;
  dominanceDelta:        number;
  aiOverviewChurnCount:  number;
}

// =============================================================================
// Internal: threshold constants
// =============================================================================

const T_ALGO_VOLATILITY   = 60;
const T_ALGO_SIMILARITY   = 0.45;
const T_COMP_DOMINANCE    = 0.30;
const T_COMP_VOLATILITY   = 40;
const T_INTENT_EVENTS     = 2;
const T_INTENT_SIMILARITY = 0.60;
const T_FEAT_TRANSITIONS  = 3;
const T_FEAT_VOLATILITY   = 30;
const T_AI_CHURN          = 2;
const T_AI_VOLATILITY     = 35;

// Overage caps — how far above threshold a signal can be before confidence
// saturates at 1.0 for that component.
const CAP_VOLATILITY      = 100;
const CAP_DOMINANCE       = 1.0;
const CAP_INTENT_EVENTS   = 10;
const CAP_FEAT_TRANS      = 15;
const CAP_AI_CHURN        = 10;

function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v));
}

/**
 * overage -- how far a value exceeds a threshold, as a 0-1 ratio.
 * For "value must be >= threshold": overage = (value - threshold) / (cap - threshold)
 * For "value must be <= threshold": overage = (threshold - value) / threshold
 * Returns 0 if the condition is not met (value does not exceed threshold).
 */
function overageAbove(value: number, threshold: number, cap: number): number {
  if (value < threshold) return 0;
  if (cap <= threshold)  return 1;
  return clamp((value - threshold) / (cap - threshold), 0, 1);
}

function overageBelow(value: number, threshold: number): number {
  if (value > threshold) return 0;
  if (threshold === 0)   return 1;
  return clamp((threshold - value) / threshold, 0, 1);
}

/**
 * ruleConfidence -- convert a list of overage ratios into a confidence score.
 * confidence = round(50 + 50 * mean(overages)), clamped to [50, 100].
 */
function ruleConfidence(overages: number[]): number {
  if (overages.length === 0) return 50;
  const mean = overages.reduce((s, v) => s + v, 0) / overages.length;
  return clamp(Math.round(50 + 50 * mean), 50, 100);
}

// =============================================================================
// Core computation
// =============================================================================

/**
 * computeChangeClassification -- pure, deterministic classifier.
 *
 * Evaluates all classification rules against the provided signal inputs,
 * selects the highest-confidence match, and returns a ChangeClassificationResult.
 *
 * When multiple rules match with identical confidence, the tie is broken by
 * classification label ASC (alphabetical) for full output determinism.
 */
export function computeChangeClassification(
  input: ChangeClassificationInput
): ChangeClassificationResult {
  const {
    volatilityScore,
    averageSimilarity,
    intentDriftEventCount,
    featureTransitionCount,
    dominanceDelta,
    aiOverviewChurnCount,
  } = input;

  // Normalised signal values for the `signals` output (pass-through / capped)
  const signals: ChangeClassificationSignals = {
    volatility:        Math.round(clamp(volatilityScore,    0, 100) * 100)    / 100,
    similarity:        Math.round(clamp(averageSimilarity,  0, 1)   * 10_000) / 10_000,
    intentDrift:       Math.max(0, intentDriftEventCount),
    featureVolatility: Math.max(0, featureTransitionCount),
    dominanceChange:   Math.round(clamp(dominanceDelta,     0, 1)   * 10_000) / 10_000,
    aiOverviewChurn:   Math.max(0, aiOverviewChurnCount),
  };

  // ── Evaluate each rule ──────────────────────────────────────────────────────

  type Candidate = { label: ChangeClassificationLabel; confidence: number };
  const candidates: Candidate[] = [];

  // algorithm_shift: volatilityScore >= 60 AND averageSimilarity <= 0.45
  if (volatilityScore >= T_ALGO_VOLATILITY && averageSimilarity <= T_ALGO_SIMILARITY) {
    candidates.push({
      label:      "algorithm_shift",
      confidence: ruleConfidence([
        overageAbove(volatilityScore,   T_ALGO_VOLATILITY, CAP_VOLATILITY),
        overageBelow(averageSimilarity, T_ALGO_SIMILARITY),
      ]),
    });
  }

  // competitor_surge: dominanceDelta >= 0.30 AND volatilityScore >= 40
  if (dominanceDelta >= T_COMP_DOMINANCE && volatilityScore >= T_COMP_VOLATILITY) {
    candidates.push({
      label:      "competitor_surge",
      confidence: ruleConfidence([
        overageAbove(dominanceDelta,  T_COMP_DOMINANCE,  CAP_DOMINANCE),
        overageAbove(volatilityScore, T_COMP_VOLATILITY, CAP_VOLATILITY),
      ]),
    });
  }

  // intent_shift: intentDriftEventCount >= 2 AND averageSimilarity <= 0.60
  if (intentDriftEventCount >= T_INTENT_EVENTS && averageSimilarity <= T_INTENT_SIMILARITY) {
    candidates.push({
      label:      "intent_shift",
      confidence: ruleConfidence([
        overageAbove(intentDriftEventCount, T_INTENT_EVENTS,    CAP_INTENT_EVENTS),
        overageBelow(averageSimilarity,     T_INTENT_SIMILARITY),
      ]),
    });
  }

  // feature_turbulence: featureTransitionCount >= 3 AND volatilityScore >= 30
  if (featureTransitionCount >= T_FEAT_TRANSITIONS && volatilityScore >= T_FEAT_VOLATILITY) {
    candidates.push({
      label:      "feature_turbulence",
      confidence: ruleConfidence([
        overageAbove(featureTransitionCount, T_FEAT_TRANSITIONS, CAP_FEAT_TRANS),
        overageAbove(volatilityScore,        T_FEAT_VOLATILITY,  CAP_VOLATILITY),
      ]),
    });
  }

  // ai_overview_disruption: aiOverviewChurnCount >= 2 AND volatilityScore >= 35
  if (aiOverviewChurnCount >= T_AI_CHURN && volatilityScore >= T_AI_VOLATILITY) {
    candidates.push({
      label:      "ai_overview_disruption",
      confidence: ruleConfidence([
        overageAbove(aiOverviewChurnCount, T_AI_CHURN,      CAP_AI_CHURN),
        overageAbove(volatilityScore,      T_AI_VOLATILITY, CAP_VOLATILITY),
      ]),
    });
  }

  // ── Select winner ───────────────────────────────────────────────────────────

  if (candidates.length === 0) {
    // stable: confidence inversely related to how close any signal is to its threshold
    // Use the maximum normalised approach distance across all rules as a proxy.
    const approachRatios = [
      volatilityScore       / CAP_VOLATILITY,
      1 - clamp(averageSimilarity, 0, 1),
      intentDriftEventCount / CAP_INTENT_EVENTS,
      featureTransitionCount / CAP_FEAT_TRANS,
      dominanceDelta        / CAP_DOMINANCE,
      aiOverviewChurnCount  / CAP_AI_CHURN,
    ];
    const maxApproach = Math.max(...approachRatios.map((r) => clamp(r, 0, 1)));
    const stableConfidence = clamp(Math.round((1 - maxApproach) * 100), 0, 100);

    return { classification: "stable", confidence: stableConfidence, signals };
  }

  // Sort candidates: confidence DESC, label ASC (tie-breaker)
  candidates.sort((a, b) => {
    if (b.confidence !== a.confidence) return b.confidence - a.confidence;
    return a.label.localeCompare(b.label);
  });

  const winner = candidates[0];
  return { classification: winner.label, confidence: winner.confidence, signals };
}
