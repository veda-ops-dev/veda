/**
 * event-causality.ts -- SIL-14 Event Causality Detection (pure library)
 *
 * Pure function. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Detects deterministic adjacent event transition patterns from an already-ordered
 * SIL-13 event timeline. Only adjacent pairs (timeline[i] → timeline[i+1]) are
 * evaluated. No multi-hop chains. No missing-event inference. No probabilities.
 *
 * Recognized patterns:
 *   feature_turbulence    → algorithm_shift
 *   ai_overview_disruption → intent_shift
 *   competitor_surge      → feature_turbulence
 *   competitor_surge      → algorithm_shift
 *   intent_shift          → competitor_surge
 *   intent_shift          → algorithm_shift
 *
 * Confidence for each pattern = round((fromConfidence + toConfidence) / 2).
 *
 * Output ordering: fromCapturedAt ASC, toCapturedAt ASC, pattern ASC.
 */

import type { ChangeClassificationLabel } from "@/lib/seo/change-classification";

// =============================================================================
// Types
// =============================================================================

export interface EventCausalityInput {
  capturedAt: string;
  event:      ChangeClassificationLabel;
  confidence: number;
}

export type EventCausalityPatternLabel =
  | "feature_turbulence_to_algorithm_shift"
  | "ai_overview_disruption_to_intent_shift"
  | "competitor_surge_to_feature_turbulence"
  | "competitor_surge_to_algorithm_shift"
  | "intent_shift_to_competitor_surge"
  | "intent_shift_to_algorithm_shift";

export interface EventCausalityPattern {
  fromCapturedAt: string;
  toCapturedAt:   string;
  fromEvent:      ChangeClassificationLabel;
  toEvent:        ChangeClassificationLabel;
  pattern:        EventCausalityPatternLabel;
  confidence:     number;
}

// =============================================================================
// Internal: pattern lookup
// =============================================================================

type PairKey = `${ChangeClassificationLabel}|${ChangeClassificationLabel}`;

const KNOWN_PATTERNS: Record<PairKey, EventCausalityPatternLabel> = {
  "feature_turbulence|algorithm_shift":       "feature_turbulence_to_algorithm_shift",
  "ai_overview_disruption|intent_shift":      "ai_overview_disruption_to_intent_shift",
  "competitor_surge|feature_turbulence":       "competitor_surge_to_feature_turbulence",
  "competitor_surge|algorithm_shift":          "competitor_surge_to_algorithm_shift",
  "intent_shift|competitor_surge":             "intent_shift_to_competitor_surge",
  "intent_shift|algorithm_shift":              "intent_shift_to_algorithm_shift",
} as Record<PairKey, EventCausalityPatternLabel>;

// =============================================================================
// Core computation
// =============================================================================

/**
 * computeEventCausality -- pure, deterministic causality pattern detector.
 *
 * Accepts an already-ordered SIL-13 timeline (capturedAt ASC). Scans adjacent
 * pairs and emits a pattern entry for each recognized transition.
 *
 * Output sorted: fromCapturedAt ASC, toCapturedAt ASC, pattern ASC.
 */
export function computeEventCausality(
  timeline: EventCausalityInput[]
): EventCausalityPattern[] {
  if (timeline.length < 2) return [];

  const patterns: EventCausalityPattern[] = [];

  for (let i = 0; i < timeline.length - 1; i++) {
    const from = timeline[i];
    const to   = timeline[i + 1];

    const key: PairKey = `${from.event}|${to.event}`;
    const patternLabel = KNOWN_PATTERNS[key];

    if (patternLabel) {
      patterns.push({
        fromCapturedAt: from.capturedAt,
        toCapturedAt:   to.capturedAt,
        fromEvent:      from.event,
        toEvent:        to.event,
        pattern:        patternLabel,
        confidence:     Math.round((from.confidence + to.confidence) / 2),
      });
    }
  }

  // Deterministic sort: fromCapturedAt ASC, toCapturedAt ASC, pattern ASC
  patterns.sort((a, b) => {
    const fc = a.fromCapturedAt.localeCompare(b.fromCapturedAt);
    if (fc !== 0) return fc;
    const tc = a.toCapturedAt.localeCompare(b.toCapturedAt);
    if (tc !== 0) return tc;
    return a.pattern.localeCompare(b.pattern);
  });

  return patterns;
}
