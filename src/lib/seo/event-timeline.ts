/**
 * event-timeline.ts -- SIL-13 SERP Event Timeline (pure library)
 *
 * Pure function. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Converts a sequence of snapshot signal inputs into a minimal event stream
 * by classifying each snapshot window and emitting only when the classification
 * changes. Duplicate consecutive classifications are collapsed.
 *
 * Ordering: capturedAt ASC, snapshotId ASC (caller must pre-sort).
 */

import {
  computeChangeClassification,
  type ChangeClassificationLabel,
} from "@/lib/seo/change-classification";

// =============================================================================
// Types
// =============================================================================

export interface TimelineSnapshotInput {
  snapshotId:             string;
  capturedAt:             string;   // ISO timestamp
  volatilityScore:        number;
  averageSimilarity:      number;
  intentDriftEventCount:  number;
  featureTransitionCount: number;
  dominanceDelta:         number;
  aiOverviewChurnCount:   number;
}

export interface TimelineEvent {
  capturedAt: string;
  event:      ChangeClassificationLabel;
  confidence: number;
}

// =============================================================================
// Core computation
// =============================================================================

/**
 * computeEventTimeline -- pure, deterministic timeline builder.
 *
 * Processes snapshots in input order (caller must sort capturedAt ASC, id ASC).
 * For each snapshot, computes the change classification using the snapshot's
 * signal values. If the classification differs from the previous emitted event,
 * a new timeline entry is emitted. Otherwise, the duplicate is collapsed.
 *
 * Returns a minimal event stream: only classification transitions are included.
 */
export function computeEventTimeline(
  snapshots: TimelineSnapshotInput[]
): TimelineEvent[] {
  if (snapshots.length === 0) return [];

  const timeline: TimelineEvent[] = [];
  let previousLabel: ChangeClassificationLabel | null = null;

  for (const snap of snapshots) {
    const result = computeChangeClassification({
      volatilityScore:        snap.volatilityScore,
      averageSimilarity:      snap.averageSimilarity,
      intentDriftEventCount:  snap.intentDriftEventCount,
      featureTransitionCount: snap.featureTransitionCount,
      dominanceDelta:         snap.dominanceDelta,
      aiOverviewChurnCount:   snap.aiOverviewChurnCount,
    });

    if (result.classification !== previousLabel) {
      timeline.push({
        capturedAt: snap.capturedAt,
        event:      result.classification,
        confidence: result.confidence,
      });
      previousLabel = result.classification;
    }
  }

  return timeline;
}
