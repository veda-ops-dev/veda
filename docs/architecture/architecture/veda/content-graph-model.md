# Content Graph Model

## Purpose

This document defines the content graph model for VEDA.

It exists to explain how VEDA records the observed structural state of project content surfaces while preserving clean boundaries around planning, production, and execution.

This is a VEDA architecture document.
It should be read as the detailed companion to:
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/architecture/veda/observatory-models.md`

If this document conflicts with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- the current Prisma schema

those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document explains:
- what the content graph is inside VEDA
- what structural objects it models
- how those objects relate
- what questions the graph is meant to answer
- what stays inside the graph boundary and what belongs elsewhere

---

## What This Doc Is Not

This document is not:
- a site-building workflow spec
- a CMS data model
- a publishing-state machine for owned outputs
- an execution-planning engine
- a blueprint ownership doc

It answers a narrower question:

```text
How does VEDA model the observed structural state of project content surfaces?
```

---

## Ownership

This document belongs to VEDA.

The content graph belongs in VEDA because it models observed structure and project-scoped observatory truth.
It does not own planning decisions or production workflow.

The bounded-system rule remains:
- Project V plans
- VEDA observes
- V Forge executes

If a proposed graph capability starts deciding what should be built next, sequencing work, managing draft revision, or tracking publish workflow as execution truth, it belongs outside VEDA.

---

## Core Definition

The content graph is VEDA’s project-scoped graph of observed content structure.

It records things like:
- what surfaces exist
- what sites exist inside those surfaces
- what canonical pages exist
- what page archetypes are present
- what topics and entities are represented
- how pages connect to each other
- what schema types are observed on pages

This is structural observability.
It is not a content management system.

The content graph fits the current VEDA pattern:

```text
entity + observation + time + interpretation
```

In this case:
- the graph objects are the entities being modeled
- the graph rows record observed or governed structural state
- timestamps preserve when graph state was captured or created
- later interpretation may reason over the graph without replacing the graph itself

---

## Why the Content Graph Exists

The content graph gives VEDA a structured way to compare:
- what a project surface currently exposes
- what external search signals appear to reward
- where structural patterns, gaps, or opportunities may exist

That lets VEDA answer questions such as:
- what pages exist on the project site?
- which topics and entities are represented?
- what page archetypes are present?
- how are pages internally linked?
- what schema usage patterns are visible?
- where might there be structural gaps worth interpreting later?

The graph is the structural floor for observability, not the final strategy layer.

---

## Scope of the Current Content Graph

The current content graph is intentionally narrow enough to stay trustworthy.

It models:
- surfaces
- sites
- pages
- content archetypes
- topics
- entities
- page-topic junctions
- page-entity junctions
- internal links
- schema usage

It does not model:
- editorial revision state
- draft content objects
- publish queue workflow
- production asset workflow
- execution plans
- roadmap actions
- proposed page artifacts as canonical graph truth

Those belong outside the content graph boundary.

---

## Graph Objects

The current graph is made from a small set of structural objects.

### `CgSurface`

Represents a project surface where content exists.

Examples:
- a website surface
- a blog surface
- a wiki surface
- a platform surface such as YouTube or X where applicable in future extensions

Key ideas:
- project-scoped
- stable machine identity via `key`
- can represent a broader content surface rather than a single domain

A surface is the widest graph container below the project.

### `CgSite`

Represents a concrete web property or site within a surface.

Examples:
- a canonical domain
- a sub-property within a broader surface

Key ideas:
- project-scoped
- tied to a `CgSurface`
- stable domain-oriented identity within project scope

This is where the graph becomes concrete enough to talk about canonical pages.

### `CgPage`

Represents a canonical page-level content unit on a site.

Examples:
- a guide page
- a comparison page
- a documentation page
- another canonical content URL

Key ideas:
- project-scoped URL identity
- tied to a site
- may reference a content archetype
- stores observed structural state such as indexability and publishing state

Important rule:
Observed page state in the graph is not the same thing as production workflow truth.
The graph may record what state a page appears to be in structurally.
It does not own production workflow.

### `CgContentArchetype`

Represents page-type classification.

Examples:
- guide
- comparison
- review
- reference
- tutorial

Key ideas:
- project-scoped taxonomy
- helps classify pages structurally
- supports later interpretation of archetype patterns without turning archetypes into execution instructions

### `CgTopic`

Represents conceptual territory clusters.

Key ideas:
- project-scoped
- stable machine identity via `key`
- used to connect pages to conceptual territory

Topics help the graph describe what territory is covered, not what must be written next.

### `CgEntity`

Represents real-world entities referenced by observed content.

Examples:
- organizations
- products
- technologies
- people
- concepts

Key ideas:
- project-scoped
- stable machine identity via `key`
- typed by `entityType` string

This is the graph’s entity model for structural observability.

---

## Junction and Relationship Objects

The content graph uses explicit junction objects rather than implied relationships.

### `CgPageTopic`

Represents the relationship between a page and a topic.

Key ideas:
- project-scoped junction
- role-aware, such as `primary` or `supporting`
- must never connect objects across projects

This is how the graph records territory coverage in explicit structural terms.

### `CgPageEntity`

Represents the relationship between a page and an entity.

Key ideas:
- project-scoped junction
- role-aware
- must never connect objects across projects

This is how the graph records entity representation in explicit structural terms.

### `CgInternalLink`

Represents an observed internal link between two pages.

Key ideas:
- project-scoped
- source page to target page
- optional anchor text
- role-aware, such as `hub`, `support`, or `navigation`

This lets the graph describe observed internal authority flow and support structure without turning into a link management workflow.

### `CgSchemaUsage`

Represents structured data observed on a page.

Examples:
- `Article`
- `FAQPage`
- `HowTo`
- `Product`
- `Review`

Key ideas:
- project-scoped
- tied to a page
- records schema type usage and optional primary-ness

This helps the graph describe visible structural signaling rather than editorial intent.

---

## Relationship Shape

At a high level, the graph looks like this:

```text
Project
 └─ CgSurface
     └─ CgSite
         └─ CgPage
             ├─ CgPageTopic -> CgTopic
             ├─ CgPageEntity -> CgEntity
             ├─ CgInternalLink -> CgPage
             └─ CgSchemaUsage
