/**
 * page-command-center.ts — Page Command Center Lite (pure library)
 *
 * Pure functions for route-text tokenization and keyword overlap matching.
 * No DB access. No Prisma. No side effects. Deterministic.
 *
 * Tokenization rules (from VSCODE-PAGE-COMMAND-CENTER spec):
 *   - lowercase normalization
 *   - strip brackets from dynamic segments: [slug] → slug
 *   - split on / . - _
 *   - exclude boilerplate tokens: page, layout, route, src, app, index,
 *     default, js, jsx, ts, tsx
 *   - exclude tokens shorter than 3 characters
 *   - full-word matching only (no fuzzy, no stemming, no embeddings)
 *   - deduplicate tokens (preserve first-occurrence order)
 */

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const BOILERPLATE_TOKENS = new Set([
  "page",
  "layout",
  "route",
  "src",
  "app",
  "index",
  "default",
  "js",
  "jsx",
  "ts",
  "tsx",
]);

const MIN_TOKEN_LENGTH = 3;

// ─────────────────────────────────────────────────────────────────────────────
// Tokenization
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Tokenize a route hint string into normalized, filtered tokens.
 *
 * Strips bracket notation from dynamic segments before splitting.
 * Returns deduplicated tokens in first-occurrence order.
 */
export function tokenizeRouteHint(routeHint: string): string[] {
  // Strip brackets: [slug] → slug, [...catchAll] → catchAll
  const stripped = routeHint.replace(/\[\.{0,3}([^\]]+)\]/g, "$1");
  return deduplicateTokens(splitAndFilter(stripped));
}

/**
 * Tokenize a file name into normalized, filtered tokens.
 *
 * Strips the file extension before splitting.
 * Returns deduplicated tokens in first-occurrence order.
 */
export function tokenizeFileName(fileName: string): string[] {
  // Remove extension (last dot-segment)
  const stem = fileName.replace(/\.[^.]+$/, "");
  return deduplicateTokens(splitAndFilter(stem));
}

/**
 * Split a string on path/name separators and filter out boilerplate + short tokens.
 */
function splitAndFilter(input: string): string[] {
  return input
    .split(/[/.\-_]/)
    .map((t) => t.toLowerCase().trim())
    .filter(
      (t) =>
        t.length >= MIN_TOKEN_LENGTH && !BOILERPLATE_TOKENS.has(t)
    );
}

/**
 * Deduplicate tokens preserving first-occurrence order.
 */
function deduplicateTokens(tokens: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const t of tokens) {
    if (!seen.has(t)) {
      seen.add(t);
      result.push(t);
    }
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyword overlap matching
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Tokenize a keyword query for matching purposes.
 *
 * Splits on whitespace, hyphens, and underscores. Applies the same
 * length filter (>= 3 chars) but does NOT apply boilerplate exclusion
 * (keyword queries like "default settings" should keep "default" as a
 * matchable token — boilerplate exclusion is only for route/file tokens).
 */
export function tokenizeQuery(query: string): string[] {
  return query
    .split(/[\s\-_]+/)
    .map((t) => t.toLowerCase().trim())
    .filter((t) => t.length >= MIN_TOKEN_LENGTH);
}

export interface KeywordOverlapCandidate {
  keywordTargetId: string;
  query: string;
}

export interface KeywordOverlapMatch {
  keywordTargetId: string;
  query: string;
  matchTokens: string[];
}

/**
 * Find keyword targets whose query tokens overlap with page context tokens.
 *
 * Full-word matching only. Returns matches sorted deterministically:
 *   matchTokens.length DESC, query ASC, keywordTargetId ASC
 *
 * Each match includes the specific tokens that overlapped.
 */
export function computeRouteTextOverlaps(
  pageTokens: string[],
  candidates: KeywordOverlapCandidate[],
  limit: number
): KeywordOverlapMatch[] {
  if (pageTokens.length === 0 || candidates.length === 0) return [];

  const pageTokenSet = new Set(pageTokens);
  const matches: KeywordOverlapMatch[] = [];

  for (const candidate of candidates) {
    const queryTokens = tokenizeQuery(candidate.query);
    // Full-word overlap: query token must exactly match a page token
    const overlap = queryTokens.filter((t) => pageTokenSet.has(t));
    if (overlap.length === 0) continue;

    // Deduplicate overlap tokens (stable order from queryTokens iteration)
    const seen = new Set<string>();
    const dedupedOverlap: string[] = [];
    for (const t of overlap) {
      if (!seen.has(t)) {
        seen.add(t);
        dedupedOverlap.push(t);
      }
    }

    // Sort matchTokens deterministically: localeCompare ASC
    dedupedOverlap.sort((a, b) => a.localeCompare(b));

    matches.push({
      keywordTargetId: candidate.keywordTargetId,
      query: candidate.query,
      matchTokens: dedupedOverlap,
    });
  }

  // Deterministic sort: matchTokens.length DESC, query ASC, keywordTargetId ASC
  matches.sort((a, b) => {
    if (b.matchTokens.length !== a.matchTokens.length)
      return b.matchTokens.length - a.matchTokens.length;
    const qCmp = a.query.localeCompare(b.query);
    if (qCmp !== 0) return qCmp;
    return a.keywordTargetId.localeCompare(b.keywordTargetId);
  });

  return matches.slice(0, limit);
}

// ─────────────────────────────────────────────────────────────────────────────
// Page relevance heuristic
// ─────────────────────────────────────────────────────────────────────────────

const PAGE_RELEVANT_FILE_TYPES = new Set(["page", "template", "view", "component"]);
const PAGE_RELEVANT_EXTENSIONS = new Set(["tsx", "jsx", "vue", "svelte", "astro"]);

/**
 * Lightweight heuristic to determine if a file/route context is page-relevant.
 *
 * Returns true if:
 *   - fileType is explicitly page-relevant, OR
 *   - fileName matches common page file patterns, OR
 *   - routeHint is provided (implies route-level context)
 *
 * This is descriptive only — does not claim analysis capability.
 */
export function isPageRelevant(
  routeHint: string | null,
  fileName: string | null,
  fileType: string | null
): boolean {
  // Explicit fileType check
  if (fileType && PAGE_RELEVANT_FILE_TYPES.has(fileType.toLowerCase())) {
    return true;
  }

  // fileName pattern check
  if (fileName) {
    const lower = fileName.toLowerCase();
    // Common page file names
    if (lower.startsWith("page.") || lower.startsWith("index.")) {
      const ext = lower.split(".").pop() ?? "";
      if (PAGE_RELEVANT_EXTENSIONS.has(ext)) return true;
    }
  }

  // routeHint presence implies route-level context
  if (routeHint && routeHint.trim().length > 0) {
    return true;
  }

  return false;
}
