# Ingest Discipline

## Purpose

This document defines the non-negotiable ingest rules for VEDA’s search observation ledger.

It explains how observation-ledger writes must behave so they remain project-scoped, deterministic, auditable, append-friendly, and aligned with post-Wave-2D observability-only ownership.

This document describes ingest behavior.
It does not define UI flows, planning behavior, or execution workflows.

If this document conflicts with current invariants, schema reality, or enforced API behavior, those authoritative sources win and this document must be updated.

---

## What This Doc Is

This document defines the ingest discipline for:
- `KeywordTarget` creation
- `SERPSnapshot` recording
- observation-ledger validation expectations
- query normalization rules
- timestamp handling
- idempotency behavior
- atomic event logging requirements

It exists so VEDA records search observations in a way that remains boring, reproducible, and safe.

---

## What This Doc Is Not

This document is not:
- a UI spec
- a roadmap phase note
- a recommendation engine spec
- a clustering spec
- a volatility model
- a publishing workflow document
- an execution automation spec

It defines how observations enter the ledger, not what downstream systems should do with them.

---

## Ownership

This doc belongs to VEDA.

VEDA owns ingest discipline here because the concern is observatory-state creation and observation recording.

This is part of the current VEDA pattern:

```text
entity + observation + time + interpretation
```

The ingest boundary is where search observability enters the system.
That makes it a VEDA concern, not a Project V planning concern and not a V Forge execution concern.

---

## Core Ingest Rules

### 1. Operator-triggered ingest only

The safe default for this layer is operator-triggered ingest.

That means:
- no silent scheduled ingest as canonical behavior
- no hidden background ingestion assumptions in core design
- no autonomous “observe everything” behavior sneaking in through convenience paths

If future automation is introduced, it must still obey the same invariants and remain explicitly governed.
It must not weaken isolation, determinism, or auditability.

### 2. Governance rows and observation rows must stay distinct

The ingest boundary must preserve the distinction between:

- `KeywordTarget` as a governance record
- `SERPSnapshot` as an observation record

These roles are not interchangeable.

A target says:
- this is what we choose to observe

A snapshot says:
- this is what we observed at a particular time

The ingest path must not blur those meanings.

### 3. Observation rows are append-friendly

Observation ingest should prefer creating new historical records rather than mutating prior observations.

For `SERPSnapshot`, the default expectation is:
- record a new snapshot
- preserve capture time
- treat duplicate handling explicitly
- do not overwrite historical reality silently

---

## Project Scoping and Non-Disclosure

All ingest behavior must enforce current VEDA isolation rules.

### Project scoping

All writes must resolve project context explicitly before mutation.

A write must never:
- infer project context from unsafe fallback
- write across project boundaries
- create records detached from project scope

### Non-disclosure

Cross-project access must not leak existence.

If a row belongs to another project, the system must behave as if it does not exist.

This is not cosmetic.
It is a structural invariant.

---

## Query Normalization

Normalization must happen at the ingest boundary before persistence.

### Minimum normalization behavior

Normalize the query string by:
- trimming leading and trailing whitespace
- collapsing internal whitespace to single spaces
- lowercasing

Example:

```text
"  Best   CRM  " -> "best crm"
```

### Why this matters

Without normalization, the ledger fragments silently.
That makes:
- joins unreliable
- list results noisy
- downstream reasoning weaker
- duplicates harder to detect

### Persistence rule

The canonical normalized query is what should be persisted in the observation ledger.

The ingest boundary should not treat superficial query variants as meaningfully different observations.

---

## Timestamp Discipline

Ingest must preserve clear time semantics.

### `capturedAt`

`capturedAt` represents when VEDA captured the observation.

This is the primary ingestion-time timestamp.

### `validAt`

`validAt` represents the provider-valid time if available.

This is useful when provider timing differs from local ingestion timing.

### Fallback rule

If provider validity time is absent, the ingest boundary should treat:

```text
validAt = capturedAt
```

This keeps time semantics usable without inventing ambiguity.

---

## Idempotency and Duplicate Semantics

Ingest behavior must distinguish between:
- governance duplication
- observation replay

