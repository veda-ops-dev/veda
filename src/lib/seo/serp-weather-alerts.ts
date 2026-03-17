/**
 * serp-weather-alerts.ts -- SIL-20: SERP Weather Alerts (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Generates project-level weather alerts from the existing disturbance /
 * attribution / weather / forecast pipeline. This is read-only compute-on-read
 * alert generation only. No persistence. No background evaluation.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * ALERT RULES (evaluated in declaration order; multiple alerts may fire)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   1. weather_deterioration
 *      forecast.trend = worsening AND weather.state in {shifting, turbulent}
 *      level: warning; upgrade message when expectedState = unstable
 *
 *   2. weather_instability
 *      weather.state = unstable
 *      level: critical
 *
 *   3. ai_overview_surge
 *      weather.featureClimate = ai_overview_surge AND forecast.momentum = accelerating
 *      level: critical (soften wording when weather is not unstable)
 *
 *   4. feature_regime_shift
 *      attribution.cause = feature_regime_shift
 *      level: warning
 *
 *   5. competitor_dominance_shift
 *      attribution.cause = competitor_dominance_shift
 *      level: warning (upgrade to critical when unstable + worsening)
 *
 *   6. intent_reclassification
 *      attribution.cause = intent_reclassification
 *      level: warning
 *
 *   7. algorithm_shift
 *      attribution.cause = algorithm_shift AND forecast.trend in {worsening, volatile}
 *      level: warning
 *
 *   8. mixed_disturbance
 *      attribution.cause = unknown AND weather.state in {turbulent, unstable}
 *      level: info (upgrade to warning when forecast.momentum = accelerating)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SORT ORDER (deterministic)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   Primary:   level severity DESC  (critical > warning > info)
 *   Secondary: type ASC             (alphabetical)
 */

import type { SerpDisturbanceResult } from "@/lib/seo/serp-disturbance";
import type { SerpEventAttribution } from "@/lib/seo/serp-event-attribution";
import type { SerpWeatherResult } from "@/lib/seo/serp-weather";
import type { SerpWeatherForecastResult } from "@/lib/seo/serp-weather-forecast";

// ─────────────────────────────────────────────────────────────────────────────
// Output types
// ─────────────────────────────────────────────────────────────────────────────

export type SerpWeatherAlertLevel = "info" | "warning" | "critical";

export type SerpWeatherAlertType =
  | "weather_deterioration"
  | "weather_instability"
  | "ai_overview_surge"
  | "feature_regime_shift"
  | "competitor_dominance_shift"
  | "intent_reclassification"
  | "algorithm_shift"
  | "mixed_disturbance";

export type SerpWeatherAlertDriver =
  | "ai_overview_expansion"
  | "feature_regime_shift"
  | "competitor_dominance_shift"
  | "intent_reclassification"
  | "algorithm_shift"
  | "unknown";

export interface SerpWeatherAlertResult {
  level: SerpWeatherAlertLevel;
  type: SerpWeatherAlertType;
  message: string;
  driver: SerpWeatherAlertDriver;
}

// ─────────────────────────────────────────────────────────────────────────────
// Severity ordering (for deterministic sort)
// ─────────────────────────────────────────────────────────────────────────────

const LEVEL_ORDER: Record<SerpWeatherAlertLevel, number> = {
  critical: 2,
  warning:  1,
  info:     0,
};

// ─────────────────────────────────────────────────────────────────────────────
// Alert rule evaluation
// ─────────────────────────────────────────────────────────────────────────────

function evalWeatherDeterioration(
  weather: SerpWeatherResult,
  forecast: SerpWeatherForecastResult,
): SerpWeatherAlertResult | null {
  if (
    forecast.trend === "worsening" &&
    (weather.state === "shifting" || weather.state === "turbulent")
  ) {
    const message =
      forecast.expectedState === "unstable"
        ? "SERP weather worsening toward instability."
        : "SERP weather worsening toward turbulence.";
    return {
      level: "warning",
      type: "weather_deterioration",
      message,
      driver: "unknown",
    };
  }
  return null;
}

function evalWeatherInstability(weather: SerpWeatherResult): SerpWeatherAlertResult | null {
  if (weather.state === "unstable") {
    return {
      level: "critical",
      type: "weather_instability",
      message: "SERP weather is unstable with low ecosystem stability.",
      driver: "unknown",
    };
  }
  return null;
}

