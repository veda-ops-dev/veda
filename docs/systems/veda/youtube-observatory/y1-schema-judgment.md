# Y1 Schema Judgment

## Purpose

This document pins the exact schema decisions for YouTube Search Observatory Y1.

It is the bridge between doctrine/research and coding.
It is grounded against live payload evidence from `Y1-STEP1-INSPECTION-REPORT.md`, not against generic schema symmetry.

This doc is subordinate to:
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/systems/veda/youtube-observatory/overview.md`
- `docs/systems/veda/youtube-observatory/observatory-model.md`
- `docs/systems/veda/youtube-observatory/ingest-discipline.md`
- `docs/systems/veda/youtube-observatory/validation-doctrine.md`

If this document conflicts with those authorities, they win.

---

## Three-Table Minimum Shape

Y1 uses exactly three tables. No more.

### 1. YtSearchTarget

**Purpose:** Governance record. Defines what the project chooses to observe on YouTube search. Equivalent to `KeywordTarget` in the existing SERP lane.

This is not an observation row. It is the target-definition row.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID (PK, server-generated) | |
| `projectId` | UUID (FK → Project) | Required. No fallback. |
| `query` | String | The YouTube search query to observe |
| `locale` | String | e.g. `"en"` — DataForSEO `language_code` |
| `device` | String | e.g. `"desktop"` |
| `locationCode` | String | e.g. `"2840"` — DataForSEO location_code, stored as string for stability |
| `isPrimary` | Boolean | Default `false`. Operator classification only. |
| `notes` | String? | Optional operator notes |
| `createdAt` | DateTime | Server-assigned |
| `updatedAt` | DateTime | Auto-updated |

**Uniqueness:** `@@unique([projectId, query, locale, device, locationCode])`

**Indexes:** `@@index([projectId])`

**Why `locationCode` is in the uniqueness key:** DataForSEO YouTube results vary by location. Two targets with identical query/locale/device but different location codes observe different reality and must be distinct targets.

**Relationship to existing `KeywordTarget`:** These are separate tables. `KeywordTarget` governs Google SERP observation. `YtSearchTarget` governs YouTube search observation. They may share the same query string across both lanes for the same project; that is normal and expected.

### 2. YtSearchSnapshot

**Purpose:** Immutable observation record. One row per capture event. Equivalent to `SERPSnapshot` in the existing SERP lane.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID (PK, server-generated) | |
| `projectId` | UUID (FK → Project) | Required. No fallback. |
| `ytSearchTargetId` | UUID (FK → YtSearchTarget) | Required. Links snapshot to its target. |
| `capturedAt` | DateTime | Server-assigned capture time |
| `validAt` | DateTime? | Provider-indicated time if available. From `result[0].datetime`. |
| `checkUrl` | String? | YouTube search URL from `result[0].check_url` |
| `itemsCount` | Int | Number of items in the snapshot. From `result[0].items_count`. |
| `itemTypes` | String[] | Summary of types present. From `result[0].item_types`. |
| `rawPayload` | Json | Full `result[0]` envelope for evidence/replay |
| `source` | String | Provider identifier. Default `"dataforseo-youtube-organic"` |
| `createdAt` | DateTime | Server-assigned |

**Uniqueness:** `@@unique([projectId, ytSearchTargetId, capturedAt])`

**Indexes:** `@@index([projectId, ytSearchTargetId, capturedAt])`, `@@index([projectId])`

**Idempotency rule:** Before creating a snapshot, check for an existing snapshot with the same `(projectId, ytSearchTargetId)` where `capturedAt` is within 60 seconds of the proposed capture time. If found, reject as duplicate. This matches the existing SERP lane's recent-window gate pattern.

**Why `rawPayload` stores the result envelope:** The full `result[0]` object is preserved for evidence, replay, and future field promotion. Individual element items are also stored in `YtSearchElement` rows with promoted fields. This is intentional duplication — the snapshot-level rawPayload is the audit trail, the element rows are the queryable surface.

### 3. YtSearchElement

**Purpose:** Per-item observation row within a snapshot. Promoted fields extracted from each item in the payload's `items[]` array.

This table does not exist in the current SERP lane (where elements live inside `rawPayload`). Y1 promotes elements to their own table because YouTube search elements carry rich identity fields (`channelId`, `videoId`, booleans) that would be trapped inside opaque JSON otherwise.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID (PK, server-generated) | |
| `snapshotId` | UUID (FK → YtSearchSnapshot) | Required. Parent snapshot. |
| `projectId` | UUID (FK → Project) | Denormalized. See justification below. |
| `elementType` | String | Vendor type string: `youtube_video`, `youtube_channel`, `youtube_playlist`, `youtube_video_paid` |
| `rankAbsolute` | Int | Position across all items in SERP (1-indexed) |
| `rankGroup` | Int | Position within same-type items |
| `blockRank` | Int | Block-sequence position (may be offset, e.g. starts at 2) |
| `blockName` | String? | Shelf/block label or null. Store but do not rely on. |
| `channelId` | String | UC-prefixed YouTube channel ID. Present on every item per payload evidence. |
| `videoId` | String? | 11-char YouTube video ID. Present on `youtube_video` only. Null for channel/playlist items. |
| `isShort` | Boolean? | `is_shorts` from payload. Null for non-video items. |
| `isLive` | Boolean? | `is_live` from payload. Null for non-video items. |
| `isMovie` | Boolean? | `is_movie` from payload. Null for non-video items. |
| `isVerified` | Boolean? | `is_verified` from payload. Present on `youtube_channel` only. Null otherwise. |
| `observedPublishedAt` | DateTime? | From vendor `timestamp` field. Computed/approximate. Null for non-video items. See naming note. |
| `rawPayload` | Json | Full individual item object from `items[]` for evidence |
| `createdAt` | DateTime | Server-assigned |

**Uniqueness:** `@@unique([snapshotId, rankAbsolute])`

**Indexes:** `@@index([projectId, channelId])`, `@@index([projectId, videoId])`, `@@index([snapshotId])`

---

## Key Schema Decisions

### Why `observedPublishedAt` instead of `publishedAt`

The vendor `timestamp` field is computed by subtracting the relative `publication_date` label from the capture datetime. It is an approximation:
- Sub-day precision for recent videos ("6 hours ago")
- Day-level only for older videos ("9 days ago" — time component copied from capture time)

The name `observedPublishedAt` signals to any consumer that this is an observed approximation, not the canonical YouTube publish timestamp. It prevents downstream surfaces from treating it as authoritative metadata.

The raw `publication_date` string (e.g., "3 days ago", "Streamed 2 days ago") stays in `rawPayload` only.

### Why `projectId` is denormalized on `YtSearchElement`

Without `projectId` on element rows, any project-scoped query across elements requires joining through `YtSearchSnapshot`. Since element-level queries are the primary analytical surface (e.g., "show me all appearances of channelId X across my project"), the two-hop join would be mandatory on every read.

Denormalized `projectId` on element rows avoids this.

**Invariant:** `YtSearchElement.projectId` must always equal `YtSearchSnapshot.projectId` for the parent snapshot. This is enforced by the ingest route writing both values from the same resolved project context in a single transaction. A DB trigger may additionally enforce this if defense-in-depth is desired.

### Why `channelId` is NOT NULL on elements

Live payload evidence confirms `channel_id` is a direct UC-prefixed field on every item type (`youtube_video` and `youtube_channel`). No null values were observed across 20 items.

If a future payload returns an item without `channel_id`, the normalizer must handle it explicitly — either reject the item or store it with a sentinel value. This is a normalizer-level decision, not a schema-level nullable column.

**Caution:** `youtube_playlist` items have not been live-verified. If playlist items lack `channel_id`, this column must be made nullable in the migration. The de-risking query pass should confirm this before or alongside migration.

**Implementation note (first migration):** The first Y1 migration implements `channelId` as nullable (`String?`) as a conservative choice, since the playlist verification pass has not yet been completed. The NOT NULL recommendation above remains the target state; the column should be tightened to NOT NULL after playlist items are live-verified and confirmed to carry `channel_id`. This is the only intentional schema deviation from this document in the first implementation pass.

### Why `elementType` is a plain String, not an enum

The vendor may add new type strings in future API versions. A Prisma enum would require a migration for each new type. A plain string column with application-level validation (Zod enum with `.catch()` fallthrough to store unrecognized types) is more resilient.

The normalizer validates against the known vocabulary (`youtube_video`, `youtube_channel`, `youtube_playlist`, `youtube_video_paid`) and stores unrecognized types as-is rather than rejecting them. This preserves observation completeness.

### What stays in rawPayload only

These fields are confirmed present but deliberately not promoted to columns:

- `title` — display text, not identity
- `description` — truncated display text
- `thumbnail_url`, `channel_logo`, `logo` — media URLs, volatile
- `channel_url`, `url` — contain tracking params or handle-format URLs, not canonical
- `channel_name`, `name` — mutable display names, not identity
- `views_count` — volatile, changes between captures
- `duration_time`, `duration_time_seconds` — useful but not required for Y1 observation floor
- `publication_date` — raw relative string, audit only
- `highlighted` — query-match markers
- `badges` — display annotations ("New", "CC")
- `video_count` — unreliable (observed `0` on active channel)

Any of these may be promoted to columns in a later pass if justified by a concrete read-surface need.

### What is intentionally NOT in the schema

- No `YtSearchBlock` table. Block structure is a flat annotation (`blockRank`, `blockName` on element rows), not a nested entity.
- No enrichment tables. Subscriber count, upload cadence, and YouTube API data are post-Y1.
- No derived/computed tables. Result-type composition, channel appearance frequency, and rank stability are compute-on-read surfaces, not materialized tables.
- No cross-lane joins. `YtSearchTarget` and `KeywordTarget` are independent tables. Cross-lane analysis is a future derived read surface, not a schema coupling.

---

## EventLog Integration

### New EntityType values

Add to the `EntityType` enum:
- `ytSearchTarget`
- `ytSearchSnapshot`

### New EventType values

Add to the `EventType` enum:
- `YT_SEARCH_TARGET_CREATED`
- `YT_SEARCH_SNAPSHOT_RECORDED`

### Event write rules

- `YT_SEARCH_TARGET_CREATED` is emitted atomically with `YtSearchTarget` creation. Actor: `system` (when auto-created during ingest) or `human` (when created via direct target management).
- `YT_SEARCH_SNAPSHOT_RECORDED` is emitted atomically with `YtSearchSnapshot` creation and all child `YtSearchElement` rows. The entire ingest (snapshot + elements + event) must be a single transaction.

No EventLog entries are emitted for element-row creation — the snapshot-level event covers the entire capture.

---

## Route Contract (Ingest)

### `POST /api/seo/youtube/search/ingest`

**Purpose:** Accept a DataForSEO YouTube Organic SERP payload, normalize it, and persist the snapshot with elements.

**Request body (Zod `.strict()`):**

```
{
  query: string         // required
  locale: string        // required, e.g. "en"
  device: string        // required, e.g. "desktop"
  locationCode: string  // required, e.g. "2840"
  payload: object       // required — the full DataForSEO response
}
```

**Behavior:**

1. Resolve `projectId` strictly (no fallback).
2. Validate request body with Zod `.strict()`.
3. Find or create `YtSearchTarget` for `(projectId, query, locale, device, locationCode)`. If created, emit `YT_SEARCH_TARGET_CREATED`.
4. Check idempotency: existing snapshot for same target within 60-second window → reject with 409.
5. Extract `result[0]` from payload. Validate structure.
6. For each item in `result[0].items[]`, run the normalizer to extract promoted fields.
7. In a single transaction: create `YtSearchSnapshot`, create all `YtSearchElement` rows, emit `YT_SEARCH_SNAPSHOT_RECORDED`.
8. Return 201 with snapshot ID and element count.

**Error responses:**

- 400: malformed body, missing required fields, invalid payload structure
- 404: project not found (cross-project non-disclosure)
- 409: duplicate snapshot within recent window
- 500: transaction failure

### Read routes — deferred

No read routes are defined for Y1. The observation floor must be validated via hammer before read surfaces are designed. Read routes may be added in a follow-on pass if justified.

---

## Normalizer Contract

The normalizer is a pure library function at `src/lib/seo/youtube/normalize-yt-search.ts`.

**Signature:** `(resultEnvelope: unknown) => NormalizedYtSearchResult`

**Behavior:**

1. Validate the result envelope structure.
2. Extract snapshot-level fields (`datetime`, `check_url`, `items_count`, `item_types`).
3. For each item, branch on `type`:
   - `youtube_video` / `youtube_video_paid`: extract `channel_id`, `video_id`, `rank_absolute`, `rank_group`, `block_rank`, `block_name`, `is_shorts`, `is_live`, `is_movie`, `timestamp`
   - `youtube_channel`: extract `channel_id`, `rank_absolute`, `rank_group`, `block_rank`, `block_name`, `is_verified`. Set video-specific fields to null.
   - `youtube_playlist`: extract `channel_id` (if present), `rank_absolute`, `rank_group`, `block_rank`, `block_name`. Set video/channel-specific fields to null.
   - Unrecognized type: extract rank fields and `channel_id` if present. Set all type-specific fields to null. Preserve full item in rawPayload.
4. Return structured result with snapshot-level data and normalized element array.

**No I/O. No Date.now(). No randomness.** The normalizer is deterministic given the same input.

---

## Prisma Model Relationships

```
Project
  ├── YtSearchTarget[]
  ├── YtSearchSnapshot[]
  └── (YtSearchElement[] via denormalized projectId)

YtSearchTarget
  └── YtSearchSnapshot[]

YtSearchSnapshot
  └── YtSearchElement[]
```

`Project` model must add reverse relation fields for the three new tables.
`EntityType` and `EventType` enums must be extended.

---

## Document Notes

- This schema is grounded against the confirmed hot fields table in `Y1-STEP1-INSPECTION-REPORT.md`, section 5.
- `youtube_playlist` field shape is not yet live-verified. The `channelId` NOT NULL decision carries low risk but should be confirmed by the playlist de-risking query pass. If playlist items lack `channel_id`, make the column nullable before migration.
- No read routes are defined here. The observation floor must prove itself through the hammer before read surfaces are designed.
- This document does not authorize schema changes by itself. The migration must be reviewed and accepted before execution.
