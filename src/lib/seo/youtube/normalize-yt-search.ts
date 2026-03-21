/**
 * normalize-yt-search.ts — Pure normalizer for DataForSEO YouTube Organic SERP payloads
 *
 * Grounded by:
 * - docs/systems/veda/youtube-observatory/y1-schema-judgment.md
 * - docs/systems/veda/youtube-observatory/y1-payload-findings.md
 * - docs/systems/veda/youtube-observatory/ingest-discipline.md
 *
 * Rules:
 * - No I/O. No Date.now(). No randomness. Pure transform.
 * - Branch on item type (youtube_video, youtube_channel, youtube_playlist, youtube_video_paid)
 * - Promote hot fields per schema judgment
 * - Preserve rawPayload per item
 * - Tolerate unknown future type strings by storing them as-is
 * - Do not parse identity from tracking URLs — use direct fields (channel_id, video_id)
 * - Reject entire payload if any item is missing rank_absolute (atomic contract)
 */

// -----------------------------------------------------------------------------
// Output types
// -----------------------------------------------------------------------------

export interface NormalizedYtSnapshotMeta {
  /** Provider datetime from result[0].datetime, or null */
  validAt: string | null;
  /** YouTube search URL from result[0].check_url */
  checkUrl: string | null;
  /** Number of items from result[0].items_count */
  itemsCount: number;
  /** Summary of types present from result[0].item_types */
  itemTypes: string[];
  /** The full result[0] envelope for rawPayload storage */
  resultEnvelope: unknown;
}

export interface NormalizedYtElement {
  elementType: string;
  rankAbsolute: number;
  rankGroup: number;
  blockRank: number;
  blockName: string | null;
  channelId: string | null;
  videoId: string | null;
  isShort: boolean | null;
  isLive: boolean | null;
  isMovie: boolean | null;
  isVerified: boolean | null;
  /** Parsed from vendor timestamp field. Approximate. Null for non-video items. */
  observedPublishedAt: string | null;
  /** Full individual item object for evidence */
  rawPayload: unknown;
}

export interface NormalizedYtSearchResult {
  snapshot: NormalizedYtSnapshotMeta;
  elements: NormalizedYtElement[];
}

// -----------------------------------------------------------------------------
// Known element type vocabulary
// -----------------------------------------------------------------------------

const VIDEO_TYPES = new Set(["youtube_video", "youtube_video_paid"]);
const CHANNEL_TYPE = "youtube_channel";
const PLAYLIST_TYPE = "youtube_playlist";

// -----------------------------------------------------------------------------
// Internal helpers — pure, no I/O
// -----------------------------------------------------------------------------

function extractString(obj: Record<string, unknown>, key: string): string | null {
  const val = obj[key];
  return typeof val === "string" ? val : null;
}

function extractNumber(obj: Record<string, unknown>, key: string): number | null {
  const val = obj[key];
  return typeof val === "number" ? val : null;
}

function extractBoolean(obj: Record<string, unknown>, key: string): boolean | null {
  const val = obj[key];
  return typeof val === "boolean" ? val : null;
}

function extractStringArray(obj: Record<string, unknown>, key: string): string[] {
  const val = obj[key];
  if (!Array.isArray(val)) return [];
  return val.filter((v): v is string => typeof v === "string");
}

// -----------------------------------------------------------------------------
// Element normalizer — branches on type
// Throws on structurally invalid items (missing type or rank_absolute).
// -----------------------------------------------------------------------------

