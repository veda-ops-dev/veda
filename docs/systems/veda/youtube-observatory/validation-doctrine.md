# YouTube Observatory Validation Doctrine

## Purpose

This document defines how a future YouTube observatory lane would be validated under current VEDA rules.

It exists to answer:

```text
What must be true for a YouTube observatory surface to count as real, bounded, and trustworthy inside VEDA?
```

This is a doctrine document.
It does not define schema or routes by itself.
It defines the validation posture that any future implementation must satisfy.

If this document conflicts with the active hammer doctrine or current higher-order truth, the authoritative sources win.

---

## Authority

Read this doc under:
- `docs/architecture/testing/hammer-doctrine.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/systems/veda/youtube-observatory/overview.md`
- `docs/systems/veda/youtube-observatory/observatory-model.md`
- `docs/systems/veda/youtube-observatory/ingest-discipline.md`

The current hammer doctrine remains the primary testing authority.
This doc narrows that doctrine to the YouTube lane.

---

## Core Validation Principles

A YouTube observatory lane is only valid if it proves all of the following:
- project isolation
- deterministic behavior where claimed
- append-friendly observation history
- correct identity normalization behavior
- explicit result-type handling
- read/write boundary discipline
- no ownership drift into planning or execution

Validation is not optional decoration.
It is the proof that the lane still belongs in VEDA.

---

## What Must Be Tested

### 1. Project isolation

A YouTube observation created for one project must not leak into another.

Validation should prove:
- project-scoped writes stay inside the target project
- cross-project reads do not disclose existence
- identity reuse across projects does not collapse isolation

### 2. Deterministic read behavior

List and detail surfaces must have explicit ordering and stable retrieval behavior.

Validation should prove:
- stable ordering rules for snapshots
- tie-break behavior is explicit
- repeated reads do not produce ambiguous order churn

### 3. Observation history preservation

Observation rows should be historical and append-friendly.

Validation should prove:
- new observations do not silently overwrite earlier history
- replay/idempotency rules behave exactly as declared
- event behavior matches true state change, not request attempts

### 4. Identity normalization

Normalization at the ingest boundary must be validated explicitly.

Validation should prove:
- channel/video/playlist identity is extracted consistently when available
- malformed or partial identity is handled predictably
- normalization does not create cross-project contamination

### 5. Mixed result-type handling

If the truth surface can emit multiple result types, the lane must model that honestly.

Validation should prove:
- result type is preserved where extractable
- mixed result sets are not forced into a fake single-type shape
- read surfaces return consistent interpretation over mixed observations

### 6. Raw evidence and promoted fields consistency

If raw payload evidence is stored, promoted fields derived from it must remain consistent.

Validation should prove:
- promoted hot fields match the evidence they claim to represent
- malformed or unusable evidence fails cleanly at the boundary
- read surfaces do not depend on fragile hidden parsing assumptions

### 7. Read/write boundary discipline

Read surfaces must remain read-only.
Mutation surfaces must remain explicit.

Validation should prove:
- read routes do not mutate state
- mutation routes require explicit project context
- no hidden automation or background mutation behavior exists

### 8. Ownership discipline

The lane must remain observability-only.

Validation should prove the implementation does not drift into:
- planning state
- publishing state
- production workflow
- execution orchestration

This is a real test concern, not just a philosophical note.

---

## Hammer Expectations

If the YouTube lane is implemented, it should receive hammer coverage consistent with the current doctrine.

Likely hammer categories include:
- target-definition contract checks
- snapshot ingest contract checks
- malformed input handling
- idempotent replay behavior
- cross-project non-disclosure
- deterministic ordering
- normalization correctness
- mixed-result-type truth handling
- event logging where mutation events are required

The hammer should protect invariants, not perform UI theater.

---

## PASS / FAIL / SKIP Guidance

### PASS

A PASS means:
- the invariant actually held
- the route/library behavior matched declared contract
- the result is strong enough to rely on

### FAIL

A FAIL means:
- the implementation violated the declared invariant
- the route/library contract is broken or ambiguous
- cross-project isolation, determinism, or truth-surface consistency failed

### SKIP

A SKIP is acceptable only when:
- an external provider dependency is genuinely unavailable
- a credential-dependent path is intentionally not provisioned
- a richer-data condition is explicitly required and honestly absent

A SKIP is not acceptable when the test could have made a real local assertion.

---

## Determinism Note

YouTube search/discovery may be less cleanly deterministic than a narrow web SERP provider lane.

That does not remove the need for deterministic VEDA behavior.
It means the lane must define explicitly:
- what baseline assumptions are used
- what scope is fixed for comparison
- what non-deterministic provider variance is tolerated
- what local ordering and replay invariants must still remain exact

For v1, the expected posture is:
- scope is fixed by the target-definition row and its declared query/context
- provider variance between captures is tolerated as observed reality, not treated as a local bug
- local ordering for recorded snapshots must still remain explicit and deterministic
- replay and idempotency behavior must remain exact even if the external truth surface is noisy

The system must not hide provider variance behind fuzzy architecture language.

---

## Minimal Validation Posture for v1

A minimal credible v1 should prove at least:
- project-scoped target creation or equivalent target-definition behavior
- project-scoped search/discovery snapshot ingest
- identity extraction at the boundary
- append-friendly observation history
- deterministic read ordering
- no cross-project disclosure
- no workflow/ownership drift

If those are not proven, the lane is not ready.

---

## Out of Scope

This doctrine does not authorize tests for:
- publishing behavior
- content production workflow
- editor-side convenience UX
- strategy recommendation quality
- execution automation

Those are not VEDA test concerns here.

---

## Maintenance Note

If a future implementation tries to avoid hammer coverage by arguing that YouTube is “too messy” to test cleanly, that is a warning sign.

Messy truth surfaces require tighter invariants, not looser ones.

The validation goal is not perfection theater.
It is boring, bounded trust.
