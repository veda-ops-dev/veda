# Observation Ledger

## Purpose

This document defines the minimum viable observation ledger for VEDA.

It explains how VEDA records governed search targets and immutable search observations in a way that is project-scoped, deterministic, append-friendly, and aligned with post-Wave-2D observability-only ownership.

This document is an architecture and behavior reference.
It is not a substitute for the Prisma schema, API code, or hammer tests.

If this document conflicts with the current schema or enforced invariants, the schema and invariants win and this document must be updated.

---

## What This Doc Is

This document describes the core observation-ledger pattern for VEDA search observability.

It covers:
- governed observation targets
- immutable SERP observation records
- time-aware capture semantics
- project-scoped isolation
- deterministic retrieval expectations
- atomic event logging requirements

---

## What This Doc Is Not

This document is not:
- a planning document
- an execution workflow document
- a keyword recommendation engine
- a volatility scoring spec
- a clustering spec
- a publishing or editorial workflow doc

It does not define what should be produced.
It defines how observed search reality is recorded.

---

## Ownership

This doc belongs to VEDA.

VEDA owns the observation ledger because it is part of observability and intelligence, not planning or execution.

This fits the core VEDA pattern:

```text
entity + observation + time + interpretation
```

In this case:
- `KeywordTarget` defines what a project chooses to observe
- `SERPSnapshot` records what was observed
- time is recorded explicitly
- later analysis and interpretation can be derived without rewriting the historical record

---

## Core Ledger Model

The minimum viable observation ledger has two distinct record types:

### 1. Governance record: `KeywordTarget`

`KeywordTarget` records that a project has chosen to observe a query within a specific locale and device scope.

This is not an observation.
It is a governed tracking decision.

A target answers questions like:
- what query are we tracking?
- for which locale?
- on which device context?
- is this a primary target?
- what intent or operator notes are attached?

### 2. Observation record: `SERPSnapshot`

`SERPSnapshot` records what the system observed on the SERP at a specific time.

This is the historical observation row.
It is append-friendly and time-aware.

A snapshot answers questions like:
- what query was observed?
- when was it captured?
- when was it valid for?
- what provider payload was captured?
- what AI overview state was observed?

These two roles must remain separate.
Governance records and observation records must not be conflated.

---

## Non-Negotiable Invariants

The observation ledger must comply with current VEDA invariants.

### Project-scoped isolation

All observation-ledger rows are project-scoped.

- `KeywordTarget` belongs to exactly one project
- `SERPSnapshot` belongs to exactly one project
- reads must enforce project ownership
- writes must resolve project context explicitly
- cross-project existence leakage is forbidden

If a row exists in another project, the system must behave as if it does not exist.

### Observation-first separation

`KeywordTarget` is a governance row.
`SERPSnapshot` is an observation row.

A planning concern must not be stored as though it were an external observation.
An execution concern must not be stored in the observation ledger at all.

### Determinism

All list and retrieval behavior must use deterministic ordering.
No implicit database ordering is allowed.

### Evented mutation

Creation of observation-ledger rows must emit canonical observatory events where required.
State change and event logging must be atomic.

### No background automation requirement

The ledger must not assume silent autonomous observation loops as canonical behavior.
Operator-triggered or explicitly initiated ingestion remains the safe baseline.

---

## Query Normalization

Observed queries must be normalized at the API boundary before they are persisted.

Minimum normalization:
- trim leading and trailing whitespace
- collapse internal whitespace to single spaces
- lowercase

This prevents silent fragmentation such as treating these as different queries:
- `Best CRM`
- `best crm`
- `best   crm`

Without normalization, the observation ledger becomes noisy and unreliable.

---

## Time Semantics

Time is first-class in the observation ledger.

### `capturedAt`

`capturedAt` records when VEDA captured the observation.

This is the system’s ingestion-time truth.

### `validAt`

`validAt` records when the provider says the observation is valid for.

This matters when provider data is delayed, replayed, or reflects a provider-side timestamp that differs from local capture time.

