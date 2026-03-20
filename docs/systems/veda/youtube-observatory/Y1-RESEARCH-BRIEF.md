# Y1 — YouTube Search Observatory: Research Brief

## Document Authority

This brief is grounded against:
- Current clean-repo truth: `C:\dev\veda-ops-dev\veda`
- Authority order: V_ECOSYSTEM.md → SYSTEM-INVARIANTS.md → VEDA_WAVE_2D_CLOSEOUT.md → SCHEMA-REFERENCE.md → search-intelligence-layer.md → hammer-doctrine.md → youtube-observatory docs
- Legacy salvage used as constrained input only — not as truth

## Research Status Summary

| Bucket | Status | Resolution |
|--------|--------|------------|
| 1 — Truth-Surface | **RESOLVED** | Live payload inspection completed. See `Y1-STEP1-INSPECTION-REPORT.md`. |
| 2 — Identity Extraction | **RESOLVED** | `channel_id` direct UC-prefixed field on every item. `video_id` direct 11-char field on every video item. No URL parsing required. |
| 3 — Determinism / Variance | **SOFT-CLOSED** | Structure and field consistency confirmed. Variance-across-captures question is a de-risking pass, not a schema blocker. Uniqueness key is time-based, not content-based. |
| 4 — Freshness Metadata | **RESOLVED** | `timestamp` is computed absolute datetime (promoted as `observedPublishedAt`). `publication_date` is raw relative string (rawPayload only). |
| 5 — Bounded Enrichment | **DEFERRED** | Enrichment explicitly deferred to post-Y1. Subscriber count not in payload. Observation floor must prove itself first. |

Schema judgment can now proceed. See `y1-schema-judgment.md`.

---

## 1. Y1 Framing

### What Y1 Is

Y1 is the minimum observation floor needed to record query-targeted YouTube search/discovery snapshots over time, with channel-first identity normalization, explicit result-type capture, and rank/order preservation.

Its purpose is to create a repeatable, append-friendly, hammer-testable observation ledger for YouTube search results — the substrate from which later read surfaces (result-type composition, channel appearance frequency, rank stability, co-appearance territory mapping, freshness composition) can be derived on read.

Y1 is not those read surfaces. It is the floor they require.

Y1 fits the existing VEDA pattern:

```
entity + observation + time + interpretation
```

Applied to YouTube:
- **entity** = a project-scoped YouTube search query target
- **observation** = an immutable ranked snapshot of what the search surface returned at a point in time
- **time** = capturedAt (server-assigned) and validAt (provider time if available, else capturedAt)
- **interpretation** = deferred to derived read surfaces; not materialized at Y1

### What Y1 Is Not

Y1 is not:
- a channel analytics system
- a video production or editorial workflow
- a recommendation-feed observatory
- a content strategy planner
- a subscriber growth tracker
- a general YouTube metrics dashboard
- a planning or execution surface
- a cross-platform media system

Y1 is also not the derived read surfaces it enables. Result-type composition over time, channel territory mapping, and freshness diagnostics are later derivation layers, not the observation floor itself.

### Why the Observation Floor Must Come First

Without a clean observation floor:
- derived read surfaces have no stable canonical substrate to operate on
- identity ambiguity compounds over time and becomes expensive to fix retrospectively
- variance in the truth surface gets baked into schema assumptions rather than observed as data
- hammer-testable behavior is impossible to define before the ingest contract is clear
- schema design will be speculative rather than grounded in what the provider actually delivers

The current VEDA pattern — confirmed across the SEO observatory, DataForSEO ingest bridge, and SIL surfaces — is to nail the observation floor first, then build derivation on top of it. Y1 must follow the same discipline.

---

## 2. Research Brief

### Bucket 1: Truth-Surface Research

**Status: RESOLVED.** Live payload inspection completed 2026-03-19. See `Y1-STEP1-INSPECTION-REPORT.md` for full field-level analysis.

**What must be learned:**

The primary candidate truth surface for Y1 is a vendor SERP source (DataForSEO YouTube Organic SERP), consistent with the direction preserved in the legacy truth-surface decision doc. Before Y1 schema or route design is justified, the following must be resolved:

