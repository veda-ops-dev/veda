/**
 * intent-drift.ts -- Intent Drift Sensor (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * All outputs are deterministic given the same inputs.
 *
 * Maps SERP feature families (from extractFeatureSignals) to intent buckets
 * and computes an intent distribution per snapshot. Detects transitions between
 * consecutive snapshots where the dominant intent bucket changes.
 *
 * Intent bucket mapping:
 *   informational -> featured_snippet, people_also_ask, knowledge_panel
 *   video         -> video
 *   transactional -> shopping
 *   local         -> local_pack
 *   news          -> top_stories
 *
 * A snapshot may activate multiple buckets simultaneously (mixed intent).
 * Buckets without any active families have weight 0.
 *
 * Distribution: each active bucket gets weight 1; total = active bucket count.
 * Percentage = (bucket weight / total active buckets) * 100, rounded to 2dp.
 * When no intent families are present, all percentages are 0 and bucket = "none".
 *
 * Transition emitted when: dominant intent bucket changes OR
 * any bucket's percentage changes by >= significanceThreshold (default 34%).
 */

import type { FeatureSignals } from "@/lib/seo/serp-extraction";

// =============================================================================
// Types
// =============================================================================

export type IntentBucket =
  | "informational"
  | "video"
  | "transactional"
  | "local"
  | "news"
  | "none";

export interface IntentDistribution {
  informational: number;
  video:         number;
  transactional: number;
  local:         number;
  news:          number;
  /** Dominant bucket; "none" when no intent families present */
  dominant:      IntentBucket;
}

export interface IntentSnapshot {
  snapshotId:   string;
  capturedAt:   string;
  distribution: IntentDistribution;
}

export interface IntentTransition {
  fromSnapshotId:   string;
  toSnapshotId:     string;
  capturedAt:       string;
  fromDominant:     IntentBucket;
  toDominant:       IntentBucket;
  dominantChanged:  boolean;
  /** Buckets whose percentage changed by >= significanceThreshold */
  significantShifts: string[];
}

export interface IntentDriftResult {
  snapshots:   IntentSnapshot[];
  transitions: IntentTransition[];
}

// =============================================================================
// Internal: family -> bucket mapping
// =============================================================================

const FAMILY_TO_BUCKET: Record<string, IntentBucket> = {
  featured_snippet: "informational",
  people_also_ask:  "informational",
  knowledge_panel:  "informational",
  video:            "video",
  shopping:         "transactional",
  local_pack:       "local",
  top_stories:      "news",
};

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

// =============================================================================
// Core computation
// =============================================================================

/**
 * buildIntentDistribution -- pure function.
 * Maps a list of feature families to an intent distribution.
 */
export function buildIntentDistribution(familiesSorted: string[]): IntentDistribution {
  const buckets: Record<IntentBucket, boolean> = {
    informational: false,
    video:         false,
    transactional: false,
    local:         false,
    news:          false,
    none:          false,
  };

  for (const family of familiesSorted) {
    const bucket = FAMILY_TO_BUCKET[family];
    if (bucket) buckets[bucket] = true;
  }

  type ActiveBucket = Exclude<IntentBucket, "none">;
  const activeNames: ActiveBucket[] = (
    ["informational", "video", "transactional", "local", "news"] as ActiveBucket[]
  ).filter((b) => buckets[b]);

  const total = activeNames.length;

  if (total === 0) {
    return {
      informational: 0,
      video:         0,
      transactional: 0,
      local:         0,
      news:          0,
      dominant:      "none",
    };
  }

  // Each active bucket gets equal weight (1/total)
  const pct = round2((1 / total) * 100);

  const dist: IntentDistribution = {
    informational: buckets.informational ? pct : 0,
    video:         buckets.video         ? pct : 0,
    transactional: buckets.transactional ? pct : 0,
    local:         buckets.local         ? pct : 0,
    news:          buckets.news          ? pct : 0,
    dominant:      "none",
  };

  // Dominant: highest percentage; tie-break by bucket name ASC
  let dominant: ActiveBucket = activeNames[0];
  for (const b of activeNames) {
    if (dist[b] > dist[dominant] || (dist[b] === dist[dominant] && b < dominant)) {
      dominant = b;
    }
  }
  dist.dominant = dominant;

  return dist;
}

/**
 * computeIntentDrift -- pure function.
 *
 * Accepts an array of (snapshotId, capturedAt, signals) tuples
 * already sorted by the caller (capturedAt ASC, snapshotId ASC).
 *
 * Returns per-snapshot intent distributions and transitions where
 * the dominant bucket changes OR any bucket shifts >= significanceThreshold.
 */
export function computeIntentDrift(
  snapshots: { snapshotId: string; capturedAt: Date; signals: FeatureSignals }[],
  significanceThreshold = 34
): IntentDriftResult {
  if (snapshots.length === 0) {
    return { snapshots: [], transitions: [] };
  }

  const intentSnapshots: IntentSnapshot[] = snapshots.map((s) => ({
    snapshotId:   s.snapshotId,
    capturedAt:   s.capturedAt.toISOString(),
    distribution: buildIntentDistribution(s.signals.familiesSorted),
  }));

  const transitions: IntentTransition[] = [];
  type NumericBucket = Exclude<IntentBucket, "none">;
  const bucketKeys: NumericBucket[] = ["informational", "video", "transactional", "local", "news"];

  for (let i = 0; i < intentSnapshots.length - 1; i++) {
    const from = intentSnapshots[i];
    const to   = intentSnapshots[i + 1];

    const dominantChanged = from.distribution.dominant !== to.distribution.dominant;

    const significantShifts: string[] = [];
    for (const key of bucketKeys) {
      const delta = Math.abs(to.distribution[key] - from.distribution[key]);
      if (delta >= significanceThreshold) significantShifts.push(key);
    }
    // significantShifts already in bucketKeys order (informational, video, transactional, local, news)

    if (!dominantChanged && significantShifts.length === 0) continue;

    transitions.push({
      fromSnapshotId:    snapshots[i].snapshotId,
      toSnapshotId:      snapshots[i + 1].snapshotId,
      capturedAt:        to.capturedAt,
      fromDominant:      from.distribution.dominant,
      toDominant:        to.distribution.dominant,
      dominantChanged,
      significantShifts,
    });
  }

  // Transitions inherit capturedAt ASC order from snapshot iteration order.
  // Tie-break by toSnapshotId ASC for full determinism.
  transitions.sort((a, b) => {
    if (a.capturedAt !== b.capturedAt) return a.capturedAt.localeCompare(b.capturedAt);
    return a.toSnapshotId.localeCompare(b.toSnapshotId);
  });

  return { snapshots: intentSnapshots, transitions };
}
