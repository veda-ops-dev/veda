# Owned Performance Overview

## Purpose

This document defines what owned-performance observation means inside current VEDA.

It exists to answer:

```text
What part of site-owned performance belongs inside VEDA, and what does it explicitly not mean?
```

This is a successor doc written against current clean-repo truth.
It is not a plugin guide.
It is not a dashboard wishlist.
It is not authority for schema or routes by itself.

If this document conflicts with current higher-order truth, the higher-order truth wins and this document must be updated.

---

## Authority Order

Before using this doc, read these first:

1. `docs/architecture/V_ECOSYSTEM.md`
2. `docs/SYSTEM-INVARIANTS.md`
3. `docs/VEDA_WAVE_2D_CLOSEOUT.md`
4. `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md`
5. `docs/architecture/architecture/veda/search-intelligence-layer.md`
6. `docs/architecture/testing/hammer-doctrine.md`

This doc is subordinate to those authority surfaces.

The following owned-performance lane docs are subordinate to this doc:

- `docs/systems/veda/owned-performance/ga4-observatory.md`
- `docs/systems/veda/owned-performance/instrumentation-and-access.md`
- `docs/systems/veda/owned-performance/observatory-model.md`
- `docs/systems/veda/owned-performance/ingest-discipline.md`
- `docs/systems/veda/owned-performance/validation-doctrine.md`
- `docs/systems/veda/owned-performance/ga4-research-brief.md`

---

## What Owned Performance Means Inside VEDA

Inside current VEDA, owned performance is valid only as an **observatory surface**.

If and when this lane is implemented, VEDA would own only the following observability concerns:
- project-scoped measurement of how owned pages and routes actually performed after users arrived
- read-oriented observation of traffic source mix, engagement signals, device patterns, and geography where the source supports them
- time-aware performance snapshots or observations that can later be compared against search and citation observatory lanes
- bounded interpretation over recorded performance observations

This fits the current VEDA pattern:

```text
entity + observation + time + interpretation
```

The owned-performance lane is valid only when it remains inside that pattern.

---

## What Owned Performance Does Not Mean Inside VEDA

Owned performance in VEDA does not mean:
- growth strategy ownership
- CRO ownership
- ad platform management
- campaign management
- tag-manager sprawl
- executive dashboard theater
- experimentation workflow ownership
- content planning ownership
- execution ownership

Those concerns belong elsewhere:
- Project V plans
- V Forge executes

If a proposed owned-performance feature starts deciding what should be produced next, how traffic should be acquired, or how pages should be optimized as canonical planning truth, it is not a VEDA feature.

---

## Current Framing

The valid owned-performance lane is:
- **observability-only**
- **project-scoped**
- **read-oriented by default**
- **thin-route + pure-library + hammer-validated**
- **small enough to stay useful**

The invalid owned-performance lane is:
- a generic analytics platform
- a BI warehouse pretending to be observability
- attribution theater without clear joins to owned pages
- marketing-operations sprawl dressed up as data collection

---

## GA4 and Search Console Are Different Lanes

This matters enough to say plainly.

### Google Analytics 4

GA4 is useful for **post-click owned performance**.

It can describe things like:
- page or route activity after arrival
- traffic source mix
- engagement behavior
- device and geography context
- time-based performance patterns

### Google Search Console

Search Console is useful for **search visibility and search-performance reality**.

It can describe things like:
- queries
- clicks
- impressions
- CTR
- position
- page/query/device/country performance in Google Search

These must remain separate observatory lanes even when they are later compared.

VEDA must not collapse them into one fake truth surface.

### Search Console lane posture

The Search Console lane is not scoped in this pass.

It is explicitly a **deferred, separately-scoped future lane**.

No GSC docs should be created until the GA4 lane reaches doctrine completion and implementation readiness.

Any future GSC docs belong under `docs/systems/veda/owned-performance/` alongside the GA4 lane docs, following the same placement and naming rules.

---

## Why This Lane May Be Worth Collecting

SERP and YouTube observation tell VEDA what is visible in external search/discovery environments.

Owned performance tells VEDA what happened after the visit arrived on an owned surface.

That comparison becomes useful later for questions like:
- which owned pages actually drew traffic or engagement after visibility appeared
- whether certain page or route types consistently outperform others after arrival
- whether device or geography patterns differ from external search visibility assumptions

This is still observability.
It is not strategy authority.

---

## Preferred First Surface

The preferred first owned-performance surface is narrow:
- GA4 as the post-click observatory source
- Search Console treated as a separate companion lane, deferred
- no ad or experimentation systems in the first slice

This keeps the lane useful without turning VEDA into analytics swamp.

---

## Boundary Checks

A proposed owned-performance feature belongs in VEDA only if all are true:
- it records or interprets observed external or measured reality
- it is project-scoped or explicitly global by current system rule
- it preserves time-aware observation history
- it does not create planning ownership
- it does not create execution ownership
- it can be validated with hammer-style invariants

If any of those fail, it belongs elsewhere or should be rejected.

---

## Doc Naming and Placement Rules

Successor docs for this lane must follow these rules:

### Placement

Place owned-performance docs only under:

`docs/systems/veda/owned-performance/`

Do not create new root-level `VEDA-GA4-*.md` files.
Do not scatter analytics notes across random folders.

### Naming

Use:
- lowercase
- hyphen-separated
- plain functional names

Examples:
- `overview.md`
- `ga4-observatory.md`
- `instrumentation-and-access.md`
- `observatory-model.md`
- `ingest-discipline.md`
- `validation-doctrine.md`
- `ga4-research-brief.md`

### Content Rules

Each successor doc should state:
- purpose
- ownership
- what it governs
- what it does not govern
- authority relationship to higher docs

---

## Maintenance Note

If this lane grows, it must grow by explicit bounded increments.

Do not let:
- ad attribution sprawl
- CRO planning authority
- dashboard-product ambition
- experimentation workflow ownership
- schema inflation without invariants

crawl back into VEDA through the owned-performance lane.

This surface should remain boring, observational, and testable.
