# y1-payload-findings.md

## Purpose

This note records what the live DataForSEO YouTube Organic SERP payload evidence has confirmed for Y1, what it has not yet confirmed, and what the next bounded step is.

It is a findings note. It is not a schema doc, a route doc, or an implementation proposal.

This note exists so payload truth from the Step 1 inspection pass does not stay trapped in chat history.

If this note and the live payload inspection report (`Y1-STEP1-INSPECTION-REPORT.md`) conflict, the inspection report is more detailed and should be treated as the more authoritative record.

---

## Evidence Base

- Live DataForSEO YouTube Organic SERP payload — keyword `weather forecast`, location_code 2840, language_code `en`, device `desktop`, `block_depth=20`, captured `2026-03-19 02:31:25 +00:00`
- Live DataForSEO YouTube Organic SERP payload — keyword `lofi playlist`, same baseline parameters (playlist verification pass)
- DataForSEO YouTube Organic SERP API documentation (fetched from `docs.dataforseo.com/v3/serp/youtube/organic/live/advanced/`)
- DataForSEO official blog post response sample (`midnights review`, December 2022)
- `Y1-RESEARCH-BRIEF.md` — the five research buckets and their questions
- `Y1-STEP1-INSPECTION-REPORT.md` — the full field-level analysis of the live payload

The `weather forecast` payload contained 20 items: 19 `youtube_video` and 1 `youtube_channel`. No playlists and no paid items appeared in that sample.

The `lofi playlist` payload contained 20 items including 5 `youtube_playlist` items.

---

## What Is Now Confirmed

### Truth surface

DataForSEO YouTube Organic SERP (`/v3/serp/youtube/organic/live/advanced`) is confirmed as a workable primary observation surface for Y1. The response structure is stable and legible.

**Video Info, Video Subtitles, and Video Comments are not Y1 surfaces.** Video Info is a per-video enrichment call for a known ID. Subtitles and Comments are content and engagement surfaces. None belong in Y1.

### Response structure

The response is a **flat `items[]` array** at `tasks[0].result[0].items`. There is no nested block structure in the response body. Every item sits at the same nesting level regardless of type.

Result-level fields (not on items):
- `datetime` — the capture timestamp in UTC (`"2026-03-19 02:31:25 +00:00"`)
- `check_url` — the YouTube search URL for the keyword
- `item_types` — array summary of which types appeared
- `items_count`, `se_results_count`

### Item types

The complete confirmed type vocabulary from documentation and live evidence:
- `youtube_video` — organic video results, including live streams and Shorts (distinguished by boolean flags)
- `youtube_video_paid` — promoted video results, same field schema as `youtube_video`
- `youtube_channel` — channel result items
- `youtube_playlist` — playlist result items (live-verified in playlist pass)

No other type strings exist in the documented API. Shorts are `youtube_video` items with `is_shorts: true`, not a separate type.

### Rank fields

All four ranking fields are present on every item, confirmed from the live payload:
- `rank_absolute` — position across all items in the entire SERP (sequential 1–N)
- `rank_group` — position within items of the same type (resets per type)
- `block_rank` — position in the page's block sequence (may be offset — starts at 2 in the live payload, not 1)
- `block_name` — string label for the shelf/block the item belongs to, or `null`

In the live payload, `block_name` was `null` on every item. Named shelves may appear for other query types but cannot be assumed consistently present.

### Channel identity

This was the highest-risk unknown in the research brief. It is now closed, with a nullable caveat for playlists.

**`channel_id` is a direct field on every `youtube_video` and `youtube_channel` item**, carrying the UC-prefixed YouTube channel ID (`UC` + 22 base64url characters). No nulls were observed on video or channel items.

**`channel_id` is NOT guaranteed on `youtube_playlist` items.** The playlist verification pass confirmed that most playlist items (4 of 5) carry `channel_id`, but radio/mix-style auto-generated playlists (`playlist_id` beginning with `RD`) return `channel_id = null` along with null `channel_name` and `channel_url`. These are real YouTube results, not malformed payloads.

**`channel_url` uses `@handle` format** (e.g., `https://www.youtube.com/@Foxweather`). This is not the canonical identity field. The canonical identity is always `channel_id`.

The normalizer reads `channel_id` directly. No URL parsing is required for the primary channel identity path.

### Video identity

**`video_id` is a direct field on every `youtube_video` item**, carrying the 11-character YouTube video ID. No URL extraction is required as the primary path.

The item `url` field contains tracking query parameters (`&pp=`, `&t=`) and must not be used as an identifier or for deduplication. The clean canonical video reference is `video_id`.

