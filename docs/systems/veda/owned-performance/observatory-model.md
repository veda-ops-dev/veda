# GA4 Owned-Performance Observatory Model

## Purpose

This document defines the human-level observatory model for a future GA4 owned-performance lane inside current VEDA.

It exists to answer:

```text
What are the entities, observations, time semantics, and interpretation boundaries for GA4-based owned-performance observability?
```

This is a doctrine and model doc.
It is not a schema file.
It is not a route contract.
It does not authorize implementation by itself.

If this document conflicts with the live schema or higher-order authority docs, the authoritative sources win.

---

## Ownership

This doc belongs to VEDA because it defines a possible observatory lane.

VEDA owns this lane only where it remains:
- observational
- project-scoped
- time-aware
- interpretation-safe

Project V and V Forge do not inherit ownership here.

---

## What This Doc Is and Is Not

### What it is

A doctrine-level statement of:
- the core pattern applied to GA4 owned-performance
- the planning-posture entity and observation model
- the identity and joinability posture direction
- the time semantics that must be explicit in any implementation
- the truth surface split
- the interpretation boundary
- out-of-scope constraints

### What it is not

- Approved schema tables
- Final normalization rules
- Route contracts
- Metric allowlists
- Dashboard product scope
- Finalized attribution model selection

Those must wait for the research brief to be executed against a real GA4 property.

---

## Core Pattern

The GA4 owned-performance lane must follow the current VEDA pattern:

```text
entity + observation + time + interpretation
```

Applied here:

- **entity** = an owned page or route within a VEDA project, observed through a declared GA4 property
- **observation** = GA4-reported performance measurements for that page for a reporting date
- **time** = the reporting date the measurements describe, paired with the time VEDA captured the data
- **interpretation** = read-oriented diagnostics derived from captured observations; not materialized at v1

The lane fails if any one of those is replaced by planning or execution ownership.

---

## Primary Observatory Object

The primary observatory object for this lane is:

```text
A project-scoped owned-page performance observation, captured from a declared GA4 property,
for a specific reporting date, recording what that page's traffic and engagement signals
looked like during that day according to GA4.
```

This is not a metric dashboard row.
It is an observatory record: who arrived, from where (broadly), how they engaged, when.

The observation is day-level (the finest grain the GA4 Reporting API provides without real-time scope).

---

## Entity Model

A future GA4 lane should distinguish clearly between:

### 1. Property configuration entity

The governed declaration of which GA4 property a VEDA project observes.

This is not an observation row.
It records:
- project identity
- GA4 property ID
- operator-declared scope (e.g., which hostname(s) belong to this project in this property)
- optional operator notes

This is the configuration anchor that makes observations interpretable.

### 2. Page performance observation entity

An immutable performance record for a specific owned page, for a specific reporting date, drawn from a specific declared property.

Conceptual fields that belong here:
- project identity
- property identity
- page identity (see joinability posture below)
- reporting date (the GA4 date dimension value for the day)
- captured-at time (when VEDA fetched this observation)
- traffic volume signal
- engagement signal
- candidate breakdown signals (source/medium, device — see metric posture below)
- raw payload evidence
- promoted hot fields

The exact table structure, field names, and which breakdown families become main-row fields vs separate breakdown rows are not decided here.
That is a schema judgment, deferred to after the research brief is executed.

---

## Identity and Joinability Posture

Joinability matters more than metric volume.

The single largest risk for this lane is collecting data that cannot be joined cleanly to known owned surfaces.

### Likely join-key direction

At planning posture, the join key for page identity will likely involve:
- **hostName**: the hostname of the page as reported by GA4
- **normalized pagePath**: the path portion of the URL after normalization

GA4's `pagePath` dimension returns the URL path without hostname.
`hostName` is a separate GA4 dimension.
Both are needed to produce a compound page identity that is stable and scoped correctly to a single owned property.

### Normalization direction

Normalization at the ingest boundary will likely need to address:
- trailing slash variation (`/about` vs `/about/`)
- case normalization
- known noise query parameters that GA4 sometimes includes in `pagePath`
- locale prefix handling if applicable

**These are planning-posture notes, not ratified normalization rules.**

The final normalization logic must be confirmed against real property data showing what `pagePath` actually looks like for the specific sites being observed.

Do not pre-approve a normalization scheme without inspecting real payloads.

### Why `pagePath` alone is not enough

`pagePath` does not include hostname.
In a property that receives data from multiple hostnames (e.g., production and staging, or multiple branded domains), `pagePath` alone will silently merge pages from different environments.

The correct join key requires explicit hostname scoping.
Environment separation must be confirmed before the first observation floor is built.

