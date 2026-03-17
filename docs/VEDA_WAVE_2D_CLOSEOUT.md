# VEDA Wave 2D Closeout

## Purpose

This document records the architectural outcome of Wave 2D and defines the post-reset truth for VEDA.

Wave 2D was the database and runtime cleanup pass that removed legacy PsyMetric-era editorial and publishing behavior from VEDA and re-established VEDA as an observability system.

This file exists to prevent architectural drift and accidental reintroduction of removed responsibilities.

---

## Wave 2D Outcome

Wave 2D completed the transition from a mixed-purpose system into an observatory-only bounded domain.

After Wave 2D:

- the Prisma schema was re-baselined to an observatory-only model
- the historical migration chain was replaced with a single `veda_baseline`
- editorial and production-oriented models were removed
- dead API routes and dashboard surfaces were removed
- MCP tooling was updated to match the surviving observability domain
- the Source Inbox was reduced to observatory-only actions

VEDA now reflects the architecture intentionally rather than only in documentation.

---

## What VEDA Owns Now

VEDA is the observability and intelligence layer of the V Ecosystem.

Its responsibility is to model observed external reality and project-scoped observatory state.

VEDA now owns:

- project-scoped observatory partitioning
- source feed and source item capture
- keyword targets
- SERP snapshots
- search performance observation
- content graph surfaces, sites, pages, topics, entities, and junctions
- observatory event logging
- system configuration relevant to observability

The core operating model remains:

```text
entity + observation + time + interpretation
```

That pattern is the basis for current and future observatories inside VEDA.

---

## What Was Intentionally Removed

The following domains and model families were intentionally removed from VEDA during Wave 2D because they do not belong to an observability system:

- `Entity`
- `EntityRelation`
- `Video` (owned production video model)
- `DistributionEvent`
- `DraftArtifact`
- `MetricSnapshot`
- `QuotableBlock`
- blueprint routes and blueprint schemas
- draft reply generation and archive routes
- public entity/news CMS-style routes and pages
- editorial dashboard pages tied to removed models

These were part of the older PsyMetric-era mixed-content system and are not part of the clean VEDA bounded domain.

---

## What Belongs Outside VEDA

### Project V

Project V owns planning and orchestration truth.

That includes:

- project lifecycle
- planning state
- sequencing
- next-step coordination
- roadmap and orchestration logic

VEDA may keep thin project scoping for observatory partitioning, but VEDA does not own rich project planning truth.

### V Forge

V Forge owns execution and production truth.

That includes:

- drafts
- editorial workflow
- publishing workflow
- asset management
- revision state
- produced articles, videos, and other owned content artifacts
- reply drafting and production-facing distribution actions

If a feature is about making, drafting, revising, or publishing owned outputs, it belongs in V Forge, not VEDA.

---

## Rules for Future Development

The following rules are now part of VEDA architectural maintenance.

### 1. Do not reintroduce production workflow into VEDA

Do not add draft, editorial, publishing, or owned-artifact workflow models back into the VEDA database.

### 2. Keep project scoping thin

Project records inside VEDA exist only to partition observatory data and support multi-project observability.

They are not a substitute for Project V.

### 3. Observability first

New VEDA capabilities should describe observed reality, not production intent.

A good default test is:

- if the system is recording what was observed, it may belong in VEDA
- if the system is managing what will be produced, it does not belong in VEDA

### 4. Preserve bounded system ownership

If a change blurs ownership between Project V, VEDA, and V Forge, stop and explicitly classify the change before implementing it.

### 5. Prefer boring architecture

Choose explicit schemas, predictable APIs, and maintainable structures over clever abstractions or hidden cross-domain coupling.

---

## Immediate Post-Wave 2D Guidance

Future work should assume the following baseline:

- VEDA is now a multi-project observatory system
- observatory data is project-scoped
- DataForSEO and similar integrations may be shared infrastructure, but observations remain project-specific
- future testing/hammers should be rebuilt for the observatory-only schema
- archived legacy scripts may be used as reference, but not restored as active system surfaces

---

## Maintenance Note

If future work appears to require reintroducing removed Wave 2D models or routes into VEDA, treat that as an architectural warning sign.

Reassess system ownership first.

The default answer should be:

- observability stays in VEDA
- planning stays in Project V
- execution stays in V Forge

That separation is intentional and must be preserved.
