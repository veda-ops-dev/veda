/**
 * domain-dominance.ts -- Domain Dominance Sensor (pure library)
 *
 * Pure functions. No Prisma. No I/O. No Date.now(). No random.
 * All outputs are deterministic given the same inputs.
 *
 * Measures which domains dominate a single SERP snapshot by counting
 * hostname occurrences across all result URLs. Duplicate URLs within
 * a snapshot are deduplicated (first-wins) before counting.
 *
 * dominanceIndex = topDomain.count / totalResults
 * topDomains: top 10 by count DESC, domain ASC tie-breaker.
 */

// =============================================================================
// Types
// =============================================================================

export interface DomainPresence {
  domain: string;
  count:  number;
}

export interface DomainDominanceSummary {
  totalResults:   number;
  uniqueDomains:  number;
  /** topDomain.count / totalResults; null when totalResults = 0 */
  dominanceIndex: number | null;
  topDomains:     DomainPresence[];
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

// =============================================================================
// Core computation
// =============================================================================

/**
 * computeDomainDominance -- pure function.
 *
 * Accepts a rawPayload (unknown) and extracts organic result URLs.
 * Supports two payload shapes:
 *   Strategy 1: DataForSEO items[] where item.type === "organic" and item.url is a string.
 *   Strategy 2: simple results[] where item.url is a string.
 *
 * Duplicate URLs within the payload are deduplicated (first-wins) before counting.
 * Domain extraction uses URL.hostname; malformed URLs are skipped.
 *
 * Returns a DomainDominanceSummary. Deterministic: identical rawPayload -> identical output.
 */
export function computeDomainDominance(rawPayload: unknown): DomainDominanceSummary {
  const EMPTY: DomainDominanceSummary = {
    totalResults:   0,
    uniqueDomains:  0,
    dominanceIndex: null,
    topDomains:     [],
  };

  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return EMPTY;
  }

  const p = rawPayload as Record<string, unknown>;

  // Collect URLs in order (rank asc for DataForSEO, index order for simple)
  const rawUrls: string[] = [];

  if (Array.isArray(p.items)) {
    // DataForSEO: organic items, sorted rank_absolute asc for first-wins dedup
    const organicItems = p.items
      .filter(
        (item): item is Record<string, unknown> =>
          item !== null &&
          typeof item === "object" &&
          !Array.isArray(item) &&
          (item as Record<string, unknown>).type === "organic" &&
          typeof (item as Record<string, unknown>).url === "string"
      )
      .sort((a, b) => {
        const ra = typeof a.rank_absolute === "number" ? a.rank_absolute : Infinity;
        const rb = typeof b.rank_absolute === "number" ? b.rank_absolute : Infinity;
        if (ra !== rb) return ra - rb;
        return (a.url as string).localeCompare(b.url as string);
      });
    for (const item of organicItems) rawUrls.push(item.url as string);
  } else if (Array.isArray(p.results)) {
    for (const item of p.results) {
      if (
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item) &&
        typeof (item as Record<string, unknown>).url === "string"
      ) {
        rawUrls.push((item as Record<string, unknown>).url as string);
      }
    }
  } else {
    return EMPTY;
  }

  // Deduplicate URLs (first-wins)
  const seenUrls = new Set<string>();
  const dedupedUrls: string[] = [];
  for (const url of rawUrls) {
    if (!seenUrls.has(url)) { seenUrls.add(url); dedupedUrls.push(url); }
  }

  if (dedupedUrls.length === 0) return EMPTY;

  // Count domains
  const domainCount = new Map<string, number>();
  for (const url of dedupedUrls) {
    const host = hostnameFromUrl(url);
    if (host !== null) {
      domainCount.set(host, (domainCount.get(host) ?? 0) + 1);
    }
  }

  const totalResults  = dedupedUrls.length;
  const uniqueDomains = domainCount.size;

  // Sort: count DESC, domain ASC; top 10
  const topDomains: DomainPresence[] = Array.from(domainCount.entries())
    .map(([domain, count]) => ({ domain, count }))
    .sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      return a.domain.localeCompare(b.domain);
    })
    .slice(0, 10);

  const dominanceIndex =
    totalResults > 0 && topDomains.length > 0
      ? Math.round((topDomains[0].count / totalResults) * 10_000) / 10_000
      : null;

  return { totalResults, uniqueDomains, dominanceIndex, topDomains };
}
