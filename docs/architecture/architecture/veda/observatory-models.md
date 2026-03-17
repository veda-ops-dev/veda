# Observatory Models

## Purpose

This document defines the observatory model shapes that belong in VEDA.

It exists to describe how VEDA can support multiple observatories while preserving clean ownership, project-scoped isolation, and time-aware observed truth.

This is a VEDA architecture document.
It does not replace `docs/architecture/veda/SCHEMA-REFERENCE.md`.
It provides the higher-level model needed to classify observatories and keep their boundaries clean.

If this document conflicts with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- the current Prisma schema

those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document defines:
- what an observatory is inside VEDA
- the shared model pattern observatories should follow
- the active observatory domains in VEDA today
- how observatories relate to project scoping, event logging, and time-aware observations
- how to classify future observatories without blurring planning and execution boundaries

---

## What This Doc Is Not

This document is not:
- a roadmap for every future surface
- an execution-planning spec
- a publishing workflow document
- a general product vision manifesto

It answers a narrower question:

```text
What kinds of observatory models belong in VEDA, and what shape should they take?
```

---

## Ownership

This document belongs to VEDA.

VEDA owns observatory models because they describe how VEDA records and interprets observed external reality and project-scoped observatory state.

The bounded-system rule remains:
- Project V plans
- VEDA observes
- V Forge executes

If a proposed model starts managing what should be produced, revised, approved, or published, it belongs outside VEDA.

---

## Core Rule

Every valid VEDA observatory should fit the pattern:

```text
entity + observation + time + interpretation
```

That does not mean every table literally has those four words in it.
It means the model must be intelligible in those terms.

### Entity
The thing being observed, tracked, or structurally modeled.

### Observation
The recorded state, capture result, or structured evidence.

### Time
When the observation was captured, valid, or logged.

### Interpretation
The governed meaning derived from observations without replacing the underlying evidence.

If a proposed capability cannot be described in this pattern, it probably does not belong in VEDA.

---

## Shared Observatory Traits

Regardless of surface, VEDA observatories should share several traits.

### 1. Project-scoped by default

Observatory data belongs to exactly one project unless a table is explicitly global.

This includes:
- intake records
- search observations
- content graph records
- event logs
- future observatory rows unless explicitly justified otherwise

### 2. Time-aware by design

Observations happen at specific moments and should preserve that reality.

### 3. Append-friendly where observation history matters

Where the system is recording observed reality over time, new observations should generally be added rather than silently overwriting the past.

### 4. Explicit schema over JSON sludge

Raw provider payloads may be stored as evidence.
Fields needed for filtering, querying, validation, or system logic should be promoted into explicit columns.

### 5. Evented where durable state changes matter

Meaningful observatory state changes should remain auditable through canonical event logging where required.

### 6. Deterministic retrieval

Observatory reads should use explicit ordering and reproducible behavior.

### 7. No execution-state impersonation

An observatory model may describe observed structure or observed external state.
It must not take on planning state, production workflow, or execution workflow.

---

## Active Observatory Domains

The current schema and truth docs support a small set of active observatory domains.

### 1. Source and capture observatory

This observatory records captured external material as project-scoped intake.

Core models include:
- `SourceFeed`
- `SourceItem`

This domain answers questions like:
- what external material entered the observatory?
- when was it captured?
- what source type and platform did it come from?
- what triage-relevant state is it in?

Primary supporting docs:
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/event-auditability.md`

### 2. Search observation ledger

This observatory records governed search targets and append-friendly search observations.

Core models include:
- `KeywordTarget`
- `SERPSnapshot`
- `SearchPerformance`

This domain answers questions like:
- what queries is the project observing?
- what did the system see on the SERP?
- when was that observation captured or valid?
- how is observed performance changing over time?

Primary supporting docs:
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/ingest-discipline.md`

### 3. Content graph observatory

This observatory records the observed structural state of content surfaces.

Core models include:
- `CgSurface`
- `CgSite`
- `CgPage`
- `CgContentArchetype`
- `CgTopic`
- `CgEntity`
- `CgPageTopic`
- `CgPageEntity`
- `CgInternalLink`
- `CgSchemaUsage`

This domain answers questions like:
- what content surfaces exist for the project?
- what pages, topics, entities, and structural links are present?
- what schema usage and page archetypes are observed?
- where are there structural patterns worth interpreting later?

### 4. Event and audit observatory

