/**
 * serp-weather-forecast.ts -- SIL-19 + SIL-19B: SERP Weather Forecasting (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Estimates short-term SERP climate trajectory based on recent observatory
 * signals. This is directional estimation, not prediction. No ML, no
 * randomness, no probabilistic modeling.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SIL-19B: FORECAST MOMENTUM ENRICHMENT
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Adds temporal momentum detection via window bisection. The snapshot window
 * is split into two halves; disturbance detection runs independently on each.
 * Comparing active disturbance dimensions between halves determines whether
 * disturbances are accelerating, decelerating, sustained, or stable.
 *
 * Momentum modifies both the forecast trend and confidence.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * TREND MAPPING (deterministic, evaluated in priority order)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   worsening — multiple disturbance dimensions active, OR high-severity
 *               weather state with strong attribution, OR AI expansion
 *               accelerating with volatility cluster
 *
 *   volatile  — disturbance signals present but unattributed (cause unknown),
 *               indicating conflicting or oscillating signals
 *
 *   improving — single weak disturbance dimension without turbulence or
 *               AI expansion, suggesting the ecosystem is stabilizing
 *
 *   stable    — no disturbance dimensions active
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * MOMENTUM-ADJUSTED TREND
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   accelerating: trend cannot be "improving"; prefer "worsening" or "volatile"
 *   decelerating: if base trend = "worsening" → downgrade to "stable"
 *   sustained:    keep base trend, confidence +3
 *   stable:       no modification
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * EXPECTED STATE (deterministic transition from current weather state)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   worsening: calm→shifting, shifting→turbulent, turbulent→unstable, unstable→unstable
 *   improving: unstable→turbulent, turbulent→shifting, shifting→calm, calm→calm
 *   stable:    current state preserved
 *   volatile:  current state preserved (oscillation, no clear direction)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DRIVER MOMENTUM
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   Derived from attribution.cause when attribution.confidence >= 60.
 *   Falls back to "unknown" when confidence is below threshold.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * CONFIDENCE
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   base = floor(attribution.confidence * 0.8)
 *   +5 per reinforcing disturbance signal (volatilityCluster, featureShift, turbulence)
 *   Momentum adjustment: accelerating +5, sustained +3, decelerating -5, stable 0
 *   Clamped to [0, 90].
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * FORECAST SUMMARY (deterministic lookup table, no random text)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   Keyed by trend + driverMomentum + momentum.
 *   Covers all 4 trends × 6 driver values × 4 momentum states.
 */

import type { SerpWeatherResult, SerpWeatherState } from "@/lib/seo/serp-weather";
import type { SerpDisturbanceResult } from "@/lib/seo/serp-disturbance";
import type { SerpEventAttribution, KeywordSignalSet } from "@/lib/seo/serp-event-attribution";

// ─────────────────────────────────────────────────────────────────────────────
// Output types
// ─────────────────────────────────────────────────────────────────────────────

export type ForecastTrend =
  | "improving"
  | "stable"
  | "worsening"
  | "volatile";

export type DriverMomentum =
  | "ai_overview_expansion"
  | "feature_regime_shift"
  | "competitor_dominance_shift"
  | "intent_reclassification"
  | "algorithm_shift"
  | "unknown";

export type MomentumDirection =
  | "accelerating"
  | "decelerating"
  | "sustained"
  | "stable";

