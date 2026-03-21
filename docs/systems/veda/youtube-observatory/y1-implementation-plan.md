# Y1 Implementation Plan

## Purpose

This document tracks the bounded implementation sequence for YouTube Search Observatory Y1.

It is the execution lane doc for this work.
It is not a roadmap phase. It is subordinate to `docs/ROADMAP.md` as an optional bounded enhancement.

---

## Sequence

### Step 1: Schema judgment acceptance
- **Artifact:** `y1-schema-judgment.md`
- **Status:** COMPLETE
- **Gate:** Operator accepted the three-table shape, column decisions, uniqueness keys, and EventLog integration.

### Step 2: Hammer story acceptance
- **Artifact:** `y1-hammer-story.md`
- **Status:** COMPLETE
- **Gate:** Operator accepted the test cases and SKIP policy.

### Step 3: De-risking query passes
- **Status:** PARTIALLY COMPLETE
- **Playlist-heavy pass:** COMPLETE. Query `lofi playlist` confirmed `youtube_playlist` field shape, direct `playlist_id` delivery, and that some playlist items (radio/mix-style, `RD`-prefixed) lack `channel_id`. Result: `channelId` remains nullable on `YtSearchElement` at Y1 by design.
- **Shorts-heavy pass:** RECOMMENDED but not blocking. `is_shorts` field is already confirmed present on all video items. A Shorts-heavy query would confirm structural completeness for `is_shorts: true` items.
- **Variance check:** OPTIONAL. Not blocking for Y1 observation floor.

### Step 4: Prisma migration
- **Status:** COMPLETE
- Added `YtSearchTarget`, `YtSearchSnapshot`, `YtSearchElement` models to `prisma/schema.prisma`.
- Extended `EntityType` enum with `ytSearchTarget`, `ytSearchSnapshot`.
- Extended `EventType` enum with `YT_SEARCH_TARGET_CREATED`, `YT_SEARCH_SNAPSHOT_RECORDED`.
- Added reverse relations on `Project` model.
- Migration applied. Build passes.

### Step 5: Pure normalizer library
- **Status:** COMPLETE
- Created `src/lib/seo/youtube/normalize-yt-search.ts`.
- Pure function. No I/O. No Date.now(). No randomness.
- Branches on `type`. Extracts promoted fields. Preserves rawPayload per item.
- Handles unrecognized types gracefully (stores with rank fields, null identity).
- Atomic rejection: throws on any item missing `type` or `rank_absolute`.

### Step 6: Ingest route
- **Status:** COMPLETE
- Created `src/app/api/seo/youtube/search/ingest/route.ts`.
- Thin handler: resolves project strictly, validates with Zod `.strict()`, delegates to normalizer, atomic write with EventLog.
- Idempotency: 60-second recent-window gate.
- Find-or-create target behavior with conditional EventLog.

### Step 7: Hammer module
- **Status:** COMPLETE
- Created `scripts/hammer/hammer-youtube-y1.ps1`.
- Registered in `scripts/api-hammer.ps1` (parse-check and run sections).
- Implements test cases from `y1-hammer-story.md`.
- Full coordinator run: **705 PASS / 0 FAIL / 11 SKIP**.

### Step 8: Docs cleanup / control-surface update
- **Status:** IN PROGRESS
- Update `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md` with the three new tables.
- Propagate playlist verification finding into YouTube docs.
- Update `docs/DOCS-CLEANUP-TRACKER.md`.

---

## Done Criteria

Y1 observation floor is done when:

1. ✅ Migration applied cleanly. Build passes.
2. ✅ Hammer module passes all non-SKIP cases.
3. ✅ Full coordinator run shows no regressions (705 PASS / 0 FAIL / 11 SKIP).
4. ⬜ Schema reference doc updated.
5. ⬜ Cleanup layer updated.

---

## Out of Scope

- Read routes (deferred until observation floor is hammer-validated)
- Enrichment (post-Y1)
- Derived read surfaces (compute-on-read, post-Y1)
- MCP tool definitions (after read routes exist)
- VS Code extension integration (after read routes exist)

---

## Document Notes

- This plan covers only the observation floor. Read surfaces, derived intelligence, and operator-surface integration are follow-on work.
- The plan is intentionally short. If it grows beyond this page, something has gone wrong.
