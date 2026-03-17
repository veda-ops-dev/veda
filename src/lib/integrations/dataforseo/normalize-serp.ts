/**
 * DataForSEO SERP Response Normalizer
 *
 * Converts a raw DataForSEO /v3/serp/google/organic/live/advanced response
 * into the internal NormalizedSerpResult shape consumed by the ingest route.
 *
 * Rules (per spec):
 *   - Organic results: items where type === "organic"
 *   - Fields: rank_absolute → rank, domain → domain, url → url
 *   - Store ALL organic results (no truncation)
 *   - topDomains: first 10 organic domains (in rank order)
 *   - aiOverviewPresent: true if any item.type === "ai_overview"
 *   - features: collect featured_snippet / people_also_ask / ai_overview / local_pack
 *   - validAt: tasks[0].result[0].datetime if present, else null (caller falls back to capturedAt)
 *   - rawPayload: the full provider response (no truncation)
 *
 * No DB access. No side effects. Pure transform.
 */

export interface NormalizedRankingEntry {
  rank: number;
  domain: string | null;
  url: string;
}

export interface NormalizedSerpResult {
  /** Organic result list — all items, no truncation */
  organicResults: NormalizedRankingEntry[];
  /** First 10 organic domains in rank order */
  topDomains: string[];
  /** True if any SERP item has type === "ai_overview" */
  aiOverviewPresent: boolean;
  /** "present" | "absent" */
  aiOverviewStatus: "present" | "absent";
  /** AI Overview text snippet if present, else null */
  aiOverviewText: string | null;
  /** Detected SERP features */
  features: string[];
  /** Provider datetime from tasks[0].result[0].datetime, or null */
  validAt: string | null;
  /** Full provider response for rawPayload storage */
  rawPayload: unknown;
}

const TRACKED_FEATURES = new Set([
  "featured_snippet",
  "people_also_ask",
  "ai_overview",
  "local_pack",
]);

/**
 * Safely extract tasks[0].result[0].items from a DataForSEO response.
 * Returns an empty array if the path is missing or malformed.
 */
function extractItems(response: unknown): unknown[] {
  try {
    const r = response as Record<string, unknown>;
    const tasks = r?.tasks;
    if (!Array.isArray(tasks) || tasks.length === 0) return [];
    const task = tasks[0] as Record<string, unknown>;
    const result = task?.result;
    if (!Array.isArray(result) || result.length === 0) return [];
    const firstResult = result[0] as Record<string, unknown>;
    const items = firstResult?.items;
    if (!Array.isArray(items)) return [];
    return items;
  } catch {
    return [];
  }
}

/**
 * Safely extract tasks[0].result[0].datetime from a DataForSEO response.
 */
function extractDatetime(response: unknown): string | null {
  try {
    const r = response as Record<string, unknown>;
    const tasks = r?.tasks;
    if (!Array.isArray(tasks) || tasks.length === 0) return null;
    const task = tasks[0] as Record<string, unknown>;
    const result = task?.result;
    if (!Array.isArray(result) || result.length === 0) return null;
    const firstResult = result[0] as Record<string, unknown>;
    const dt = firstResult?.datetime;
    return typeof dt === "string" && dt.length > 0 ? dt : null;
  } catch {
    return null;
  }
}

/**
 * Normalize a raw DataForSEO SERP response into the internal shape.
 */
export function normalizeDataForSeoSerp(
  response: unknown
): NormalizedSerpResult {
  const items = extractItems(response);

  const organicResults: NormalizedRankingEntry[] = [];
  const features: string[] = [];
  let aiOverviewPresent = false;
  let aiOverviewText: string | null = null;

  const seenFeatures = new Set<string>();

  for (const rawItem of items) {
    const item = rawItem as Record<string, unknown>;
    const type = item?.type;

    if (typeof type !== "string") continue;

    // Collect tracked SERP features (deduplicated)
    if (TRACKED_FEATURES.has(type) && !seenFeatures.has(type)) {
      features.push(type);
      seenFeatures.add(type);
    }

    // AI Overview detection
    if (type === "ai_overview") {
      aiOverviewPresent = true;
      // Attempt to extract snippet text — field name varies by API version
      const text =
        (item?.text as string | undefined) ??
        (item?.description as string | undefined) ??
        null;
      if (typeof text === "string" && text.length > 0) {
        aiOverviewText = text;
      }
    }

    // Organic results only
    if (type !== "organic") continue;

    const rank =
      typeof item?.rank_absolute === "number" ? item.rank_absolute : null;
    const domain =
      typeof item?.domain === "string" ? item.domain : null;
    const url = typeof item?.url === "string" ? item.url : null;

    // url is required; skip malformed entries
    if (!url) continue;

    organicResults.push({
      rank: rank ?? organicResults.length + 1,
      domain,
      url,
    });
  }

  // topDomains: first 10 organic domains in rank order (already sorted by DataForSEO)
  const topDomains = organicResults
    .slice(0, 10)
    .map((r) => r.domain)
    .filter((d): d is string => d !== null);

  const validAt = extractDatetime(response);

  return {
    organicResults,
    topDomains,
    aiOverviewPresent,
    aiOverviewStatus: aiOverviewPresent ? "present" : "absent",
    aiOverviewText,
    features,
    validAt,
    rawPayload: response,
  };
}
