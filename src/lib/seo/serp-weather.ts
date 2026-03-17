/**
 * serp-weather.ts -- SIL-18: SERP Weather (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Converts existing observatory (SIL-15), disturbance (SIL-16), and
 * event-attribution (SIL-17) signals into a concise operator-facing
 * SERP weather model. This is current-state synthesis only — no
 * forecasting, no recommendations, no operator advice.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * STATE MAPPING (deterministic, evaluated in order)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   unstable  — turbulent conditions AND attribution confidence >= 65
 *               AND multiple strong co-occurring signals
 *               (featureShiftDetected + rankingTurbulence + volatilityCluster)
 *
 *   turbulent — volatilityCluster = true AND rankingTurbulence = true
 *
 *   shifting  — volatilityCluster = true OR featureShiftDetected = true
 *               (but not both-true + turbulence → that is turbulent/unstable)
 *
 *   calm      — none of the above
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * STABILITY MAPPING
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   high      — calm state
 *   moderate  — shifting state
 *   low       — turbulent or unstable state
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * FEATURE CLIMATE MAPPING (deterministic, evaluated in order)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   ai_overview_surge  — aiOverviewActivity ∈ {increasing, volatile}
 *                        AND dominantSerpFeatures or dominantNewFeatures
 *                        includes "ai_overview"
 *
 *   feature_rotation   — featureShiftDetected = true
 *                        AND ai_overview NOT dominant
 *
 *   stable_features    — featureShiftDetected = false
 *                        AND aiOverviewActivity ∈ {none, present}
 *
 *   mixed_features     — fallback
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SUMMARY STRINGS (deterministic lookup table — no template variation)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   Keyed by state + driver combination. Covers all 6 driver values × 4 states.
 *   Falls back to a generic state sentence when no specific combination matches.
 */

import type { SerpObservatoryResult } from "@/lib/seo/serp-observatory";
import type { SerpDisturbanceResult } from "@/lib/seo/serp-disturbance";
import type { SerpEventAttribution, AttributionCause } from "@/lib/seo/serp-event-attribution";

// ─────────────────────────────────────────────────────────────────────────────
// Output types
// ─────────────────────────────────────────────────────────────────────────────

export type SerpWeatherState =
  | "calm"
  | "shifting"
  | "turbulent"
  | "unstable";

export type SerpWeatherStability =
  | "high"
  | "moderate"
  | "low";

export type SerpFeatureClimate =
  | "stable_features"
  | "ai_overview_surge"
  | "feature_rotation"
  | "mixed_features";

