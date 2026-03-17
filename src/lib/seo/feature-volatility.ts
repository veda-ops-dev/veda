/**
 * feature-volatility.ts -- Feature Presence Volatility Analysis (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * All outputs are deterministic given the same inputs.
 *
 * Computes consecutive-pair transitions between SERP feature sets and
 * summarizes which feature families are most volatile.
 *
 * Input contract:
 *   snapshots[] must be pre-sorted by the caller: capturedAt ASC, snapshotId ASC.
 *   familiesSorted on each snapshot must already be sorted ASC (as produced by
 *   extractFeatureSignals).
 *
 * Output contract:
 *   transitions[] sorted capturedAt ASC, toSnapshotId ASC.
 *   entered/exited arrays within each transition sorted ASC.
 *   Only transitions where entered.length > 0 OR exited.length > 0 are emitted.
 *   summary.mostVolatileFeatures sorted changes DESC, family ASC; top 10 only;
 *   families with zero changes are excluded.
 *   summary.transitionCount = total emitted transitions (before any external truncation).
 */

// =============================================================================
// Types
// =============================================================================

export interface FeatureSnapshot {
  snapshotId:     string;
  capturedAt:     Date;
  familiesSorted: string[];
}

export interface FeatureTransition {
  fromSnapshotId: string;
  toSnapshotId:   string;
  /** ISO timestamp of the "to" snapshot */
  capturedAt:     string;
  /** Families present in "to" but not "from", sorted ASC */
  entered:        string[];
  /** Families present in "from" but not "to", sorted ASC */
  exited:         string[];
}

export interface FeatureVolatilitySummary {
  snapshotCount:        number;
  transitionCount:      number;
  mostVolatileFeatures: { family: string; changes: number }[];
}

// =============================================================================
// Core computation
// =============================================================================

/**
 * computeFeatureVolatility -- pure function.
 *
 * Accepts a pre-sorted snapshot list and returns all feature transitions
 * plus a volatility summary.
 *
 * Snapshots must be sorted capturedAt ASC, snapshotId ASC before calling.
 * This function does not re-sort its input.
 */
export function computeFeatureVolatility(snapshots: FeatureSnapshot[]): {
  transitions: FeatureTransition[];
  summary:     FeatureVolatilitySummary;
} {
  const transitions: FeatureTransition[] = [];

  // Change counter per family: family -> count of entries+exits
  const changeCount = new Map<string, number>();

  for (let i = 0; i < snapshots.length - 1; i++) {
    const from = snapshots[i];
    const to   = snapshots[i + 1];

    const fromSet = new Set(from.familiesSorted);
    const toSet   = new Set(to.familiesSorted);

    // entered: in to but not from
    const entered: string[] = [];
    for (const f of to.familiesSorted) {
      if (!fromSet.has(f)) entered.push(f);
    }

    // exited: in from but not to
    const exited: string[] = [];
    for (const f of from.familiesSorted) {
      if (!toSet.has(f)) exited.push(f);
    }

    // Only emit if something changed
    if (entered.length === 0 && exited.length === 0) continue;

    // entered/exited are derived by iterating over already-sorted arrays,
    // so they are already sorted ASC. No additional sort needed.

    transitions.push({
      fromSnapshotId: from.snapshotId,
      toSnapshotId:   to.snapshotId,
      capturedAt:     to.capturedAt.toISOString(),
      entered,
      exited,
    });

    // Accumulate change counts
    for (const f of entered) changeCount.set(f, (changeCount.get(f) ?? 0) + 1);
    for (const f of exited)  changeCount.set(f, (changeCount.get(f) ?? 0) + 1);
  }

  // Sort transitions: capturedAt ASC, toSnapshotId ASC
  transitions.sort((a, b) => {
    if (a.capturedAt !== b.capturedAt) return a.capturedAt.localeCompare(b.capturedAt);
    return a.toSnapshotId.localeCompare(b.toSnapshotId);
  });

  // Build mostVolatileFeatures: exclude zero-change families, sort changes DESC / family ASC, top 10
  const mostVolatileFeatures = Array.from(changeCount.entries())
    .filter(([, count]) => count > 0)
    .map(([family, changes]) => ({ family, changes }))
    .sort((a, b) => {
      if (b.changes !== a.changes) return b.changes - a.changes;
      return a.family.localeCompare(b.family);
    })
    .slice(0, 10);

  return {
    transitions,
    summary: {
      snapshotCount:        snapshots.length,
      transitionCount:      transitions.length,
      mostVolatileFeatures,
    },
  };
}
