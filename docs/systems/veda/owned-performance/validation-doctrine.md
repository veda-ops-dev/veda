# GA4 Owned-Performance Validation Doctrine

## Purpose

This document defines how a future GA4 owned-performance lane would be validated under current VEDA rules.

It exists to answer:

```text
What must be true for a GA4 owned-performance surface to count as real, bounded, and trustworthy inside VEDA?
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
- `docs/systems/veda/owned-performance/overview.md`
- `docs/systems/veda/owned-performance/observatory-model.md`
- `docs/systems/veda/owned-performance/ingest-discipline.md`

The current hammer doctrine remains the primary testing authority.
This doc narrows that doctrine to the GA4 owned-performance lane.

---

## Core Validation Principles

A GA4 owned-performance lane is only valid if it proves all of the following:
- project isolation
- deterministic behavior where claimed
- append-friendly observation history
- correct identity/joinability handling at the ingest boundary
- explicit time semantics (reporting date vs captured-at are separate)
- raw evidence present, promoted fields consistent
- read/write boundary discipline
- no ownership drift into planning, campaigns, or CRO

Validation is not optional decoration.
It is the proof that the lane still belongs in VEDA.

---

## What Must Be Tested

### 1. Project isolation

A GA4 performance observation created for one project must not leak into another.

Validation should prove:
- project-scoped writes stay inside the target project
- cross-project reads do not disclose existence
- property configuration rows and observation rows cannot be accessed across project boundaries

### 2. Deterministic read behavior

List and detail surfaces must have explicit ordering and stable retrieval behavior.

Validation should prove:
- stable ordering rules for observations (explicit tie-breakers on `id` fields where needed)
- repeated reads do not produce ambiguous order churn
- deterministic pagination behavior where applicable

### 3. Observation history preservation

Observation rows should be historical and append-friendly.

Validation should prove:
- new observations do not silently overwrite earlier history
- replay/idempotency rules behave exactly as declared
- event behavior matches true state change, not request attempts
- idempotent replay does not emit a spurious fresh mutation event

### 4. Identity and joinability consistency

Normalization at the ingest boundary must be validated explicitly.

Validation should prove:
- page identity normalization is applied consistently (trailing slash, case, noise params)
- the same logical page arriving with minor URL variation produces the same normalized identity
- malformed or missing page identity is handled predictably and rejected at the boundary
- normalization does not create cross-project contamination

### 5. Time semantics correctness

Validation should prove:
- `reportingDate` (the GA4 date dimension value) is stored separately from `capturedAt` (the VEDA fetch time)
- malformed or absent `reportingDate` causes explicit rejection, not silent substitution of `capturedAt`
- stored time values are in the declared format

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
- campaign or conversion management
- CRO workflow
- dashboard-product behavior that executes actions based on observed signals

This is a real test concern, not just a philosophical note.

---

## Fixture-Based vs Live-Source Validation Posture

**GA4 is an external dependency. Hammer tests must be fixture-based.**

Live GA4 API calls are not acceptable as the primary test path.

They are slow, require credentials, depend on real property data, and produce results that are not deterministic across test runs.

### Correct posture

The hammer must operate on locally seeded fixture data that represents realistic GA4 observations.

This means:
- seed observation rows directly into the test database using fixture scripts or ingest-path helpers
- test the route and library behavior against that seeded state
- assert on exact promoted field values, ordering, isolation, and time semantics

Fixture design must be carefully engineered to test the conditions that matter.
This is the same discipline as the DataForSEO SERP hammer fixtures.

### When live-source SKIPs are acceptable

A SKIP for live GA4 API behavior is acceptable where:
- the test genuinely requires a real GA4 property credential that is not provisioned in the test environment
- the test covers provider-side behavior that cannot be simulated locally

A SKIP is not acceptable when:
- the test could assert on already-seeded local fixture data
- the SKIP is used to avoid writing a real invariant check

---

## Hammer Expectations

If the GA4 owned-performance lane is implemented, it should receive hammer coverage consistent with current doctrine.

Likely hammer categories include:
- property configuration contract checks
- observation ingest contract checks
- malformed input handling (bad date, bad path, missing fields)
- idempotent replay behavior
- cross-project non-disclosure
- deterministic read ordering
- identity normalization correctness
- time semantics correctness (reportingDate vs capturedAt)
- raw evidence presence
- promoted field consistency
- event logging where mutation events are required
- read/write boundary enforcement

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
- cross-project isolation, determinism, or time-semantics correctness failed

### SKIP

A SKIP is acceptable only when:
- a live GA4 API credential is genuinely not provisioned
- a richer-data condition is explicitly required and honestly absent

A SKIP is not acceptable when:
- the test could have made a real local fixture-based assertion
- the SKIP is hiding a missing invariant check
- the SKIP is covering for a test that was not written yet

---

## Minimum Credible v1 Validation Floor

A minimum credible v1 implementation should prove at least:
- project-scoped property configuration creation or equivalent governance behavior
- project-scoped page performance observation ingest
- page identity normalization at the boundary
- append-friendly observation history (no silent overwrite)
- deterministic read ordering
- no cross-project disclosure
- `reportingDate` and `capturedAt` are separate and explicit
- idempotent replay does not create duplicate rows or spurious events
- no ownership drift into planning or execution

If those are not proven, the lane is not ready.

---

## Out of Scope

This doctrine does not authorize tests for:
- live GA4 API rate limits or quota behavior
- GA4 property setup correctness
- tag-manager configuration
- cross-lane GA4 + Search Console comparison behavior
- dashboard UI behavior
- campaign or conversion workflow
- CRO execution
- experimentation tooling

Those are not VEDA test concerns here.

---

## Maintenance Note

If a future implementation tries to avoid hammer coverage by arguing that GA4 data is "too variable" or "too dependent on real properties" to test cleanly, that is a warning sign.

Variable external sources require tighter local invariants, not looser ones.

The validation goal is not perfection theater.
It is boring, bounded trust in what the lane actually claims to do.
