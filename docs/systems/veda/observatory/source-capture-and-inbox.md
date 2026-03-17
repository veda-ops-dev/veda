# Source Capture and Inbox

## Purpose

This document defines how external material enters VEDA as observatory intake.

It exists to preserve provenance, keep capture intentional, reduce link sprawl, and support later analysis without confusing intake with planning, drafting, or publishing.

This document describes capture and triage behavior inside the observatory boundary.
It does not define publishing, editorial, or execution workflow.

If this document conflicts with current invariants, schema reality, or enforced system behavior, the authoritative sources win and this document must be updated.

---

## What This Doc Is

This document defines the observatory intake model for external material entering VEDA.

It covers:
- what source capture means
- how captured material is represented
- why provenance comes first
- how the inbox/triage layer should behave
- how source status transitions remain explicit and evented

---

## What This Doc Is Not

This document is not:
- a content drafting workflow
- a publishing workflow
- a Project V planning doc
- a V Forge execution doc
- a CMS/editorial lifecycle doc

It does not define what should be produced.
It defines how external material is captured and triaged as observatory input.

---

## Ownership

This doc belongs to VEDA.

VEDA owns source capture and source-item intake because they are observatory concerns:
- material is being captured as input
- provenance is being preserved
- operator intent is being recorded
- later interpretation can happen without losing evidence

This fits the VEDA pattern:

```text
entity + observation + time + interpretation
```

In this case:
- the source item is the captured entity
- capture is the observatory event
- `capturedAt` preserves time
- later triage and interpretation remain grounded in recorded intake

---

## Core Principle

Nothing should enter durable observatory use without first being captured as a source item or equivalent intake record.

The point of source capture is not bureaucracy.
The point is traceability.

Without explicit capture:
- links disappear into chats and notes
- provenance is weakened
- operator intent is lost
- later reasoning becomes less trustworthy

Source capture exists to stop that rot before it starts.

---

## What Counts as a Source

A source is any external or semi-external artifact that may inform later observatory use.

Examples include:
- articles
- videos
- repositories
- social threads
- papers
- websites
- comments or replies
- notes with enough context to preserve why they matter

A source does not need to be high quality in order to be captured.
It needs to be worth remembering and traceable enough to support later use or rejection.

---

## Source Item Intake Model

A source item represents a captured intake artifact in the observatory layer.

At minimum, a source item should preserve:
- source type
- title or identifying label
- URL when available
- operator notes or intent when relevant
- capture time
- current intake status

Depending on the capture path, it may also preserve:
- platform
- tags or rough topical hints
- snapshot or payload references
- capture method metadata

The purpose of the source item is not to become published output.
Its purpose is to preserve a traceable intake record.

---

## Intake Status Model

Source items move through a simple observatory status flow.

Typical statuses include:
- `ingested`
- `triaged`
- `used`
- `archived`

### `ingested`

The material has been captured but not yet meaningfully reviewed.

### `triaged`

The material has been reviewed and kept in the observatory layer for possible downstream use.

### `used`

The material has been explicitly referenced or consumed in a later grounded workflow.

This is an observatory usage marker, not a publishing marker.

### `archived`

The material was intentionally retained as historical intake but set aside from active use.

Status changes should be explicit and evented.
They should not happen silently.

---

## Manual Capture First

Manual capture is the safest default.

The core capture flow should allow an operator to:
- provide a URL or source reference
- preserve the title or identifying label
- add brief notes on why the source matters
- persist the item into the intake layer as `ingested`

Manual capture matters because it preserves operator intent at the moment of intake.
That is often the difference between useful provenance and meaningless pile-building.

---

## Assisted Capture

Assisted capture may help reduce operator friction.

Safe assistive behavior may include:
- metadata extraction from a URL
- title and platform detection
- snapshot or payload capture where appropriate
- structured hints that help later triage

But assistance must not erase intent.

The system may assist capture.
It must not pretend capture happened meaningfully if the operator did not provide or confirm the intake action.

---

## Inbox and Triage Behavior

The inbox is the operator-facing intake queue for captured source material.

Its purpose is decision-making, not writing.

The inbox should help an operator answer:
- what was captured?
- why was it captured?
- what still needs review?
- what should be kept, archived, or used?

Typical inbox actions include:
- keep / retain for observatory use
- archive / set aside
- mark as used when later workflows explicitly consume it

The important rule is that inbox actions must remain explicit.
The inbox is not a hidden automation lane.

---

## Provenance Rule

A captured source should preserve enough context that a human can later understand:
- what it was
- where it came from
- when it entered the system
- why it was captured

That does not mean every source needs maximal metadata.
It means the system should preserve enough provenance to make later interpretation defensible.

This is one of the main reasons source capture belongs in VEDA.
It is about preserving observed input truth, not creating output.

---

## Event Logging Expectations

Meaningful source capture and source status transitions should align with canonical VEDA event logging.

Typical relevant events include:
- `SOURCE_CAPTURED`
- `SOURCE_TRIAGED`

These events should:
- be project-scoped
- identify the correct source item
- record actor attribution
- remain append-only historical truth

If state changes and event logging are both required, they should remain atomic.

---

## LLM Involvement

LLMs may assist with intake-oriented work such as:
- summarizing captured material
- extracting structured hints from captured sources
- suggesting candidate classifications or topical hints

LLMs must not:
- invent sources
- silently capture sources without explicit governed action
- erase provenance
- convert intake state into publishing or planning state by implication

LLM help is acceptable when it remains inside:

```text
Propose -> Review -> Apply
```

---

## Anti-Patterns

The following patterns are explicitly bad:

- treating links in chats as durable capture
- letting important sources exist only in memory or ad hoc notes
- bulk ingestion without review or provenance discipline
- treating source items as publishable outputs
- using intake state as a disguised publishing workflow
- skipping capture and pretending later reasoning is still grounded

These are how observability systems turn into junk drawers.

---

## Relationship to Other Systems

### Project V

Project V may decide that certain research or source gathering should happen.
But Project V does not own the captured observatory intake record inside VEDA.

### V Forge

V Forge may later consume grounded material during execution workflows.
But source capture itself is not a V Forge concern.
Drafting, revising, and publishing belong there, not here.

This separation matters.
Capture is intake.
Execution is not intake.

---

## Out of Scope

This document does not define:
- draft creation workflows
- editorial attachment workflows as canonical VEDA behavior
- publish review or gating
- social reply drafting
- execution asset management
- roadmap prioritization

Those belong to other systems or other document sets.

---

## Boundary Check

The following concepts were intentionally excluded because they belong elsewhere or were removed from active VEDA truth.

### Belongs to Project V
- deciding what source-gathering work should happen next
- planning prioritization based on source intake
- lifecycle/orchestration truth

### Belongs to V Forge
- creating drafts from source intake as execution truth
- editorial workflow
- publish review and gating
- reply drafting and production-facing workflows

### Historical / removed from active VEDA truth
- draft promotion as active VEDA-owned workflow
- entity/editorial CMS assumptions
- public/news CMS routes
- old mixed publishing language

---

## Maintenance Note

If future work tries to turn source capture into:
- a hidden drafting system
- a planning state machine
- an execution queue
- a bulk ingestion dump without provenance

that is an architectural warning sign.

Source capture should remain intentional, traceable, project-scoped, and observatory-first.
