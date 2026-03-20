# Y1 Hammer Story

## Purpose

This document defines the actual hammer test cases for YouTube Search Observatory Y1.

It must be written and accepted before route code exists.
The hammer is the proof that the design is testable.

This doc is subordinate to:
- `docs/architecture/testing/hammer-doctrine.md`
- `docs/systems/veda/youtube-observatory/validation-doctrine.md`
- `docs/systems/veda/youtube-observatory/y1-schema-judgment.md`

---

## Hammer Module

**File:** `scripts/hammer/hammer-youtube-y1.ps1`

**Registration:** Must be added to both parse-check and run sections of `scripts/api-hammer.ps1`.

**Route under test:** `POST /api/seo/youtube/search/ingest`

**Fixture strategy:** The hammer constructs synthetic DataForSEO-shaped payloads locally. No live DataForSEO calls. All assertions are local and deterministic.

---

## Setup Phase

The hammer must bootstrap its own test state:

1. Resolve or create a test project (use existing hammer project conventions).
2. Construct a synthetic payload matching the DataForSEO YouTube Organic SERP response shape, containing:
   - At least 3 `youtube_video` items at known ranks
   - At least 1 `youtube_channel` item at a known rank
   - Known `channel_id`, `video_id`, `rank_absolute`, `rank_group`, `block_rank` values
   - Known `timestamp` and `publication_date` values on video items
   - Known boolean flags (`is_shorts`, `is_live`, `is_movie`, `is_verified`)
3. Store the test query, locale, device, and locationCode as fixture constants.

---

## Test Cases

### Category 1: Target-Definition Tests

**T1-01: Target auto-creation on first ingest**
- Submit a valid ingest payload with a query that has no existing target.
- PASS: 201 response. Target row exists with correct `(projectId, query, locale, device, locationCode)`.
- Verify: EventLog contains `YT_SEARCH_TARGET_CREATED` for the target.

**T1-02: Target reuse on subsequent ingest**
- Submit a second ingest payload with the same query/locale/device/locationCode (different capturedAt).
- PASS: 201 response. No new target created (same target ID). No duplicate `YT_SEARCH_TARGET_CREATED` event.

**T1-03: Distinct targets for different locationCodes**
- Submit an ingest payload identical to T1-01 but with a different locationCode.
- PASS: 201 response. A new, distinct target row is created.

### Category 2: Snapshot Ingest Tests

**T2-01: Successful snapshot creation**
- Submit a valid ingest payload.
- PASS: 201 response. Response body includes `snapshotId` and `elementCount`. Snapshot row exists with correct `projectId`, `ytSearchTargetId`, `capturedAt`, `validAt`, `checkUrl`, `itemsCount`, `source`.

**T2-02: Snapshot rawPayload preserved**
- After T2-01, read the snapshot row.
- PASS: `rawPayload` is valid JSON. Contains the result envelope structure.

**T2-03: Snapshot EventLog**
- After T2-01, query EventLog.
- PASS: Exactly one `YT_SEARCH_SNAPSHOT_RECORDED` event with correct `entityId` matching the snapshot ID, correct `projectId`, actor = `system`.

**T2-04: Idempotency — reject duplicate within 60-second window**
- Submit the same ingest payload again immediately (within 60 seconds of T2-01).
- PASS: 409 response. No new snapshot row created. No new EventLog entry.

**T2-05: Allow new snapshot after window expires**
- Submit the same ingest payload with server time advanced beyond the 60-second window (or use a distinct capturedAt if the route accepts it).
- PASS: 201 response. New snapshot row created with distinct `capturedAt`.
- Note: If the route does not accept client-provided capturedAt, this test may need to SKIP with justification that the 60-second gate is time-dependent. Alternatively, use a shorter test window or test against DB state directly.

### Category 3: Element-Row Tests

**T3-01: Element rows created for all items**
- After a successful ingest with N items in the payload.
- PASS: Exactly N `YtSearchElement` rows exist for the snapshot.

**T3-02: youtube_video element promoted fields**
- Pick a known video item from the fixture payload.
- PASS: Element row has correct `elementType` = `"youtube_video"`, `rankAbsolute`, `rankGroup`, `blockRank`, `channelId` (UC-prefixed), `videoId` (11-char), `isShort`, `isLive`, `isMovie`. `observedPublishedAt` is a parseable datetime. `isVerified` is null.

**T3-03: youtube_channel element promoted fields**
- Pick the known channel item from the fixture payload.
- PASS: Element row has `elementType` = `"youtube_channel"`, correct `rankAbsolute`, `rankGroup`, `blockRank`, `channelId`. `videoId` is null. `isShort`, `isLive`, `isMovie` are null. `isVerified` matches fixture value. `observedPublishedAt` is null.

