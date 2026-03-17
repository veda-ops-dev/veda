/**
 * serp-alert-briefing.ts -- SIL-21: SERP Alert Briefing Packets (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Converts weather alerts into a single operator-readable briefing packet
 * summarizing the current SERP situation for the project. Consumes only the
 * outputs of the existing disturbance / attribution / weather / forecast /
 * alerts pipeline. No new data sources.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * PRIMARY ALERT SELECTION
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   First alert from the already-sorted alerts array (severity DESC, type ASC).
 *   null when alerts is empty.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SUPPORTING SIGNALS
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   Derived deterministically from disturbance + attribution fields.
 *   Possible tokens:
 *     ai_overview_activity        aiOverviewActivity ∈ {increasing, volatile}  (via attribution supportingSignals)
 *     ai_overview_expansion       attribution.cause = ai_overview_expansion
 *     dominance_shift             attribution supportingSignals includes dominance_shift_cluster
 *     feature_shift_detected      disturbance.featureShiftDetected = true
 *     intent_drift                attribution supportingSignals includes intent_drift_cluster
 *     ranking_turbulence          disturbance.rankingTurbulence = true
 *     volatility_cluster          disturbance.volatilityCluster = true
 *
 *   All tokens sorted alphabetically (ASC).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SUMMARY LOOKUP TABLE
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   Key: ${weatherState}:${forecastTrend}:${driver}
 *   Covers all 4 states × 4 trends × 6 drivers = 96 entries.
 *   Falls back to a generic state:trend string when key is absent.
 */

import type { SerpDisturbanceResult } from "@/lib/seo/serp-disturbance";
import type { SerpEventAttribution } from "@/lib/seo/serp-event-attribution";
import type { SerpWeatherResult, SerpWeatherState } from "@/lib/seo/serp-weather";
import type { SerpWeatherForecastResult, ForecastTrend, MomentumDirection } from "@/lib/seo/serp-weather-forecast";
import type { SerpWeatherAlertResult, SerpWeatherAlertDriver } from "@/lib/seo/serp-weather-alerts";

// ─────────────────────────────────────────────────────────────────────────────
// Output type
// ─────────────────────────────────────────────────────────────────────────────

