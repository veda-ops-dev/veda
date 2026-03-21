# Y1 Step 1 — Payload Inspection Report

## Document Status

**COMPLETE.** Live payload inspection executed against real DataForSEO YouTube Organic SERP data.

Query: `weather forecast` | Baseline: en-US, desktop, location_code 2840, `block_depth=20`
Captured: `2026-03-19 02:31:25 +00:00` | Items returned: 20 | Types observed: `youtube_video`, `youtube_channel`

---

## 1. Execution Status

**Live payload inspection successfully executed** via the DataForSEO SERP Playground, using the curl command from the sample documentation with real credentials. The full 20-item response was provided and analyzed.

The repo credentials in `.env.local` are invalid for direct API calls from this environment (confirmed 401). The operator ran the curl externally and provided the raw JSON payload, which is the correct approach.

---

## 2. Baseline Used

- **Locale:** `en-US` (location_code 2840, language_code `en`)
- **Device:** `desktop`
- **OS:** `windows`
- **block_depth:** `20`
- **Auth context:** DataForSEO server-side crawl (no signed-in YouTube session)
- **Endpoint:** `/v3/serp/youtube/organic/live/advanced`

---

## 3. Query Sample

This pass used a single query (`weather forecast`) from the DataForSEO sample curl. The 10-query set from the research brief has not yet been run. However, this payload is sufficient to close the critical research questions because it contains both `youtube_video` and `youtube_channel` items, allowing real field-level verification for both types.

| Query | Reason | Status |
|-------|--------|--------|
| `weather forecast` | Head term, news/freshness-heavy, likely mixed types | ✓ Inspected |
| `learn python` | Head term, mixed channels/videos | Pending |
| `how to tie a bowline knot` | Tail term, video-heavy | Pending |
| `fix leaky faucet bathroom` | Tail instructional | Pending |
| `MrBeast` | Branded entity, channel result | Pending |
| `beginner guitar lessons playlist` | Playlist-targeted | Pending |
| `funny cats shorts` | Shorts-targeted | Pending |
| `Linus Tech Tips` | Branded channel | Pending |
| `excel vlookup tutorial` | Instructional | Pending |
| `javascript promises explained` | Technical instructional | Pending |

A separate playlist-heavy verification pass was run using `lofi playlist` — see section 9.

The critical research questions (channel identity format, video identity, freshness fields, type vocabulary) are all closeable from this single payload.

---

## 4. Observed Payload Reality

### 4.1 Envelope Structure

The response is a flat `items[]` array at `tasks[0].result[0].items`. There is no nested block structure.

Result-level fields (not on individual items):
- `result[0].datetime` — `"2026-03-19 02:31:25 +00:00"` — the snapshot capture time
- `result[0].check_url` — `"https://www.youtube.com/results?search_query=weather%20forecast"` — the YouTube search URL
- `result[0].item_types` — `["youtube_video", "youtube_channel"]` — summary of types present
- `result[0].items_count` — `20`
- `result[0].se_results_count` — `143137061`
- `result[0].spell` — `null`

### 4.2 Result Types Observed

From 20 items in this payload:
- `youtube_video`: 19 items
- `youtube_channel`: 1 item (at rank_absolute 15)
- `youtube_playlist`: 0 items
- `youtube_video_paid`: 0 items

No other type strings appeared. The channel item interrupts the video list at position 15, then video results resume at position 16.

### 4.3 Rank / Order Fields

All four ranking fields are present on every item without exception:

| Field | Behavior in this payload |
|-------|--------------------------|
| `rank_absolute` | Sequential 1–20 across all items and all types |
| `rank_group` | Resets per type: videos 1–14 then resume at 15–19 after the channel; channel = 1 |
| `block_rank` | Sequential 2–21 (offset by +1 from rank_absolute — block_rank 1 is absent, likely reserved for an above-results slot) |
| `block_name` | `null` on every item in this payload — no named shelves appeared |

**block_rank offset observation:** rank_absolute 1 has block_rank 2; rank_absolute 20 has block_rank 21. block_rank 1 is never present in this result. This suggests block_rank 1 is reserved for a promoted/ads slot above the organic list that is absent here. This must not be treated as an error — it is observed reality.

**block_name = null everywhere:** For this query, no named shelf blocks appeared (no "People also watched", no "Channels new to you"). block_name may only appear for specific query types or with higher block_depth. It cannot be relied upon as a consistent field.

### 4.4 Channel Identity — RESOLVED

**This was the highest-risk question. It is now definitively answered.**

**`channel_id` is a direct UC-prefixed field on every item.** It is present on all 19 `youtube_video` items and on the `youtube_channel` item. No item was missing a channel_id. No null channel_ids observed.

