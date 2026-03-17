/**
 * serp-disturbance.ts -- SIL-16: SERP Disturbance Detection (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * Deterministic: identical inputs always produce identical output.
 *
 * Detects when multiple keyword targets experience synchronized SERP changes
 * across three disturbance dimensions:
 *
 *   1. Volatility Cluster
 *      >= 30% of keywords with sampleSize >= 1 have volatilityScore >= threshold.
 *      Signals: broad ecosystem instability, likely algorithm or intent shift.
 *
 *   2. Feature Regime Shift
 *      Dominant SERP features in the most recent snapshot differ from those
 *      in the oldest snapshot across a meaningful portion of keywords.
 *      Returns top-3 newly-dominant features (frequency DESC, family ASC).
 *      Signals: structural SERP format change (AI Overview expansion, etc.).
 *
 *   3. Ranking Turbulence Cluster
 *      Multiple keywords show rank entries, exits, or large rank movements
 *      (> RANK_TURBULENCE_THRESHOLD positions) in their most recent pair.
 *      Returns the count of affected keywords.
 *      Signals: synchronized competitive or algorithmic displacement.
 *
 * Thresholds are intentionally conservative to reduce false positives on
 * low-snapshot-count projects.
 */

import { computeVolatility, type SnapshotForVolatility } from "@/lib/seo/volatility-service";
import { extractFeatureSignals } from "@/lib/seo/serp-extraction";

// ─────────────────────────────────────────────────────────────────────────────
// Thresholds
// ─────────────────────────────────────────────────────────────────────────────

/** Fraction of active keywords that must exceed VOLATILITY_SCORE_THRESHOLD. */
const VOLATILITY_CLUSTER_FRACTION = 0.30;

/** Minimum volatility score for a keyword to count toward the cluster. */
const VOLATILITY_SCORE_THRESHOLD = 30;

/** Minimum active keywords (sampleSize >= 1) required before any disturbance fires. */
const MIN_ACTIVE_KEYWORDS = 2;

/** Minimum rank shift (absolute positions) for a keyword to count as turbulence. */
const RANK_TURBULENCE_THRESHOLD = 5;

/** Minimum keywords affected by ranking turbulence to set rankingTurbulence=true. */
const RANKING_TURBULENCE_MIN_KEYWORDS = 2;

/** Fraction of keywords that must show a feature regime shift for featureShiftDetected. */
const FEATURE_SHIFT_FRACTION = 0.30;

// ─────────────────────────────────────────────────────────────────────────────
// Input / Output Types
// ─────────────────────────────────────────────────────────────────────────────

/** One keyword's snapshot bucket, pre-sorted capturedAt ASC, id ASC. */
export interface SnapshotSet {
  keywordTargetId: string;
  snapshots: SnapshotForVolatility[];
}

export interface SerpDisturbanceResult {
  /** True when >= 30% of active keywords have volatilityScore >= 30. */
  volatilityCluster: boolean;
  /** True when dominant SERP features shifted across >= 30% of keywords. */
  featureShiftDetected: boolean;
  /** Top-3 newly-dominant feature families (frequency DESC, family ASC). */
  dominantNewFeatures: string[];
  /** True when >= 2 keywords show large rank turbulence in their recent pair. */
  rankingTurbulence: boolean;
  /** Count of keywords exhibiting rank turbulence. */
  affectedKeywordCount: number;
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Extract ranked URLs and their positions from a rawPayload.
 * Returns a Map<url, rank> for the organic results (rank=position, 1-based).
 * Only URLs with non-null numeric ranks are included.
 */
function extractRankMap(rawPayload: unknown): Map<string, number> {
  const result = new Map<string, number>();

  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return result;
  }
  const p = rawPayload as Record<string, unknown>;

