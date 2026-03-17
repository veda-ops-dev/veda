/**
 * serp-operator-hints.ts -- SIL-24: Operator Action Hints (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Generates investigation hints for the operator based on the current
 * SERP climate and alert state. These are observatory prompts, not
 * content recommendations.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * HINT RULES (deterministic mapping, max 3 hints)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   ai_overview_expansion
 *     → high:   review_ai_overview_keywords
 *     → medium: inspect_feature_transitions (when weather ≠ calm)
 *
 *   competitor_dominance_shift
 *     → high:   inspect_domain_dominance
 *     → medium: inspect_rank_turbulence (when rankingTurbulence = true)
 *
 *   intent_reclassification
 *     → high:   inspect_intent_shift
 *     → medium: inspect_feature_transitions
 *
 *   feature_regime_shift
 *     → high:   inspect_feature_transitions
 *     → medium: review_ai_overview_keywords (when featureClimate = ai_overview_surge)
 *
 *   algorithm_shift
 *     → high:   inspect_rank_turbulence
 *     → medium: inspect_domain_dominance (when rankingTurbulence = true)
 *
 *   unknown / mixed
 *     → low:    monitor_mixed_disturbance
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SORT ORDER (deterministic)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   Primary:   priority DESC  (high > medium > low)
 *   Secondary: type ASC       (alphabetical)
 */

import type { SerpEventAttribution } from "@/lib/seo/serp-event-attribution";
import type { SerpWeatherResult } from "@/lib/seo/serp-weather";
import type { SerpWeatherForecastResult } from "@/lib/seo/serp-weather-forecast";
import type { SerpWeatherAlertResult } from "@/lib/seo/serp-weather-alerts";
import type { AlertAffectedKeyword } from "@/lib/seo/serp-keyword-impact";
import type { SerpDisturbanceResult } from "@/lib/seo/serp-disturbance";

// ─────────────────────────────────────────────────────────────────────────────
// Output types
// ─────────────────────────────────────────────────────────────────────────────

export type HintPriority = "high" | "medium" | "low";

export type HintType =
  | "review_ai_overview_keywords"
  | "inspect_feature_transitions"
  | "inspect_rank_turbulence"
  | "inspect_domain_dominance"
  | "inspect_intent_shift"
  | "monitor_mixed_disturbance";

export interface SerpOperatorActionHint {
  priority: HintPriority;
  type: HintType;
  label: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Deterministic label table
// ─────────────────────────────────────────────────────────────────────────────

const HINT_LABELS: Record<HintType, string> = {
  review_ai_overview_keywords: "Review AI overview affected keywords.",
  inspect_feature_transitions: "Inspect feature transitions on high-impact queries.",
  inspect_rank_turbulence:     "Inspect rank turbulence across high-impact keywords.",
  inspect_domain_dominance:    "Inspect domain dominance changes across affected keywords.",
  inspect_intent_shift:        "Inspect intent-shift patterns across affected keywords.",
  monitor_mixed_disturbance:   "Monitor mixed disturbance across the affected keyword set.",
};

// ─────────────────────────────────────────────────────────────────────────────
// Priority ordering (for deterministic sort)
// ─────────────────────────────────────────────────────────────────────────────

const PRIORITY_ORDER: Record<HintPriority, number> = {
  high:   2,
  medium: 1,
  low:    0,
};

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

function makeHint(priority: HintPriority, type: HintType): SerpOperatorActionHint {
  return { priority, type, label: HINT_LABELS[type] };
}

function sortHints(hints: SerpOperatorActionHint[]): SerpOperatorActionHint[] {
  return hints.slice().sort((a, b) => {
    const pd = PRIORITY_ORDER[b.priority] - PRIORITY_ORDER[a.priority];
    if (pd !== 0) return pd;
    return a.type.localeCompare(b.type);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeSerpOperatorActionHints -- generate investigation hints for the operator.
 *
 * Pure function. Deterministic. No side effects. Max 3 hints returned.
 *
 * @param disturbance       Output of computeSerpDisturbances()
 * @param attribution       Output of computeSerpEventAttribution()
 * @param weather           Output of computeSerpWeather()
 * @param forecast          Output of computeSerpWeatherForecast()
 * @param alerts            Output of computeSerpWeatherAlerts() (pre-sorted)
 * @param affectedKeywords  Output of selectAlertAffectedKeywords()
 */
export function computeSerpOperatorActionHints(
  disturbance: SerpDisturbanceResult,
  attribution: SerpEventAttribution,
  weather: SerpWeatherResult,
  forecast: SerpWeatherForecastResult,
  alerts: SerpWeatherAlertResult[],
  affectedKeywords: AlertAffectedKeyword[],
): SerpOperatorActionHint[] {
  // forecast and affectedKeywords accepted for future enrichment
  void forecast;
  void affectedKeywords;
  void alerts;

  const cause = attribution.cause;
  const hints: SerpOperatorActionHint[] = [];

  if (cause === "ai_overview_expansion") {
    hints.push(makeHint("high", "review_ai_overview_keywords"));
    if (weather.state !== "calm") {
      hints.push(makeHint("medium", "inspect_feature_transitions"));
    }
  } else if (cause === "competitor_dominance_shift") {
    hints.push(makeHint("high", "inspect_domain_dominance"));
    if (disturbance.rankingTurbulence) {
      hints.push(makeHint("medium", "inspect_rank_turbulence"));
    }
  } else if (cause === "intent_reclassification") {
    hints.push(makeHint("high", "inspect_intent_shift"));
    hints.push(makeHint("medium", "inspect_feature_transitions"));
  } else if (cause === "feature_regime_shift") {
    hints.push(makeHint("high", "inspect_feature_transitions"));
    if (weather.featureClimate === "ai_overview_surge") {
      hints.push(makeHint("medium", "review_ai_overview_keywords"));
    }
  } else if (cause === "algorithm_shift") {
    hints.push(makeHint("high", "inspect_rank_turbulence"));
    if (disturbance.rankingTurbulence) {
      hints.push(makeHint("medium", "inspect_domain_dominance"));
    }
  } else {
    // unknown / mixed disturbance
    hints.push(makeHint("low", "monitor_mixed_disturbance"));
  }

  return sortHints(hints).slice(0, 3);
}
