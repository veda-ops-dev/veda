# y1-payload-findings.md

## Purpose

This note records what the live DataForSEO YouTube Organic SERP payload evidence has confirmed for Y1, what it has not yet confirmed, and what the next bounded step is.

It is a findings note. It is not a schema doc, a route doc, or an implementation proposal.

This note exists so payload truth from the Step 1 inspection pass does not stay trapped in chat history.

If this note and the live payload inspection report (`Y1-STEP1-INSPECTION-REPORT.md`) conflict, the inspection report is more detailed and should be treated as the more authoritative record.

---

## Evidence Base

- Live DataForSEO YouTube Organic SERP payload — keyword `weather forecast`, location_code 2840, language_code `en`, device `desktop`, `block_depth=20`, captured `2026-03-19 02:31:25 +00:00`
- DataForSEO YouTube Organic SERP API documentation (fetched from `docs.dataforseo.com/v3/serp/youtube/organic/live/advanced/`)
- DataForSEO official blog post response sample (`midnights review`, December 2022)
- `Y1-RESEARCH-BRIEF.md` — the five research buckets and their questions
- `Y1-STEP1-INSPECTION-REPORT.md` — the full field-level analysis of the live payload

The live payload contained 20 items: 19 `youtube_video` and 1 `youtube_channel`. No playlists and no paid items appeared in this sample.

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
- `youtube_playlist` — playlist result items

No other type strings exist in the documented API. Shorts are `youtube_video` items with `is_shorts: true`, not a separate type.

### Rank fields

All four ranking fields are present on every item, confirmed from the live payload:
- `rank_absolute` — position across all items in the entire SERP (sequential 1–N)
- `rank_group` — position within items of the same type (resets per type)
- `block_rank` — position in the page's block sequence (may be offset — starts at 2 in the live payload, not 1)
- `block_name` — string label for the shelf/block the item belongs to, or `null`

In the live payload, `block_name` was `null` on every item. Named shelves may appear for other query types but cannot be assumed consistently present.

### Channel identity

This was the highest-risk unknown in the research brief. It is now closed.

**`channel_id` is a direct field on every item, carrying the UC-prefixed YouTube channel ID** (`UC` + 22 base64url characters). It appeared on all 19 `youtube_video` items and on the 1 `youtube_channel` item. No nulls were observed.

**`channel_url` uses `@handle` format** (e.g., `https://www.youtube.com/@Foxweather`). This is not the canonical identity field. The canonical identity is always `channel_id`.

The normalizer reads `channel_id` directly. No URL parsing is required for the primary channel identity path.

### Video identity

**`video_id` is a direct field on every `youtube_video` item**, carrying the 11-character YouTube video ID. No URL extraction is required as the primary path.

The item `url` field contains tracking query parameters (`&pp=`, `&t=`) and must not be used as an identifier or for deduplication. The clean canonical video reference is `video_id`.

### Freshness

Two fields exist on `youtube_video` items. Neither appears on `youtube_channel` items.

**`timestamp`** — absolute UTC datetime string (`"2026-03-17 02:31:25 +00:00"`). Parseable. But it is computed by DataForSEO by subtracting the relative label from the capture datetime, not sourced from YouTube's own metadata. Day-level accuracy only for videos older than ~24 hours — the time component mirrors the capture time for those items.

**`publication_date`** — relative display string (`"3 days ago"`, `"22 hours ago"`, `"Streamed 2 days ago"`). Human-readable only. Not machine-parseable without heuristics. Store for audit/display. Do not use as a canonical date.

For Y1 purposes: `timestamp` is the promoted freshness field, stored as `publishedAt`. Its computed/approximate nature must be documented. `publication_date` stays in `rawPayload`.

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

These are de-risking passes. They are not structural blockers for schema design.

**1. `youtube_playlist` item shape and `playlist_id` delivery**
No playlist items appeared in the `weather forecast` payload. A query likely to return playlists (e.g., `beginner guitar lessons playlist`) should be run to confirm: whether `playlist_id` is a direct field, the exact field schema for playlist items, and whether `channel_id` is present on playlist items as expected.

**2. `is_shorts: true` item completeness**
No Shorts items appeared in this payload (`is_shorts: false` on all 19 video items). A Shorts-heavy query should be run to confirm that `is_shorts: true` items are structurally complete and that no fields are absent for Shorts vs standard video items.

**3. `block_name` with non-null values**
All `block_name` fields were null in this payload. A query known to produce named shelves (e.g., a branded channel query or a query that reliably produces "People also watched") would confirm what block_name values look like in practice and how stable they are.

**4. Result-set variance across repeated captures**
A single snapshot does not characterize how much the result set changes between captures of the same query. Running the same query at 24-hour intervals and computing Jaccard overlap would establish how stable the observation surface is. This affects how hammer tests for the observation floor should be written.

---

## Y1 Implications

The confirmed payload evidence supports the following for Y1 design:

**Channel-first identity is realizable at the ingest boundary.** `channel_id` is always present as a direct field. No enrichment, no URL parsing, no API call required to populate it.

**Video identity is clean.** `video_id` is a direct field. The `url` field is not suitable for deduplication.

**Freshness is partially available at ingest time.** `timestamp` provides a computed absolute date suitable for freshness-related read surfaces, with the documented limitation that it is an approximation for videos older than ~24 hours.

**The normalizer must be type-aware.** `youtube_video` and `youtube_channel` use different field names for the same concepts. A shared accessor pattern will fail. The normalizer must branch on `type` before extracting any fields.

**`rawPayload` should store the complete item.** Fields not promoted to explicit columns — `title`, `description`, `thumbnail_url`, `channel_url`, `url`, `channel_logo`, `highlighted`, `badges`, `views_count`, `duration_time`, `publication_date`, `channel_name` / `name` — belong in `rawPayload`. Display names (`channel_name`, `name`) are mutable and must not serve as identity.

**`youtube_playlist` and Shorts-heavy items are confirmed item types but not live-verified from this payload.** Schema design can proceed now; the pending de-risking passes validate the existing design rather than gate it.

---

## Recommended Next Step

Schema and route judgment for Y1 can now proceed.

The payload evidence is sufficient to design the Y1 observation floor: a target-definition table, a snapshot table, and a search-element table. The field inventory above determines which fields are promoted columns and which stay in `rawPayload`.

Before or alongside schema design, run the two higher-priority de-risking passes: a playlist-returning query and a Shorts-returning query. These validate the design rather than block it.

Any schema or route work must still satisfy current VEDA invariants: project isolation, atomic writes with EventLog, deterministic ordering, hammer-testable behavior, no schema changes without explicit justification, no new routes without explicit justification.

---

## Document Notes

- Evidence basis: live DataForSEO payload provided 2026-03-19
- Stored alongside: `Y1-RESEARCH-BRIEF.md`, `Y1-STEP1-INSPECTION-REPORT.md`
- Authority: subordinate to `overview.md`, `observatory-model.md`, `ingest-discipline.md`, `validation-doctrine.md`, and the full authority chain in the research brief