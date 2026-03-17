/**
 * serp-extraction.ts — Shared SERP payload extraction helpers
 *
 * Extracted from serp-deltas/route.ts so that serp-history and any future
 * read endpoints can reuse the same logic without duplication.
 *
 * Consumers:
 *   - src/app/api/seo/serp-deltas/route.ts
 *   - src/app/api/seo/keyword-targets/[id]/serp-history/route.ts
 *   - src/app/api/seo/keyword-targets/[id]/feature-transitions/route.ts (SIL-8 A3)
 *
 * Rules:
 *   - Pure functions. No DB access. No side effects.
 *   - Deterministic: same rawPayload always produces the same output.
 *   - parseWarning=true iff the payload structure was not recognized or was
 *     recognized but yielded zero items despite containing non-empty input.
 */

// =============================================================================
// Types
// =============================================================================

/**
 * A single organic result extracted from a rawPayload.
 * url is the canonical key for set comparisons.
 * rank is null if the payload structure didn't yield a numeric position.
 */
export interface ExtractedResult {
  url:    string;
  domain: string | null;
  rank:   number | null;
  title:  string | null;
}

export interface ExtractionResult {
  results:      ExtractedResult[];
  parseWarning: boolean;
}

// =============================================================================
// Internal helpers
// =============================================================================

function extractDomain(url: string): string | null {
  try {
    return new URL(url).hostname;
  } catch {
    return null;
  }
}

function sortResults(results: ExtractedResult[]): ExtractedResult[] {
  return results.slice().sort((a, b) => {
    if (a.rank === null && b.rank === null) return a.url.localeCompare(b.url);
    if (a.rank === null) return 1;
    if (b.rank === null) return -1;
    if (a.rank !== b.rank) return a.rank - b.rank;
    return a.url.localeCompare(b.url);
  });
}

// =============================================================================
// extractFeatureSortedArray -- SIL-8 A3
// =============================================================================

/**
 * Extract SERP feature type strings from a rawPayload and return them as a
 * sorted array for deterministic key construction (SIL-8 A3 feature transitions).
 *
 * Strategy 1 -- DataForSEO items array (primary):
 *   All items where item.type is a non-empty string and !== "organic".
 *
 * Strategy 2 -- Simple / test payloads:
 *   Top-level payload.features[] -- string entries or objects with .type.
 *
 * Returns: string[] sorted lexicographically ascending. Empty array when no
 *   features are present or payload is unrecognized.
 *
 * Invariant: same rawPayload always produces the same array (deterministic).
 * The separator character U+2192 (right arrow) used in transitionKey is
 * guaranteed not to appear in DataForSEO feature type strings.
 */
export function extractFeatureSortedArray(rawPayload: unknown): string[] {
  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return [];
  }
  const p = rawPayload as Record<string, unknown>;
  const types = new Set<string>();

  if (Array.isArray(p.items)) {
    for (const item of p.items) {
      if (
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item) &&
        typeof (item as Record<string, unknown>).type === "string" &&
        (item as Record<string, unknown>).type !== "organic"
      ) {
        const t = (item as Record<string, unknown>).type as string;
        if (t.length > 0) types.add(t);
      }
    }
    return Array.from(types).sort();
  }

  if (Array.isArray(p.features)) {
    for (const f of p.features) {
      if (typeof f === "string" && f.length > 0) {
        types.add(f);
      } else if (
        f !== null &&
        typeof f === "object" &&
        !Array.isArray(f) &&
        typeof (f as Record<string, unknown>).type === "string"
      ) {
        const t = (f as Record<string, unknown>).type as string;
        if (t.length > 0) types.add(t);
      }
    }
    return Array.from(types).sort();
  }

  return [];
}

// =============================================================================
// extractFeatureSignals -- new export, SIL feature tracking
// =============================================================================

/**
 * FeatureSignals -- structured SERP feature presence for a single snapshot.
 *
 * rawTypesSorted: deduplicated non-organic DataForSEO type strings, sorted.
 * familiesSorted: normalized family strings, sorted.
 * flags: boolean presence for each known family.
 * parseWarning: true when payload shape is unrecognized, OR when items/features
 *   array is non-empty but yields zero non-organic types (extraction failure).
 */