**`channel_url` delivers the @handle form.** Every item uses `https://www.youtube.com/@HandleName` format. No `/channel/UC...` URLs appear in channel_url. However, because `channel_id` is a separate direct field carrying the UC... ID, this is not a problem: the normalizer reads `channel_id` directly and never needs to parse `channel_url` for the canonical identifier.

Real examples from the payload:
- `channel_id: "UC1FbPiXx59_ltnFVx7IxWow"` / `channel_url: "https://www.youtube.com/@Foxweather"`
- `channel_id: "UCvBVK2ymNzPLRJrgip2GeQQ"` / `channel_url: "https://www.youtube.com/@MaxVelocityWX"`
- `channel_id: "UCkH1uDkyuO9sVjSqdqBygOg"` / `channel_url: "https://www.youtube.com/@CBSLA"`

**Conclusion:** Channel-first identity is fully realizable at the ingest boundary. The normalizer reads `channel_id` directly. `channel_url` is metadata only — store it but never use it as the identity anchor.

**Update (playlist pass):** The playlist verification pass (section 9) confirmed that `channel_id` is NOT guaranteed on all item types. Some radio/mix-style `youtube_playlist` results return `channel_id = null`. See section 9 for details.

### 4.5 Video Identity — RESOLVED

**`video_id` is a direct 11-character field on every `youtube_video` item.** No URL extraction required as the primary path.

Real examples:
- `video_id: "K08QPpNB7cI"`
- `video_id: "YtFc9uUYUEs"`
- `video_id: "AgWdJS_zbpU"`

**`url` field is noisy and not canonical.** The item `url` includes tracking params: `&pp=ygUQd2VhdGhlciBmb3JlY2FzdA%3D%3D` (base64 of the query). One item also has `&t=49s`. The url field must not be used as a canonical identifier or uniqueness key — use `video_id` directly.

The `youtube_channel` item has no `video_id`. Its identity is `channel_id` + `url` (the channel URL).

### 4.6 Freshness — RESOLVED

Two fields exist on `youtube_video` items. Neither exists on `youtube_channel` items.

| Field | Format | Example | Usability |
|-------|--------|---------|-----------|
| `publication_date` | Relative human string | `"3 days ago"`, `"Streamed 2 days ago"`, `"22 hours ago"`, `"12 hours ago"`, `"6 hours ago"`, `"9 days ago"` | Not machine-parseable without heuristics |
| `timestamp` | UTC datetime string | `"2026-03-17 02:31:25 +00:00"` | Parseable, but computed — see note |

**`timestamp` is computed, not sourced from YouTube's metadata.** It is produced by subtracting the relative offset from `result[0].datetime`. Evidence:
- `result[0].datetime` = `2026-03-19 02:31:25 +00:00`
- Item with `publication_date: "6 hours ago"` → `timestamp: "2026-03-18 20:31:25 +00:00"` → exactly 6h before capture
- Item with `publication_date: "9 days ago"` → `timestamp: "2026-03-10 02:31:25 +00:00"` → exactly 9 days before capture, time component copied from capture time

**Implications for Y1:**
- The `timestamp` is useful for ordering and day-level freshness analysis, but is an approximation. For a video published "9 days ago", the actual publish time within that day is unknown — the time component is always the capture time.
- For sub-day precision ("6 hours ago", "22 hours ago"), the timestamp is more accurate.
- Store both fields: `timestamp` as the promoted date column for freshness queries, `publication_date` as a raw string for audit/display.
- Field name to use in Y1 schema: `publishedAt` (from `timestamp`) and `publicationDateRaw` (from `publication_date`).

### 4.7 Boolean Flags

All three boolean flags present on every `youtube_video` item in this payload:
- `is_live`: all `false` in this sample
- `is_shorts`: all `false` in this sample (expected — weather forecast query returns no Shorts)
- `is_movie`: all `false` in this sample — and **confirmed present** (was uncertain from docs)

All three are valid hot-field candidates for `youtube_video` items.

### 4.8 youtube_channel Field Schema — Confirmed Polymorphism

The single `youtube_channel` item (rank_absolute 15) confirms the field name differences documented in secondary research:

| Concept | On `youtube_video` | On `youtube_channel` |
|---------|-------------------|---------------------|
| Display name | `channel_name` | `name` |
| Page URL | `channel_url` | `url` |
| Logo | `channel_logo` | `logo` |
| Subscriber/video count | (absent) | `video_count` (= 0 in this sample — unreliable) |
| Verification | (absent) | `is_verified` (= `true`) |
| Date fields | `publication_date`, `timestamp` | absent |
| `title` | present | absent |
| `video_id` | present | absent |
| `views_count` | present | absent |
| `duration_time` | present | absent |
| `is_live`, `is_shorts`, `is_movie` | present | absent |
| `badges` | present | absent |

