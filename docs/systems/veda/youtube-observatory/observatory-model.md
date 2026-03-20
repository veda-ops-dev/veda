# YouTube Observatory Model

## Purpose

This document defines the human-level observatory model for a future YouTube lane inside current VEDA.

It exists to answer:

```text
What are the entities, observations, time semantics, and interpretation boundaries for YouTube observability?
```

This is a doctrine/model doc.
It is not a schema file.
It is not a route contract by itself.

If this document conflicts with the live schema or higher-order authority docs, the authoritative sources win.

---

## Ownership

This doc belongs to VEDA because it defines a possible observatory lane.

VEDA owns this lane only where it remains:
- observational
- project-scoped
- time-aware
- interpretation-safe

Project V and V Forge do not inherit ownership here.

---

## Core Pattern

The YouTube lane must follow the current VEDA pattern:

```text
entity + observation + time + interpretation
```

Applied here:

- **entity** = YouTube identity being observed
- **observation** = search/discovery result state captured from an external truth surface
- **time** = when VEDA captured or validated that result state
- **interpretation** = read-oriented diagnostics derived from captured observations

The lane fails if any one of those is replaced by planning or execution ownership.

---

## Preferred Identity Posture

### Channel-first

The preferred observatory identity posture is channel-first.

Why:
- channels are the more stable durable actor surface
- video-level observations can change rapidly while still belonging to the same durable channel surface
- channel-first modeling keeps the lane closer to observatory identity and farther from owned-production thinking

### Video-level observation still matters

Channel-first does not mean video-blind.

The observatory should still be able to record:
- observed video identity
- observed ranking position
- observed result type
- observed association to channel identity

### Playlist and mixed result types

If search/provider results include playlists or other recognizable YouTube result types, they must be modeled as observed result types rather than forced into a fake video-only assumption.

---

## Entity Model

A future YouTube lane should distinguish clearly between:

### 1. Target-definition entity

The governed definition of what the project chooses to observe.

Examples:
- a YouTube search query target
- locale/device or search-context scope if applicable
- optional operator notes or target classification

This is not an observation row.
It is the observatory target-definition row.

### 2. Snapshot observation entity

An immutable search/discovery snapshot captured at a specific time.

Examples of fields that conceptually belong here:
- target identity
- capture time
- provider/source identity
- raw payload evidence
- promoted ranking/result fields

This is the actual observation ledger.

### 3. Normalized identity entity or boundary structure

A stable normalized record of observed YouTube identities where justified.

Examples:
- channel ID
- video ID
- playlist ID
- normalized handle or canonical URL when available

Normalization must support observability.
It must not turn into a production-asset ownership system.

#### Y1 identity posture

At Y1, normalized identity lives directly on element observation rows rather than in a separate identity lookup table. This is confirmed by payload evidence: `channel_id` (UC-prefixed) and `video_id` (11-char) are direct fields extractable at the ingest boundary for every item. Promoting identity to per-element columns is sufficient for Y1's channel-first observation needs.

A separate identity lookup table may be justified in a later phase if cross-snapshot identity analysis (e.g., "all observations of channel X across all queries") requires a first-class identity entity with its own lifecycle. At Y1, the element-level identity columns plus a project-scoped index on `channelId` provide this capability without a separate table.

---

## Observation Model

The core observation unit should be an immutable ranked search/discovery snapshot.

A useful YouTube search observation should preserve:
- project scope
- target scope
- capture time
- rank/order
- observed result type
- normalized identities where extractable
- raw payload evidence
- promoted queryable fields for diagnostics

This keeps the lane aligned with VEDA's existing search-observation style.

---

## Time Semantics

The YouTube lane should preserve clear time semantics just like the current search ledger.

### Captured time

When VEDA recorded the observation.

### Valid/provider time

When the provider/source claims the observation was valid, if available.

### Historical rule

Observation rows should be append-friendly and historical.
Silent overwriting of prior observed state is not acceptable observatory behavior.

---

## Interpretation Boundary

Derived interpretation may include things like:
- channel visibility over time
- repeated appearance patterns
- query/result-type patterns
- observed ranking change
- comparative result-surface composition

Derived interpretation may not become:
- content planning authority
- video production strategy ownership
- publishing automation
- creator workflow management

Interpretation stays read-oriented.
Planning and execution remain elsewhere.

---

## Truth Surface Split

The preferred truth split is:

### Primary truth
External search/provider snapshot evidence.

### Secondary enrichment
YouTube API enrichment where justified and bounded.

### Validation support
Manual/operator spot checks when needed to confirm ambiguous results or provider edge cases.

This split keeps the observatory grounded instead of speculative.

---

## Relationship to Current VEDA Structures

The existing clean-repo pattern already supports this lane conceptually:
- project scoping
- capture discipline
- search-observation patterns
- raw payload preservation with promoted fields
- thin-route + pure-library + hammer validation discipline

But current live truth does not yet imply an active YouTube schema or route set.

This document therefore defines model posture, not implementation existence.

---

## Out of Scope

This model does not authorize:
- YouTube publishing state
- script workflow
- thumbnail workflow
- video asset management
- content planning sequencing
- creator-studio analytics sprawl
- comment/reply operations
- recommendation-feed observability by default

Those may be discussed elsewhere.
They are not the observatory model here.

---

## Maintenance Note

If future work tries to force this lane into:
- a generic media model
- a production-asset model
- a workflow state engine
- a strategy authority layer

stop and reassess.

The YouTube lane is valid only while it remains a narrow, time-aware, search/discovery observatory.