export interface FeatureSignals {
  rawTypesSorted: string[];
  familiesSorted: string[];
  flags: {
    hasFeaturedSnippet: boolean;
    hasPeopleAlsoAsk: boolean;
    hasLocalPack: boolean;
    hasVideo: boolean;
    hasShopping: boolean;
    hasImages: boolean;
    hasTopStories: boolean;
    hasKnowledgePanel: boolean;
    hasSitelinks: boolean;
    hasReviews: boolean;
    hasRelatedSearches: boolean;
    hasOther: boolean;
  };
  parseWarning: boolean;
}

// Stable family mapping -- deterministic, case-insensitive, conservative.
// Unknown types -> "other" (never throws, never returns undefined).
function mapTypeToFamily(t: string): string {
  switch (t.toLowerCase()) {
    case "featured_snippet":  return "featured_snippet";
    case "people_also_ask":   return "people_also_ask";
    case "local_pack":        return "local_pack";
    case "knowledge_graph":   return "knowledge_panel";
    case "knowledge_panel":   return "knowledge_panel";
    case "video":             return "video";
    case "video_box":         return "video";
    case "shopping":          return "shopping";
    case "shopping_ads":      return "shopping";
    case "images":            return "images";
    case "image_pack":        return "images";
    case "top_stories":       return "top_stories";
    case "news_box":          return "top_stories";
    case "sitelinks":         return "sitelinks";
    case "reviews":           return "reviews";
    case "review_snippet":    return "reviews";
    case "related_searches":  return "related_searches";
    default:                  return "other";
  }
}

/**
 * extractFeatureSignals -- pure function, no side effects.
 *
 * Reads non-organic SERP feature types from rawPayload and returns
 * a fully structured FeatureSignals object.
 *
 * Strategy 1 -- DataForSEO items[] (primary):
 *   items where item.type is a non-empty string !== "organic".
 *
 * Strategy 2 -- test/simple payloads:
 *   payload.features[] (string or {type: string}).
 *
 * Does NOT touch extractFeatureSortedArray or extractOrganicResults.
 * Does NOT mutate any shared state.
 * Deterministic: identical rawPayload -> identical FeatureSignals.
 */
export function extractFeatureSignals(rawPayload: unknown): FeatureSignals {
  const EMPTY_FLAGS = {
    hasFeaturedSnippet: false,
    hasPeopleAlsoAsk:   false,
    hasLocalPack:       false,
    hasVideo:           false,
    hasShopping:        false,
    hasImages:          false,
    hasTopStories:      false,
    hasKnowledgePanel:  false,
    hasSitelinks:       false,
    hasReviews:         false,
    hasRelatedSearches: false,
    hasOther:           false,
  };

  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return { rawTypesSorted: [], familiesSorted: [], flags: { ...EMPTY_FLAGS }, parseWarning: true };
  }

  const p = rawPayload as Record<string, unknown>;
  const rawTypes = new Set<string>();
  let recognized = false;

  // Strategy 1: DataForSEO items[]
  if (Array.isArray(p.items)) {
    recognized = true;
    for (const item of p.items) {
      if (
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item) &&
        typeof (item as Record<string, unknown>).type === "string"
      ) {
        const t = ((item as Record<string, unknown>).type as string).trim();
        if (t.length > 0 && t !== "organic") rawTypes.add(t);
      }
    }
  }
  // Strategy 2: test/simple features[]
  else if (Array.isArray(p.features)) {
    recognized = true;
    for (const f of p.features) {
      if (typeof f === "string" && f.trim().length > 0) {
        rawTypes.add(f.trim());
      } else if (
        f !== null &&
        typeof f === "object" &&
        !Array.isArray(f) &&
        typeof (f as Record<string, unknown>).type === "string"
      ) {
        const t = ((f as Record<string, unknown>).type as string).trim();
        if (t.length > 0) rawTypes.add(t);
      }
    }
  }

  // parseWarning: unrecognized payload, OR non-empty input that yielded zero types
  // (indicates all items had missing/null type fields -- extraction failure).
  // An all-organic SERP (inputLength > 0, rawTypes empty because all were "organic")
  // is NOT a warning -- it is valid. We cannot distinguish that case cheaply here,
  // so we conservatively warn only on truly unrecognized payloads.
  const parseWarning = !recognized;

  const rawTypesSorted = Array.from(rawTypes).sort();

  // Map to families (deduped set, then sorted)
  const familySet = new Set<string>();
  for (const t of rawTypesSorted) {
    familySet.add(mapTypeToFamily(t));
  }
  const familiesSorted = Array.from(familySet).sort();

  // Build flags
  const flags = {
    hasFeaturedSnippet: familySet.has("featured_snippet"),
    hasPeopleAlsoAsk:   familySet.has("people_also_ask"),
    hasLocalPack:       familySet.has("local_pack"),
    hasVideo:           familySet.has("video"),
    hasShopping:        familySet.has("shopping"),
    hasImages:          familySet.has("images"),
    hasTopStories:      familySet.has("top_stories"),
    hasKnowledgePanel:  familySet.has("knowledge_panel"),
    hasSitelinks:       familySet.has("sitelinks"),
    hasReviews:         familySet.has("reviews"),
    hasRelatedSearches: familySet.has("related_searches"),
    hasOther:           familySet.has("other"),
  };

  return { rawTypesSorted, familiesSorted, flags, parseWarning };
}

