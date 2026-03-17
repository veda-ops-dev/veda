# VEDA System Invariants

## Purpose

This document defines the non-negotiable system invariants of VEDA.

These invariants are architectural constraints, not implementation preferences.
They must remain true regardless of refactors, feature additions, UI changes, or internal reorganizations.

If a proposed change violates an invariant in this document, the change is incorrect.

Wave 2D re-established VEDA as an observability-only bounded domain.
These invariants reflect that current reality.

---

## 1. Bounded Domain Invariants

### 1.1 VEDA is observability-only

VEDA models observed external reality and project-scoped observatory state.

VEDA owns:
- project-scoped observatory partitioning
- source feed and source item capture
- keyword targets
- SERP snapshots
- search performance observation
- content graph structures
- observatory event logging
- observability-relevant system configuration

VEDA does not own:
- drafts
- editorial workflow
- publishing workflow
- owned content entities
- distribution events
- blueprint workflows
- reply drafting workflows
- production-facing asset management

If a feature is about planning, drafting, revising, or publishing owned outputs, it does not belong in VEDA.

### 1.2 VEDA uses the observability pattern

The core operating pattern of VEDA is:

```text
entity + observation + time + interpretation
```

New observatory capabilities should fit this pattern.
If they do not, ownership must be reconsidered before implementation.

---

## 2. Project Isolation Invariants

### 2.1 All observatory rows are project-scoped unless explicitly global

Every observatory domain row must belong to exactly one `Project`, unless the table is intentionally global.

Project-scoped tables include:
- `SourceItem`
- `SourceFeed`
- `EventLog`
- `KeywordTarget`
- `SERPSnapshot`
- `SearchPerformance`
- all Content Graph tables

Global tables must be rare and intentional.
`SystemConfig` is currently the primary global table.

No project-scoped row may exist without a project.

### 2.2 All reads and writes must enforce project ownership

All internal API reads must filter by the resolved `projectId` unless the table is explicitly global.

All writes must resolve project context explicitly and must never write across project boundaries.

Accessing a row by UUID must still enforce project ownership.
If a row exists but belongs to another project, the response must behave as if it does not exist.
No cross-project existence leakage is allowed.

### 2.3 Project context rules differ for reads vs writes

Mutation endpoints must require explicit project context before any write is permitted.
Silent fallback for mutations is forbidden.

Read-only endpoints may use a first-run fallback only where explicitly intended and safe.
Convenience must never weaken data isolation.

---

## 3. Content Graph Integrity Invariants

### 3.1 Content Graph junctions must never connect across projects

A `CgPageTopic` row must only connect a page and topic from the same project.
A `CgPageEntity` row must only connect a page and entity from the same project.
A `CgInternalLink` row must only connect pages from the same project.

Cross-project graph contamination is forbidden.

This invariant must be enforced at both:
- the application layer
- the database layer where critical integrity is at stake

### 3.2 Canonical identifiers must remain stable within project scope

Where a content graph object uses a canonical identifier, key, domain, or URL as its identity surface, that identity must remain stable and unique within its intended scope.

Examples:
- `CgSurface.projectId + key`
- `CgSite.projectId + domain`
- `CgPage.projectId + url`
- `CgTopic.projectId + key`
- `CgEntity.projectId + key`

Cross-project duplication may be allowed where intended.
Within project scope, ambiguity is not allowed.

---

## 4. Observation Ledger Invariants

### 4.1 Observations must be append-friendly and time-aware

Observation tables must preserve time as a first-class concept.

Examples:
- `SERPSnapshot.capturedAt`
- `SearchPerformance.capturedAt`
- `EventLog.timestamp`
- `SourceItem.capturedAt`

VEDA should prefer recording new observations over mutating historical observations.
If an observation must be corrected, the correction path must be explicit.

### 4.2 Search observations must remain observation-first, not intent-shaped

`KeywordTarget` is a governance record describing what a project chooses to observe.
`SERPSnapshot` and `SearchPerformance` are observation records describing what was seen.

These roles must not be conflated.
A planning or execution concern must not be stored as though it were an external observation.

### 4.3 Provider payloads may be archived, but hot query fields must be explicit

Raw provider payloads may be stored for evidence and future re-interpretation.
But fields that are frequently queried, filtered, or used in system logic must be promoted to explicit columns.

