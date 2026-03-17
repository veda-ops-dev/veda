# VEDA Schema Reference

## Purpose

This document is the high-level schema reference for VEDA after Wave 2D.

It describes the current observatory-only data model in human terms.
It is not intended to replace `prisma/schema.prisma`.
Instead, it provides the architectural map that humans and LLMs should use before reading the raw schema.

If this document and `prisma/schema.prisma` ever disagree, the schema is authoritative and this document must be updated.

---

## Design Principle

VEDA is a multi-project observability system.

Its core data pattern is:

```text
entity + observation + time + interpretation
```

The schema is intentionally scoped to observed external reality and project-scoped observatory state.

It does not model production workflows, owned drafts, publishing state for owned assets, or editorial execution.

---

## Schema Domains

The current VEDA schema is organized into six major domains.

1. Project scoping
2. Source and capture
3. Event logging
4. Search intelligence
5. System configuration
6. Content graph

---

## 1. Project Scoping

### `Project`

`Project` is the thin observatory partitioning container.

It exists to scope all project-owned observatory data.
It is not intended to become a full planning/orchestration system.

Key responsibilities:
- partition observatory data
- provide stable project identity
- support multi-project isolation

Important note:
Rich project planning truth belongs in Project V, not in VEDA.

---

## 2. Source and Capture

### `SourceFeed`

Represents a recurring external source that VEDA can monitor or ingest from.

Examples:
- RSS feed
- channel/feed-like external source
- durable external input stream

Key ideas:
- project-scoped
- reusable capture source
- operator-defined

### `SourceItem`

Represents an individual captured external item.

Examples:
- webpage
- comment
- reply
- video reference
- other captured source artifact

Key ideas:
- project-scoped
- capture-time aware
- operator-intent aware
- status-tracked (`ingested`, `triaged`, `used`, `archived`)

This is one of the main observatory intake tables.

---

## 3. Event Logging

### `EventLog`

`EventLog` is the canonical append-only observatory event ledger.

It records project-scoped state transitions and important system-level observatory events.

Key ideas:
- append-only history
- project-scoped
- references the affected entity via `entityType + entityId`
- actor-aware (`human`, `llm`, `system`)
- time-aware (`timestamp`)

`EventLog` is not a general-purpose analytics or telemetry dump.
It is the durable audit trail for stateful observatory events.

---

## 4. Search Intelligence

### `KeywordTarget`

Represents a governed decision to observe a query within a specific locale/device scope.

This is not an observation record.
It is a target-definition record.

Key ideas:
- what the project chooses to observe
- unique within project + query + locale + device
- supports notes, intent, and primary-target semantics

### `SERPSnapshot`

Represents an immutable SERP observation at a specific capture time.

Key ideas:
- observation record, not planning record
- project-scoped
- query/locale/device specific
- stores raw provider payload for evidence
- stores promoted fields for practical querying
- time-aware (`capturedAt`, optional `validAt`)

This is one of the primary historical observation ledgers in VEDA.

### `SearchPerformance`

Represents query × page × date-range performance observations.

Key ideas:
- URL-based observation
- no editorial/entity FK coupling
- project-scoped
- optimized for query and page-based performance analysis

This table should remain observation-first rather than becoming a content planning table.

---

## 5. System Configuration

### `SystemConfig`

Represents global observability configuration.

Key ideas:
- intentionally global rather than project-scoped
- stores configuration in JSON where flexibility is required
- updates are tracked by actor

This table should remain small and intentional.
It is not a substitute for arbitrary application state storage.

---

## 6. Content Graph

The Content Graph models the observed structural state of external content surfaces.

It is not an owned-content CMS.
It is an observatory graph describing surfaces, sites, pages, entities, topics, links, and schema usage.

### `CgSurface`

Represents a brand or platform surface where content exists.

Examples:
- website surface
- blog surface
- wiki surface
- X surface
- YouTube surface

Key ideas:
- project-scoped
- stable machine identity via `key`
- optional canonical identifier for platform-level identity

### `CgSite`

Represents a concrete web property or site within a surface.

Examples:
- a canonical domain
- a sub-property under a surface