  // DataForSEO items[] primary path
  if (Array.isArray(p.items)) {
    for (const item of p.items) {
      if (
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item) &&
        (item as Record<string, unknown>).type === "organic" &&
        typeof (item as Record<string, unknown>).url === "string"
      ) {
        const url = (item as Record<string, unknown>).url as string;
        const rank =
          typeof (item as Record<string, unknown>).rank_absolute === "number"
            ? ((item as Record<string, unknown>).rank_absolute as number)
            : typeof (item as Record<string, unknown>).position === "number"
            ? ((item as Record<string, unknown>).position as number)
            : null;
        if (rank !== null && !result.has(url)) {
          result.set(url, rank);
        }
      }
    }
    return result;
  }

  // Simple/test results[] fallback
  if (Array.isArray(p.results)) {
    for (const item of p.results) {
      if (
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item) &&
        typeof (item as Record<string, unknown>).url === "string"
      ) {
        const url = (item as Record<string, unknown>).url as string;
        const rank =
          typeof (item as Record<string, unknown>).rank === "number"
            ? ((item as Record<string, unknown>).rank as number)
            : typeof (item as Record<string, unknown>).position === "number"
            ? ((item as Record<string, unknown>).position as number)
            : null;
        if (rank !== null && !result.has(url)) {
          result.set(url, rank);
        }
      }
    }
  }
  return result;
}

/**
 * Compute the maximum rank shift for a URL between two consecutive snapshots.
 * Also detects URL entries and exits (treated as turbulence regardless of threshold).
 *
 * Returns:
 *   maxShift: max absolute rank movement for shared URLs
 *   hasEntry: a URL entered the SERP (not in "from" but in "to")
 *   hasExit:  a URL exited the SERP (in "from" but not in "to")
 */
function computePairTurbulence(
  fromPayload: unknown,
  toPayload: unknown
): { maxShift: number; hasEntry: boolean; hasExit: boolean } {
  const fromMap = extractRankMap(fromPayload);
  const toMap   = extractRankMap(toPayload);

  if (fromMap.size === 0 && toMap.size === 0) {
    return { maxShift: 0, hasEntry: false, hasExit: false };
  }

  let maxShift = 0;
  let hasEntry = false;
  let hasExit  = false;

  // Shared URLs -- compute rank shift
  for (const [url, fromRank] of fromMap) {
    if (toMap.has(url)) {
      const shift = Math.abs(fromRank - toMap.get(url)!);
      if (shift > maxShift) maxShift = shift;
    } else {
      // URL disappeared
      hasExit = true;
    }
  }

  // URLs appearing in "to" that weren't in "from" -- entries
  for (const url of toMap.keys()) {
    if (!fromMap.has(url)) hasEntry = true;
  }

  return { maxShift, hasEntry, hasExit };
}

/**
 * Determine whether the most-recent consecutive pair for a keyword shows
 * ranking turbulence (large shift, entry, or exit).
 *
 * Only evaluates the last pair (snapshots[n-2] and snapshots[n-1]).
 */
function keywordHasTurbulence(snapshots: SnapshotForVolatility[]): boolean {
  if (snapshots.length < 2) return false;
  const from = snapshots[snapshots.length - 2];
  const to   = snapshots[snapshots.length - 1];
  const { maxShift, hasEntry, hasExit } = computePairTurbulence(
    from.rawPayload,
    to.rawPayload
  );
  return maxShift > RANK_TURBULENCE_THRESHOLD || hasEntry || hasExit;
}

/**
 * Derive the feature family set from the oldest and newest snapshot in a bucket.
 * Returns { oldFamilies, newFamilies } — both as sorted string arrays.
 */