JSON is allowed as supporting evidence.
JSON must not become a substitute for clear schema design.

---

## 5. Transaction & Atomicity Invariants

### 5.1 No multi-write mutation may exist outside a transaction

Any operation that changes persisted state across multiple writes must execute inside a single transaction.

This includes, but is not limited to:
- state transitions
- observatory object creation with linked event logs
- source capture with related writes
- content graph mutation flows

Partial writes are forbidden.

### 5.2 State change and event log must be atomic when both are required

If a mutation changes persisted state and should produce an `EventLog` entry, both actions must occur in the same transaction.

It must be impossible for:
- state to change without the required event
- an event to exist without the corresponding state transition

If the transaction rolls back, both state and event must roll back.

---

## 6. Event Logging Invariants

### 6.1 Event logs are canonical observatory history

All event-eligible state changes must emit canonical `EventLog` entries.

Event logs must include:
- `eventType`
- `entityType`
- `entityId`
- `actor`
- `projectId`

Event logs are append-only.
They must never be rewritten to alter historical truth.

### 6.2 Read-only endpoints must not emit state-change events

GET endpoints and other read-only operations must not create state-change event logs.

VEDA event logs represent durable state transitions, not ordinary reads.
If read-observation logging is ever introduced, it must be explicitly modeled as a separate concern rather than silently mixed into the canonical event log.

### 6.3 Event vocabulary must remain observatory-scoped

`EventType` and `EntityType` values in VEDA must describe observatory entities and observatory events.

Removed production/editorial vocabularies must not be reintroduced.

---

## 7. Determinism Invariants

### 7.1 All list endpoints must have deterministic ordering

All list endpoints must define deterministic ordering.
Ordering must include a stable tie-breaker where necessary.
No endpoint may rely on implicit database ordering.

### 7.2 Validation must be deterministic and reproducible

Validation errors must be deterministic and reproducible.
Enum validation must be explicit.
No unsafe casting of enums or JSON types is allowed.

### 7.3 Context assembly and observatory retrieval must prefer reproducibility

Where VEDA assembles or ranks observatory context, the same query against the same state should produce the same result unless intentional nondeterminism is explicitly introduced and documented.

LLM-facing observatory behavior should prefer reproducible system truth over clever but unstable heuristics.

---

## 8. Database Constraint Invariants

### 8.1 Uniqueness must match real ownership scope

Where uniqueness is domain-scoped, the uniqueness boundary must reflect actual ownership scope.

If a value is only unique within a project, the constraint must include `projectId`.
If a value is intentionally global, that decision must be explicit and justified.

Global uniqueness must not be used accidentally where project-scoped duplication is legitimate.

### 8.2 DB-level enforcement is authoritative for critical integrity

Critical isolation and graph-integrity constraints must be enforced at the database level where practical.

Application checks alone are insufficient for invariants that protect:
- multi-project isolation
- cross-row graph integrity
- canonical uniqueness guarantees

If an invariant protects structural safety, the database should be treated as the authoritative enforcement layer.

---

## 9. Public Surface Invariants

### 9.1 Public or external-facing surfaces must respect project boundaries

Any public or external-facing VEDA surface must remain project-scoped unless it is explicitly designed as a global surface.

Public exposure must never leak cross-project data.

### 9.2 Build-time and automation paths must not bypass safety rules silently

Automation, ingestion jobs, scripts, and build-time execution must not bypass project isolation, transaction safety, or observatory-only ownership rules just because they are internal.

Internal code is not exempt from system invariants.

---

## 10. Testing & Verification Invariants

### 10.1 The system must maintain repeatable verification

VEDA must maintain deterministic, repeatable verification through:
- API hammer tests
- database hammer tests
- build and lint guardrails
- targeted invariants testing

If these fail, the system is not safe.

### 10.2 Cross-project violation probes must fail

Any probe that attempts to create cross-project contamination must fail.

Examples:
- cross-project content graph junctions
- writes using the wrong project context
- reads that leak cross-project data

### 10.3 Transaction rollback behavior must be testable

Atomicity claims are not enough.
Rollback behavior for multi-write mutations must be tested and confirmed.

---

## Final Principle

VEDA is a multi-project, observability-only, event-logged, transaction-safe system.

Isolation is structural.
Observations are canonical.
Events are append-only.
Determinism is required.
Bounded ownership matters.

Any change that weakens these properties is invalid.
