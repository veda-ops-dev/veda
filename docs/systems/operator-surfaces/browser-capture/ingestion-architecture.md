# Browser Capture Ingestion Architecture

## Purpose

This document defines how browser-captured material enters governed system flows.

It exists to answer:

```text
How does browser capture move from operator-triggered intake into bounded system records without bypassing ownership, provenance, or review discipline?
```

This is an active cross-system operator-surface document with VEDA-heavy intake relevance.
It is not a mobile/browser compatibility note, not a draft-generation workflow, and not an execution spec.

---

## Core Framing

Browser capture is the front edge of intake.
It is where the operator intentionally says:

```text
This external material matters enough to capture.
```

From there, the architecture should remain boring and legible:

```text
operator-triggered capture -> browser payload -> governed API boundary -> project-scoped intake record -> later triage / analysis
```

The capture surface should stop at governed intake.
It must not silently spill into planning ownership, draft ownership, or external action.

---

## Ownership

### Browser capture surface

The browser capture surface is an operator interface.
It helps collect source material and context.
It does not own the captured record after submission.

### VEDA ownership after intake

When the captured material is entering observatory intake, VEDA owns:
- project-scoped intake records
- provenance-preserving source capture
- intake status
- event logging for intake actions
- later observatory analysis over the captured material

### Not owned by browser capture

The browser capture surface does not own:
- planning state
- blueprint state
- drafting state
- publishing state
- reply execution
- external account actions

That is the important wall. No trap doors.

---

## Intake Architecture Shape

The intended path is:

```text
1. operator selects material or chooses a capture target
2. browser surface assembles a bounded payload
3. payload is sent through a governed API route
4. API validates project scope, payload shape, and required intent/context
5. VEDA creates a project-scoped intake record
6. relevant intake event is logged atomically where required
7. later triage, summarization, or analysis happens downstream
```

This keeps the capture surface thin and the system boundary explicit.

---

## Capture Payload Rules

A browser-capture payload should preserve enough evidence and intent to make later use defensible.

Typical required fields should include:
- project scope or an explicit operator flow that resolves project scope
- source type
- URL when available
- captured text or visible excerpt when relevant
- operator intent or operator note

Useful optional fields may include:
- page title
- platform
- author/handle when visible and relevant
- parent/ancestor URL when context matters
- lightweight capture metadata

The payload should prefer explicit fields over giant mystery blobs.
Raw payload retention may be useful, but hot fields should remain queryable and understandable.

---

## Validation Boundary

The browser capture surface should not be trusted as the final validator.
The API boundary is the enforcement point.

That means the ingestion API should validate:
- required fields
- project scope
- allowed source and platform values
- non-empty operator intent when required
- payload shape
- deduplication rules where applicable

If the browser side performs early validation, that is convenience.
If the API does not enforce it, that is theater.

---

## Project Scope Rule

Browser capture must end up project-scoped when it enters durable system state.

That means:
- no orphan durable records
- no silent default to the wrong project
- no mixed-project intake
- no “capture now, figure out ownership later” sludge

If the operator has not resolved project context yet, the flow should make that explicit before durable intake is accepted.

---

## Provenance Rule

The ingestion architecture must preserve enough provenance to answer later:
- what was captured
- where it came from
- when it was captured
- why it was captured
- who captured it

This is why browser capture belongs near intake discipline and source capture, not near execution tooling.
The main value is trustworthy intake, not browser-side magic tricks.

---

## Event Logging Expectations

Meaningful capture actions should align with event logging discipline.

Typical expectations include:
- project-scoped capture events
- actor attribution
- event/entity linkage to the intake record
- atomic behavior where state write and event write belong together

Capture without an auditable trail is how observability systems quietly rot.

---

## Deduplication and Replay

The ingestion architecture should make duplicate behavior explicit.

Possible cases include:
- the exact same source is captured again intentionally
- the operator retries due to a flaky network
- the same URL appears with different operator intent or capture context

The important rule is not that every duplicate must be rejected.
The important rule is that duplicate behavior must be governed, explainable, and consistent.

No spooky “sometimes we kept it, sometimes we merged it, sometimes the moon was full” behavior.

---

## Relationship to Source Capture and Inbox

Browser capture should feed the broader source-capture and inbox model.
That means the architecture should harmonize with:
- project-scoped source records
- intake statuses such as `ingested`, `triaged`, `used`, and `archived`
- explicit later review and triage
- provenance-first observatory intake

Browser capture is just one intake path.
It should not invent a parallel universe of capture state.

---

## LLM Boundary

LLMs may assist after capture with things like:
- summarization
- light classification proposals
- structured hint extraction
- later analysis

LLMs should not:
- silently create intake records on their own
- invent operator intent
- convert captured material directly into execution actions
- bypass review discipline

The ingest architecture should assume:

```text
capture first, assist later
```

not:

```text
assistant improvises reality and the system cleans up afterward
```

---

## Explicitly Rejected Patterns

The following patterns are out of scope or explicitly bad:
- browser capture creating drafts as a default ingest side effect
- browser capture owning reply-generation workflow
- capture surfaces storing execution artifacts as canonical truth
- silent background ingestion
- external-platform automation tied directly to capture
- treating a browser extension as the owner of intake policy

Those are legacy-drift traps, not architecture.

---

## Current Reconstruction Guidance

For the current repo phase:
- browser capture should remain a thin operator surface
- durable logic should live in governed APIs and bounded system behavior
- VEDA-owned intake should remain provenance-first and project-scoped
- execution-oriented follow-on work should be classified separately rather than smuggled into capture architecture
- legacy browser/extension docs may be mined for grounded ideas, but current successor docs define the active framing

---

## Related Docs

This document should be read with:
- `docs/systems/operator-surfaces/overview.md`
- `docs/systems/operator-surfaces/browser-capture/scope-and-behavior.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/ingest-discipline.md`
- `docs/architecture/architecture/api/api-contract-principles.md`
- `docs/architecture/architecture/api/validation-and-error-taxonomy.md`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/archive/post-wave2-cleanup/08-EXTENSION-INGESTION-ARCHITECTURE.md`

The legacy extension ingestion doc remains useful as grounded historical input for capture payload ideas and guardrails.
It is not active authority by itself.