### `SERPSnapshot` replay behavior

Observation replay should be handled idempotently where the uniqueness boundary matches the intended observation identity.

The important behavior rule is:
- safe replay should not create a duplicate observation row
- safe replay should not emit a second mutation event when no new row was created

This keeps retries safe and preserves event-log meaning.

### `KeywordTarget` duplicate behavior

Governance duplication should be treated differently from observation replay.

A duplicate target create is not the same as replaying an already-recorded observation.

The important rule is:
- governance duplicates must be handled explicitly and consistently
- the system should not quietly create multiple target definitions for the same governed scope

---

## Validation Discipline

The ingest boundary must validate inputs explicitly and deterministically.

### Validation expectations

The ingest path should:
- reject malformed input clearly
- validate enums explicitly
- validate JSON payload structure where required
- avoid unsafe coercion
- return reproducible error results

### Device, locale, and source validation

Even when the persistence layer stores strings, the ingest boundary should still validate expected shapes and allowed values where they matter.

This is part of keeping behavior deterministic rather than “stringly typed and vibes-based.”

### Raw payload handling

Provider payloads may be stored as evidence.
But malformed JSON or unusable payload shape must fail cleanly at the boundary.

---

## Event Logging and Atomicity

All meaningful ingest mutations must align with canonical VEDA event logging.

Typical events include:
- `KEYWORD_TARGET_CREATED`
- `SERP_SNAPSHOT_RECORDED`

### Atomicity rule

Where state change and event logging are both required, they must occur atomically.

It must not be possible for:
- a row to be created without the required event
- an event to exist without the corresponding state change

### Replay rule

If an ingest request resolves as idempotent replay rather than a new persisted observation, the system must not emit a fresh mutation event pretending a new state change occurred.

Events represent durable state changes, not request attempts.

---

## Deterministic Read Defaults

Although this document is about ingest, the ingest layer should support deterministic retrieval later.

That means persisted records and retrieval expectations should be compatible with explicit ordering rules.

Typical list ordering patterns include:
- keyword targets ordered by `createdAt`, then `id`
- SERP snapshots ordered by `capturedAt`, then `id`

No implicit ordering should be assumed.

---

## Error Handling Principles

The ingest boundary should keep error behavior boring and explicit.

Typical classes include:
- malformed input
- validation failure
- true duplicate conflict where applicable
- idempotent replay where applicable
- cross-project non-disclosure or missing-resource behavior

The exact wire contract may evolve with implementation, but the architectural rule is stable:
- errors should be deterministic
- errors should not leak cross-project information
- retries should behave predictably

---

## What Good Ingest Discipline Prevents

A clean ingest boundary prevents the observation ledger from degrading into:
- duplicate query sludge
- inconsistent timestamps
- silent event mismatches
- cross-project contamination
- replay confusion
- accidental planning/execution drift at the ingest edge

This discipline is boring on purpose.
Boring ingest is what makes later interpretation trustworthy.

---

## Out of Scope

This document does not define:
- keyword clustering
- volatility scoring
- recommendation generation
- content planning actions
- LLM recommendation workflows
- publishing actions
- editorial state
- vector retrieval design
- GraphRAG behavior

Those may depend on clean ingest later.
They are not part of ingest discipline itself.

---

## Boundary Check

The following concepts were intentionally excluded because they belong elsewhere or were removed from current VEDA truth.

### Belongs to Project V
- deciding which observations matter most for next-step planning
- prioritization and sequencing based on search signals

### Belongs to V Forge
- turning observed search opportunities into drafted outputs
- publish or revision workflows tied to search observations
- execution automation on owned surfaces

### Historical / removed from active VEDA truth
- draft and editorial workflow assumptions
- `DistributionEvent`
- `MetricSnapshot`
- blueprint workflow language
- reply-drafting routes
- old mixed publish-state behavior

---

## Maintenance Note

If future work tries to make ingest discipline do any of the following:
- manage planning intent as canonical state
- manage publishing state
- act as an execution queue
- silently automate observation behavior without governance

that is an architectural warning sign.

The ingest boundary should remain narrow, deterministic, and observatory-first.
