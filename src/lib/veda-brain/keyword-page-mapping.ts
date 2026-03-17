/**
 * keyword-page-mapping.ts — VEDA Brain Foundational Module
 *
 * Deterministically maps tracked keyword targets to project pages.
 * This mapping feeds all downstream brain comparison modules.
 *
 * Matching strategies (in priority order):
 *   1. GSC exact match — SearchPerformance links a query to a pageUrl
 *   2. URL slug token overlap — keyword query tokens appear in page URL slug
 *   3. Title token overlap — keyword query tokens appear in page title
 *
 * Confidence levels:
 *   - strong:    GSC data links keyword to page with clicks > 0
 *   - moderate:  GSC impressions-only OR high token overlap (≥ 0.5)
 *   - weak:      low token overlap (> 0 but < 0.5)
 *   - unmapped:  no match found
 *
 * Pure function. No DB access. No side effects. Deterministic output.
 */
import type { VedaBrainInput, BrainKeywordTarget, BrainPage } from "./load-brain-input";

// =============================================================================
// Types
// =============================================================================

export type MappingConfidence = "strong" | "moderate" | "weak" | "unmapped";

export type MappingStrategy =
  | "gsc_exact"
  | "url_token_overlap"
  | "title_token_overlap"
  | "none";

export interface KeywordPageMatch {
  pageId: string;
  pageUrl: string;
  confidence: MappingConfidence;
  strategy: MappingStrategy;
  overlapScore: number; // 0.0–1.0 for token overlap, 1.0 for GSC exact
}

export interface KeywordMapping {
  keywordTargetId: string;
  query: string;
  locale: string;
  device: string;
  isPrimary: boolean;
  bestMatch: KeywordPageMatch | null;
  allMatches: KeywordPageMatch[];
}

export interface KeywordPageMappingResult {
  mappings: KeywordMapping[];
  unmappedKeywords: string[];
  weakMappings: string[];
  ambiguousMappings: string[];
  summary: {
    total: number;
    strong: number;
    moderate: number;
    weak: number;
    unmapped: number;
    ambiguous: number;
  };
}

// =============================================================================
// Token helpers — deterministic normalization
// =============================================================================

/**
 * Normalize a string into lowercase alpha-numeric tokens.
 * Strips punctuation, collapses whitespace, splits on space.
 */
function tokenize(input: string): string[] {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .split(" ")
    .filter((t) => t.length > 1); // drop single-char noise
}

/**
 * Compute the ratio of query tokens found in target tokens.
 * Returns 0.0–1.0. Deterministic.
 */
function tokenOverlap(queryTokens: string[], targetTokens: string[]): number {
  if (queryTokens.length === 0) return 0;
  const targetSet = new Set(targetTokens);
  let matches = 0;
  for (const qt of queryTokens) {
    if (targetSet.has(qt)) {
      matches++;
    }
  }
  return matches / queryTokens.length;
}

/**
 * Extract path slug tokens from a URL.
 * e.g., "https://example.com/guides/how-to-fine-tune" → ["guides", "how", "to", "fine", "tune"]
 */
function urlSlugTokens(url: string): string[] {
  try {
    const pathname = new URL(url).pathname;
    return tokenize(pathname.replace(/[\/\-_\.]/g, " "));
  } catch {
    return tokenize(url);
  }
}

// =============================================================================
// Core computation
// =============================================================================

