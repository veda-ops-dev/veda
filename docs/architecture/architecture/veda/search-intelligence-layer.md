# Search Intelligence Layer

## Purpose

This document defines the Search Intelligence Layer inside VEDA.

It exists to explain how VEDA derives deterministic, operator-facing search diagnostics from observatory records without taking on planning ownership, execution ownership, or hidden workflow state.

This is a VEDA architecture document.
It should be read together with:
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/architecture/veda/observatory-models.md`
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/ingest-discipline.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`

If this document conflicts with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- the current implementation in `src/lib/seo/` and `src/app/api/seo/`

those higher-authority sources or current implementation win and this document must be updated.

---

## What This Doc Is

This document defines:
- what the Search Intelligence Layer is inside VEDA
- what observatory records it consumes
- what kinds of derived intelligence it produces
- the architectural pattern its implementation must follow
- the registry of active numbered search-intelligence surfaces
- the ownership boundary it must not cross

---

## What This Doc Is Not

This document is not:
- a roadmap for speculative search features
- a strategy engine charter
- a planning-state document
- a publishing or execution workflow document
- a claim that every numbered surface deserves equal future investment

It answers a narrower question:

```text
How does VEDA derive project-scoped search intelligence from observatory records while staying inside observability ownership?
```

---

## Ownership

This document belongs to VEDA.

The Search Intelligence Layer belongs inside VEDA because it derives interpretation from observed search reality.
It consumes observatory records and produces diagnostics, summaries, and operator-facing intelligence.
It does not own planning truth or production truth.

The bounded-system rule remains:
- Project V plans
- VEDA observes
- V Forge executes

If a search-intelligence surface starts deciding what should be built next, advancing roadmap state, managing draft workflow, or owning execution tasks, it has crossed the boundary and must be reclassified.

---

## Core Definition

The Search Intelligence Layer is VEDA’s derived search-diagnostics layer.

It sits on top of observatory records such as:
- `KeywordTarget`
- `SERPSnapshot`
- `SearchPerformance`
- `EventLog` where relevant to auditability

It computes project-scoped search intelligence such as:
- deltas
- volatility
- change classification
- event timelines
- causality patterns
- intent drift
- feature volatility
- domain dominance
- risk summaries
- operator briefings and reasoning aids

This is derived intelligence, not a second canonical truth store.

The canonical observed truth remains in the observatory records.
The Search Intelligence Layer interprets those records without replacing them.

---

## Architectural Pattern

The Search Intelligence Layer follows a strict pattern.

```text
observatory records -> pure derivation -> thin route/tool surface -> operator-facing result
```

### 1. Observatory records first

The layer begins from governed, project-scoped observatory inputs.
It does not invent its own independent truth domain.

### 2. Pure derivation

Core computation should live in pure library functions where practical.
Those functions should be:
- deterministic
- side-effect free
- explicit about their inputs
- explicit about ordering requirements
- testable without hidden environment state

### 3. Thin route handlers

API handlers should be thin orchestration surfaces.
Their job is to:
- resolve project scope
- validate input
- fetch the required observatory records
- call pure derivation functions
- return contract-compliant responses

They should not hide business logic in route spaghetti.

### 4. Compute-on-read by default

The layer prefers compute-on-read over premature materialization.
That keeps the system:
- easier to reason about
- less likely to drift from source observations
- less likely to accumulate stale derived state

Materialization is allowed only when there is a clear performance or operational reason and the ownership model remains clean.

### 5. No silent authority escalation

Derived results may inform operators and future planning.
They do not become planning truth, execution truth, or autonomous mutation authority.

---

## Relationship to the Observatory Model

The Search Intelligence Layer fits the VEDA pattern:

```text
entity + observation + time + interpretation
```

### Entity
The observed search target, query, project, page, domain, or related search object.

### Observation
Captured search snapshots, performance records, and other observatory evidence.

### Time
Captured times, pairwise deltas, windows, and ordered sequences across observations.

### Interpretation
Derived diagnostics such as volatility, classification, causality, and operator-facing summaries.

The key discipline is simple:
- observations remain canonical
- interpretation remains derived

---

## Inputs and Outputs

### Primary inputs

The Search Intelligence Layer primarily consumes:
- `KeywordTarget`
- `SERPSnapshot`
- `SearchPerformance`
- provider payloads already preserved inside observatory records
- project-scoped request context

### Primary outputs

The layer primarily produces:
- API responses under `src/app/api/seo/`
- MCP tool results under `mcp/server/src/`
- hammer-verifiable diagnostic surfaces under `scripts/hammer/`
- operator-facing summaries suitable for UI, MCP, and reviewable reasoning support

These outputs are derived views, not a separate write-owned truth layer.

---

## Invariants

A compliant Search Intelligence Layer must preserve the following invariants.

### 1. Project scope is mandatory

