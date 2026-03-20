# YouTube Observatory Overview

## Purpose

This document defines the YouTube lane inside VEDA after reconstruction closeout.

It exists to answer:

```text
What does YouTube mean inside current VEDA, and what does it explicitly not mean?
```

This is a successor doc written against current clean-repo truth.
It is not a port of old YouTube planning notes.
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

---

## What YouTube Means Inside VEDA

Inside current VEDA, YouTube is only valid as an **observatory surface**.

If and when this lane is implemented, VEDA would own only the following observability surfaces:
- project-scoped YouTube search/discovery observation
- query-targeted YouTube search snapshots over time
- channel/video identity normalization at the observatory boundary
- provider/API enrichment in support of observation accuracy
- read-oriented diagnostics over recorded YouTube observations

This fits the current VEDA pattern:

```text
entity + observation + time + interpretation
```

The YouTube lane is valid only when it remains inside that pattern.

---

## What YouTube Does Not Mean Inside VEDA

YouTube in VEDA does not mean:
- channel operations
- publishing workflow
- video production workflow
- thumbnail workflow
- script workflow
- editorial state
- creator-studio replacement
- automated posting
- content planning ownership
- execution ownership

Those concerns belong elsewhere:
- Project V plans
- V Forge executes

If a proposed YouTube feature starts managing what should be produced or how it should be published, it is not a VEDA feature.

---

## Current Framing

The valid YouTube lane is:

- **search-first**
- **observability-only**
- **project-scoped**
- **read-oriented by default**
- **thin-route + pure-library + hammer-validated**

The invalid YouTube lane is:
- generic social/media analytics sprawl
- recommendation-engine theater by default
- workflow or strategy ownership dressed up as observability

---

## Preferred v1 Shape

The narrowest justified first lane is:

### YouTube Search Observatory v1

A project-scoped, search-first, time-aware observation layer for YouTube search results.

Preferred posture:
- query-targeted observations
- immutable snapshots over time
- raw evidence preserved
- normalized identity extracted at the boundary
- channel-first observatory identity, with video-level observation included where present

This is intentionally smaller than a generic “YouTube system.”

---

## Truth Surface Guidance

The canonical truth-surface posture for this lane is defined in `observatory-model.md`.

In short:
- vendor/provider search snapshot is the primary observation evidence
- YouTube API is bounded enrichment where justified
- manual/operator spot-checks support validation where needed

This lane should not depend on hidden background automation or fuzzy inferred truth.

---

## Boundary Checks

A proposed YouTube feature belongs in VEDA only if all are true:
- it records or interprets observed external reality
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

Place YouTube observatory docs only under:

`docs/systems/veda/youtube-observatory/`

Do not create new root-level `VEDA-YOUTUBE-*.md` files.
Do not create ad hoc architecture notes in random folders.

### Naming

Use:
- lowercase
- hyphen-separated
- plain functional names

Examples:
- `overview.md`
- `observatory-model.md`
- `ingest-discipline.md`
- `validation-doctrine.md`

Do not use fossil-style names like:
- `VEDA-YOUTUBE-OBSERVATORY-SPEC.md`
- `youtube-final-v2.md`
- `TRUTH-SURFACE-NOTE.md`

### Content Rules

Each successor doc should state:
- purpose
- ownership
- what it governs
- what it does not govern
- authority relationship to higher docs

---

## Relationship to Historical Notes

Old YouTube/SEO docs from the legacy repo may still contain grounded ideas.
They are not truth.
They may be used only as historical salvage.

Current clean-repo truth always wins.

---

## Maintenance Note

If this lane grows, it must grow by explicit bounded increments.

Do not let:
- publishing workflow
- planning ownership
- recommendation sprawl
- creator-tool UX ambition
- schema inflation without invariants

crawl back into VEDA through the YouTube lane.

This surface should remain boring, observational, and testable.