**The normalizer must branch on `type` before accessing any field.** A shared field access pattern will fail.

### 4.9 Other Fields

- `highlighted`: array of matched query terms, or `null` (item 9 has `null`) — rawPayload only, not a hot field
- `badges`: array of strings (`"New"`, `"CC"`) or absent — rawPayload candidate; `"CC"` indicates closed captions, `"New"` is recency marker
- `description`: present on all items, truncated — rawPayload only
- `thumbnail_url`: present on all items — rawPayload only
- `channel_logo`: present on all video items — rawPayload only
- `duration_time`: string (`"3:21"`, `"11:55:00"`) — rawPayload or promoted if duration analysis matters
- `duration_time_seconds`: integer — promotable if needed
- `views_count`: integer — rawPayload candidate; useful for enrichment diagnostics but volatile

---

## 5. Confirmed Hot Fields

Fields confirmed as reliable and consistent enough to promote to explicit columns in Y1:

| Field (source) | Y1 column name | Type | Applies to | Confidence |
|----------------|---------------|------|-----------|------------|
| `type` | `elementType` | string enum | all items | CONFIRMED — present on every item |
| `rank_absolute` | `rankAbsolute` | integer | all items | CONFIRMED — present on every item |
| `rank_group` | `rankGroup` | integer | all items | CONFIRMED — present on every item |
| `block_rank` | `blockRank` | integer | all items | CONFIRMED — present on every item |
| `block_name` | `blockName` | string\|null | all items | CONFIRMED present — but `null` in this payload; store for future |
| `channel_id` | `channelId` | string\|null | all items | CONFIRMED on video/channel items; **nullable** — some playlist items lack it (see section 9) |
| `video_id` | `videoId` | string | youtube_video only | CONFIRMED — direct 11-char field |
| `is_shorts` | `isShort` | boolean | youtube_video only | CONFIRMED — present on every video item |
| `is_live` | `isLive` | boolean | youtube_video only | CONFIRMED — present on every video item |
| `is_movie` | `isMovie` | boolean | youtube_video only | CONFIRMED — present on every video item |
| `timestamp` | `publishedAt` | datetime | youtube_video only | CONFIRMED — parseable absolute; note it is computed/approximate |
| `is_verified` | `isVerified` | boolean | youtube_channel only | CONFIRMED — present on channel item |

Fields that should stay in `rawPayload`:
- `publication_date` (raw string — store for audit, too fragile to query against)
- `title`, `description`, `thumbnail_url`, `channel_logo`, `logo`, `channel_url`, `url`
- `highlighted`, `badges`
- `views_count`, `duration_time`, `duration_time_seconds`
- `channel_name` / `name` (display names are mutable — identity is `channel_id`)

---

## 6. Ambiguities / Risks

**1. `timestamp` is computed, not sourced.**
The timestamp is an approximation computed from the relative `publication_date` label. Day-level accuracy only for videos older than ~24h. Do not represent it to operators as the exact YouTube publish time.

**2. `block_name` was null for this query.**
Whether named shelves appear on other query types (branded, playlist-targeted, Shorts-heavy) is unknown. The field must be stored but cannot be relied upon as consistently populated.

**3. `video_count: 0` on the channel item.**
The channel item shows `video_count: 0` for a clearly active channel. This field may be unreliable or may require a separate enrichment call. Do not promote `video_count` to a hot column.

**4. `block_rank` starts at 2, not 1.**
Block_rank 1 is absent in this 20-item payload. This is likely a structural artifact (block_rank 1 = reserved above-fold position). Normalizer and schema must not assume block_rank starts at 1.

**5. Pending query types: Shorts, branded entity.**
Playlists are now live-verified (see section 9). This query returns no Shorts (`is_shorts: false` everywhere) and no `youtube_video_paid`. The field inventory for Shorts is doc-confirmed but not live-confirmed. Low risk — `is_shorts` field is already confirmed present on all video items.

**6. `url` field contains tracking params.**
Item URLs include `&pp=` query params. These cannot be used as canonical identifiers or for URL-based deduplication. Only `video_id` and `channel_id` are clean canonical identifiers.

---

## 7. Y1 Unblocking Judgment

### What This Inspection Resolves

**Bucket 1 (Truth-Surface) — RESOLVED for video + channel + playlist types.**
The payload structure is confirmed: flat `items[]`, four fields per item for ranking, result-level metadata for capture time and check_url. Field presence is confirmed for `youtube_video` and `youtube_channel` types from this payload, and for `youtube_playlist` from the playlist verification pass (section 9).