1. What result types does the DataForSEO YouTube Organic SERP payload actually deliver, and what is the definitive controlled vocabulary for `type` strings? The legacy vendor validation doc identifies an expected vocabulary (`video`, `short`, `channel`, `playlist`, `movie`, `ad`, `card`) but the vendor's full enumerated list is not confirmed. Unknown types must fall through to an `other` bucket — but the normalizer cannot be written defensively without first knowing what the surface actually emits.

2. What fields are consistently extractable at the item level? Confirmed: `rank_absolute`, `type`, `is_shorts`, `block_name`, `check_url`. Partially confirmed: direct `video_id` field vs URL-only delivery. Uncertain: `rank_group` / within-block rank, `channel_name` display field consistency across element types, title presence on non-video items, payload completeness at lower rank positions.

3. What does the truth surface **not** reliably tell us? Specifically: does the vendor surface deliver channel identity as `UC...` IDs (extractable), as `/@handle` URLs (not extractable without API), or as both depending on the result item? This is the highest-risk gap from the legacy vendor validation work and remains unresolved without live payload inspection.

4. What is the practical query scope? Does the surface apply across arbitrary queries reliably, or are there known gaps for low-volume queries, non-English queries, or queries with few YouTube-specific results?

**Resolution:** The live payload confirmed: flat `items[]` array, four rank fields on every item, `channel_id` as direct UC-prefixed field, `video_id` as direct 11-char field, type vocabulary of `youtube_video` and `youtube_channel` (with `youtube_playlist` and `youtube_video_paid` documented but not yet observed in live sample). Field presence is consistent and well-structured.

---

### Bucket 2: Identity Extraction Research

**Status: RESOLVED.** Channel identity and video identity questions definitively answered by live payload inspection.

**What must be learned:**

1. Can `channelId` (`UC...` format) be reliably extracted from vendor payloads? Or does the vendor sometimes deliver only `/@handle` channel URLs, requiring null storage with deferred enrichment?

2. Can `videoId` (11-character base64url) be reliably extracted from vendor payloads? Is there a direct `video_id` field, or is URL extraction (from `watch?v=`, `/shorts/`, `youtu.be/`) always the required path?

3. Can `playlistId` (`PL...` prefix) be extracted from playlist-type result items?

4. What is the practical fallback order when canonical IDs are absent? The legacy identity normalization doc defines a sound order: `UC...` channel ID direct > extract from `/channel/UC...` URL > null with raw URL preserved in `rawPayload`. This must be confirmed against real payload shapes.

5. What identity ambiguity cases must Y1 accept as normal? Specifically: items where `channelId` is null because the vendor delivered only a handle URL; items where `videoId` is null because the URL did not match any known extraction pattern.

**Resolution:** `channel_id` is a direct field on every item (100% coverage in live sample). `video_id` is a direct field on every `youtube_video` item. No URL parsing required for primary identity path. `channel_url` uses `@handle` format but is metadata only — the canonical identity is always `channel_id`. Playlist identity remains unverified (de-risking pass pending, non-blocking).

---

### Bucket 3: Determinism / Variance Research

**Status: SOFT-CLOSED.** Structure confirmed stable. Cross-capture variance is a de-risking observation, not a schema blocker.

**What must be learned:**

1. What varies across repeated captures of the same query at different times, and what can be held constant as a declared Y1 baseline?

2. What is the expected variance from: locale differences, device differences (desktop vs mobile), time of day, and repeated fetches with the same declared context?

3. What variance should Y1 treat as observed external reality (to be recorded) rather than as a local implementation failure (to be prevented)?

4. What fixed baseline can Y1 declare that is realistic and hammer-testable? The existing SERP observatory declares `en-US` locale only, desktop device as default, operator-triggered ingest. The same discipline must apply to Y1, but the scope must be confirmed against what the vendor actually supports cleanly.

**Current posture:** The uniqueness key is `(projectId, ytSearchTargetId, capturedAt)` — time-based, not content-based. Provider variance between captures is recorded as observed reality, not treated as a local bug. This design is sound regardless of whether result-set overlap is 60% or 95%. The de-risking pass (repeated captures at 24h intervals) would characterize the variance level for documentation but does not gate schema design.

---

### Bucket 4: Freshness Metadata Research

**Status: RESOLVED.** Two fields confirmed. Decision made.

**What must be learned:**