export interface SerpAlertBriefing {
  primaryAlert: SerpWeatherAlertResult | null;
  weatherState: SerpWeatherState;
  forecastTrend: ForecastTrend;
  momentum: MomentumDirection;
  driver: SerpWeatherAlertDriver;
  affectedKeywords: number;
  supportingSignals: string[];
  summary: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Deterministic summary lookup table
// ─────────────────────────────────────────────────────────────────────────────

// Key format: `${state}:${trend}:${driver}`
const SUMMARY_TABLE: Record<string, string> = {
  // calm
  "calm:stable:unknown":                       "Calm SERP conditions with no significant disturbance.",
  "calm:stable:ai_overview_expansion":         "Calm SERP conditions with stable AI Overview activity.",
  "calm:stable:feature_regime_shift":          "Calm SERP conditions with stable feature distribution.",
  "calm:stable:competitor_dominance_shift":    "Calm SERP conditions with stable competitive positions.",
  "calm:stable:intent_reclassification":       "Calm SERP conditions with stable intent distribution.",
  "calm:stable:algorithm_shift":               "Calm SERP conditions with no significant ranking movement.",
  "calm:improving:unknown":                    "Calm SERP conditions stabilizing further.",
  "calm:improving:ai_overview_expansion":      "Calm SERP conditions as AI Overview activity settles.",
  "calm:improving:feature_regime_shift":       "Calm SERP conditions as feature changes subside.",
  "calm:improving:competitor_dominance_shift": "Calm SERP conditions as competitive positions consolidate.",
  "calm:improving:intent_reclassification":    "Calm SERP conditions as intent signals normalize.",
  "calm:improving:algorithm_shift":            "Calm SERP conditions with reduced ranking turbulence.",
  "calm:worsening:unknown":                    "Calm SERP conditions with early instability signals.",
  "calm:worsening:ai_overview_expansion":      "Calm SERP conditions shifting as AI Overview activity rises.",
  "calm:worsening:feature_regime_shift":       "Calm SERP conditions shifting due to emerging feature changes.",
  "calm:worsening:competitor_dominance_shift": "Calm SERP conditions shifting due to emerging competitive movement.",
  "calm:worsening:intent_reclassification":    "Calm SERP conditions shifting as intent signals diverge.",
  "calm:worsening:algorithm_shift":            "Calm SERP conditions shifting as ranking movement begins.",
  "calm:volatile:unknown":                     "Calm SERP conditions with mixed and unattributed signals.",
  "calm:volatile:ai_overview_expansion":       "Calm SERP conditions with volatile AI Overview signals.",
  "calm:volatile:feature_regime_shift":        "Calm SERP conditions with mixed feature signals.",
  "calm:volatile:competitor_dominance_shift":  "Calm SERP conditions with mixed competitive signals.",
  "calm:volatile:intent_reclassification":     "Calm SERP conditions with mixed intent signals.",
  "calm:volatile:algorithm_shift":             "Calm SERP conditions with mixed ranking signals.",

  // shifting
  "shifting:stable:unknown":                       "Shifting SERP conditions holding steady.",
  "shifting:stable:ai_overview_expansion":         "Shifting SERP conditions driven by steady AI Overview activity.",
  "shifting:stable:feature_regime_shift":          "Shifting SERP conditions driven by feature regime changes.",
  "shifting:stable:competitor_dominance_shift":    "Shifting SERP conditions driven by steady competitive movement.",
  "shifting:stable:intent_reclassification":       "Shifting SERP conditions driven by stable intent reclassification.",
  "shifting:stable:algorithm_shift":               "Shifting SERP conditions driven by steady ranking movement.",
  "shifting:improving:unknown":                    "Shifting SERP conditions with weakening disturbance signals.",
  "shifting:improving:ai_overview_expansion":      "Shifting SERP conditions stabilizing as AI Overview activity settles.",
  "shifting:improving:feature_regime_shift":       "Shifting SERP conditions stabilizing as feature changes subside.",
  "shifting:improving:competitor_dominance_shift": "Shifting SERP conditions stabilizing as competitive positions consolidate.",
  "shifting:improving:intent_reclassification":    "Shifting SERP conditions stabilizing as intent signals normalize.",
  "shifting:improving:algorithm_shift":            "Shifting SERP conditions stabilizing with reduced ranking turbulence.",
  "shifting:worsening:unknown":                    "Shifting SERP conditions worsening with mixed disturbance signals.",
  "shifting:worsening:ai_overview_expansion":      "Shifting SERP conditions worsening due to AI Overview expansion.",
  "shifting:worsening:feature_regime_shift":       "Shifting SERP conditions worsening due to ongoing feature regime changes.",
  "shifting:worsening:competitor_dominance_shift": "Shifting SERP conditions worsening due to competitive displacement.",
  "shifting:worsening:intent_reclassification":    "Shifting SERP conditions worsening due to active intent reclassification.",
  "shifting:worsening:algorithm_shift":            "Shifting SERP conditions worsening due to broad ranking movement.",
  "shifting:volatile:unknown":                     "Shifting SERP conditions with conflicting and unattributed signals.",
  "shifting:volatile:ai_overview_expansion":       "Shifting SERP conditions with volatile AI Overview signals.",
  "shifting:volatile:feature_regime_shift":        "Shifting SERP conditions with mixed feature signals.",
  "shifting:volatile:competitor_dominance_shift":  "Shifting SERP conditions with mixed competitive signals.",
  "shifting:volatile:intent_reclassification":     "Shifting SERP conditions with mixed intent signals.",
  "shifting:volatile:algorithm_shift":             "Shifting SERP conditions with mixed ranking signals.",

  // turbulent
  "turbulent:stable:unknown":                       "Turbulent SERP conditions holding without further escalation.",
  "turbulent:stable:ai_overview_expansion":         "Turbulent SERP conditions driven by AI Overview expansion, stable trajectory.",
  "turbulent:stable:feature_regime_shift":          "Turbulent SERP conditions driven by feature regime shift, stable trajectory.",
  "turbulent:stable:competitor_dominance_shift":    "Turbulent SERP conditions driven by competitor dominance shift, stable trajectory.",
  "turbulent:stable:intent_reclassification":       "Turbulent SERP conditions driven by intent reclassification, stable trajectory.",
  "turbulent:stable:algorithm_shift":               "Turbulent SERP conditions driven by algorithm shift, stable trajectory.",
  "turbulent:improving:unknown":                    "Turbulent SERP conditions beginning to stabilize.",
  "turbulent:improving:ai_overview_expansion":      "Turbulent SERP conditions stabilizing as AI Overview activity settles.",
  "turbulent:improving:feature_regime_shift":       "Turbulent SERP conditions stabilizing as feature changes subside.",
  "turbulent:improving:competitor_dominance_shift": "Turbulent SERP conditions stabilizing as competitive positions consolidate.",
  "turbulent:improving:intent_reclassification":    "Turbulent SERP conditions stabilizing as intent signals normalize.",
  "turbulent:improving:algorithm_shift":            "Turbulent SERP conditions stabilizing with reduced ranking turbulence.",
  "turbulent:worsening:unknown":                    "Turbulent SERP conditions worsening toward instability.",
  "turbulent:worsening:ai_overview_expansion":      "Turbulent SERP conditions driven by AI Overview expansion.",
  "turbulent:worsening:feature_regime_shift":       "Turbulent SERP conditions driven by feature regime shift.",
  "turbulent:worsening:competitor_dominance_shift": "Turbulent SERP conditions driven by competitor dominance shift.",
  "turbulent:worsening:intent_reclassification":    "Turbulent SERP conditions driven by intent reclassification.",
  "turbulent:worsening:algorithm_shift":            "Turbulent SERP conditions driven by algorithm shift.",
  "turbulent:volatile:unknown":                     "Turbulent SERP conditions with conflicting and unattributed signals.",
  "turbulent:volatile:ai_overview_expansion":       "Turbulent SERP conditions with volatile AI Overview signals.",
  "turbulent:volatile:feature_regime_shift":        "Turbulent SERP conditions with mixed feature signals.",
  "turbulent:volatile:competitor_dominance_shift":  "Turbulent SERP conditions with mixed competitive signals.",
  "turbulent:volatile:intent_reclassification":     "Turbulent SERP conditions with mixed intent signals.",
  "turbulent:volatile:algorithm_shift":             "Turbulent SERP conditions with mixed ranking signals.",

  // unstable
  "unstable:stable:unknown":                       "Unstable SERP conditions holding without further escalation.",
  "unstable:stable:ai_overview_expansion":         "Unstable SERP conditions driven by AI Overview expansion, holding steady.",
  "unstable:stable:feature_regime_shift":          "Unstable SERP conditions driven by feature regime shift, holding steady.",
  "unstable:stable:competitor_dominance_shift":    "Unstable SERP conditions driven by competitor dominance shift, holding steady.",
  "unstable:stable:intent_reclassification":       "Unstable SERP conditions driven by intent reclassification, holding steady.",
  "unstable:stable:algorithm_shift":               "Unstable SERP conditions driven by algorithm shift, holding steady.",
  "unstable:improving:unknown":                    "Unstable SERP conditions beginning to stabilize.",
  "unstable:improving:ai_overview_expansion":      "Unstable SERP conditions stabilizing as AI Overview activity settles.",
  "unstable:improving:feature_regime_shift":       "Unstable SERP conditions stabilizing as feature changes subside.",
  "unstable:improving:competitor_dominance_shift": "Unstable SERP conditions stabilizing as competitive positions consolidate.",
  "unstable:improving:intent_reclassification":    "Unstable SERP conditions stabilizing as intent signals normalize.",
  "unstable:improving:algorithm_shift":            "Unstable SERP conditions stabilizing with reduced ranking turbulence.",
  "unstable:worsening:unknown":                    "Unstable SERP conditions with broad turbulence and no clear driver.",
  "unstable:worsening:ai_overview_expansion":      "SERP weather unstable with accelerating AI Overview expansion.",
  "unstable:worsening:feature_regime_shift":       "SERP weather unstable with ongoing feature regime shift.",
  "unstable:worsening:competitor_dominance_shift": "SERP weather unstable with competitor dominance shift accelerating.",
  "unstable:worsening:intent_reclassification":    "SERP weather unstable with active intent reclassification.",
  "unstable:worsening:algorithm_shift":            "SERP weather unstable with broad algorithmic ranking movement.",
  "unstable:volatile:unknown":                     "SERP weather unstable with conflicting and unattributed signals.",
  "unstable:volatile:ai_overview_expansion":       "SERP weather unstable with volatile AI Overview signals.",
  "unstable:volatile:feature_regime_shift":        "SERP weather unstable with mixed feature signals.",
  "unstable:volatile:competitor_dominance_shift":  "SERP weather unstable with mixed competitive signals.",
  "unstable:volatile:intent_reclassification":     "SERP weather unstable with mixed intent signals.",
  "unstable:volatile:algorithm_shift":             "SERP weather unstable with mixed ranking signals.",
};

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

function buildSupportingSignals(
  disturbance: SerpDisturbanceResult,
  attribution: SerpEventAttribution,
): string[] {
  const signals = new Set<string>();

  if (disturbance.volatilityCluster)    signals.add("volatility_cluster");
  if (disturbance.rankingTurbulence)    signals.add("ranking_turbulence");
  if (disturbance.featureShiftDetected) signals.add("feature_shift_detected");

  if (attribution.cause === "ai_overview_expansion") {
    signals.add("ai_overview_expansion");
  }

  // ai_overview_activity: present when attribution supporting signals include
  // ai_overview_activity_increasing or ai_overview_activity_volatile
  if (
    attribution.supportingSignals.some((s) => s.startsWith("ai_overview_activity"))
  ) {
    signals.add("ai_overview_activity");
  }

  // dominance_shift: present when attribution supporting signals include dominance_shift_cluster
  if (attribution.supportingSignals.includes("dominance_shift_cluster")) {
    signals.add("dominance_shift");
  }

  // intent_drift: present when attribution supporting signals include intent_drift_cluster
  if (attribution.supportingSignals.includes("intent_drift_cluster")) {
    signals.add("intent_drift");
  }

  // Deterministic sort ASC
  return Array.from(signals).sort((a, b) => a.localeCompare(b));
}

function buildSummary(
  state: SerpWeatherState,
  trend: ForecastTrend,
  driver: SerpWeatherAlertDriver,
): string {
  const key = `${state}:${trend}:${driver}`;
  return (
    SUMMARY_TABLE[key] ??
    `${state.charAt(0).toUpperCase() + state.slice(1)} SERP conditions with ${trend} trajectory.`
  );
}

function resolveDriver(
  attribution: SerpEventAttribution,
  primaryAlert: SerpWeatherAlertResult | null,
): SerpWeatherAlertDriver {
  // Prefer the primary alert's driver if it is specific
  if (primaryAlert && primaryAlert.driver !== "unknown") {
    return primaryAlert.driver;
  }
  // Fall back to attribution cause if it maps to a driver type
  const cause = attribution.cause;
  if (
    cause === "ai_overview_expansion" ||
    cause === "feature_regime_shift" ||
    cause === "competitor_dominance_shift" ||
    cause === "intent_reclassification" ||
    cause === "algorithm_shift"
  ) {
    return cause;
  }
  return "unknown";
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeSerpAlertBriefing -- generate a single operator-readable briefing
 * packet from the full SIL-16 through SIL-20 pipeline outputs.
 *
 * Pure function. Deterministic. No side effects. No persistence.
 *
 * @param disturbance          Output of computeSerpDisturbances()
 * @param attribution          Output of computeSerpEventAttribution()
 * @param weather              Output of computeSerpWeather()
 * @param forecast             Output of computeSerpWeatherForecast()
 * @param alerts               Output of computeSerpWeatherAlerts() (pre-sorted)
 * @param affectedKeywordCount Number of keywords exhibiting rank turbulence
 */
export function computeSerpAlertBriefing(
  disturbance: SerpDisturbanceResult,
  attribution: SerpEventAttribution,
  weather: SerpWeatherResult,
  forecast: SerpWeatherForecastResult,
  alerts: SerpWeatherAlertResult[],
  affectedKeywordCount: number,
): SerpAlertBriefing {
  const primaryAlert = alerts.length > 0 ? alerts[0] : null;
  const driver = resolveDriver(attribution, primaryAlert);
  const supportingSignals = buildSupportingSignals(disturbance, attribution);
  const summary = buildSummary(weather.state, forecast.trend, driver);

  return {
    primaryAlert,
    weatherState: weather.state,
    forecastTrend: forecast.trend,
    momentum: forecast.momentum,
    driver,
    affectedKeywords: affectedKeywordCount,
    supportingSignals,
    summary,
  };
}