### Playlist identity

**`playlist_id` is a direct field on every `youtube_playlist` item.** This was confirmed in the playlist verification pass. Standard playlists carry normal `PL`-prefixed IDs. Radio/mix-style playlists carry `RD`-prefixed IDs.

### Freshness

Two fields exist on `youtube_video` items. Neither appears on `youtube_channel` or `youtube_playlist` items.

**`timestamp`** — absolute UTC datetime string (`"2026-03-17 02:31:25 +00:00"`). Parseable. But it is computed by DataForSEO by subtracting the relative label from the capture datetime, not sourced from YouTube's own metadata. Day-level accuracy only for videos older than ~24 hours — the time component mirrors the capture time for those items.

**`publication_date`** — relative display string (`"3 days ago"`, `"22 hours ago"`, `"Streamed 2 days ago"`). Human-readable only. Not machine-parseable without heuristics. Store for audit/display. Do not use as a canonical date.

For Y1 purposes: `timestamp` is the promoted freshness field, stored as `observedPublishedAt`. Its computed/approximate nature must be documented. `publication_date` stays in `rawPayload`.

### Field schema differences between item types

The `youtube_channel` item type uses different field names for the same concepts. This is confirmed from the live payload and the documentation. The normalizer must branch on `type`.

| Concept | `youtube_video` | `youtube_channel` |
|---------|----------------|-------------------|
| Display name | `channel_name` | `name` |
| Page URL | `channel_url` | `url` |
| Logo | `channel_logo` | `logo` |
| Verification | absent | `is_verified` |
| Title | `title` | absent |
| Date fields | `publication_date`, `timestamp` | absent |
| Video/content fields | `video_id`, `is_shorts`, `is_live`, `is_movie`, `views_count`, `duration_time`, `badges` | absent |

### Boolean flags

All three boolean flags confirmed present on every `youtube_video` item:
- `is_shorts` — false in this sample (expected: weather forecast returns no Shorts)
- `is_live` — false in this sample
- `is_movie` — false in this sample; field confirmed present (was uncertain from docs)

---

## What Remains Unverified

These are optional de-risking passes. They are not blockers.

**1. `is_shorts: true` item completeness**
No Shorts items appeared in the `weather forecast` payload (`is_shorts: false` on all 19 video items). A Shorts-heavy query should be run to confirm that `is_shorts: true` items are structurally complete and that no fields are absent for Shorts vs standard video items. Low risk — the `is_shorts` field is already confirmed present.

**2. `block_name` with non-null values**
All `block_name` fields were null in both payloads. A query known to produce named shelves would confirm what block_name values look like in practice.

**3. Result-set variance across repeated captures**
A single snapshot does not characterize how much the result set changes between captures of the same query. Optional.

---

## Y1 Implications

The confirmed payload evidence supports the following for Y1 design:

**Channel-first identity is realizable at the ingest boundary for video and channel items.** `channel_id` is always present as a direct field on those types. No enrichment, no URL parsing, no API call required.

**Playlist items may lack channel identity.** Radio/mix-style auto-generated playlists have no owning channel and return null `channel_id`. The schema must allow nullable `channelId` on element rows.

**Video identity is clean.** `video_id` is a direct field. The `url` field is not suitable for deduplication.

**Playlist identity is clean.** `playlist_id` is a direct field on playlist items.

**Freshness is partially available at ingest time.** `timestamp` provides a computed absolute date suitable for freshness-related read surfaces, with the documented limitation that it is an approximation for videos older than ~24 hours.

**The normalizer must be type-aware.** `youtube_video` and `youtube_channel` use different field names for the same concepts. `youtube_playlist` has its own field shape. A shared accessor pattern will fail. The normalizer must branch on `type` before extracting any fields.

**`rawPayload` should store the complete item.** Fields not promoted to explicit columns belong in `rawPayload`. Display names (`channel_name`, `name`) are mutable and must not serve as identity.

---

## Recommended Next Step

Y1 observation floor is implemented and hammer-validated. Next priorities are read routes for the YouTube observation data, followed by batch ingest capability.

---

## Document Notes

- Evidence basis: live DataForSEO payloads — `weather forecast` (2026-03-19), `lofi playlist` (playlist verification pass)
- Stored alongside: `Y1-RESEARCH-BRIEF.md`, `Y1-STEP1-INSPECTION-REPORT.md`
- Authority: subordinate to `overview.md`, `observatory-model.md`, `ingest-discipline.md`, `validation-doctrine.md`, and the full authority chain in the research brief