1. Is publish date or upload age reliably available in the primary truth surface (the vendor payload), or does it require bounded enrichment from the YouTube Data API?

2. If present in the vendor payload, how is it expressed? As an ISO timestamp, a relative label ("3 days ago"), a display string, or a structured field?

3. Is freshness metadata stable enough across result types (video, short, playlist, channel) to be promoted to an explicit column in Y1, or should it be left in `rawPayload` for later enrichment?

**Resolution:** Two fields exist on `youtube_video` items. `timestamp` is a computed absolute UTC datetime (DataForSEO subtracts the relative label from capture time). `publication_date` is the raw relative display string. Decision: promote `timestamp` as `observedPublishedAt` (safer name documenting its computed nature). Store `publication_date` in rawPayload only. Neither field exists on `youtube_channel` items — `observedPublishedAt` is null for non-video elements.

---

### Bucket 5: Bounded Enrichment Research

**Status: DEFERRED to post-Y1.**

**What must be learned:**

1. Are subscriber count and upload cadence realistically obtainable from the YouTube Data API in a bounded, quota-safe way for Y1 scale?

2. Are these values stable enough between observations to be worth capturing at Y1, or do they change too frequently to be meaningful without near-real-time refresh?

3. Are they v1 concerns, or should they be deferred until the observation floor proves itself?

**Resolution:** Deferred. Subscriber count is not present in the vendor payload (`video_count: 0` on the channel item is unreliable). Upload cadence is not a direct field. The observation floor must prove itself before enrichment is coupled to ingest. Enrichment is a post-Y1 concern.

---

## 3. Priority Ranking

Research buckets ranked by importance for unblocking Y1:

**1. Bucket 1 — Truth-Surface Research (highest priority)** — RESOLVED
Nothing else can be designed without knowing what the primary truth surface reliably delivers. The normalizer contract, promoted fields, `rawPayload` strategy, and uniqueness key all depend on this.

**2. Bucket 2 — Identity Extraction Research** — RESOLVED
Channel-first identity is a core architectural commitment for Y1. Whether `channelId` can be reliably extracted at the ingest boundary determines whether the channel-first model is realizable at Y1 or requires post-ingest enrichment. Must be resolved before schema design.

**3. Bucket 3 — Determinism / Variance Research** — SOFT-CLOSED
Idempotency model, uniqueness constraints, and hammer test expectations all depend on understanding what variance is inherent in the truth surface vs. what must be controlled. Must be resolved before hammer coverage can be defined.

**4. Bucket 4 — Freshness Metadata Research** — RESOLVED
Required for the freshness composition read surface, but the observation floor can be built without it. Freshness can be left in `rawPayload` temporarily if the field presence question is unresolved. Promotes to higher priority if freshness diagnostics are required at v1.

**5. Bucket 5 — Bounded Enrichment Research (lowest priority)** — DEFERRED
Enrichment is a post-observation-floor concern. The five target derived read surfaces can be scoped to work from the observation floor alone. Enrichment must not be designed into Y1 until the floor proves itself.

---

## 4. Failure Modes

**1. Designing schema before verifying channel identity delivery format**
If schema is designed assuming `channelId` is always extractable from the vendor payload, and live payloads reveal that a material fraction of channel references are delivered as `/@handle` URLs only, the `channelId` column will have a high null rate in practice. Downstream derived surfaces that depend on channel identity (appearance frequency, territory mapping) will silently degrade. The uniqueness invariant holds, but the channel-first model fails without explanation.

**Mitigated:** Live payload confirms `channel_id` is a direct UC-prefixed field on every item. 0% null rate observed.

**2. Confusing result-type variance with implementation failure**
YouTube search surfaces more result-type diversity than Google organic search. If Y1 is designed expecting a clean list of video results and the vendor delivers mixed result sets (channels, playlists, Shorts, Official Cards, ads), the normalizer will map unknowns to a catch-all `other` bucket and lose structured identity for those items. The observation floor will be silently incomplete in ways that corrupt later analytics.

**Mitigated:** Schema uses plain string `elementType` with application-level validation. Unrecognized types are stored as-is rather than rejected.

**3. Treating block structure as first-class**
If Y1 materializes a `YtSearchBlock` table or uses `block_name` as a join key, it stores a vendor-defined localized display string as a structural schema element. `block_name` values are unstable and change across API versions. The observation floor becomes brittle to vendor updates with no migration path.