The canonical event ledger records meaningful observatory state changes.

Core model:
- `EventLog`

This domain answers questions like:
- what changed?
- when did it change?
- which observatory object changed?
- which actor initiated it?

Primary supporting docs:
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`
- `docs/systems/veda/observatory/event-auditability.md`

### 5. Global observability configuration

This is a narrow supporting domain rather than a broad observatory surface.

Core model:
- `SystemConfig`

This exists for small, intentional observability-relevant configuration.
It must not become a junk drawer for arbitrary application state.

---

## How Active Observatories Relate

The active observatories are complementary, not redundant.

### Source and capture
Preserves incoming evidence and provenance.

### Search observation ledger
Records what the project chooses to observe and what the system sees on search surfaces over time.

### Content graph
Records structural state of content surfaces as observed graph objects.

### Event ledger
Records meaningful observatory state change history.

Together they allow VEDA to build richer interpretation later without confusing evidence, governance, structure, and audit history.

---

## Interpretation vs Observation

Observatory models may support interpretation, but they must not collapse interpretation into canonical observed truth.

### Good pattern
- record the observed page
- record the observed schema usage
- record the captured SERP snapshot
- derive later interpretation from those records

### Bad pattern
- persist strategic conclusions as if they were raw observations
- store future execution intent as though it were observed reality
- materialize speculative scores everywhere just because scoring feels smart

Interpretation may grow on top of observatory models.
It should not replace them.

---

## Candidate Future Observatory Types

VEDA can support future observatories, but they must be added deliberately and classified properly.

Potential future observatories include:
- competitor observation models
- LLM citation observation models
- additional external surface observatories where justified

A future observatory is only a good fit if it can answer:
- what entity is being observed?
- what observation is being recorded?
- what is the time model?
- what interpretation is derived later?
- how is project scope enforced?
- how is this distinct from planning or execution?

If those questions cannot be answered cleanly, the proposed observatory is not ready.

---

## Future Observatory Admission Test

Before adding a new observatory model, run this test.

### 1. Ownership test
Does it clearly belong to VEDA rather than Project V or V Forge?

### 2. Pattern test
Can it be explained as `entity + observation + time + interpretation`?

### 3. Scope test
Can project ownership and non-disclosure rules be enforced cleanly?

### 4. Evidence test
Does it preserve observed evidence rather than merely storing conclusions?

### 5. Schema test
Can the hot-path structure be modeled explicitly without collapsing into JSON sludge?

### 6. Audit test
Can meaningful state changes be logged coherently where required?

### 7. Anti-blob test
Does it avoid quietly pulling planning or execution responsibilities into VEDA?

A proposed observatory should not pass just because it sounds cool in a late-night architecture trance.
It should pass because the ownership and model shape are actually sound.

---

## Explicit Non-Examples

The following do not belong in VEDA observatory models:
- draft lifecycle models
- editorial workflow models
- publish queue models
- production asset management models
- reply drafting workflows
- execution distribution workflows
- rich project lifecycle ownership
- blueprint workflow ownership

These belong outside VEDA.

---

## Relationship to Current Schema

At the schema level, today’s observatory model families map roughly to:

```text
Project
 ├─ SourceFeed
 ├─ SourceItem
 ├─ EventLog
 ├─ KeywordTarget
 ├─ SERPSnapshot
 ├─ SearchPerformance
 ├─ CgSurface
 │   └─ CgSite
 │       └─ CgPage
 │           ├─ CgPageTopic -> CgTopic
 │           ├─ CgPageEntity -> CgEntity
 │           ├─ CgInternalLink
 │           └─ CgSchemaUsage
 └─ SystemConfig (global exception)
```

This is the active observatory floor today.
Future observatories should extend this model carefully rather than ignore it.

---

## Relationship to Active Docs

This document should be read together with:
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/ingest-discipline.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/event-auditability.md`
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`
- `docs/architecture/veda/content-graph-model.md`

---

## Maintenance Note

If future work tries to use observatory language to justify:
- planning-state ownership inside VEDA
- execution-planning ownership inside VEDA
- production workflow inside VEDA
- storing strategy as raw observed truth
- turning VEDA into an all-in-one system blob

that is an architectural warning sign.

The durable rule remains simple:
- Project V plans
- VEDA observes
- V Forge executes

This document exists to keep observatory models legible, bounded, and safe to extend.
