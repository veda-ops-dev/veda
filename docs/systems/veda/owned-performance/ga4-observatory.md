# GA4 Observatory

## Purpose

This document defines how Google Analytics 4 should be understood inside current VEDA.

It exists to answer:

```text
What is the bounded observability role of GA4 inside VEDA, and what questions must it answer without turning VEDA into analytics swamp?
```

This is a successor doctrine and research-alignment doc.
It is not a schema file.
It is not a route contract.
It is not a dashboard product plan.

If this document conflicts with current higher-order truth, the higher-order truth wins and this document must be updated.

---

## Authority

Read this doc under:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/architecture/architecture/veda/search-intelligence-layer.md`
- `docs/architecture/testing/hammer-doctrine.md`
- `docs/systems/veda/owned-performance/overview.md`

Official external references for this lane should prefer:
- Google Analytics Data API official documentation
- official Next.js documentation only where instrumentation context matters

The model posture for this lane is defined in:
- `docs/systems/veda/owned-performance/observatory-model.md`

The research sequence that must run before schema/route judgment is defined in:
- `docs/systems/veda/owned-performance/ga4-research-brief.md`

---

## What GA4 Is Inside VEDA

Inside current VEDA, GA4 is a **post-click owned-performance observatory surface**.

That means GA4 may be used to observe things like:
- how owned pages or routes performed after arrival
- traffic source and medium mix
- engagement behavior at page or route level
- device and geography patterns where the source supports them
- time-aware performance changes across owned surfaces

This fits the VEDA pattern:

```text
entity + observation + time + interpretation
```

Applied here:
- **entity** = owned page, route, property, or other bounded owned-performance subject
- **observation** = GA4-reported performance measurements for that subject
- **time** = date or other declared reporting window
- **interpretation** = later read-oriented comparison against search, YouTube, or citation observatory lanes

The formal entity model, time semantics, and observation floor posture are defined in `observatory-model.md`.

---

## What GA4 Is Not Inside VEDA

GA4 inside VEDA is not:
- a marketing command center
- a campaign-management surface
- an ad attribution engine
- a CRO authority system
- an experimentation workflow surface
- a product analytics platform
- a replacement for Search Console
- a planning or execution system

If a proposed GA4 feature starts deciding what should be built next, what should be optimized next, how traffic should be acquired, or what campaign actions should occur, it has crossed out of VEDA.

---

## Why GA4 May Be Worth Collecting

SERP, YouTube, and later citation observatory lanes describe external visibility.

GA4 describes what happened after the visit reached an owned property.

That makes GA4 useful for bounded questions like:
- which owned pages actually received visits after visibility appeared elsewhere
- whether certain page or route types consistently show stronger engagement than others
- whether device or geography reality differs from assumptions formed from search-only observation
- whether traffic source mix and engagement patterns change over time for owned surfaces

This is still observability.
It is not strategy authority.

---

## What Makes GA4 Useful But Dangerous

GA4 is useful because it can provide post-click measurements that search observability cannot.

GA4 is dangerous because it can also tempt the system toward:
- vanity metrics
- campaign obsession
- attribution theater
- dashboard sprawl
- BI-system creep

The lane stays clean only if VEDA asks the narrower question:

```text
What observed owned-performance signals materially help interpret how owned surfaces perform after arrival?
```

Not:

```text
How can VEDA become the whole analytics department?
```

---

## Preferred First Questions

A bounded first GA4 slice should focus on questions like:
- which owned pages or routes actually received meaningful traffic
- what source / medium mix brought visits to those surfaces
- what engagement signals are worth preserving at page or route level
- what device and geography patterns are visible in a stable enough way to matter
- what time-aware performance changes can later be compared against other VEDA lanes

A bounded first GA4 slice should not try to answer everything GA4 can theoretically report.

---

## Joinability Matters More Than Metric Volume

The primary risk for this lane is not "missing a metric."
The primary risk is collecting data that cannot be joined cleanly to owned surfaces.

That means the lane must pay close attention to:
- page path / route identity
- hostname / environment separation
- URL normalization
- soft-navigation behavior for App Router sites
- route changes over time

A smaller, joinable observatory is more useful than a larger metric pile that cannot be trusted.

The join-key posture and identity discipline for this lane are defined in `observatory-model.md`.

---

## Attribution Model Posture

GA4 exposes multiple attribution scopes for source and medium signals.

These include:
- session-scoped source/medium (what brought this session)
- first-user source/medium (how the user originally acquired)
- last-user source/medium (most recent channel before the session)

These produce different numbers for the same property over the same date range.

The owned-performance lane must declare which attribution scope it commits to before any source/medium fields are included in schema design.

**This is a planning-stage decision. It is not pre-approved here.**

The research brief and observatory model define the right moment for this decision.
The short expectation is that session-scoped source/medium is the simpler default, but this must be confirmed against real property data before being locked in.

---

## Minimum Useful Metric Posture

This doc does not lock schema, but it does establish a posture.

The preferred first slice should be small and boring.

The likely minimum observation floor at planning posture includes:
- traffic volume (sessions or equivalent)
- engagement (engaged sessions or equivalent)
- candidate breakdown families: source/medium, device, geography

Whether source/medium, device, or geography become main-row fields in the primary observation table, separate breakdown rows, or deferred enrichment is a later schema/model judgment.

That judgment must not happen before the research brief is executed against a real GA4 property.

Metric families that should be treated skeptically include:
- marketing vanity summaries
- attribution narratives that exceed what the source can actually prove
- dashboards that reward metric collection more than observatory clarity

---

## Relationship to Search Console

GA4 and Search Console must remain distinct.

### GA4
Describes post-click owned-performance observation.

### Search Console
Describes Google Search visibility and search-performance reality.

These may later be compared.
They must not be collapsed into one fake truth surface.

Search Console is a separately scoped deferred lane.
No GSC docs or tables belong in the GA4 lane.

---

## Access and Instrumentation Reality

This lane depends on two different truths:

### 1. Site-side measurement reality
If site instrumentation is wrong, the observatory lies.

### 2. API-side reporting reality
If GA4 Data API metadata, compatibility, or access constraints are misunderstood, the observatory lies differently.

That means instrumentation and access discipline matter before schema ambition.

The readiness discipline for both is defined in:
- `docs/systems/veda/owned-performance/instrumentation-and-access.md`

The structured research sequence that must run before schema/route judgment is defined in:
- `docs/systems/veda/owned-performance/ga4-research-brief.md`

---

## Current Implementation Posture

The current posture must stay conservative.

Schema and route work cannot begin until the research brief has been executed against a real GA4 property.

Until then:

### 1. Confirm the research brief first
Run the research sequence defined in `ga4-research-brief.md` before any implementation judgment.

### 2. Keep the first surface small
A narrow owned-performance floor is better than broad analytics sprawl.

### 3. Prefer explicit observations over dashboard imitation
VEDA should preserve queryable observatory truth, not build a metric museum.

### 4. Keep GA4 separate from Search Console
Comparison can come later. Collapse must not.

### 5. Use official source documentation
This lane should be grounded in official GA4 Data API behavior, not plugin-era folklore or analytics-blog noise.

---

## Out of Scope

This document does not define:
- schema tables
- route contracts
- metric allowlists
- dashboard UX
- ad-platform data collection
- campaign optimization workflows
- experimentation workflows
- business-intelligence product scope

Those concerns require separate explicit judgment if they ever become real work.

---

## Maintenance Note

If this lane grows, it must grow by explicit bounded increments.

Do not let:
- campaign ownership
- CRO ownership
- analytics-product ambition
- attribution mythology
- schema inflation without invariants

crawl back into VEDA through the GA4 lane.

This surface should remain boring, observational, and testable.
