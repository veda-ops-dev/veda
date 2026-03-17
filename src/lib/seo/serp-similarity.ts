/**
 * serp-similarity.ts -- SERP Structural Similarity Sensor (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * All outputs are deterministic given the same inputs.
 *
 * Computes Jaccard similarity between consecutive SERP snapshots using:
 *   - domain set (extracted from organic result URLs)
 *   - feature family set (from extractFeatureSignals)
 *
 * Jaccard(A, B) = |A ∩ B| / |A ∪ B|
 * Returns 1.0 when both sets are empty (identical empty snapshots).
 * Returns 0.0 when one set is empty and the other is not.
 *
 * Combined score = (domainSimilarity + familySimilarity) / 2, rounded to 4dp.
 *
 * All outputs sorted deterministically.
 */

import type { FeatureSignals } from "@/lib/seo/serp-extraction";

// =============================================================================
// Types
// =============================================================================

export interface SimilarityPair {
  fromSnapshotId:    string;
  toSnapshotId:      string;
  /** ISO timestamp of the "to" snapshot */
  capturedAt:        string;
  domainSimilarity:  number;
  familySimilarity:  number;
  /** (domainSimilarity + familySimilarity) / 2, rounded to 4dp */
  combinedSimilarity: number;
}

export interface SerpSimilarityResult {
  pairCount:  number;
  pairs:      SimilarityPair[];
}

// =============================================================================
// Internal helpers
// =============================================================================

function hostnameFromUrl(url: string): string | null {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch {
    return null;
  }
}

function round4(n: number): number {
  return Math.round(n * 10_000) / 10_000;
}

function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 && b.size === 0) return 1.0;
  if (a.size === 0 || b.size === 0) return 0.0;

  let intersection = 0;
  for (const item of a) {
    if (b.has(item)) intersection++;
  }
  const union = a.size + b.size - intersection;
  return round4(intersection / union);
}

/**
 * domainsFromPayload -- pure function.
 * Extracts the set of unique hostnames from organic results in a rawPayload.
 * Strategy 1: DataForSEO items[] where type === "organic".
 * Strategy 2: simple results[].
 */
function domainsFromPayload(rawPayload: unknown): Set<string> {
  const domains = new Set<string>();
  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return domains;
  }
  const p = rawPayload as Record<string, unknown>;

  if (Array.isArray(p.items)) {
    for (const item of p.items) {
      if (
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item) &&
        (item as Record<string, unknown>).type === "organic" &&
        typeof (item as Record<string, unknown>).url === "string"
      ) {
        const h = hostnameFromUrl((item as Record<string, unknown>).url as string);
        if (h) domains.add(h);
      }
    }
  } else if (Array.isArray(p.results)) {
    for (const item of p.results) {
      if (
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item) &&
        typeof (item as Record<string, unknown>).url === "string"
      ) {
        const h = hostnameFromUrl((item as Record<string, unknown>).url as string);
        if (h) domains.add(h);
      }
    }
  }

  return domains;
}

// =============================================================================
// Core computation
// =============================================================================

/**
 * computeSerpSimilarity -- pure function.
 *
 * Accepts an array of (snapshotId, capturedAt, rawPayload, signals) tuples
 * already sorted by the caller (capturedAt ASC, snapshotId ASC).
 *
 * Computes consecutive-pair Jaccard similarity on domain sets and feature family sets.
 * Returns all pairs sorted capturedAt ASC, toSnapshotId ASC.
 */
export function computeSerpSimilarity(
  snapshots: {
    snapshotId:  string;
    capturedAt:  Date;
    rawPayload:  unknown;
    signals:     FeatureSignals;
  }[]
): SerpSimilarityResult {
  if (snapshots.length < 2) {
    return { pairCount: 0, pairs: [] };
  }

  const pairs: SimilarityPair[] = [];

  for (let i = 0; i < snapshots.length - 1; i++) {
    const from = snapshots[i];
    const to   = snapshots[i + 1];

    const fromDomains  = domainsFromPayload(from.rawPayload);
    const toDomains    = domainsFromPayload(to.rawPayload);
    const fromFamilies = new Set(from.signals.familiesSorted);
    const toFamilies   = new Set(to.signals.familiesSorted);

    const domainSimilarity  = jaccard(fromDomains, toDomains);
    const familySimilarity  = jaccard(fromFamilies, toFamilies);
    const combinedSimilarity = round4((domainSimilarity + familySimilarity) / 2);

    pairs.push({
      fromSnapshotId:    from.snapshotId,
      toSnapshotId:      to.snapshotId,
      capturedAt:        to.capturedAt.toISOString(),
      domainSimilarity,
      familySimilarity,
      combinedSimilarity,
    });
  }

  // Already in capturedAt ASC order from iteration; sort with tie-breaker for full determinism
  pairs.sort((a, b) => {
    if (a.capturedAt !== b.capturedAt) return a.capturedAt.localeCompare(b.capturedAt);
    return a.toSnapshotId.localeCompare(b.toSnapshotId);
  });

  return { pairCount: pairs.length, pairs };
}