**Mitigated:** Block structure is flat annotations (`blockRank`, `blockName`) on element rows. No block table.

**4. Storing relative freshness labels without conversion at ingest time**
If the vendor delivers freshness as "3 days ago" and Y1 stores this string without converting it to an absolute date using `capturedAt` as the reference, those freshness values are permanently ambiguous. The freshness composition read surface cannot be built from them, and there is no remediation path.

**Mitigated:** Vendor `timestamp` provides the computed absolute datetime. Promoted as `observedPublishedAt`. Raw label stays in rawPayload.

**5. Designing hammer tests assuming determinism that does not exist at the provider surface**
If Y1 assumes that repeated captures of the same query return stable, deterministic results and writes hammer tests around this assumption, provider variance will cause hammer failures misread as bugs. The hammer must verify what Y1 guarantees (deterministic local behavior, deterministic row ordering) while tolerating what Y1 cannot control (provider result variance between captures).

**Mitigated:** Hammer uses locally constructed fixture payloads. No live provider calls. All assertions are local and deterministic.

**6. Coupling enrichment to ingest before the observation floor is stable**
If bounded enrichment is designed into Y1 before the observation floor has been validated, two truth surfaces are coupled at ingest time. If the enrichment path fails, the observation floor is blocked or contaminated. Enrichment must not be ingest-blocking at Y1.

**Mitigated:** Enrichment explicitly deferred to post-Y1.

---

## 5. Recommendation

The exact bounded research sequence to run before Y1 schema/route judgment:

**Step 1: Live payload inspection (Bucket 1 + Bucket 2 combined)** — COMPLETE

Obtain DataForSEO YouTube Organic SERP access. Run ≥10 representative queries across:
- head terms likely to return mixed result types (channel + video + playlist)
- tail terms likely to return mostly video results
- queries with known Shorts presence
- at least one query with an expected Official Card or structured block

For each capture, document per item:
- exact `type` value strings the vendor delivers
- whether `rank_absolute` is present on every item
- whether channel identity is delivered as `/channel/UC...` URL, `/@handle` URL, or a direct `channel_id` field
- whether `video_id` is a direct field or must be extracted from URL
- whether `published_at` or equivalent is present on video items, and in what format
- whether `is_shorts` is present on short-type items
- whether `block_name` is present and what values appear

This resolves Bucket 1 and Bucket 2 and produces the field presence inventory the normalizer must be built against.

**Step 2: Variance baseline (Bucket 3)** — DE-RISKING PASS (non-blocking)

Repeat 3 of the Step 1 queries at 24h intervals with the same declared locale/device baseline. Compare result-set overlap (Jaccard on `rank_absolute` + item identity). Document the observed stability level. Decide whether Y1 should implement a freshness-window idempotency gate (analogous to the 60-second recent-window gate in the current `serp-snapshot/route.ts`) or whether YouTube snapshot uniqueness is purely timestamp-based.

**Step 3: Freshness field decision (Bucket 4)** — COMPLETE

Using the Step 1 payload samples, answer the freshness field question definitively: present as absolute timestamp, present as relative label, or absent. Make one clear decision: promote to explicit column, convert at ingest from relative label, or defer to `rawPayload`.

**Step 4: Enrichment deferral confirmation (Bucket 5)** — COMPLETE (deferred)

Review the five target derived read surfaces against the Step 1 payload inventory. If all five can be supported from the observation floor alone, defer enrichment explicitly to post-Y1. If one or more require enrichment, scope the minimum enrichment call (likely: subscriber count via a single `channels.list` call per unique channel per snapshot) and document it as optional post-ingest enrichment, not ingest-blocking.

**Step 5: Schema and route judgment** — COMPLETE

See `y1-schema-judgment.md` for the pinned three-table schema and `y1-hammer-story.md` for the test cases.

---

## Document Notes

- This brief was produced against current clean-repo truth in `C:\dev\veda-ops-dev\veda`.
- Legacy YouTube salvage docs under `C:\dev\veda\docs\specs\future-ideas\youtube\` were used as constrained historical input only.
- Status annotations added after Step 1 payload inspection and schema judgment pass (2026-03-20).
- The brief remains a valid reference for understanding why each research question mattered and how it was resolved.