function evalAiOverviewSurge(
  weather: SerpWeatherResult,
  forecast: SerpWeatherForecastResult,
): SerpWeatherAlertResult | null {
  if (
    weather.featureClimate === "ai_overview_surge" &&
    forecast.momentum === "accelerating"
  ) {
    const message =
      weather.state === "unstable"
        ? "AI Overview expansion is accelerating with unstable SERP weather."
        : weather.state === "turbulent"
        ? "AI Overview expansion is accelerating with turbulent SERP weather."
        : "AI Overview expansion is accelerating with shifting SERP conditions.";
    return {
      level: "critical",
      type: "ai_overview_surge",
      message,
      driver: "ai_overview_expansion",
    };
  }
  return null;
}

function evalFeatureRegimeShift(attribution: SerpEventAttribution): SerpWeatherAlertResult | null {
  if (attribution.cause === "feature_regime_shift") {
    return {
      level: "warning",
      type: "feature_regime_shift",
      message: "SERP feature regime shift detected across the project.",
      driver: "feature_regime_shift",
    };
  }
  return null;
}

function evalCompetitorDominanceShift(
  attribution: SerpEventAttribution,
  weather: SerpWeatherResult,
  forecast: SerpWeatherForecastResult,
): SerpWeatherAlertResult | null {
  if (attribution.cause === "competitor_dominance_shift") {
    const isEscalated =
      weather.state === "unstable" && forecast.trend === "worsening";
    return {
      level: isEscalated ? "critical" : "warning",
      type: "competitor_dominance_shift",
      message: "Competitor dominance shift detected across affected keywords.",
      driver: "competitor_dominance_shift",
    };
  }
  return null;
}

function evalIntentReclassification(attribution: SerpEventAttribution): SerpWeatherAlertResult | null {
  if (attribution.cause === "intent_reclassification") {
    return {
      level: "warning",
      type: "intent_reclassification",
      message: "Intent reclassification detected across the search ecosystem.",
      driver: "intent_reclassification",
    };
  }
  return null;
}

function evalAlgorithmShift(
  attribution: SerpEventAttribution,
  forecast: SerpWeatherForecastResult,
): SerpWeatherAlertResult | null {
  if (
    attribution.cause === "algorithm_shift" &&
    (forecast.trend === "worsening" || forecast.trend === "volatile")
  ) {
    return {
      level: "warning",
      type: "algorithm_shift",
      message: "Algorithm-shift pattern detected with worsening SERP conditions.",
      driver: "algorithm_shift",
    };
  }
  return null;
}

function evalMixedDisturbance(
  attribution: SerpEventAttribution,
  weather: SerpWeatherResult,
  forecast: SerpWeatherForecastResult,
): SerpWeatherAlertResult | null {
  if (
    attribution.cause === "unknown" &&
    (weather.state === "turbulent" || weather.state === "unstable")
  ) {
    const isEscalated = forecast.momentum === "accelerating";
    return {
      level: isEscalated ? "warning" : "info",
      type: "mixed_disturbance",
      message: "Mixed SERP disturbance detected with no single dominant driver.",
      driver: "unknown",
    };
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeSerpWeatherAlerts -- generate project-level weather alerts from
 * existing disturbance / attribution / weather / forecast outputs.
 *
 * Pure function. Deterministic. No side effects. No persistence.
 *
 * Returns alerts sorted by level severity DESC (critical > warning > info),
 * then by type ASC (alphabetical) as a stable secondary key.
 *
 * @param disturbance  Output of computeSerpDisturbances()
 * @param attribution  Output of computeSerpEventAttribution()
 * @param weather      Output of computeSerpWeather()
 * @param forecast     Output of computeSerpWeatherForecast()
 */
export function computeSerpWeatherAlerts(
  disturbance: SerpDisturbanceResult,
  attribution: SerpEventAttribution,
  weather: SerpWeatherResult,
  forecast: SerpWeatherForecastResult,
): SerpWeatherAlertResult[] {
  // disturbance is accepted for future enrichment; current rules use weather/attribution/forecast
  void disturbance;

  const candidates: Array<SerpWeatherAlertResult | null> = [
    evalWeatherDeterioration(weather, forecast),
    evalWeatherInstability(weather),
    evalAiOverviewSurge(weather, forecast),
    evalFeatureRegimeShift(attribution),
    evalCompetitorDominanceShift(attribution, weather, forecast),
    evalIntentReclassification(attribution),
    evalAlgorithmShift(attribution, forecast),
    evalMixedDisturbance(attribution, weather, forecast),
  ];

  const alerts = candidates.filter((a): a is SerpWeatherAlertResult => a !== null);

  // Deterministic sort: severity DESC, type ASC
  alerts.sort((a, b) => {
    const levelDiff = LEVEL_ORDER[b.level] - LEVEL_ORDER[a.level];
    if (levelDiff !== 0) return levelDiff;
    return a.type.localeCompare(b.type);
  });

  return alerts;
}
