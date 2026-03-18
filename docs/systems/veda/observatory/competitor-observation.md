# Competitor Observation

## Purpose

This document defines how competitor pages and competitor structures should be observed inside VEDA.

It exists to preserve a clean, observability-only approach to competitive search intelligence without collapsing VEDA into strategy ownership, production workflow, or background crawling theater.

This is a VEDA architecture and behavior document.
It should be read together with:
- `docs/architecture/architecture/veda/observatory-models.md`
- `docs/architecture/architecture/veda/content-graph-model.md`
- `docs/architecture/architecture/veda/search-intelligence-layer.md`
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`

If this document conflicts with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md`
- the current Prisma schema

those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document defines:
- what competitor observation means inside VEDA
- why competitor observation should be SERP-led by default
- what kinds of competitor signals are worth recording
- how competitor observation relates to the current observatory floor
- what implementation stance should be used now

---

## What This Doc Is Not

This document is not:
- a whole-web crawling charter
- a site-mirroring plan
- a Project V strategy doc
- a V Forge production response workflow
- a claim that dedicated competitor tables already exist in the current schema
- a license to smuggle planning or execution state into VEDA wearing fake observability glasses

It answers a narrower question:

```text
How should VEDA observe competitor pages that matter in search reality while preserving post-Wave-2D ownership boundaries?
```

---

## Ownership

This document belongs to VEDA.

Competitor observation belongs in VEDA when it remains observation-first:
- external pages are being observed
- structural signals are being recorded
- time and provenance are being preserved
- later interpretation can compare observed competitor patterns with project-scoped observatory records

The bounded-system rule remains:
- Project V plans
- VEDA observes
- V Forge executes

If a competitor-oriented feature starts deciding what the project should build next, sequencing roadmap work, generating production drafts as canonical state, or managing publishing workflow, it has crossed out of VEDA.

---

## Core Principle

Competitor observation is targeted external observation.

The safe default entry point is the search observation ledger.

```text
SERP snapshot -> ranking URL appears -> operator decides it is worth observing -> structural signals are captured or derived -> later diagnostics compare competitor structure against project structure and search reality
```

This keeps VEDA focused on competitor pages that actually matter in the observed search environment rather than wandering off into internet-hoovering nonsense.

---

## Why SERP-Led Observation Is the Default

Blind crawling answers a broad question:

```text
What pages exist on a competitor domain?
```

VEDA usually needs the narrower and more useful question:

```text
What competitor pages are actually winning or appearing in the search ecosystem this project observes?
```

Starting from `docs/systems/veda/observatory/observation-ledger.md` keeps the system:
- project-scoped
- relevance-driven
- easier to reason about
- less likely to accumulate junk evidence
- less likely to turn into a speculative crawler subsystem before the boring foundation is ready

Observation may expand beyond a ranking URL in careful cases, but SERP-led selection remains the safest default posture.

---

## Current Baseline in This Repo

The current repo supports competitor observation conceptually, but it does **not** yet define dedicated competitor-specific Prisma models as active schema truth.

That means the current baseline is:
- search reality is already captured through `KeywordTarget`, `SERPSnapshot`, and related derived intelligence
- external pages can already enter VEDA through source capture and intake behavior
- owned project structure is already modeled through the content graph
- competitor observation must not silently merge external competitor pages into owned content graph truth

The practical implication is simple:

### Current floor
Use the existing observatory floor first:
- `SERPSnapshot` and related search observations for discovery
- `SourceItem` capture for preserved evidence and provenance
- thin derivation inside `docs/architecture/architecture/veda/search-intelligence-layer.md` for diagnostics

### Current non-claim
This doc does **not** claim that competitor-specific schema, APIs, or MCP tools already exist.

### Current implementation preference
Prefer compute-on-read, targeted capture, and explicit provenance before inventing a new persistence layer.

Any future dedicated persistence must be justified by real query pressure, repeated operator value, or integrity needs rather than by architecture cosplay.

---

## Observation Units

Competitor observation is easiest to reason about when split into a few conceptual units.

These are conceptual units for architecture discussion.
They are **not** all current schema objects.

### 1. Competitor surface or domain

The broad external property being observed.

Examples:
- a competing site
- a documentation domain
- a marketplace listing surface
- another external content property visible in tracked search results

### 2. Competitor page

The canonical URL-level unit that appeared in the observed competitive environment.

This is usually the first durable external object that matters.

### 3. Competitor page observation

A time-aware record of what VEDA saw about that page when it was examined.

This may be connected to:
- a ranking context
- a capture time
- a valid time when available
- a structural extraction pass
- a preserved evidence payload or snapshot reference

### 4. Structural signals

The observed signals extracted from that page.

Examples include:
- page archetype hints
- heading structure
- schema usage
- citation patterns
- internal support-link patterns
- freshness hints

This keeps the mental model aligned with the VEDA rule:

```text
entity + observation + time + interpretation
```

---

## Signals Worth Observing

The goal is not to preserve a maximal copy of a competitor page.
The goal is to preserve enough structural evidence to support later comparison and grounded interpretation.

Useful signal families include:

### Page signals
- canonical URL
- domain or host
- title
- meta description
- obvious page-type or archetype hints

### Structure signals
- heading hierarchy
- section layout
- definitional or comparison block presence
- rough content-shape hints

### Schema signals
- schema types present
- likely primary schema pattern
- notable schema combinations when they appear repeatedly

### Link and citation signals
- internal support links
- outbound citation domains
- visible source/reference patterns

