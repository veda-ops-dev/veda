# GA4 Owned-Performance Ingest Discipline

## Purpose

This document defines the ingest rules for a future GA4 owned-performance lane inside current VEDA.

It explains how GA4 performance observations may enter VEDA without breaking current bounded ownership, project isolation, determinism, or post-Wave-2D observability-only truth.

This document defines ingest behavior.
It does not define planning behavior, dashboard products, or execution automation.

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

This document governs future GA4 owned-performance ingest only where the ingest path creates:
- project-scoped owned-page performance observations
- append-friendly observation records
- evented observatory mutations where required

It does not govern:
- dashboard-side aggregations
- campaign or ad attribution ingestion
- Search Console data ingestion
- experimentation or CRO data
- content publishing or editorial workflows
- any execution workflow of any kind

---

## Core Ingest Rules

### 1. Operator-triggered by default

The safe default for this lane is operator-triggered ingest.

That means:
- no hidden background GA4 polling as canonical behavior
- no silent recurring fetch assumptions
- no autonomous "pull everything always" posture sneaking in through convenience design

If automation is ever added later, it must still preserve the same invariants and auditability.

### 2. Governance rows and observation rows must stay distinct

The ingest boundary must preserve the distinction between:
- property configuration state (which GA4 property a VEDA project observes)
- page performance observation state (what was observed, when, for which page)

A property configuration row says:
- this project observes this GA4 property at this declared scope

A performance observation row says:
- this is what we observed for this page on this reporting date

Those meanings must not blur.

### 3. Observations are append-friendly

Page performance observations should create new historical records rather than mutate prior observations silently.

Safe replay handling may be idempotent where the uniqueness boundary is explicit.
But historical state must remain durable and boring.

---

## Project Scoping and Non-Disclosure

All GA4 ingest must obey current VEDA isolation rules.

### Project scoping

Every write must resolve project context explicitly before mutation.

A write must never:
- infer project scope from unsafe fallback
- write across projects
- create detached observatory rows

`resolveProjectIdStrict()` or equivalent applies.
Fallback to a default project is not acceptable for mutation paths.

### Non-disclosure

Cross-project references must not leak existence.

If a row belongs to another project, the system must behave as if it does not exist.

This is structural, not cosmetic.

---

## Identity and Joinability at the Ingest Boundary

Normalization should happen at the ingest boundary before persistence where page identity is extractable from the GA4 payload.

### Likely normalization direction

At planning posture, the page identity key will likely require:
- extracting `hostName` and `pagePath` from the GA4 report row
- normalizing `pagePath` to remove trailing slash variation, case variation, and known noise query parameters

**These are planning-posture notes, not ratified normalization rules.**

The final normalization logic must be confirmed against real property data showing what `pagePath` values actually look like.
Do not implement normalization rules before the research brief has been executed and the actual `pagePath` shape is known.

### Why this matters

Without boundary normalization:
- the same owned page appears as multiple identity fragments across observation rows
- time-series comparisons degrade
- cross-lane joins become unreliable
- hammer validation becomes blob-heavy and fragile

### Rule

Normalize identity to support observability.
Do not normalize so aggressively that legitimate route distinctions are collapsed.

---

## Raw Evidence and Promoted Fields

GA4 API response payloads may be stored as evidence.

But common hot fields must be promoted explicitly where they are required for:
- page identity (after normalization)
- time-series comparison (reporting date, captured-at)
- traffic volume analysis
- engagement comparison
- deterministic diagnostics
- hammer assertions

This follows the existing VEDA rule:
- raw evidence is allowed
- important query fields should not live only inside opaque blobs

Which fields are promoted is a schema judgment deferred to after the research brief.

---

## Time Discipline

Ingest must preserve clear time semantics.

### Reporting date

The GA4 `date` dimension value from the report row.

This is the calendar day the user activity occurred (YYYYMMDD).

This is the primary time anchor for the observation.

### Captured-at time

When VEDA fetched this observation from the GA4 Data API.

Server-assigned at ingest time.

This is not the same as reporting date and must not be used interchangeably with it.

### Fallback rule

If reporting date is absent or malformed in the payload, the ingest boundary should reject the row rather than silently substituting `capturedAt` as the reporting date.
The two values mean different things. Silent substitution creates false history.

---

## Validation at the Ingest Boundary

The ingest boundary must validate inputs explicitly and deterministically.

Validation expectations include:
- malformed or missing property ID rejection
- malformed or missing page identity rejection
- malformed reporting date rejection
- project context validation
- explicit handling of missing or partial dimension values
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

## Idempotency

The ingest layer should support idempotent replay.

The likely idempotency key will involve a combination of:
- project identity
- property identity
- normalized page identity
- reporting date

**The exact uniqueness key is not pre-approved here.**
It must be defined as part of the schema design that follows the research brief.

The rule is: same input for the same page and reporting date should not create duplicate observation rows.

---

## Out of Scope

This document does not define:
- GA4 conversion or goal ingestion
- campaign or ad attribution ingestion
- Search Console data ingestion
- audience or segment-level ingestion
- cross-property aggregation
- user-level data ingestion
- dashboard or BI integration
- experimentation or CRO data
- content publishing workflows
- any execution automation

---

## Boundary Check

The following concerns are intentionally excluded because they belong elsewhere:

### Belongs to Project V
- deciding what pages should be built based on performance observations
- sequencing publishing actions based on GA4 findings

### Belongs to V Forge
- producing content in response to performance signals
- executing publishing workflows

### Not VEDA concerns
- GA4 goal setup or conversion configuration
- tag-manager architecture
- account-level permission management

---

## Maintenance Note

If future work tries to make GA4 ingest do any of the following:
- manage planning intent as canonical state
- act as a campaign execution queue
- poll GA4 broadly without governed target boundaries
- ingest cross-property or cross-project data without explicit isolation
- merge GA4 and Search Console observations into a single ingest path

that is an architectural warning sign.

The ingest boundary should remain narrow, operator-triggered, deterministic, and observatory-only.