Key ideas:
- domain-scoped identity within project
- tied to a `CgSurface`

### `CgContentArchetype`

Represents structural page-type classification.

Examples:
- guide
- comparison
- review
- supporting structure

Key ideas:
- project-scoped taxonomy
- used to classify pages structurally

### `CgPage`

Represents a canonical page-level content unit on a site.

Key ideas:
- project-scoped URL identity
- tied to site and optionally archetype
- stores structural state such as indexability and publishingState

Important note:
This does not mean VEDA owns editorial publishing workflow.
`publishingState` here reflects observed/recorded page state in the content graph context.

### `CgTopic`

Represents conceptual territory clusters.

Key ideas:
- project-scoped
- stable topic identity via `key`
- used to connect pages to conceptual territory

### `CgEntity`

Represents real-world entities referenced by observed content.

Key ideas:
- project-scoped
- stable entity identity via `key`
- typed via `entityType` string

This is a content-graph entity model, not the old PsyMetric publishing entity model.

### `CgPageTopic`

Represents the junction between a page and a topic.

Key ideas:
- project-scoped junction
- role-aware (`primary`, `supporting`, etc.)
- must never connect across projects

### `CgPageEntity`

Represents the junction between a page and an entity.

Key ideas:
- project-scoped junction
- role-aware
- must never connect across projects

### `CgInternalLink`

Represents observed structural internal links between two pages.

Key ideas:
- project-scoped
- source page → target page
- optional anchor text
- role-aware (`hub`, `support`, `navigation`)

### `CgSchemaUsage`

Represents structured data observed on a page.

Examples:
- Article
- FAQPage
- Product
- Review

Key ideas:
- project-scoped
- tied to page
- identifies schema type usage and primary-ness

---

## Current Enumerations

The current schema uses these enum families:

### Intake / source enums
- `SourceType`
- `Platform`
- `SourceItemStatus`
- `CapturedBy`

### Event enums
- `EntityType`
- `EventType`
- `ActorType`

### Content graph enums
- `CgSurfaceType`
- `CgPublishingState`
- `CgPageRole`
- `CgLinkRole`

These enums are now observatory-scoped.
Removed editorial or production vocabularies should not be reintroduced casually.

---

## Removed Wave 2D Domains

The following domains were intentionally removed during Wave 2D and are not part of the current schema:

- `Entity`
- `EntityRelation`
- `Video` (owned production model)
- `DistributionEvent`
- `DraftArtifact`
- `MetricSnapshot`
- `QuotableBlock`

Any documentation or code that assumes these are still active is outdated.

---

## Structural Rules

The schema follows these structural rules:

### 1. Project-scoped isolation is the default

Most domain tables are project-scoped.
Global tables must be explicit exceptions.

### 2. Observations are time-aware

Historical state matters.
Observation tables should preserve capture time and avoid silent overwriting of history.

### 3. Graph integrity matters

Content graph junctions and links must not create cross-project contamination.

### 4. Raw evidence is allowed, but hot fields should be explicit

Provider payloads may be stored in JSON, but common query fields should be promoted to explicit columns.

### 5. The schema is observatory-first, not execution-first

The database should describe what VEDA observes and governs as observatory truth.
Execution state belongs elsewhere.

---

## Relationship Summary

At a high level:

```text
Project
 ├─ SourceFeed
 ├─ SourceItem
 ├─ EventLog
 ├─ KeywordTarget
 ├─ SERPSnapshot
 ├─ SearchPerformance
 ├─ CgSurface
 │   └─ CgSite
 │       └─ CgPage
 │           ├─ CgPageTopic -> CgTopic
 │           ├─ CgPageEntity -> CgEntity
 │           ├─ CgInternalLink
 │           └─ CgSchemaUsage
 └─ SystemConfig (global exception, not project-scoped)
```

---

## How to Use This Document

Use this document when you need to:
- understand the current schema quickly
- orient an LLM before schema work
- classify whether a feature belongs in VEDA
- understand which domains survived Wave 2D
- compare old documentation against current schema truth

Do not use this document as a substitute for the real schema file.
Use it as the architectural map that keeps humans and LLMs from getting lost.