### Freshness and change signals
- visible update hints
- modified-date hints where available
- repeated observation change patterns over time

### SERP context signals
- which tracked query exposed the page
- rank position or feature context where applicable
- whether the page repeatedly appears across snapshots

The boring rule still applies:
- raw evidence may be retained when useful
- hot query fields should be made explicit if they become operationally important

---

## Time, Provenance, and Auditability

Competitor observation should preserve time and provenance with the same seriousness used elsewhere in VEDA.

Important questions include:
- when did the page appear in observed search reality?
- when did VEDA capture supporting evidence about it?
- what operator or system path initiated the capture?
- what source or SERP context justified keeping it?

That means competitor observation should stay aligned with:
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/event-auditability.md`

Current practical rule:
- use the time and provenance semantics of the underlying observatory records that actually exist
- do not invent phantom event or schema guarantees that the repo does not currently implement

Until dedicated competitor persistence exists, the durable audit trail comes from the records VEDA already owns, such as source capture records and search observation records.

---

## Relationship to the Content Graph

The content graph in `docs/architecture/architecture/veda/content-graph-model.md` is the project-scoped graph of observed **project** content structure.

That distinction matters.

Competitor pages are external observations.
They are not automatically part of the owned project content graph.

This means:
- the content graph remains the structural model for project surfaces
- competitor observation remains an external observatory concern
- comparison between project structure and competitor structure is a derived intelligence problem, not a license to blur the models together

If future implementation pressure ever justifies a dedicated external-structure graph, that should be classified explicitly instead of being smuggled into `Cg*` models by stealth.

---

## Relationship to the Search Intelligence Layer

Competitor observation is useful because it improves the quality of derived search diagnostics.

Examples of derived use include:
- spotting archetype mismatches between ranking competitors and project pages
- detecting repeated schema patterns among observed winners
- surfacing domain dominance or support-structure patterns
- comparing observed competitor page structure against project content graph structure

Those are Search Intelligence Layer uses.
They remain derived and read-oriented.

This doc therefore complements `docs/architecture/architecture/veda/search-intelligence-layer.md` rather than replacing it.
Competitor observation preserves better external evidence.
The Search Intelligence Layer interprets it.

---

## Current Implementation Stance

The current implementation stance should stay conservative.

### 1. Start with targeted observation, not crawling ambition
Observe the pages that matter because search observation exposed them or an operator intentionally captured them.

### 2. Reuse the existing observatory floor first
Use the current search observation ledger and source-capture layer before adding new persistence.

### 3. Keep compute-on-read as the default
If a useful comparison can be derived from existing observations plus captured evidence, prefer that to speculative materialization.

### 4. Add dedicated persistence only when justified
A future dedicated competitor-observation model is reasonable **only if** repeated use proves that the existing floor cannot preserve the needed evidence cleanly or query it deterministically enough.

### 5. Preserve project scope
Even though competitor pages are external, the observation of them is still project-scoped because the competitive context is project-specific.

### 6. Keep human-gated control
Operators may trigger capture, approve interpretation, or review derived findings.
LLMs may assist with extraction or summarization.
They must not silently mutate canonical competitive truth.

---

## If Dedicated Models Are Ever Added Later

This is not current schema truth.
It is only a boundary-safe shape for future classification if real implementation pressure appears.

The likely split would be:
- an observed competitor site or surface identity
- an observed competitor page identity
- a time-aware observation record for that page
- subordinate structural evidence for schema, links, citations, or archetype hints where justified

If that happens later, the design must still preserve:
- project-scoped isolation
- append-friendly observations where history matters
- explicit schema over JSON sludge
- deterministic retrieval
- no planning or execution ownership leakage

Any such change would require explicit schema, API, and cleanup-map updates rather than wishful hand-waving.

---

## Anti-Patterns

The following patterns should be rejected unless explicitly reclassified with real justification:

- crawling the whole web just because the idea sounds dramatic
- mirroring competitor sites as if VEDA were building a secret CMS museum
- treating competitor observations as planning truth for Project V
- turning competitor insights into production workflow ownership for V Forge
- silently merging competitor pages into the owned content graph
- assuming background scraping automation is the canonical default
- storing giant raw payloads as hot operational truth when explicit fields are what the system actually needs

---

## Out of Scope

This document does not define:
- Project V roadmap decisions based on competitor findings
- V Forge drafting or publishing responses to competitor patterns
- a dedicated crawler subsystem
- a full external-domain graph implementation
- a schema migration plan
- a public product UX for competitor analysis

Those may be discussed elsewhere if and when they become real work.
They are not established here.

---

## Boundary Check

### Belongs to Project V
- deciding which competitive gaps matter strategically
- prioritizing what should happen next because of observed competitor patterns
- turning observed gaps into roadmap or plan truth

### Belongs to V Forge
- drafting, revising, producing, or publishing outputs in response to competitor findings
- execution-side asset or editorial workflow

### Historical or rejected VEDA drift
- autonomous crawl fantasies
- execution workflow disguised as observability
- strategy ownership hidden inside competitor diagnostics

---

## Maintenance Note

Use this document as the active successor for competitor-observation framing.

Read it with:
- `docs/architecture/architecture/veda/observatory-models.md`
- `docs/architecture/architecture/veda/content-graph-model.md`
- `docs/architecture/architecture/veda/search-intelligence-layer.md`
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/event-auditability.md`

If current schema, code, or higher-authority truth docs change, this document should be updated rather than allowed to become another fossil with opinions.