### GA4 identity vs Search Console identity

GA4's `pagePath` is a path-only value.
Google Search Console's `page` dimension is a full URL including scheme and hostname.

These are not the same identity space.
Any future cross-lane comparison between GA4 and Search Console observations must apply explicit identity reconciliation at that comparison layer.
They must not be assumed to join on the same key.

---

## Observation Model

The core observation unit should be a day-level owned-page performance record.

A useful GA4 owned-page observation should preserve:
- project scope
- property scope
- page identity (as described in joinability posture)
- reporting date (the GA4 `date` dimension value for that day)
- captured-at time (server-assigned, distinct from reporting date)
- traffic volume signal (sessions or equivalent)
- engagement signal (engaged sessions or equivalent)
- raw payload evidence
- promoted hot fields for diagnostics

### Candidate breakdown families

The following are candidate breakdown families for later enrichment or breakdown rows:
- **source / medium** — what brought this session; attribution model must be declared before including
- **device category** — desktop / mobile / tablet
- **geography** — country or region

Whether these become main-row fields in the primary observation table, separate breakdown entities, or deferred to v2 is a schema judgment.

That judgment must not precede the research brief.

---

## Time Semantics

This lane must keep two distinct time values explicit.

### Reporting date

The GA4 `date` dimension value.

This is the calendar day the user activity occurred, expressed as YYYYMMDD.

This is the primary time anchor for comparing observations across days or periods.

GA4 data has a typical 24–48 hour latency from event occurrence to API availability.
This latency is inherent to the source and must be documented, not hidden.

### Captured-at time

When VEDA called the GA4 Data API to fetch the observation.

This is server-assigned at ingest time.

This is useful for understanding when VEDA's own record was created, but it is not the same as when the user activity occurred.

### Why both must be stored

Storing only `capturedAt` without `reportingDate` makes time-series analysis impossible.
Storing only `reportingDate` without `capturedAt` makes ingest auditability opaque.

Both must be explicit and separated in any implementation.

### Historical rule

Observation rows should be append-friendly.
Re-fetching a date range does not silently overwrite prior stored observations unless an explicit idempotency key match is found and the update is explicitly governed.

---

## Truth Surface Split

### Primary truth
GA4 Data API reporting data.

### Secondary enrichment
No enrichment is planned at v1.

The v1 floor should be built on the GA4 Reporting API alone.

YouTube API enrichment and other secondary sources are not relevant to this lane.

### Validation support
Manual/operator spot-checks where needed to confirm that reported numbers match what the GA4 property shows in the standard GA4 interface.

This supports readiness confirmation and can reveal instrumentation problems before ingest is built.

---

## Interpretation Boundary

Derived interpretation may include things like:
- which owned pages consistently receive meaningful traffic
- how engagement patterns change over time for specific pages
- how device or source mix differs across owned surfaces
- how GA4-side signals compare to search-observatory or YouTube-observatory signals for the same owned pages

Derived interpretation may not become:
- content planning authority
- SEO optimization prescriptions
- campaign management
- publishing workflow guidance
- execution ownership of any kind

Interpretation stays read-oriented and compute-on-read.
Planning and execution remain elsewhere.

---

## Relationship to Future Search Console Comparison

GA4 and Search Console describe different things.

GA4 describes what happened **after** the visit arrived.
Search Console describes what happened **before** the visit arrived (search visibility, impressions, CTR, position).

A future cross-lane comparison between GA4 observations and Search Console observations may be useful for questions like:
- does page-level search visibility correspond to page-level traffic in practice?
- which pages receive impressions but convert poorly from search to visit?

That comparison is a **derived read surface** built above both lanes.

It is not a reason to merge the two lanes at ingest, at schema level, or in the observatory model.

The Search Console lane is separately scoped and deferred.
It must not be designed into the GA4 model as a dependency.

---

## Out of Scope

This model does not authorize:
- GA4 conversion or goal metrics
- audience or segment analysis
- real-time or sub-day reporting
- attribution model comparison or multi-touch analysis
- ad platform data of any kind
- cross-property aggregation
- user-level metrics
- Search Console data in the GA4 observation layer
- dashboard product features
- CRO planning
- experimentation workflow
- campaign management

Those may be discussed elsewhere.
They are not the observatory model here.

---

## Maintenance Note

If future work tries to force this lane into:
- a BI system
- a campaign analytics layer
- a multi-source merged truth surface
- a dashboard product
- an execution authority surface

stop and reassess.

The GA4 owned-performance lane is valid only while it remains a narrow, time-aware, page-level post-click observatory anchored to a declared GA4 property.