export interface SerpWeatherForecastResult {
  trend: ForecastTrend;
  expectedState: SerpWeatherState;
  confidence: number;
  driverMomentum: DriverMomentum;
  momentum: MomentumDirection;
  forecastSummary: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Thresholds
// ─────────────────────────────────────────────────────────────────────────────

/** Minimum attribution confidence to use attribution.cause as driver momentum. */
const DRIVER_CONFIDENCE_THRESHOLD = 60;

/** Maximum forecast confidence. */
const CONFIDENCE_CAP = 90;

/** Minimum forecast confidence. */
const CONFIDENCE_FLOOR = 0;

/** Points per reinforcing disturbance signal. */
const SIGNAL_BONUS = 5;

/** Momentum confidence adjustments. */
const MOMENTUM_CONFIDENCE: Record<MomentumDirection, number> = {
  accelerating: 5,
  sustained:    3,
  decelerating: -5,
  stable:       0,
};

// ─────────────────────────────────────────────────────────────────────────────
// Deterministic forecast summary lookup table
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Build the full summary table keyed by `${trend}:${driverMomentum}:${momentum}`.
 *
 * For stable momentum the summary omits momentum phrasing (backward-compatible).
 * For other momentum values, it appends momentum-specific phrasing.
 */
function buildSummaryTable(): Record<string, string> {
  const table: Record<string, string> = {};

  // Base summaries per trend:driver (same as SIL-19 original)
  const baseSummaries: Record<string, string> = {
    "worsening:ai_overview_expansion":      "SERP climate trending toward turbulence due to continued AI Overview expansion",
    "worsening:feature_regime_shift":       "SERP climate trending toward turbulence due to ongoing feature regime changes",
    "worsening:competitor_dominance_shift": "SERP climate trending toward turbulence due to accelerating competitive displacement",
    "worsening:intent_reclassification":    "SERP climate trending toward turbulence due to active intent reclassification",
    "worsening:algorithm_shift":            "SERP climate trending toward turbulence due to broad algorithmic ranking movement",
    "worsening:unknown":                    "SERP climate trending toward turbulence with unidentified driving factors",

    "improving:ai_overview_expansion":      "SERP volatility stabilizing as AI Overview activity settles",
    "improving:feature_regime_shift":       "SERP volatility stabilizing as feature regime changes subside",
    "improving:competitor_dominance_shift": "SERP volatility stabilizing as competitive positions consolidate",
    "improving:intent_reclassification":    "SERP volatility stabilizing as intent signals normalize",
    "improving:algorithm_shift":            "SERP volatility stabilizing with reduced ranking turbulence",
    "improving:unknown":                    "SERP volatility stabilizing with weakening disturbance signals",

    "stable:ai_overview_expansion":      "SERP climate stable with no significant momentum changes",
    "stable:feature_regime_shift":       "SERP climate stable with no significant momentum changes",
    "stable:competitor_dominance_shift": "SERP climate stable with no significant momentum changes",
    "stable:intent_reclassification":    "SERP climate stable with no significant momentum changes",
    "stable:algorithm_shift":            "SERP climate stable with no significant momentum changes",
    "stable:unknown":                    "SERP climate stable with no significant disturbance signals",

    "volatile:ai_overview_expansion":      "SERP conditions volatile with mixed AI Overview signals",
    "volatile:feature_regime_shift":       "SERP conditions volatile with mixed feature signals",
    "volatile:competitor_dominance_shift": "SERP conditions volatile with mixed competitive signals",
    "volatile:intent_reclassification":    "SERP conditions volatile with mixed intent signals",
    "volatile:algorithm_shift":            "SERP conditions volatile with mixed ranking signals",
    "volatile:unknown":                    "SERP conditions volatile with conflicting and unattributed signals",
  };

  const momentumSuffixes: Record<MomentumDirection, string> = {
    accelerating: " with accelerating disturbance signals.",
    decelerating: " with decelerating disturbance signals.",
    sustained:    " with sustained disturbance patterns.",
    stable:       ".",
  };

  for (const [trendDriver, base] of Object.entries(baseSummaries)) {
    for (const momentum of ["accelerating", "decelerating", "sustained", "stable"] as MomentumDirection[]) {
      const key = `${trendDriver}:${momentum}`;
      table[key] = `${base}${momentumSuffixes[momentum]}`;
    }
  }

  return table;
}

const FORECAST_SUMMARY_TABLE = buildSummaryTable();

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Count active disturbance dimensions (0–3).
 */
function countDisturbanceDimensions(disturbance: SerpDisturbanceResult): number {
  return (
    (disturbance.volatilityCluster ? 1 : 0) +
    (disturbance.featureShiftDetected ? 1 : 0) +
    (disturbance.rankingTurbulence ? 1 : 0)
  );
}

/**
 * Determine forecast trend from current signals.
 *
 * Evaluated in priority order; first match wins.
 */
function computeTrend(
  weather: SerpWeatherResult,
  disturbance: SerpDisturbanceResult,
  attribution: SerpEventAttribution,
): ForecastTrend {
  const dims = countDisturbanceDimensions(disturbance);

  const aiExpanding =
    weather.featureClimate === "ai_overview_surge" ||
    disturbance.dominantNewFeatures.includes("ai_overview");

  // ── No disturbance → stable ────────────────────────────────────────────
  if (dims === 0) return "stable";

  // ── Unattributed disturbance → volatile (conflicting signals) ──────────
  if (attribution.cause === "unknown") return "volatile";

  // ── Three dimensions active → definitively worsening ───────────────────
  if (dims >= 3) return "worsening";

  // ── Two+ dimensions with ranking turbulence → worsening ────────────────
  if (dims >= 2 && disturbance.rankingTurbulence) return "worsening";

  // ── Two+ dimensions with AI expansion → worsening ─────────────────────
  if (dims >= 2 && aiExpanding) return "worsening";

  // ── Two dimensions with moderate-to-high confidence → worsening ────────
  if (dims >= 2 && attribution.confidence >= 50) return "worsening";

  // ── Single dimension without turbulence or AI expansion → improving ────
  // The disturbance exists but is mild and contained; ecosystem stabilizing.
  if (dims === 1 && !disturbance.rankingTurbulence && !aiExpanding) {
    return "improving";
  }

  // ── Remaining: single dimension with turbulence or AI → worsening ──────
  return "worsening";
}

/**
 * Apply momentum adjustment to base trend.
 *
 * accelerating: trend cannot be "improving"; prefer "worsening" or "volatile"
 * decelerating: if base trend = "worsening" → downgrade to "stable"
 * sustained:    keep base trend
 * stable:       no modification
 */
function adjustTrendByMomentum(
  baseTrend: ForecastTrend,
  momentum: MomentumDirection,
): ForecastTrend {
  if (momentum === "accelerating") {
    if (baseTrend === "improving") return "volatile";
    return baseTrend;
  }
  if (momentum === "decelerating") {
    if (baseTrend === "worsening") return "stable";
    return baseTrend;
  }
  // sustained and stable: no modification
  return baseTrend;
}

/**
 * Map current weather state + trend direction to expected next state.
 *
 * Deterministic state transition table.
 */
function computeExpectedState(
  currentState: SerpWeatherState,
  trend: ForecastTrend,
): SerpWeatherState {
  // stable and volatile → current state preserved
  if (trend === "stable" || trend === "volatile") return currentState;

  if (trend === "worsening") {
    switch (currentState) {
      case "calm":      return "shifting";
      case "shifting":  return "turbulent";
      case "turbulent": return "unstable";
      case "unstable":  return "unstable";
    }
  }

  // improving
  switch (currentState) {
    case "unstable":  return "turbulent";
    case "turbulent": return "shifting";
    case "shifting":  return "calm";
    case "calm":      return "calm";
  }
}

/**
 * Derive driver momentum from attribution cause with confidence gate.
 */
function computeDriverMomentum(attribution: SerpEventAttribution): DriverMomentum {
  if (
    attribution.confidence >= DRIVER_CONFIDENCE_THRESHOLD &&
    attribution.cause !== "unknown"
  ) {
    return attribution.cause as DriverMomentum;
  }
  return "unknown";
}

/**
 * Compute forecast confidence from attribution base + reinforcing signals + momentum.
 *
 *   base = floor(attribution.confidence × 0.8)
 *   +5 per active disturbance dimension
 *   +momentum adjustment
 *   Clamped to [0, 90].
 */
function computeConfidence(
  attribution: SerpEventAttribution,
  disturbance: SerpDisturbanceResult,
  momentum: MomentumDirection,
): number {
  const base = Math.floor(attribution.confidence * 0.8);
  const dims = countDisturbanceDimensions(disturbance);
  const raw = base + dims * SIGNAL_BONUS + MOMENTUM_CONFIDENCE[momentum];
  return Math.min(CONFIDENCE_CAP, Math.max(CONFIDENCE_FLOOR, raw));
}

/**
 * Look up deterministic forecast summary.
 */
function buildForecastSummary(
  trend: ForecastTrend,
  driverMomentum: DriverMomentum,
  momentum: MomentumDirection,
): string {
  const key = `${trend}:${driverMomentum}:${momentum}`;
  return FORECAST_SUMMARY_TABLE[key] ?? `SERP climate ${trend} with ${driverMomentum} momentum.`;
}

// ─────────────────────────────────────────────────────────────────────────────
// SIL-19B: Disturbance Momentum via Window Bisection
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeDisturbanceMomentum -- compare active disturbance dimensions
 * between two halves of the snapshot window.
 *
 * Pure function. Deterministic. No side effects.
 *
 * @param firstHalf  Disturbance result computed from the first window half
 * @param secondHalf Disturbance result computed from the second window half
 */
export function computeDisturbanceMomentum(
  firstHalf: SerpDisturbanceResult,
  secondHalf: SerpDisturbanceResult,
): MomentumDirection {
  const firstDims  = countDisturbanceDimensions(firstHalf);
  const secondDims = countDisturbanceDimensions(secondHalf);

  // accelerating: second window has MORE active dimensions
  if (secondDims > firstDims) return "accelerating";

  // decelerating: second window has FEWER active dimensions
  if (secondDims < firstDims) return "decelerating";

  // sustained: both windows have 2+ active dimensions (same count)
  if (firstDims >= 2 && secondDims >= 2) return "sustained";

  // stable: same count AND dims <= 1
  return "stable";
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeSerpWeatherForecast -- estimate short-term SERP climate trajectory.
 *
 * Pure function. Deterministic. No side effects. No ML. No randomness.
 *
 * Derives forecast entirely from already-computed observatory signals.
 * No extra DB queries required.
 *
 * SIL-19B: Now accepts optional firstHalfDisturbance and secondHalfDisturbance
 * for momentum enrichment. When not provided, momentum defaults to "stable"
 * for backward compatibility.
 *
 * @param weather                  Output of computeSerpWeather()
 * @param disturbance              Output of computeSerpDisturbances() (full window)
 * @param attribution              Output of computeSerpEventAttribution()
 * @param keywordSignals           Per-keyword intent-drift and dominance-shift signals
 * @param firstHalfDisturbance     Optional: disturbance from first half of snapshot window
 * @param secondHalfDisturbance    Optional: disturbance from second half of snapshot window
 */
export function computeSerpWeatherForecast(
  weather: SerpWeatherResult,
  disturbance: SerpDisturbanceResult,
  attribution: SerpEventAttribution,
  keywordSignals: KeywordSignalSet[],
  firstHalfDisturbance?: SerpDisturbanceResult,
  secondHalfDisturbance?: SerpDisturbanceResult,
): SerpWeatherForecastResult {
  // keywordSignals accepted per spec signature for future enrichment;
  // current forecast logic operates on aggregate disturbance/weather/attribution.
  void keywordSignals;

  // ── SIL-19B: Compute momentum ──────────────────────────────────────────
  const momentum: MomentumDirection =
    firstHalfDisturbance && secondHalfDisturbance
      ? computeDisturbanceMomentum(firstHalfDisturbance, secondHalfDisturbance)
      : "stable";

  // ── Base trend + momentum adjustment ────────────────────────────────────
  const baseTrend       = computeTrend(weather, disturbance, attribution);
  const trend           = adjustTrendByMomentum(baseTrend, momentum);
  const expectedState   = computeExpectedState(weather.state, trend);
  const driverMomentum  = computeDriverMomentum(attribution);
  const confidence      = computeConfidence(attribution, disturbance, momentum);
  const forecastSummary = buildForecastSummary(trend, driverMomentum, momentum);

  return {
    trend,
    expectedState,
    confidence,
    driverMomentum,
    momentum,
    forecastSummary,
  };
}
