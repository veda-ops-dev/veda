# Event Auditability

## Purpose

This document defines how VEDA records meaningful observatory state changes in a way that remains traceable, explainable, and reconstructible over time.

It exists to preserve accountability for human, LLM, and system-initiated observatory actions without turning the event log into analytics sludge or a vague telemetry bucket.

If something important changed in VEDA, the system should be able to explain:
- what changed
- when it changed
- which observatory object changed
- who or what initiated the change
- which project the change belonged to

This document describes observatory event auditability.
It does not define production workflow, publishing workflow, or execution telemetry.

---

## What This Doc Is

This document explains the auditability rules for VEDA’s canonical observatory event ledger.

It covers:
- what counts as an auditable event
- why event logs are append-only
- actor attribution
- minimum event meaning
- how event logs support reconstruction and debugging
- what event logs must not become

---

## What This Doc Is Not

This document is not:
- a performance telemetry spec
- an analytics spec
- a product metrics spec
- a publishing lifecycle doc
- an execution workflow audit spec
- a replacement for the event vocabulary document

This document explains why and how observatory events remain auditable.
The event vocabulary document remains the canonical explanation of current event types and entity types.

---

## Ownership

This doc belongs to VEDA.

VEDA owns observatory event auditability because event logs are part of canonical observatory history.
They record meaningful persisted observatory state changes inside the VEDA boundary.

This fits the post-Wave-2D observability model:

```text
entity + observation + time + interpretation
```

Event logs preserve the time-aware state-change history of observatory entities.

---

## Core Principle

Nothing important should happen silently.

If a meaningful observatory state change occurs, the system should record it in the canonical event ledger.

The event log exists so the system can reconstruct observatory history rather than depend on memory, guesswork, or scattered implementation side effects.

---

## What an Event Represents

An event is a durable record that a meaningful persisted observatory state transition happened.

An event is not:
- a scratchpad
- a cache entry
- a debug print
- a read trace
- a generic telemetry blob

An event says:
- a real state change occurred
- it affected a real observatory entity
- it happened at a specific time
- it belonged to a specific project
- a human, LLM, or system actor initiated it

That is what makes the log auditable rather than decorative.

---

## Event Ledger Model

VEDA’s canonical event history is represented through:
- `EventLog`
- `EventType`
- `EntityType`
- `ActorType`

These are observatory-scoped.
They do not recreate the removed editorial and production workflow vocabularies that existed before Wave 2D.

The event vocabulary document defines the current allowed values.
This document explains the auditability discipline around them.

---

## Actor Attribution

Every event should preserve actor attribution.

Current actor families are:
- `human`
- `llm`
- `system`

### `human`

Use when the initiating action came from an operator.

### `llm`

Use when an LLM directly initiated an allowed state change through an approved tool path.

### `system`

Use when the state change was initiated by internal system behavior rather than a direct human or LLM action.

Actor attribution matters because auditability is not just about what happened.
It is also about understanding how the action entered the system.

---

## Minimum Event Meaning

At minimum, an auditable event should preserve enough structure to answer:
- what happened
- what kind of thing it happened to
- which specific record it happened to
- which project it belongs to
- who or what initiated it
- when it happened

That is why the canonical event model centers on:
- `eventType`
- `entityType`
- `entityId`
- `projectId`
- `actor`
- `timestamp`
- optional structured details

The details field may enrich meaning.
It must not become the only place where meaning lives.

---

## When Event Logging Is Required

Event logging is required for meaningful persisted observatory state changes.

Typical examples include:
- source capture
- source triage state changes
- keyword target creation
- SERP snapshot recording
- content-graph object creation
- content-graph junction creation
- meaningful observability configuration changes
- project-scoping record creation inside VEDA

The simplest test is:
- if durable observatory state changed, an event likely belongs here
- if nothing durable changed, the canonical event log probably should not be used

---

## Read Operations Are Not State Events

Ordinary reads must not emit canonical state-change events.

That means:
- GET requests do not create state-change history
- rendering a page does not create state-change history
- reading an observatory object does not become an event by default

If future read-observation logging is needed, it must be modeled as a separate concern rather than mixed into the canonical state-change ledger.

This keeps the event log meaningful instead of noisy.

---

## Append-Only Rule

The event log is append-only.

Events are historical truth.
They must not be rewritten to reshape the past.

If a correction is needed:
- write a new event
- keep the old event intact
- preserve the sequence of what actually happened

Auditability dies the moment history becomes editable theater.

---

## Atomicity Rule

If an observatory mutation requires both:
- a persisted state change
- a canonical event log entry

then both actions should happen atomically where required.

It must not be possible for:
- state to change with no required event
- an event to exist for a state change that never committed

State and event must agree.

This is one of the central reasons event logs are useful during debugging and system reconstruction.

---

## Reconstruction Use Cases

A good event ledger should support reconstruction of observatory history.

That includes questions like:
- when was this source captured?
- when did this source move to a triaged or used state?
- when was this keyword target created?
- when was this SERP observation recorded?
- which actor created this content-graph structure?
- which project did this change belong to?

The event ledger is not there to flatter the system.
It is there to make historical state explainable.

---

## Debugging Use Cases

The event ledger should also support debugging.

That includes:
- understanding why a record exists
- verifying whether a state change actually committed
- checking whether duplicate ingest replay incorrectly emitted events
- distinguishing human-initiated vs LLM-initiated vs system-initiated changes
- tracing unexpected observatory state back to a real historical action

Without an auditable event ledger, debugging becomes folklore.

---

## What Event Logs Must Not Become

The canonical event ledger must not become:
- a general telemetry sink
- engagement analytics
- performance monitoring
- behavioral profiling
- vague “activity feed” sludge
- a substitute for schema design

Those concerns may exist elsewhere.
They are not the purpose of `EventLog`.

Audit logs work best when they stay narrow, durable, and meaningful.

---

## Relationship to the Event Vocabulary

This document should be read together with:

- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`

That document defines:
- current `EventType` values
- current `EntityType` values
- current `ActorType` values
- event emission rules tied to the vocabulary

This document adds the auditability layer:
- why append-only history matters
- why actor attribution matters
- why state/event agreement matters
- why event logs must remain observatory-scoped

---

## Out of Scope

This document does not define:
- production artifact workflows
- editorial lifecycle events
- publishing transitions
- draft lifecycle events
- distribution actions
- metric snapshot workflows from removed domains
- blueprint workflow events

Those were removed from active VEDA truth or belong to other systems.

---

## Boundary Check

The following concepts were intentionally excluded because they belong elsewhere or were removed from active VEDA truth.

### Belongs to Project V
- planning-state change history
- orchestration sequencing events
- roadmap and next-step coordination events

### Belongs to V Forge
- draft lifecycle events
- publishing and revision events
- execution/distribution workflow events
- production artifact audit logs

### Historical / removed from active VEDA truth
- legacy publishing/entity events
- `DraftArtifact` lifecycle events
- `DistributionEvent`
- `MetricSnapshot` lifecycle events
- blueprint application events
- old editorial dashboard workflow events

---

## Maintenance Note

If future work tries to turn the event ledger into:
- a production workflow log
- a generic analytics stream
- an editable history surface
- a catch-all activity feed

that is an architectural warning sign.

VEDA event auditability should remain:
- observatory-scoped
- append-only
- actor-aware
- project-scoped
- reconstructible
- transaction-safe

That is what keeps the system explainable over time.