Every derived result must respect explicit project scope.
No cross-project leakage.
No silent fallback to another project.

### 2. Deterministic ordering

Any derivation that depends on sequence must define ordering explicitly.
The active implementation pattern is ordered time first, then a stable tie-breaker such as ID.

### 3. Derived results do not mutate canonical truth silently

Read surfaces should not perform hidden writes.
Mutation paths, if ever required, must be explicit, bounded, and governed.

### 4. Compute-on-read is the default

If a result can be derived safely and cheaply from observatory records, prefer derivation over persistence.

### 5. Thin handlers, thick library discipline

Route handlers should stay thin.
Reusable derivation should live in pure library modules where possible.

### 6. Validation and non-disclosure rules still apply

The layer is not exempt from API validation, auth, scope, or non-disclosure behavior just because it is read-heavy.

### 7. Search intelligence is not planning ownership

The layer may surface what is happening.
It does not decide what should happen next.
That belongs to Project V.

---

## Active Tiers Inside the Layer

The active Search Intelligence Layer can be understood in three tiers.

### Tier 1 — observatory floor

This is the observatory substrate the layer depends on.

It includes:
- query governance
- snapshot capture
- performance observation
- project scoping
- audit vocabulary

This tier is defined primarily by:
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/ingest-discipline.md`

### Tier 2 — derived diagnostic surfaces

This is the core compute layer.
It derives structured search intelligence from observed records.

Examples include:
- volatility
- classification
- timelines
- causality
- intent drift
- feature volatility
- domain dominance
- similarity
- disturbance and weather summaries

Most of this tier should remain pure-library and compute-on-read.

### Tier 3 — operator-facing synthesis surfaces

This tier presents derived diagnostics in forms useful to operators.

Examples include:
- keyword overview
- operator insight
- operator reasoning
- briefing surfaces
- page command center
- alert-oriented summaries

This tier may synthesize multiple Tier 2 results into one response, but it still does not become planning or execution ownership.

---

## Active Search Intelligence Registry

The numbered surfaces below are the current active registry for the implemented search-intelligence layer.
The registry exists to make the active implementation legible.
It does not mean every surface has equal strategic priority.

| Layer | Name | Primary implementation anchor | Primary delivery surface |
| --- | --- | --- | --- |
| 1 | Observation Ledger | observatory records and search-observation schema | `src/app/api/seo/keyword-targets/route.ts`, `src/app/api/seo/serp-snapshots/route.ts`, `src/app/api/seo/serp-snapshot/route.ts` |
| 2 | SERP Deltas | `src/lib/seo/serp-extraction.ts` | `src/app/api/seo/serp-deltas/route.ts` |
| 3 | Keyword Volatility | `src/lib/seo/volatility-service.ts` | `src/app/api/seo/keyword-targets/[id]/volatility/route.ts` |
| 4 | Project Volatility Summary | project-level volatility summarization logic in API layer | `src/app/api/seo/volatility-summary/route.ts`, `src/app/api/seo/projects/[projectId]/volatility-summary/route.ts` |
| 5 | Volatility Alerts | alert summarization logic in API layer | `src/app/api/seo/volatility-alerts/route.ts`, `src/app/api/seo/alerts/route.ts` |
| 6 | SERP Time Series | extraction and time-series assembly over snapshots | `src/app/api/seo/keyword-targets/[id]/serp-history/route.ts`, `src/app/api/seo/keyword-targets/[id]/feature-history/route.ts` |
| 7 | Attribution Components | `src/lib/seo/volatility-service.ts` | surfaced through Layer 3 outputs |
| 8 | Deep Diagnostics | multiple diagnostic libraries and route compositions | `src/app/api/seo/keyword-targets/[id]/volatility-breakdown/route.ts`, `src/app/api/seo/keyword-targets/[id]/volatility-spikes/route.ts`, `src/app/api/seo/keyword-targets/[id]/feature-transitions/route.ts` |
| 9 | Alerting | alert briefing and aggregation logic | `src/app/api/seo/alerts/route.ts` |
| 10 | Risk Attribution | route-level risk attribution summary logic | `src/app/api/seo/risk-attribution-summary/route.ts` |
| 11 | Operator Reasoning | `src/lib/seo/operator-insight.ts`, `src/lib/seo/reasoning/operator-reasoning.ts`, `src/lib/seo/briefing/operator-briefing.ts` | `src/app/api/seo/operator-insight/route.ts`, `src/app/api/seo/operator-reasoning/route.ts`, `src/app/api/seo/operator-briefing/route.ts` |
| 12 | Change Classification | `src/lib/seo/change-classification.ts` | `src/app/api/seo/keyword-targets/[id]/change-classification/route.ts` |
| 13 | Event Timeline | `src/lib/seo/event-timeline.ts` | `src/app/api/seo/keyword-targets/[id]/event-timeline/route.ts` |
| 14 | Event Causality | `src/lib/seo/event-causality.ts` | `src/app/api/seo/keyword-targets/[id]/event-causality/route.ts` |
| 15 | Keyword Overview | `src/lib/seo/keyword-overview.ts` | `src/app/api/seo/keyword-targets/[id]/overview/route.ts` |
| 16 | SERP Disturbance | `src/lib/seo/serp-disturbance.ts` | `src/app/api/seo/serp-disturbances/route.ts` |
| 17 | SERP Event Attribution | `src/lib/seo/serp-event-attribution.ts` | `src/app/api/seo/serp-disturbances/route.ts` |
| 18 | SERP Weather | `src/lib/seo/serp-weather.ts` | `src/app/api/seo/serp-disturbances/route.ts` |
| 19 | Weather Forecast | `src/lib/seo/serp-weather-forecast.ts` | `src/app/api/seo/serp-disturbances/route.ts` |
| 19B | Weather Momentum | `src/lib/seo/serp-weather-forecast.ts` | `src/app/api/seo/serp-disturbances/route.ts` |
| 20 | Weather Alerts | `src/lib/seo/serp-weather-alerts.ts` | `src/app/api/seo/serp-disturbances/route.ts` |
| 21 | Alert Briefing Packets | `src/lib/seo/serp-alert-briefing.ts` | `src/app/api/seo/serp-disturbances/route.ts` |
| 22 | Keyword Impact Ranking | `src/lib/seo/serp-keyword-impact.ts` | `src/app/api/seo/serp-disturbances/route.ts` |
| 23 | Alert-Affected Keyword Set | `src/lib/seo/serp-keyword-impact.ts` | `src/app/api/seo/serp-disturbances/route.ts` |
| 24 | Operator Action Hints | `src/lib/seo/serp-operator-hints.ts` | `src/app/api/seo/serp-disturbances/route.ts` |

---

## Registry Notes

### Layer 1 is the floor, not a separate brain

Layer 1 is the observatory foundation that makes the rest possible.
It is included in the registry for legibility, but it remains observatory truth rather than a secondary intelligence store.

### Some layers share delivery surfaces

Several layers are grouped into composite delivery routes such as:
- `src/app/api/seo/serp-disturbances/route.ts`
- `src/app/api/seo/keyword-targets/[id]/overview/route.ts`

That is acceptable as long as the underlying derivation remains explicit and bounded.

### Numbering is a registry, not a governance loophole

The numbered registry helps map current implementation.
It does not create permission for hidden state, hidden ownership, or undocumented mutation.

---

## Relationship to API and MCP Surfaces

The Search Intelligence Layer is exposed through:
- HTTP API routes under `src/app/api/seo/`
- MCP tools under `mcp/server/src/`
- hammer modules under `scripts/hammer/`

### API expectation

API routes should:
- resolve project scope explicitly
- enforce validation rules
- preserve non-disclosure behavior
- delegate derivation cleanly
- avoid hidden side effects

### MCP expectation

MCP surfaces should expose search intelligence as operator-facing read surfaces.
They must not bypass auth, scope, or review discipline.

### Hammer expectation

Every important search-intelligence surface should be hammer-verifiable.
A surface that is clever but unverified is still a future bug with nice posture.

---

## What the Layer Does Not Own

The Search Intelligence Layer does not own:
- project planning truth
- roadmap sequencing
- editorial workflow
- drafting workflow
- publishing workflow
- execution queues
- production asset state
- external distribution actions

It may surface inputs that inform those systems.
It must not become those systems.

---

## Verification Expectations

The active verification posture for this layer should cover:
- project-scoped non-disclosure
- deterministic ordering
- validation and error-contract behavior
- correctness of pure derivation functions
- route-level composition correctness
- transaction and event behavior where a surface includes writes
- include-gating and selective-depth behavior where composite routes support it

DB integrity is necessary but not sufficient.
The layer also needs API-level hammer coverage for its composite and operator-facing surfaces.

---

## Relationship to Active Docs

This document should be read with:
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/architecture/veda/observatory-models.md`
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/ingest-discipline.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`
- `docs/architecture/security/auth-and-actor-model.md`
- `docs/architecture/llm-assisted-operations.md`

Together these define:
- the observatory floor
- the derived interpretation layer
- the API and validation discipline
- the actor and governance rules for operator-facing delivery

---

## Maintenance Note

If future work tries to turn the Search Intelligence Layer into:
- a planning engine
- an execution engine
- a hidden write path
- a second canonical truth store
- a vaguely magical AI brain blob

that is an architectural warning sign.

The durable rule remains:
- Project V plans
- VEDA observes
- VEDA’s Search Intelligence Layer derives search diagnostics from observatory truth
- V Forge executes

This document exists so that the active implementation surface stays legible, bounded, and safe to extend.