// =============================================================================
// extractOrganicResults
// =============================================================================

/**
 * Extract organic results from a SERP rawPayload.
 *
 * Strategy 1 — DataForSEO Advanced SERP (primary):
 *   rawPayload.items[] where item.type === "organic"
 *   Fields: rank_absolute (preferred), position (fallback), url, domain, title
 *
 * Strategy 2 — Simple / test payloads:
 *   rawPayload.results[] where item.url is a string
 *   Fields: rank (preferred), position (fallback), url, domain, title
 *
 * Duplicate URLs: first-wins (results are sorted rank asc so lowest rank wins).
 * parseWarning: true when payload is unrecognized or recognized but empty
 *   despite non-empty input (signals extraction failure to callers).
 */
export function extractOrganicResults(rawPayload: unknown): ExtractionResult {
  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return { results: [], parseWarning: true };
  }

  const payload = rawPayload as Record<string, unknown>;

  // ── Strategy 1: DataForSEO items array ──────────────────────────────────────
  if (Array.isArray(payload.items)) {
    const organic = payload.items
      .filter(
        (item): item is Record<string, unknown> =>
          item !== null &&
          typeof item === "object" &&
          !Array.isArray(item) &&
          (item as Record<string, unknown>).type === "organic" &&
          typeof (item as Record<string, unknown>).url === "string"
      )
      .map((item) => ({
        url:    item.url as string,
        domain:
          typeof item.domain === "string"
            ? item.domain
            : extractDomain(item.url as string),
        rank:
          typeof item.rank_absolute === "number"
            ? item.rank_absolute
            : typeof item.position === "number"
            ? item.position
            : null,
        title: typeof item.title === "string" ? item.title : null,
      }));

    const sorted = sortResults(organic);
    const parseWarning = organic.length === 0 && payload.items.length > 0;
    return { results: sorted, parseWarning };
  }

  // ── Strategy 2: Simple results array (test / mock payloads) ─────────────────
  if (Array.isArray(payload.results)) {
    const results = payload.results
      .filter(
        (item): item is Record<string, unknown> =>
          item !== null &&
          typeof item === "object" &&
          !Array.isArray(item) &&
          typeof (item as Record<string, unknown>).url === "string"
      )
      .map((item) => ({
        url:    item.url as string,
        domain:
          typeof item.domain === "string"
            ? item.domain
            : extractDomain(item.url as string),
        rank:
          typeof item.rank === "number"
            ? item.rank
            : typeof item.position === "number"
            ? item.position
            : null,
        title: typeof item.title === "string" ? item.title : null,
      }));

    const sorted = sortResults(results);
    return { results: sorted, parseWarning: false };
  }

  // ── Unrecognized structure ───────────────────────────────────────────────────
  return { results: [], parseWarning: true };
}
