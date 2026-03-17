/**
 * Validation utilities shared across VEDA API surfaces.
 * Grounded by:
 * - `docs/architecture/api/api-contract-principles.md`
 * - `docs/architecture/api/validation-and-error-taxonomy.md`
 * - `docs/architecture/veda/search-intelligence-layer.md`
 */

// --- Enum validation sets (from Prisma enums / canonical docs) ---

export const VALID_SOURCE_TYPES = [
  "rss",
  "webpage",
  "comment",
  "reply",
  "video",
  "other",
] as const;

export const VALID_PLATFORMS = [
  "website",
  "x",
  "youtube",
  "github",
  "reddit",
  "hackernews",
  "substack",
  "linkedin",
  "discord",
  "other",
] as const;

export const VALID_SOURCE_ITEM_STATUSES = [
  "ingested",
  "triaged",
  "used",
  "archived",
] as const;

// --- Simple helpers ---

export function isValidEnum<T extends string>(
  value: unknown,
  allowed: readonly T[]
): value is T {
  return typeof value === "string" && allowed.includes(value as T);
}

export function isValidUrl(url: unknown): url is string {
  if (typeof url !== "string" || url.trim().length === 0) return false;
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}

export function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

/**
 * Normalize a search query for deterministic matching.
 * Grounded by the current ingest discipline and search-intelligence rules:
 * 1. trim leading/trailing whitespace
 * 2. collapse internal whitespace to single spaces
 * 3. lowercase
 */
export function normalizeQuery(query: string): string {
  return query.trim().replace(/\s+/g, " ").toLowerCase();
}

/**
 * Generate a slug from a title.
 * Per docs: slugs are lowercase, hyphens, no spaces.
 */
export function slugify(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/**
 * Generate a content hash from a URL.
 * Per API contract: POST /api/source-items/capture generates contentHash from URL.
 * Using a simple hash since we're in a browser/edge-compatible context.
 */
export async function generateContentHash(url: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(url);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}