```

This shape is intentionally explicit.
It is easier for humans and LLMs to reason about than hidden relationship magic.

---

## Structural Questions the Graph Should Answer

The current content graph should be able to answer questions like:
- what surfaces and sites exist for this project?
- what canonical pages are present?
- what archetypes are represented?
- which topics are primary or supporting on which pages?
- which entities are represented on which pages?
- how do pages link internally?
- what schema usage is visible on those pages?

Those are observability questions.

The graph should not directly answer questions like:
- what content should we produce next?
- which draft is in review?
- what should be published tomorrow?
- what execution queue should run?

Those belong to Project V or V Forge depending on the concern.

---

## Integrity Rules

The content graph must obey current invariants.

### Project isolation

Every graph row is project-scoped.
Cross-project contamination is forbidden.

### Junction integrity

`CgPageTopic`, `CgPageEntity`, and `CgInternalLink` must never connect rows from different projects.

This should be enforced:
- at the application layer
- at the database layer where structural safety matters

### Canonical identity stability

The graph relies on stable identifiers within project scope.

Examples include:
- `CgSurface.projectId + key`
- `CgSite.projectId + domain`
- `CgPage.projectId + url`
- `CgTopic.projectId + key`
- `CgEntity.projectId + key`

These identity surfaces should remain unambiguous within project scope.

### Deterministic retrieval

Graph reads must define explicit ordering.
No implicit DB ordering nonsense.

---

## Observed State vs Execution State

One of the easiest ways to corrupt the content graph is to confuse observed structure with execution truth.

### Observed structure belongs here
Examples:
- a page exists at a canonical URL
- a page appears indexable or non-indexable
- a page uses a schema type
- a page links to another page
- a page covers a topic or entity

### Execution truth does not belong here
Examples:
- draft revision workflow
- publish approvals
- editorial review queue
- owned asset production state
- execution tasks and scheduling

The graph may support later interpretation about those things.
It should not become the authoritative store for them.

---

## Time and Mutation Discipline

The content graph is structural and should still remain time-aware where useful.

That means:
- creation time matters
- update time matters
- meaningful graph mutations should remain auditable

However, the graph is not primarily a snapshot ledger like `SERPSnapshot`.
Some graph objects represent a current structural state rather than an append-only observation stream.

Even so:
- multi-write graph mutations should be transactional
- required graph events should be emitted atomically with state change
- silent partial writes are forbidden

---

## Interpretation on Top of the Graph

The graph is meant to support interpretation later.

Examples of interpretation that may be derived from the graph include:
- structural coverage analysis
- archetype distribution analysis
- support-link pattern analysis
- schema distribution analysis
- topic and entity representation analysis

Those interpretations should generally be compute-on-read or otherwise explicitly derived.
They should not turn the graph into a storage tomb for speculative scores and strategy sludge.

The content graph stores structure first.
Interpretation grows on top of that foundation.

---

## Phase Discipline

The active content graph should stay focused on structural observability.

Future expansions may include:
- richer competitor observation alignment
- broader surface modeling
- deeper graph-derived interpretation

Any future expansion should preserve:
- VEDA observatory ownership
- project-scoped isolation
- explicit schema
- deterministic behavior
- clear separation from planning and execution systems

---

## Relationship to Other Observatory Domains

The content graph works alongside other active observatory domains.

### Search observation ledger
The ledger records governed search targets and observed SERP/performance state.
The content graph records the project’s structural state.

### Source capture
Source capture records incoming evidence and provenance.
The content graph records structured content-surface state.

### Event ledger
The event ledger records meaningful state changes affecting graph objects where required.

These are complementary domains, not duplicates.

---

## Explicit Non-Examples

The following do not belong in the current content graph model:
- editorial drafts
- publish request states as execution truth
- review assignments
- distribution actions
- blueprint ownership state
- roadmap sequencing records
- execution queues
- autonomous recommendation artifacts stored as canonical graph objects

If a proposed graph model starts taking on planning or execution responsibilities, stop and reclassify it.

---

## Relationship to Active Docs

This document should be read alongside:
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/architecture/veda/observatory-models.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`
- `docs/systems/veda/observatory/event-auditability.md`

These docs together define:
- what the graph is
- how it fits the broader observatory model
- what invariants it must obey
- how graph-related events remain auditable

---

## Maintenance Note

If future work tries to turn the content graph into:
- a CMS core
- an execution planner
- a publish-state authority system
- a strategic blob that stores conclusions instead of structure

that is an architectural warning sign.

The durable rule remains:
- Project V plans
- VEDA observes
- V Forge executes

The content graph should remain a structural observatory model inside that system.