### Fallback rule

If the provider does not supply `validAt`, the ingest boundary should treat:

```text
validAt = capturedAt
```

This preserves usable temporal semantics without inventing a second source of time.

---

## Immutability Doctrine

Observation rows should be append-friendly and treated as historical records.

### `SERPSnapshot`

`SERPSnapshot` is the immutable observation row in the ledger.

The safe default rule is:
- do not update historical snapshots in place
- record a new snapshot instead
- treat corrections as explicit later observations or explicit correction paths

This preserves historical search reality over time.

### `KeywordTarget`

`KeywordTarget` is not immutable in the same way.
It is a governance/configuration record.

It may change in bounded ways, such as:
- notes
- intent
- primary-target flag

That does not violate ledger discipline because it is not the historical observation row.

---

## Raw Evidence and Hot Fields

The observation ledger may retain raw provider payloads for evidence and future reinterpretation.

That is useful.
But raw JSON must not become an excuse for schema sludge.

Frequently used fields should be promoted into explicit columns where they matter for:
- filtering
- querying
- validation
- system logic
- deterministic list behavior

The rule is:
- raw payloads may be kept as supporting evidence
- hot query fields should be explicit

This is consistent with current VEDA schema guidance.

---

## Retrieval Expectations

Observation-ledger retrieval must remain deterministic and project-scoped.

### Keyword target lists

Target lists should:
- filter by project
- use explicit ordering
- include a stable tie-breaker

A typical pattern is:
- `createdAt`
- then `id`

### SERP snapshot lists

Snapshot lists should:
- filter by project
- use explicit ordering
- include a stable tie-breaker

A typical pattern is:
- `capturedAt`
- then `id`

The exact order direction may vary by endpoint, but it must always be explicit.

---

## Event Logging Requirements

Observation-ledger mutations should align with VEDA’s canonical event vocabulary.

Typical events include:
- `KEYWORD_TARGET_CREATED`
- `SERP_SNAPSHOT_RECORDED`

These events must:
- reference the correct `entityType`
- reference the correct `entityId`
- include project scope
- include actor attribution
- be recorded atomically with the state change where required

The event log is not telemetry fluff.
It is the canonical audit trail for observatory state changes.

---

## What the Observation Ledger Enables

A clean observation ledger gives VEDA a stable base for higher-order observability work.

It enables:
- reproducible historical comparison
- future delta detection
- future deterministic read models
- future derived interpretation without rewriting original observations
- operator review grounded in persisted evidence

It does not require VEDA to become:
- a planning engine
- a publishing system
- a recommendation theater machine

Interpretation can grow later.
The historical ledger must stay boring and reliable first.

---

## Out of Scope

The following are outside this document’s scope:
- keyword clustering
- volatility scoring
- competitor recommendation logic
- content planning actions
- execution sequencing
- editorial workflow
- publishing workflow
- autonomous recommendation pipelines
- vector retrieval design
- GraphRAG design

Those may depend on the ledger later.
They are not part of the ledger itself.

---

## Boundary Check

The following concepts were intentionally excluded because they belong elsewhere or were removed from active VEDA truth:

### Belongs to Project V
- choosing what to do next based on observations
- planning prioritization logic
- roadmap sequencing from search signals

### Belongs to V Forge
- drafting content in response to observations
- publishing workflows tied to keyword opportunities
- execution state for owned outputs

### Historical / removed from active VEDA truth
- `DistributionEvent`
- `MetricSnapshot`
- draft or editorial lifecycle behavior
- blueprint or reply-drafting workflow language
- legacy publishing/entity workflow models

---

## Maintenance Note

If future work tries to turn the observation ledger into:
- a planning store
- an execution queue
- a publishing state machine
- a recommendation engine with weak provenance

that is an architectural warning sign.

The ledger should remain observation-first.

The durable rule is:
- VEDA records what was observed
- Project V decides what to do
- V Forge executes what gets made