**T3-04: Element rawPayload preserved**
- Pick any element row.
- PASS: `rawPayload` is valid JSON. Contains the individual item object.

**T3-05: Element projectId matches snapshot projectId**
- For all element rows of a snapshot.
- PASS: Every element's `projectId` equals the snapshot's `projectId`.

**T3-06: Element rankAbsolute uniqueness within snapshot**
- After successful ingest.
- PASS: No two elements in the same snapshot share the same `rankAbsolute`.

### Category 4: Project Isolation Tests

**T4-01: Cross-project ingest rejected**
- Submit an ingest payload using a project header for Project A, but the test verifies no rows leak into Project B.
- PASS: All created rows (target, snapshot, elements) have `projectId` = Project A. No rows visible under Project B.

**T4-02: Cross-project non-disclosure on target lookup**
- Create a target under Project A. Attempt to read it from Project B context.
- PASS: 404 response (not 403). No existence leakage.

### Category 5: Determinism / Ordering Tests

**T5-01: Element rows ordered by rankAbsolute**
- Query elements for a snapshot.
- PASS: Results are ordered by `rankAbsolute` ascending. Deterministic. Repeated reads return same order.

**T5-02: Snapshots ordered by capturedAt descending**
- Query snapshots for a target.
- PASS: Results ordered by `capturedAt` descending, with `id` as tie-breaker.

### Category 6: Mixed Result-Type Tests

**T6-01: Mixed-type payload preserves all types**
- Submit a payload with `youtube_video`, `youtube_channel`, and (if fixture includes) `youtube_playlist` items.
- PASS: Element rows exist for each type. `elementType` is correctly set per item. No items dropped or coerced to a single type.

**T6-02: Unrecognized type falls through gracefully**
- Submit a payload with an item whose `type` is `"youtube_unknown_future_type"`.
- PASS: Element row created with `elementType` = `"youtube_unknown_future_type"`. Rank fields populated. Identity fields null where not extractable. `rawPayload` preserved.

### Category 7: Malformed Input Tests

**T7-01: Missing required body fields**
- Submit request with missing `query` field.
- PASS: 400 response. No rows created.

**T7-02: Empty payload items array**
- Submit a valid request whose payload has `items: []`.
- PASS: 201 response (or 400 if the route requires at least one item — decision to be made at implementation). Snapshot row created with `itemsCount: 0` and zero element rows. OR: 400 rejection. Pin the decision here: **201 is preferred** — an empty result set is a valid observation ("YouTube returned no results for this query").

**T7-03: Malformed payload structure**
- Submit a request where `payload` is present but `tasks[0].result[0]` is missing.
- PASS: 400 response. No rows created.

**T7-04: Item with missing rank_absolute**
- Submit a payload where one item lacks `rank_absolute`.
- PASS: 400 response. Entire ingest rejected (atomic — no partial element creation).

**T7-05: Extra fields in request body rejected**
- Submit request with an unexpected extra field in the body.
- PASS: 400 response (Zod `.strict()` enforcement).

### Category 8: Read/Write Boundary Tests

**T8-01: Ingest route mutates state**
- Confirm that `POST /api/seo/youtube/search/ingest` creates rows.
- PASS: Rows exist after POST. This is a write route and must behave as one.

**T8-02: No hidden writes on failed ingest**
- Submit a malformed payload that triggers 400.
- PASS: No target, snapshot, or element rows created. No EventLog entries. Transaction rolled back completely.

### Category 9: Transaction Atomicity Tests

**T9-01: All-or-nothing on element failure**
- Submit a payload where normalizer succeeds on the first item but a subsequent item would violate a constraint (e.g., duplicate `rankAbsolute` within the same payload).
- PASS: 400 response. No snapshot row. No element rows. No EventLog. Complete rollback.

---

## SKIP Policy

**Acceptable SKIPs:**
- T2-05 (time-window idempotency) if the route uses server-assigned `capturedAt` and the test cannot control time. Document the SKIP reason explicitly.
- Any test that requires a real DataForSEO credential or live API call — but none of the above tests require this.

**Unacceptable SKIPs:**
- Project isolation tests must never SKIP.
- Element-row contract tests must never SKIP.
- Malformed input tests must never SKIP.
- Atomicity tests must never SKIP.

Every SKIP must include a one-line reason in the hammer output.

---

## Output Discipline

Exactly one output line per test: `PASS`, `FAIL`, or `SKIP`.
Use the `$seedSkipped` boolean gate pattern if setup steps are conditional.

---

## Document Notes

- All tests use locally constructed fixture payloads. No live DataForSEO calls.
- The fixture payload must match the confirmed field shapes from `Y1-STEP1-INSPECTION-REPORT.md`.
- This hammer story must be accepted before route implementation begins.
- The hammer module must be registered in `scripts/api-hammer.ps1` before the first run.