export function computeKeywordPageMapping(
  input: VedaBrainInput
): KeywordPageMappingResult {
  // Build GSC lookup: query (lowered) → [{ pageUrl, clicks, impressions }]
  const gscMap = new Map<string, { pageUrl: string; clicks: number; impressions: number }[]>();
  for (const sp of input.searchPerformance) {
    const key = sp.query.toLowerCase();
    if (!gscMap.has(key)) gscMap.set(key, []);
    gscMap.get(key)!.push({
      pageUrl: sp.pageUrl,
      clicks: sp.clicks,
      impressions: sp.impressions,
    });
  }

  // Build page URL → page lookup
  const pageByUrl = new Map<string, BrainPage>();
  for (const p of input.pages) {
    pageByUrl.set(p.url, p);
    // Also try without trailing slash
    const normalized = p.url.endsWith("/") ? p.url.slice(0, -1) : p.url + "/";
    if (!pageByUrl.has(normalized)) pageByUrl.set(normalized, p);
  }

  const mappings: KeywordMapping[] = [];

  for (const kt of input.keywordTargets) {
    const queryTokens = tokenize(kt.query);
    const allMatches: KeywordPageMatch[] = [];

    // Strategy 1: GSC exact match
    const gscEntries = gscMap.get(kt.query.toLowerCase());
    if (gscEntries) {
      for (const entry of gscEntries) {
        const page = pageByUrl.get(entry.pageUrl);
        if (page) {
          const confidence: MappingConfidence = entry.clicks > 0 ? "strong" : "moderate";
          allMatches.push({
            pageId: page.id,
            pageUrl: page.url,
            confidence,
            strategy: "gsc_exact",
            overlapScore: 1.0,
          });
        }
      }
    }

    // Strategy 2 & 3: Token overlap (URL slug + title)
    if (queryTokens.length > 0) {
      for (const page of input.pages) {
        // Skip pages already matched via GSC
        if (allMatches.some((m) => m.pageId === page.id)) continue;

        const slugTokens = urlSlugTokens(page.url);
        const titleTokens = tokenize(page.title);

        const slugOverlap = tokenOverlap(queryTokens, slugTokens);
        const titleOverlap = tokenOverlap(queryTokens, titleTokens);
        const bestOverlap = Math.max(slugOverlap, titleOverlap);
        const bestStrategy: MappingStrategy =
          slugOverlap >= titleOverlap ? "url_token_overlap" : "title_token_overlap";

        if (bestOverlap > 0) {
          const confidence: MappingConfidence =
            bestOverlap >= 0.5 ? "moderate" : "weak";
          allMatches.push({
            pageId: page.id,
            pageUrl: page.url,
            confidence,
            strategy: bestStrategy,
            overlapScore: bestOverlap,
          });
        }
      }
    }

    // Deterministic sort: confidence rank → overlapScore desc → pageId asc
    const confRank: Record<MappingConfidence, number> = {
      strong: 0,
      moderate: 1,
      weak: 2,
      unmapped: 3,
    };
    allMatches.sort((a, b) => {
      const cr = confRank[a.confidence] - confRank[b.confidence];
      if (cr !== 0) return cr;
      if (b.overlapScore !== a.overlapScore) return b.overlapScore - a.overlapScore;
      return a.pageId.localeCompare(b.pageId);
    });

    const bestMatch = allMatches.length > 0 ? allMatches[0] : null;

    mappings.push({
      keywordTargetId: kt.id,
      query: kt.query,
      locale: kt.locale,
      device: kt.device,
      isPrimary: kt.isPrimary,
      bestMatch,
      allMatches,
    });
  }

  // Deterministic sort: query asc, locale asc, device asc
  mappings.sort((a, b) => {
    const q = a.query.localeCompare(b.query);
    if (q !== 0) return q;
    const l = a.locale.localeCompare(b.locale);
    if (l !== 0) return l;
    return a.device.localeCompare(b.device);
  });

  // Compute summary
  const unmappedKeywords: string[] = [];
  const weakMappings: string[] = [];
  const ambiguousMappings: string[] = [];
  let strong = 0;
  let moderate = 0;
  let weak = 0;
  let unmapped = 0;

  for (const m of mappings) {
    if (!m.bestMatch) {
      unmapped++;
      unmappedKeywords.push(m.query);
    } else if (m.bestMatch.confidence === "strong") {
      strong++;
    } else if (m.bestMatch.confidence === "moderate") {
      moderate++;
    } else {
      weak++;
      weakMappings.push(m.query);
    }

    // Ambiguous: multiple matches with similar confidence
    const topConfidence = m.bestMatch?.confidence;
    if (
      topConfidence &&
      m.allMatches.filter((am) => am.confidence === topConfidence).length > 1
    ) {
      ambiguousMappings.push(m.query);
    }
  }

  return {
    mappings,
    unmappedKeywords: unmappedKeywords.sort(),
    weakMappings: weakMappings.sort(),
    ambiguousMappings: ambiguousMappings.sort(),
    summary: {
      total: mappings.length,
      strong,
      moderate,
      weak,
      unmapped,
      ambiguous: ambiguousMappings.length,
    },
  };
}
