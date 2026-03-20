# Y1 Implementation Plan

## Purpose

This document tracks the bounded implementation sequence for YouTube Search Observatory Y1.

It is the execution lane doc for this work.
It is not a roadmap phase. It is subordinate to `docs/ROADMAP.md` as an optional bounded enhancement.

---

## Sequence

### Step 1: Schema judgment acceptance
- **Artifact:** `y1-schema-judgment.md`
- **Status:** COMPLETE — written and ready for operator review
- **Gate:** Operator accepts the three-table shape, column decisions, uniqueness keys, and EventLog integration before migration.

### Step 2: Hammer story acceptance
- **Artifact:** `y1-hammer-story.md`
- **Status:** COMPLETE — written and ready for operator review
- **Gate:** Operator accepts the test cases and SKIP policy before route implementation.

### Step 3: De-risking query passes
- **Status:** PENDING
- Run at least one playlist-returning query and one Shorts-returning query against DataForSEO YouTube Organic SERP.
- Confirm: `youtube_playlist` field shape, `playlist_id` delivery, `channel_id` presence on playlist items, `is_shorts: true` item completeness.
- If playlist items lack `channel_id`, update `y1-schema-judgment.md` to make `channelId` nullable before migration.
- Non-blocking for steps 1–2. Should complete before or alongside step 4.

### Step 4: Prisma migration
- **Status:** PENDING
- Add `YtSearchTarget`, `YtSearchSnapshot`, `YtSearchElement` models to `prisma/schema.prisma`.
- Extend `EntityType` enum with `ytSearchTarget`, `ytSearchSnapshot`.
- Extend `EventType` enum with `YT_SEARCH_TARGET_CREATED`, `YT_SEARCH_SNAPSHOT_RECORDED`.
- Add reverse relations on `Project` model.
- Run migration. Verify clean build.

### Step 5: Pure normalizer library
- **Status:** PENDING
- Create `src/lib/seo/youtube/normalize-yt-search.ts`.
- Pure function. No I/O. No Date.now(). No randomness.
- Branch on `type`. Extract promoted fields. Preserve rawPayload per item.
- Handle unrecognized types gracefully (store with rank fields, null identity).

### Step 6: Ingest route
- **Status:** PENDING
- Create `src/app/api/seo/youtube/search/ingest/route.ts`.
- Thin handler: resolve project strictly, validate with Zod `.strict()`, delegate to normalizer, atomic write with EventLog.
- Idempotency: 60-second recent-window gate.
- Find-or-create target behavior with conditional EventLog.

### Step 7: Hammer module
- **Status:** PENDING
- Create `scripts/hammer/hammer-youtube-y1.ps1`.
- Register in `scripts/api-hammer.ps1` (parse-check and run sections).
- Implement all test cases from `y1-hammer-story.md`.
- Run full coordinator. Confirm no regressions.

### Step 8: Docs cleanup / control-surface update
- **Status:** PENDING
- Update `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md` with the three new tables.
- Update `docs/DOCS-CLEANUP-TRACKER.md` and `docs/DOCS-CLEANUP-GROUNDED-IDEAS-EXTRACTION.md`.
- Confirm `docs/ROADMAP.md` note is still accurate.

---

## Done Criteria

Y1 observation floor is done when:

1. Migration applied cleanly. Build passes.
2. Hammer module passes all non-SKIP cases.
3. Full coordinator run shows no regressions from current baseline (680 PASS / 0 FAIL / 10 SKIP + new Y1 cases).
4. Schema reference doc updated.
5. Cleanup layer updated.

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