function extractFirstLastFeatureFamilies(
  snapshots: SnapshotForVolatility[]
): { oldFamilies: string[]; newFamilies: string[] } {
  if (snapshots.length === 0) {
    return { oldFamilies: [], newFamilies: [] };
  }
  const first = snapshots[0];
  const last  = snapshots[snapshots.length - 1];
  const oldSignals = extractFeatureSignals(first.rawPayload);
  const newSignals = extractFeatureSignals(last.rawPayload);
  return {
    oldFamilies: oldSignals.familiesSorted,
    newFamilies: newSignals.familiesSorted,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeSerpDisturbances -- detect synchronized disturbance signals across
 * all keyword snapshot buckets.
 *
 * Input: SnapshotSet[] where each entry's snapshots[] is pre-sorted
 *   capturedAt ASC, id ASC.
 *
 * Returns a zero-signal SerpDisturbanceResult when fewer than
 *   MIN_ACTIVE_KEYWORDS have sampleSize >= 1.
 */
export function computeSerpDisturbances(
  keywordSnapshots: SnapshotSet[]
): SerpDisturbanceResult {
  const ZERO: SerpDisturbanceResult = {
    volatilityCluster: false,
    featureShiftDetected: false,
    dominantNewFeatures: [],
    rankingTurbulence: false,
    affectedKeywordCount: 0,
  };

  if (keywordSnapshots.length === 0) return ZERO;

  // ── Per-keyword signals ────────────────────────────────────────────────────
  let activeCount          = 0;  // keywords with sampleSize >= 1
  let volatileCount        = 0;  // active keywords exceeding volatility threshold
  let featureShiftCount    = 0;  // keywords whose feature set changed
  let turbulenceCount      = 0;  // keywords with rank turbulence in recent pair

  // Frequency map for "new" feature families across all keywords with a shift
  const newFeatureFreq = new Map<string, number>();

  for (const { snapshots } of keywordSnapshots) {
    const profile = computeVolatility(snapshots);

    if (profile.sampleSize < 1) continue;
    activeCount++;

    // ── Volatility cluster ───────────────────────────────────────────────
    if (profile.volatilityScore >= VOLATILITY_SCORE_THRESHOLD) {
      volatileCount++;
    }

    // ── Ranking turbulence ───────────────────────────────────────────────
    if (keywordHasTurbulence(snapshots)) {
      turbulenceCount++;
    }

    // ── Feature regime shift ─────────────────────────────────────────────
    const { oldFamilies, newFamilies } = extractFirstLastFeatureFamilies(snapshots);
    const oldSet = new Set(oldFamilies);
    const newSet = new Set(newFamilies);

    // A feature shift occurs when any family appeared or disappeared
    let shifted = false;
    for (const f of newFamilies) {
      if (!oldSet.has(f)) { shifted = true; }
    }
    for (const f of oldFamilies) {
      if (!newSet.has(f)) { shifted = true; }
    }

    if (shifted) {
      featureShiftCount++;
      // Accumulate frequency for families newly present in the latest snapshot
      for (const f of newFamilies) {
        if (!oldSet.has(f)) {
          newFeatureFreq.set(f, (newFeatureFreq.get(f) ?? 0) + 1);
        }
      }
    }
  }

  // Not enough active keywords to declare disturbances
  if (activeCount < MIN_ACTIVE_KEYWORDS) return ZERO;

  // ── Volatility cluster ─────────────────────────────────────────────────────
  const volatilityCluster =
    volatileCount / activeCount >= VOLATILITY_CLUSTER_FRACTION;

  // ── Feature regime shift ───────────────────────────────────────────────────
  const featureShiftDetected =
    featureShiftCount / activeCount >= FEATURE_SHIFT_FRACTION;

  // Dominant new features: top-3, frequency DESC, family ASC, exclude "other"
  const dominantNewFeatures = Array.from(newFeatureFreq.entries())
    .filter(([family]) => family !== "other")
    .sort(([familyA, freqA], [familyB, freqB]) => {
      if (freqB !== freqA) return freqB - freqA;
      return familyA.localeCompare(familyB);
    })
    .slice(0, 3)
    .map(([family]) => family);

  // ── Ranking turbulence ─────────────────────────────────────────────────────
  const rankingTurbulence = turbulenceCount >= RANKING_TURBULENCE_MIN_KEYWORDS;

  return {
    volatilityCluster,
    featureShiftDetected,
    dominantNewFeatures,
    rankingTurbulence,
    affectedKeywordCount: turbulenceCount,
  };
}
