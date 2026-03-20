# YouTube Observatory Ingest Discipline

## Purpose

This document defines the ingest rules for a future YouTube observatory lane inside current VEDA.

It explains how YouTube search/discovery observations may enter VEDA without breaking current bounded ownership, project isolation, determinism, or post-Wave-2D observability-only truth.

This document defines ingest behavior.
It does not define planning behavior, publishing workflow, or execution automation.

If this document conflicts with current invariants, schema reality, or enforced API behavior, those authoritative sources win and this document must be updated.

---

## Ownership

This doc belongs to VEDA.

VEDA owns this discipline only because it governs observatory-state creation and observation recording.

This remains part of the current VEDA pattern:

```text
entity + observation + time + interpretation
```

If a proposed ingest path starts managing planning or execution state, it does not belong here.

---

## What This Doc Governs

This document governs future YouTube observatory ingest only where the ingest path creates:
- project-scoped YouTube search/discovery targets
- time-aware YouTube search/discovery snapshots
- normalized identity extraction at the ingest boundary
- append-friendly observation records
- evented observatory mutations where required

It does not govern:
- publishing to YouTube
- editing YouTube metadata
- creator workflow
- script or thumbnail preparation
- recommendation-system behavior

---

## Core Ingest Rules

### 1. Search-first ingest only

The safe default for this lane is search/discovery ingest.

That means:
- search-query-targeted snapshots are valid
- result-surface capture is valid
- minimal enrichment in support of observation is valid
- generic channel-ops or creator-tool ingestion is not the default

Recommendation or feed-style surfaces are out of scope until explicitly justified later.

### 2. Operator-triggered by default

The safe default is operator-triggered ingest.

That means:
- no hidden background YouTube crawling as canonical behavior
- no silent recurring ingest assumptions
- no autonomous “watch everything” posture sneaking in through convenience design

If automation is ever added later, it must still preserve the same invariants and auditability.

### 3. Governance rows and observation rows must stay distinct

The ingest boundary must preserve the distinction between:
- target-definition state
- snapshot observation state

A target says:
- this is what we choose to observe

A snapshot says:
- this is what we observed at a particular time

Those meanings must not blur.

### 4. Observations are append-friendly

Search/discovery observations should create new historical records rather than mutate prior observations silently.

Safe replay handling may be idempotent where the uniqueness boundary is explicit.
But historical state must remain durable and boring.

---

## Project Scoping and Non-Disclosure

All YouTube ingest must obey current VEDA isolation rules.

### Project scoping

Every write must resolve project context explicitly before mutation.

A write must never:
- infer project scope from unsafe fallback
- write across projects
- create detached observatory rows

### Non-disclosure

Cross-project references must not leak existence.

If a row belongs to another project, the system must behave as if it does not exist.

This is structural, not cosmetic.

---

## Identity Normalization at the Boundary

Normalization should happen at the ingest boundary before persistence where identity is extractable.

Expected identity examples:
- channel ID
- video ID
- playlist ID
- canonical URL/handle when available

### Why this matters

Without boundary normalization:
- duplicate identity fragments spread through observations
- time-series comparisons weaken
- ranked result comparisons become ambiguous
- hammer validation becomes blob-heavy and fragile

### Rule

Normalize identity to support observability.
Do not turn normalization into a production-asset ownership system.

---

## Raw Evidence and Promoted Fields

Provider/source payloads may be stored as evidence.

But common hot fields must be promoted explicitly where they are required for:
- rank comparison
- result-type analysis
- identity extraction
- deterministic diagnostics
- hammer assertions

This follows the existing VEDA rule:
- raw evidence is allowed
- important query fields should not live only inside opaque blobs

---

## Time Discipline

Ingest must preserve clear time semantics.

### Captured time

When VEDA captured the observation.

### Valid/provider time

When the provider/source indicates the observation was valid, if available.

### Fallback rule

If provider-valid time is absent, the ingest boundary should treat:

```text
validAt = capturedAt
```

This keeps time semantics usable without fake ambiguity.

---

## Result-Type Discipline

YouTube search/discovery observations may contain mixed result types.

Examples may include:
- channel results
- video results
- playlist results

The ingest boundary must record observed result type explicitly where extractable.

Do not force mixed result types into a fake one-type-only model just because a narrower model is easier to code.

---

## Validation Discipline

The ingest boundary must validate inputs explicitly and deterministically.

Validation expectations include:
- malformed input rejection
- provider/source payload shape validation where needed
- project context validation
- explicit handling of missing or partial identity
- deterministic error behavior

The goal is boring reproducibility, not permissive vibes-based acceptance.

---

## Event Logging and Atomicity

Meaningful ingest mutations must align with canonical VEDA event logging where required.

The exact event vocabulary can be defined later if the lane is implemented.
But the structural rule is already clear:
- state change and required event write must be atomic
- idempotent replay must not emit a fake fresh mutation event

Events represent durable observatory state changes, not request attempts.

---

## Truth Surface Guidance

Preferred ingest truth posture:
- provider/search snapshot evidence as primary
- YouTube API as bounded enrichment only when justified
- manual spot-checks as validation support where ambiguity exists

This lane should not depend on hidden scraping theater or black-box unverifiable transformation.

---

## Out of Scope

This document does not define:
- YouTube publishing workflow
- script or thumbnail generation
- channel management
- recommendation feed modeling by default
- content strategy decisions
- cross-platform execution automation

Those concerns belong elsewhere or require later explicit bounded review.

---

## Boundary Check

The following concepts are intentionally excluded because they belong elsewhere or are stale fossils:

### Belongs to Project V
- deciding what YouTube content should be produced next
- sequencing YouTube actions based on observatory findings

### Belongs to V Forge
- producing YouTube assets
- editing metadata for publication
- publishing or updating YouTube content

### Historical / removed from active VEDA truth
- owned `Video` production model
- `MetricSnapshot`
- `DraftArtifact`
- workflow-first SEO/video execution models

---

## Maintenance Note

If future work tries to make YouTube ingest do any of the following:
- manage planning intent as canonical state
- manage publishing state
- act as an execution queue
- scrape broadly without governed target boundaries

that is an architectural warning sign.

The ingest boundary should remain narrow, search-first, deterministic, and observatory-only.