**Bucket 2 (Identity Extraction) — RESOLVED.**
Channel identity: `channel_id` direct field, UC-prefixed, present on every video and channel item. No extraction needed. Video identity: `video_id` direct field, 11-char, present on every video item. Playlist identity: `playlist_id` is a direct field on playlist items. Note: `channel_id` is NOT guaranteed on all playlist items — radio/mix-style results may have null channel identity (see section 9).

**Bucket 4 (Freshness) — RESOLVED.**
Two fields confirmed: `timestamp` (computed absolute, promotable) and `publication_date` (raw relative string, rawPayload only). `publishedAt` should map from `timestamp`. The computed nature is a documented limitation, not a blocker.

**Bucket 3 (Variance) — PARTIALLY resolved.**
Structure and field consistency confirmed. The variance-across-repeated-captures question (Jaccard stability over 24h) is not answered by a single snapshot. Low risk for schema design — uniqueness key is `(projectId, query, locale, device, capturedAt)` which is time-based, not content-based.

**Bucket 5 (Enrichment) — CONFIRMED deferred.**
Subscriber count is not in the payload (`video_count: 0` on the channel item is unreliable). Upload cadence is not present. Post-Y1.

### What Still Needs Research

1. ~~Live payload for a query that returns `youtube_playlist`.~~ **RESOLVED** — playlist verification pass completed. See section 9.
2. Live payload for a Shorts-heavy query — to confirm `is_shorts: true` items and their field completeness. Recommended but not blocking.
3. Live payload for a branded entity query — to confirm whether `youtube_channel` items appear differently and whether `block_name` is populated for known-channel queries. Optional.
4. Variance baseline (Bucket 3) — same query repeated at 24h to characterize result-set stability. Optional.

---

## 8. Artifacts Created / Updated

- **This report (updated):** `docs/systems/veda/youtube-observatory/Y1-STEP1-INSPECTION-REPORT.md`
- **Inspection script (ready for remaining queries):** `scripts/yt-payload-inspect.mjs`

---

## 9. Playlist Verification Pass

### Evidence

A playlist-heavy query (`lofi playlist`) was run against DataForSEO YouTube Organic SERP with the same baseline parameters (en-US, desktop, location_code 2840).

Results: 20 total items, including 5 `youtube_playlist` items.

### Confirmed

- `playlist_id` is a direct field on every `youtube_playlist` item.
- `channel_id` is present on 4 of 5 playlist items (UC-prefixed, same format as video/channel items).
- Rank fields (`rank_absolute`, `rank_group`, `block_rank`) are present on all playlist items.

### Null channel identity case

1 of 5 playlist items returned with null channel identity fields:
- `type`: `youtube_playlist`
- `playlist_id`: begins with `RD` (radio/mix-style auto-generated playlist)
- `channel_id`: `null`
- `channel_name`: `null`
- `channel_url`: `null`

This is a real playlist result from YouTube, not a malformed payload. Radio/mix-style playlists are auto-generated by YouTube and have no owning channel.

### Schema implication

`channelId` must remain nullable on `YtSearchElement` at Y1. This is not a temporary conservative deviation — it is the correct schema truth supported by live payload evidence. The normalizer correctly stores null `channelId` for these items.

---

## Appendix: Annotated Item Examples From Live Payload

### youtube_video item (rank 1)

```json
{
  "type": "youtube_video",
  "rank_group": 1,
  "rank_absolute": 1,
  "block_rank": 2,
  "block_name": null,
  "title": "LIVE Coverage Tracking Major Bomb Cyclone Blizzard...",
  "url": "https://www.youtube.com/watch?v=K08QPpNB7cI&pp=...",
  "video_id": "K08QPpNB7cI",
  "channel_id": "UC1FbPiXx59_ltnFVx7IxWow",
  "channel_name": "FOX Weather",
  "channel_url": "https://www.youtube.com/@Foxweather",
  "is_live": false,
  "is_shorts": false,
  "is_movie": false,
  "views_count": 112299,
  "publication_date": "Streamed 2 days ago",
  "timestamp": "2026-03-17 02:31:25 +00:00",
  "duration_time": "11:55:00",
  "duration_time_seconds": 42900
}
```

### youtube_channel item (rank 15)

```json
{
  "type": "youtube_channel",
  "rank_group": 1,
  "rank_absolute": 15,
  "block_rank": 16,
  "block_name": null,
  "channel_id": "UCvBVK2ymNzPLRJrgip2GeQQ",
  "name": "Max Velocity - Severe Weather Center",
  "url": "https://www.youtube.com/@MaxVelocityWX",
  "logo": "https://yt3.ggpht.com/...",
  "video_count": 0,
  "is_verified": true,
  "description": "Max Velocity is a degreed meteorologist..."
}
```