function normalizeElement(item: unknown, index: number): NormalizedYtElement {
  if (!item || typeof item !== "object" || Array.isArray(item)) {
    throw new Error(`Item at index ${index} is not a valid object`);
  }
  const rec = item as Record<string, unknown>;

  const elementType = extractString(rec, "type");
  if (!elementType) {
    throw new Error(`Item at index ${index} is missing required field: type`);
  }

  const rankAbsolute = extractNumber(rec, "rank_absolute");
  if (rankAbsolute === null) {
    throw new Error(`Item at index ${index} is missing required field: rank_absolute`);
  }

  const rankGroup = extractNumber(rec, "rank_group");
  const blockRank = extractNumber(rec, "block_rank");
  const blockName = extractString(rec, "block_name");
  const channelId = extractString(rec, "channel_id");

  // Branch on type for type-specific field extraction
  if (VIDEO_TYPES.has(elementType)) {
    return {
      elementType,
      rankAbsolute,
      rankGroup: rankGroup ?? 0,
      blockRank: blockRank ?? 0,
      blockName,
      channelId,
      videoId: extractString(rec, "video_id"),
      isShort: extractBoolean(rec, "is_shorts"),
      isLive: extractBoolean(rec, "is_live"),
      isMovie: extractBoolean(rec, "is_movie"),
      isVerified: null, // not present on video items
      observedPublishedAt: extractString(rec, "timestamp"),
      rawPayload: item,
    };
  }

  if (elementType === CHANNEL_TYPE) {
    return {
      elementType,
      rankAbsolute,
      rankGroup: rankGroup ?? 0,
      blockRank: blockRank ?? 0,
      blockName,
      channelId,
      videoId: null,
      isShort: null,
      isLive: null,
      isMovie: null,
      isVerified: extractBoolean(rec, "is_verified"),
      observedPublishedAt: null,
      rawPayload: item,
    };
  }

  if (elementType === PLAYLIST_TYPE) {
    return {
      elementType,
      rankAbsolute,
      rankGroup: rankGroup ?? 0,
      blockRank: blockRank ?? 0,
      blockName,
      channelId, // may be null — conservative nullable pending playlist verification
      videoId: null,
      isShort: null,
      isLive: null,
      isMovie: null,
      isVerified: null,
      observedPublishedAt: null,
      rawPayload: item,
    };
  }

  // Unrecognized future type — store with rank fields, null identity where not extractable
  return {
    elementType,
    rankAbsolute,
    rankGroup: rankGroup ?? 0,
    blockRank: blockRank ?? 0,
    blockName,
    channelId,
    videoId: extractString(rec, "video_id"),
    isShort: null,
    isLive: null,
    isMovie: null,
    isVerified: null,
    observedPublishedAt: null,
    rawPayload: item,
  };
}

// -----------------------------------------------------------------------------
// Main normalizer — pure function
// -----------------------------------------------------------------------------

/**
 * Normalize a DataForSEO YouTube Organic SERP result envelope.
 *
 * Expects the full DataForSEO response object. Extracts tasks[0].result[0].
 * Returns structured snapshot metadata and normalized element array.
 *
 * Throws on structurally invalid input:
 * - missing tasks/result/items
 * - any item missing type or rank_absolute (atomic rejection — entire payload fails)
 */
export function normalizeYtSearchPayload(payload: unknown): NormalizedYtSearchResult {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("Invalid payload: expected an object");
  }

  const root = payload as Record<string, unknown>;
  const tasks = root.tasks;
  if (!Array.isArray(tasks) || tasks.length === 0) {
    throw new Error("Invalid payload: missing or empty tasks array");
  }

  const task0 = tasks[0] as Record<string, unknown>;
  const results = task0?.result;
  if (!Array.isArray(results) || results.length === 0) {
    throw new Error("Invalid payload: missing or empty result array in tasks[0]");
  }

  const result0 = results[0] as Record<string, unknown>;
  const items = result0?.items;
  if (!Array.isArray(items)) {
    throw new Error("Invalid payload: missing items array in tasks[0].result[0]");
  }

  // Extract snapshot-level fields
  const snapshot: NormalizedYtSnapshotMeta = {
    validAt: extractString(result0, "datetime"),
    checkUrl: extractString(result0, "check_url"),
    itemsCount: typeof result0.items_count === "number" ? result0.items_count : items.length,
    itemTypes: extractStringArray(result0, "item_types"),
    resultEnvelope: result0,
  };

  // Normalize each element — throws on any invalid item (atomic rejection)
  const elements: NormalizedYtElement[] = [];
  for (let i = 0; i < items.length; i++) {
    elements.push(normalizeElement(items[i], i));
  }

  return { snapshot, elements };
}