export interface SerpWeatherResult {
  state: SerpWeatherState;
  driver: AttributionCause;
  confidence: number;
  stability: SerpWeatherStability;
  featureClimate: SerpFeatureClimate;
  summary: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Thresholds
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Minimum attribution confidence required (alongside all other conditions)
 * for the state to escalate from "turbulent" to "unstable".
 */
const UNSTABLE_CONFIDENCE_THRESHOLD = 65;

// ─────────────────────────────────────────────────────────────────────────────
// Deterministic summary lookup table
// ─────────────────────────────────────────────────────────────────────────────

// Key format: `${state}:${driver}`
const SUMMARY_TABLE: Record<string, string> = {
  // calm
  "calm:unknown":                    "Calm SERP climate with no significant disturbance signals.",
  "calm:ai_overview_expansion":      "Calm SERP climate with early AI Overview activity observed.",
  "calm:feature_regime_shift":       "Calm SERP climate with minor feature variation detected.",
  "calm:competitor_dominance_shift": "Calm SERP climate with limited competitive movement.",
  "calm:intent_reclassification":    "Calm SERP climate with stable intent distribution.",
  "calm:algorithm_shift":            "Calm SERP climate with no significant ranking movement.",

  // shifting
  "shifting:unknown":                    "Shifting SERP climate with mixed signals.",
  "shifting:ai_overview_expansion":      "Shifting SERP climate driven by AI Overview activity.",
  "shifting:feature_regime_shift":       "Shifting SERP climate driven by feature regime change.",
  "shifting:competitor_dominance_shift": "Shifting SERP climate driven by competitive movement.",
  "shifting:intent_reclassification":    "Shifting SERP climate driven by intent reclassification.",
  "shifting:algorithm_shift":            "Shifting SERP climate driven by broad ranking movement.",

  // turbulent
  "turbulent:unknown":                    "Turbulent SERP climate with broad instability.",
  "turbulent:ai_overview_expansion":      "Turbulent SERP climate driven by AI Overview expansion.",
  "turbulent:feature_regime_shift":       "Turbulent SERP climate driven by feature regime shift.",
  "turbulent:competitor_dominance_shift": "Turbulent SERP climate driven by competitor dominance shift.",
  "turbulent:intent_reclassification":    "Turbulent SERP climate driven by intent reclassification.",
  "turbulent:algorithm_shift":            "Turbulent SERP climate driven by algorithm shift.",

  // unstable
  "unstable:unknown":                    "Unstable SERP climate with broad ranking turbulence and low stability.",
  "unstable:ai_overview_expansion":      "Unstable SERP climate with broad ranking turbulence driven by AI Overview expansion.",
  "unstable:feature_regime_shift":       "Unstable SERP climate with broad ranking turbulence driven by feature regime shift.",
  "unstable:competitor_dominance_shift": "Unstable SERP climate with broad ranking turbulence driven by competitor dominance shift.",
  "unstable:intent_reclassification":    "Unstable SERP climate with broad ranking turbulence driven by intent reclassification.",
  "unstable:algorithm_shift":            "Unstable SERP climate with broad ranking turbulence driven by algorithm shift.",
};

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

function mapState(
  disturbance: SerpDisturbanceResult,
  attribution: SerpEventAttribution
): SerpWeatherState {
  const { volatilityCluster, featureShiftDetected, rankingTurbulence } = disturbance;

  // unstable: full turbulent conditions + high confidence + all three strong signals
  if (
    volatilityCluster &&
    rankingTurbulence &&
    featureShiftDetected &&
    attribution.confidence >= UNSTABLE_CONFIDENCE_THRESHOLD
  ) {
    return "unstable";
  }

  // turbulent: broad synchronized disruption
  if (volatilityCluster && rankingTurbulence) {
    return "turbulent";
  }

  // shifting: one major signal active
  if (volatilityCluster || featureShiftDetected) {
    return "shifting";
  }

  return "calm";
}

function mapStability(state: SerpWeatherState): SerpWeatherStability {
  if (state === "calm")     return "high";
  if (state === "shifting") return "moderate";
  return "low"; // turbulent | unstable
}

function mapFeatureClimate(
  observatory: SerpObservatoryResult,
  disturbance: SerpDisturbanceResult
): SerpFeatureClimate {
  const aiRising =
    observatory.aiOverviewActivity === "increasing" ||
    observatory.aiOverviewActivity === "volatile";

  const aiDominant =
    observatory.dominantSerpFeatures.includes("ai_overview") ||
    disturbance.dominantNewFeatures.includes("ai_overview");

  // ai_overview_surge: AI activity rising AND ai_overview is dominant
  if (aiRising && aiDominant) return "ai_overview_surge";

  // feature_rotation: features shifted but AI overview not driving it
  if (disturbance.featureShiftDetected && !aiDominant) return "feature_rotation";

  // stable_features: no shift, AI overview calm
  if (!disturbance.featureShiftDetected && !aiRising) return "stable_features";

  // mixed_features: everything else
  return "mixed_features";
}

function buildSummary(state: SerpWeatherState, driver: AttributionCause): string {
  const key = `${state}:${driver}`;
  return SUMMARY_TABLE[key] ?? `${state.charAt(0).toUpperCase() + state.slice(1)} SERP climate.`;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeSerpWeather -- synthesize observatory, disturbance, and attribution
 * signals into a compact operator-facing SERP weather model.
 *
 * Pure function. Deterministic. No side effects.
 *
 * @param observatory  Output of computeSerpObservatory()
 * @param disturbance  Output of computeSerpDisturbances()
 * @param attribution  Output of computeSerpEventAttribution()
 */
export function computeSerpWeather(
  observatory: SerpObservatoryResult,
  disturbance: SerpDisturbanceResult,
  attribution: SerpEventAttribution
): SerpWeatherResult {
  const state         = mapState(disturbance, attribution);
  const stability     = mapStability(state);
  const featureClimate = mapFeatureClimate(observatory, disturbance);
  const summary       = buildSummary(state, attribution.cause);

  return {
    state,
    driver:      attribution.cause,
    confidence:  attribution.confidence,
    stability,
    featureClimate,
    summary,
  };
}
