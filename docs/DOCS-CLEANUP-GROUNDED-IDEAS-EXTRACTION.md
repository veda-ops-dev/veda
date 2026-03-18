# Docs Cleanup Grounded Ideas Extraction

## Purpose

This document is the working extraction layer for the remaining VEDA docs cleanup pass.

It exists to preserve useful ideas from older or mixed-quality docs without treating those docs as current truth.

This is not a canonical truth document.
It is a staging document for grounded salvage.

The canonical truth remains:

- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`

---

## Working Rules

### 1. Truth layer wins

If an older document conflicts with the truth-layer docs, the truth-layer docs win.

### 2. Extract ideas, not authority

Older docs may contain useful implementation ideas, UX patterns, naming suggestions, operator flow concepts, testing notes, or structural observations.

Those ideas may be extracted.
The source doc does not become active truth just because one idea survives.

### 3. Preserve system boundaries

Use the current ecosystem framing:

- Project V plans
- VEDA observes
- V Forge executes

### 4. Do not reintroduce removed Wave 2D domains

Do not salvage ideas in ways that reintroduce removed VEDA ownership such as:

- drafts
- editorial workflow
- publishing workflow
- reply drafting
- blueprint workflow ownership
- distribution events
- owned production artifacts
- rich planning/orchestration truth

### 5. Human-gated state only

Where a doc proposes automation or LLM behavior, apply the rule:

```text
Propose -> Review -> Apply
```

### 6. Boring architecture beats exciting nonsense

Prefer:

- explicit schemas
- predictable APIs
- project-scoped isolation
- deterministic validation
- transaction safety
- append-friendly observations
- DB-enforced integrity where structurally important

---

## Root Docs Salvage Notes

These are not full extraction entries. They are grounded notes from the root-doc cleanup wave so the useful ideas are not lost to chat fog.

### `docs/VSCODE-EXTENSION-SPEC.md`
Grounded ideas worth carrying forward:
- the VS Code extension should remain an API client, never a DB client
- it should be an operator surface, not a backdoor control plane
- thin-client behavior, explicit transport boundaries, and no silent mutation are strong enduring rules
- extension commands should stay bounded and purposeful rather than becoming a generic everything sidebar

### `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
Grounded ideas worth carrying forward:
- show next valid action rather than dumping inert state
- signal-gate transitions so operators are not dropped into dead-end UX
- preserve continuity across panels and workflows
- lifecycle-facing UX likely belongs more to Project V / cross-system operator surfaces than VEDA-only docs

### `docs/First-run operator journey.md`
Grounded ideas worth carrying forward:
- first-run continuity matters
- no-project recovery should be explicit and humane
- environment clarity should be persistent and obvious
- onboarding should help the operator recover context, not just start from zero
- cross-panel continuity and proposal visibility are valuable operator-surface principles

### `docs/VISION-VEDA-COMMAND-CENTER.md`
Grounded ideas worth carrying forward:
- observe first, automate later is a useful vision principle
- operator clarity, consolidated visibility, and proposal visibility are worth preserving at the vision level
- this is vision language, not canonical architecture truth
- command-center framing must not be allowed to collapse Project V, VEDA, and V Forge into one blob

---

## Extraction Template

Use this structure when reviewing each document.

### Source doc
- path:
- current folder:
- likely date/era:

### Initial classification
- keep active
- keep but rewrite later
- move into new docs structure
- archive

### Likely system owner
- VEDA
- Project V
- V Forge
- cross-system / operator surface
- historical only

### Boundary check
- what still fits post-Wave-2D truth?
- what conflicts with current truth?
- what belongs to another system?

### Grounded ideas worth salvaging
- 

### Ideas that must be rejected
- 

### Recommended disposition
- archive as-is
- rewrite in place
- move and rewrite
- split into multiple successor docs

### Proposed target path(s)
- 

---

## Folder Pass Tracking

### 1. docs/specs/
Status: in progress

### 2. docs/site-architecture/
Status: reviewed

### 3. docs/operations-planning/
Status: reviewed

### 4. docs/operations-planning-api/
Status: reviewed

---

## High-Value Salvage Themes To Watch For

These themes are more likely to survive cleanup if they can be reframed cleanly within current boundaries.

### VEDA-aligned salvage themes
- observatory intake discipline
- source capture rules
- search observation structures
- content graph as observed structure
- project-scoped observatory partitioning
- event logging and auditability
- actor modeling for human / llm / system
- validation and error taxonomy
- operator-facing read and proposal surfaces
- MCP/API client behavior that respects bounded ownership
- infrastructure and DB hardening aligned with observability needs

### Cross-system but salvageable themes
- operator continuity
- environment clarity
- first-run recovery
- next valid action
- proposal visibility
- no silent mutation of canonical state

These may survive, but often need relocation out of VEDA-only docs.

### High-risk contamination themes
- site publishing workflows
- editorial lifecycle
- social reply drafting
- blueprint ownership
- distribution workflow
- command-center everything-engine language
- rich project lifecycle inside VEDA
- execution state disguised as observability

---

## Reviewed Docs

### Source doc
- path: `docs/operations-planning-api/01-API-ENDPOINTS-AND-VALIDATION-CONTRACTS.md`
- current folder: `docs/operations-planning-api/`
- likely date/era: v1 contract doc with strong API discipline and stale mixed-system models

### Initial classification
- keep but rewrite later
- move into new docs structure

### Likely system owner
- mixed
- strong API contract value
- stale ownership assumptions tied to removed content/distribution workflows

### Boundary check
- what still fits post-Wave-2D truth?
  - APIs enforce invariants, not UIs
  - deterministic validation, explicit error shapes, and evented writes are strong surviving principles
  - pagination, response contracts, and human-intent rules are useful contract discipline
- what conflicts with current truth?
  - assumes active VEDA ownership of entities, relationships, publish flow, and DistributionEvent
  - relation/entity vocabulary depends on removed or stale models
  - publish/editorial/distribution workflow endpoints do not match current bounded VEDA reality
- what belongs to another system?
  - execution/publish/distribution endpoints belong outside VEDA
  - generic API boundary discipline is cross-system

### Grounded ideas worth salvaging
- keep API contracts explicit and deterministic
- keep error shapes stable and human-usable
- keep validation and mutation rules enforced at the boundary
- keep irreversible actions human-intent-gated

### Ideas that must be rejected
- treating old entity/publish/distribution contract surfaces as active VEDA truth
- reviving removed relationship/distribution models through API docs

### Recommended disposition
- move and rewrite
- likely split into current API contract principles rather than preserve old endpoint inventory

### Proposed target path(s)
- `docs/architecture/api/api-contract-principles.md`

---

### Source doc
- path: `docs/operations-planning-api/02-AUTH-AND-ACTOR-MODEL.md`
- current folder: `docs/operations-planning-api/`
- likely date/era: strong governance doc with stale dashboard/content assumptions

### Initial classification
- keep but rewrite later
- move into new docs structure

### Likely system owner
- cross-system governance

### Boundary check
- what still fits post-Wave-2D truth?
  - humans have authority
  - LLMs assist but never decide
  - systems enforce but never invent intent
  - every write action should be attributable
  - no anonymous writes and no LLM-authenticated writes are strong invariants
- what conflicts with current truth?
  - examples and surface framing still rely on old dashboard/content/publish/distribution assumptions
  - some attribution examples assume old active workflow models
- what belongs to another system?
  - auth/actor model is cross-system governance, not VEDA-only domain truth

### Grounded ideas worth salvaging
- keep authority boundaries explicit
- preserve actor attribution for all writes
- keep LLM assistance as metadata/gated support rather than direct authority
- use constrained session/token scope for operator tools

### Ideas that must be rejected
- letting stale dashboard/content workflow assumptions define current architecture
- treating old surface examples as active truth without reclassification

### Recommended disposition
- move and rewrite

### Proposed target path(s)
- `docs/architecture/security/auth-and-actor-model.md`

---

### Source doc
- path: `docs/operations-planning-api/03-VALIDATION-RULES-AND-ERROR-TAXONOMY.md`
- current folder: `docs/operations-planning-api/`
- likely date/era: strong validation doctrine doc tied to stale entity/content model specifics

### Initial classification
- keep but rewrite later
- move into new docs structure

### Likely system owner
- mixed
- strong generic validation doctrine
- stale concrete rule set from old entity/content model

### Boundary check
- what still fits post-Wave-2D truth?
  - validation blocks publish, not draft
  - deterministic results, stable error codes, and human-readable failures are excellent rules
  - warning vs blocking distinction is good
  - explicit eventing on validation failure is good discipline
- what conflicts with current truth?
  - concrete validation rules are tied to old guide/concept/project/news content model
  - comparisonTargets, citation rules, and contentRef assumptions derive from stale workflow architecture
- what belongs to another system?
  - generic validation doctrine is cross-system
  - old content-model-specific rules do not belong in active VEDA truth as written

### Grounded ideas worth salvaging
- keep validation category-based and deterministic
- keep error codes stable and machine-usable
- separate blocking failures from warnings cleanly
- keep validation explainable to humans and usable by LLM assistance

### Ideas that must be rejected
- preserving old entity/content-specific validation rules as current truth
- letting stale content-model assumptions drive new validation architecture

### Recommended disposition
- move and rewrite

### Proposed target path(s)
- `docs/architecture/api/validation-and-error-taxonomy.md`
- `docs/architecture/source-provenance-and-citation.md`

---

### Source doc
- path: `docs/operations-planning-api/04-ADMIN-DASHBOARD-UI-CONTRACT.md`
- current folder: `docs/operations-planning-api/`
- likely date/era: CMS/editor/publish queue UI contract doc from mixed-era workflow architecture

### Initial classification
- archive
- salvage tiny operator-surface principles only

### Likely system owner
- mostly V Forge
- small cross-system operator-surface relevance

### Boundary check
- what still fits post-Wave-2D truth?
  - UI never bypasses API rules
  - explicit transitions, actionable validation feedback, and visible event timelines are useful principles
  - authenticated preview/noindex discipline is good
- what conflicts with current truth?
  - custom CMS/editor/publish queue is not VEDA ownership
  - source inbox/entity library/entity editor/publish queue flow depends on stale content workflow assumptions
  - references stale relationship vocabulary file
- what belongs to another system?
  - most of this belongs to V Forge execution/admin UI
  - tiny operator-surface principles can be reused elsewhere

### Grounded ideas worth salvaging
- make UI transitions explicit
- keep validation feedback actionable
- show event history visibly in operator surfaces
- ensure preview remains gated and non-public

### Ideas that must be rejected
- treating CMS/editor/publish queue contract as active VEDA truth
- reviving old content workflow ownership through UI contract language

### Recommended disposition
- archive or split hard
- likely move to V Forge candidate archive after extraction

### Proposed target path(s)
- `docs/archive/v-forge-candidates/04-ADMIN-DASHBOARD-UI-CONTRACT.md`

---

### Source doc
- path: `docs/operations-planning-api/05-VIDEO-SEO-WORKFLOW-CONTRACT.md`
- current folder: `docs/operations-planning-api/`
- likely date/era: execution-side YouTube/video workflow contract

### Initial classification
- archive
- salvage grounded ideas for V Forge review

### Likely system owner
- V Forge

### Boundary check
- what still fits post-Wave-2D truth?
  - humans publish, systems prepare is strong
  - tasks should be discrete, reviewable, and optional
  - no auto-posting and no silent external mutation are good rules
  - keyword files treated as raw input rather than truth is useful
- what conflicts with current truth?
  - this is plainly execution workflow, not VEDA observability truth
  - assumes active Video entity / execution-side workflow in this repo
- what belongs to another system?
  - video SEO workflow, metadata preparation, and YouTube application belong to V Forge or future execution workflow docs

### Grounded ideas worth salvaging
- keep task outputs reviewable and manually accepted
- preserve manual external platform application
- treat keyword files as raw inputs, not authority
- keep execution traceability without auto-posting

### Ideas that must be rejected
- treating video SEO workflow as active VEDA doc
- letting execution workflow concepts re-enter observability ownership

### Recommended disposition
- archive in a V Forge candidate bucket after extraction

### Proposed target path(s)
- `docs/archive/v-forge-candidates/05-VIDEO-SEO-WORKFLOW-CONTRACT.md`

---

### Source doc
- path: `docs/specs/COMPETITOR-CONTENT-OBSERVATORY.md`
- current folder: `docs/specs/`
- likely date/era: post-Wave-2D competitor-observation concept doc with useful SERP-led framing and some speculative model inflation

### Initial classification
- move into new docs structure
- archive legacy source after successor is established

### Likely system owner
- VEDA

### Boundary check
- what still fits post-Wave-2D truth?
  - competitor observation belongs in VEDA when it stays observation-first
  - SERP-led selection is strong because it starts from observed search reality instead of blind crawling
  - structural signals such as schema, headings, citations, and internal-link patterns are useful observational inputs
  - competitor intelligence should complement the project content graph rather than replace it
- what conflicts with current truth?
  - the legacy doc speaks too casually about new dedicated models as though they are ready to exist without current schema pressure
  - strategy-recommendation language needs stricter boundary control so VEDA does not quietly absorb Project V planning authority
  - phased expansion toward domain-graph coverage can become speculative architecture inflation if treated as default
- what belongs to another system?
  - deciding what the project should build because of competitor findings belongs to Project V
  - producing drafts or publish responses belongs to V Forge

### Grounded ideas worth salvaging
- keep competitor observation SERP-led by default
- focus on pages that actually appear in tracked search reality
- observe structural signals, not full-site mirrors
- keep competitor observations separate from the owned project content graph
- allow later comparison between competitor structure, project structure, and observed search outcomes through derived read surfaces

### Ideas that must be rejected
- treating speculative dedicated competitor models as current schema truth
- allowing competitor observation to drift into strategy ownership or execution workflow
- assuming broad crawl expansion is the default instead of a justified later step
- turning competitive observation into a hidden background scraping subsystem

### Recommended disposition
- successor doc created in the active observatory spine
- legacy doc can move to archive during the cleanup archive pass

### Proposed target path(s)
- `docs/systems/veda/observatory/competitor-observation.md`
- `docs/archive/post-wave2-cleanup/COMPETITOR-CONTENT-OBSERVATORY.md`

---
### Source doc
- path: `docs/site-architecture/07-CITATION-AND-SOURCE-USAGE.md`
- current folder: `docs/site-architecture/`
- likely date/era: site-surface citation rules doc with strong provenance discipline and stale Wiki/Main Site framing

### Initial classification
- move into new docs structure
- archive legacy source after successor is established

### Likely system owner
- mixed
- provenance belongs to VEDA, output citation behavior belongs to V Forge, and the surviving rule set is best expressed as shared architecture

### Boundary check
- what still fits post-Wave-2D truth?
  - citations should support factual claims rather than credibility theater
  - time-sensitive claims need explicit sourcing and temporal qualification
  - source quality hierarchy is useful when kept boring and evidence-oriented
  - SourceItem-backed provenance is a strong surviving rule
- what conflicts with current truth?
  - Wiki and Main Site framing is too tied to stale site-surface assumptions
  - the doc talks like citation behavior is one surface-owned ruleset instead of a bounded cross-system contract
  - VEDA should not own output rendering rules just because it owns provenance
- what belongs to another system?
  - output-facing citation rendering belongs to V Forge
  - captured source provenance belongs to VEDA
  - shared rules about claim support and evidence discipline belong in shared architecture

### Grounded ideas worth salvaging
- preserve the rule that citations support claims rather than decorate credibility
- require citations for versioned, factual, benchmarked, quoted, or time-sensitive claims
- avoid cluttering conceptual explanations with unnecessary references
- keep primary technical sources above commentary and weak secondary summaries
- preserve a defensible path between captured source evidence and output-facing citation use

### Ideas that must be rejected
- keeping stale Wiki/Main Site framing as active authority
- letting a site-architecture doc define cross-system provenance ownership
- treating every explanation as citation-worthy by default

### Recommended disposition
- successor doc created in shared architecture
- legacy source can live in archive as historical input only

### Proposed target path(s)
- `docs/architecture/source-provenance-and-citation.md`
- `docs/archive/post-wave2-cleanup/07-CITATION-AND-SOURCE-USAGE.md`

---
### Source doc
- path: `docs/site-architecture/08-SEO-AND-RESEARCH-HOOKS.md`
- current folder: `docs/site-architecture/`
- likely date/era: site-planning SEO guidance doc with strong anti-volume-chasing discipline and stale site/wiki lock-language

### Initial classification
- archive
- rehome as Project V candidate material rather than active VEDA or shared-architecture truth

### Likely system owner
- Project V

### Boundary check
- what still fits post-Wave-2D truth?
  - SEO should inform prioritization rather than dictate structure
  - search research is useful for phrasing, ambiguity detection, and prioritization
  - volume chasing, trend chasing, and clickbait drift are rightly rejected
  - long-term coherence matters more than short-term traffic spikes
- what conflicts with current truth?
  - page-type and site/wiki framing belong to stale site-planning assumptions rather than current bounded-system docs
  - language about locked architectural/content decisions is too tied to an old planning surface
  - some references to knowledge-graph coherence as a site-planning rule are not the right active authority surface for current repo truth
- what belongs to another system?
  - prioritization rules based on observed search opportunity belong to Project V
  - observatory evidence feeding those rules belongs to VEDA
  - output execution in response to those priorities belongs to V Forge

### Grounded ideas worth salvaging
- keep the rule that SEO informs prioritization but should not dictate system structure
- preserve anti-volume-chasing and anti-clickbait discipline
- use search research to refine wording, intent understanding, and prioritization of real concepts
- treat tools as optional and replaceable rather than architectural authorities

### Ideas that must be rejected
- keeping stale site/wiki content-model framing as active truth
- treating SEO tool behavior as an architecture-defining force
- letting this doc remain in VEDA-adjacent site architecture when its real surviving value is Project V prioritization guidance

### Recommended disposition
- archive to Project V candidate bucket
- preserve its grounded ideas for future Project V planning/prioritization docs

### Proposed target path(s)
- `docs/archive/project-v-candidates/08-SEO-AND-RESEARCH-HOOKS.md`

---
### Source doc
- path: `docs/specs/CONTENT-GRAPH-DATA-MODEL.md`
- current folder: `docs/specs/`
- likely date/era: early content-graph structural model doc with useful graph-floor thinking and strong phase-based boundary drift later in the file

### Initial classification
- move into new docs structure
- archive legacy source after successor is established

### Likely system owner
- VEDA

### Boundary check
- what still fits post-Wave-2D truth?
  - the content graph should model the project’s observed structural state rather than external search reality
  - compute-on-read derived analysis is the right default for graph interpretation
  - topic coverage, entity coverage, archetype distribution, internal linking, and schema usage are valid structural concerns
  - project isolation and deterministic behavior are good surviving architectural rules
- what conflicts with current truth?
  - the doc uses legacy language like domination loop that encourages strategy and execution creep
  - future phases drift into execution planning objects such as ProposedPage, CoverageGap, and ExecutionPlan, which do not belong in VEDA
  - competitor-observation ideas are useful, but they should not be smuggled into the owned content graph boundary
  - page publishing state language needs tighter handling so observed structure is not mistaken for production workflow truth
- what belongs to another system?
  - deciding what should be produced because of graph analysis belongs to Project V
  - producing outputs in response to graph findings belongs to V Forge
  - external competitor observation belongs in VEDA as a separate observatory concern, not as owned graph truth

### Grounded ideas worth salvaging
- keep the content graph as the structural observatory floor for project surfaces
- keep explicit graph objects for surfaces, sites, pages, topics, entities, internal links, and schema usage
- keep compute-on-read interpretation above the graph rather than storing speculative derived scores as canonical truth
- preserve the rule that the graph stores structure, not planning or execution authority

### Ideas that must be rejected
- execution-planning phases inside VEDA
- strategy-language that turns structural observation into roadmap authority
- collapsing competitor observation into the owned content graph
- treating the graph as a CMS or publish-workflow state engine

### Recommended disposition
- successor doc already created in the active VEDA architecture spine
- legacy source can remain archived as historical input only

### Proposed target path(s)
- `docs/architecture/veda/content-graph-model.md`
- `docs/architecture/veda/observatory-models.md`
- `docs/archive/post-wave2-cleanup/CONTENT-GRAPH-DATA-MODEL.md`

---
### Source doc
- path: `docs/specs/VEDA-GRAPH-MODEL.md`
- current folder: `docs/specs/`
- likely date/era: multi-graph framing doc with useful observatory-layer thinking and heavy strategy/execution inflation in the later synthesis stack

### Initial classification
- move into new docs structure
- archive legacy source after successor docs are established

### Likely system owner
- mixed
- useful VEDA observatory framing mixed with stale strategy and execution layering

### Boundary check
- what still fits post-Wave-2D truth?
  - VEDA can be understood as multiple complementary observatory views rather than one flat record pile
  - search observation, project content structure, competitor observation, and citation-oriented observation can be treated as distinct observational lenses
  - deterministic outputs, compute-on-read analytics, transactional mutations, and project isolation are strong surviving rules
- what conflicts with current truth?
  - the project content graph is described as explicitly stewarded through VEDA workflows rather than as observed structural state, which risks ownership drift
  - the strategy synthesis, execution planning, tactics, and SEO lab stack clearly crosses out of VEDA observability ownership
  - the graph set is presented too much like a grand unified brain rather than bounded observatory domains with derived read surfaces
  - citation-observatory concepts remain speculative and should not be treated as active schema truth
- what belongs to another system?
  - strategy synthesis and deciding what should happen next belong to Project V
  - execution planning and tactic application belong to V Forge
  - any future citation-observation layer would need explicit classification before becoming active VEDA truth

### Grounded ideas worth salvaging
- preserve the notion that VEDA may contain multiple observational lenses with different entities and signals
- keep the content graph, competitor observation, and search observation as separate but comparable observational domains
- keep cross-graph comparison as a derived intelligence activity rather than a new canonical truth layer
- preserve the boring invariants: deterministic outputs, compute-on-read, evented mutation, and project isolation

### Ideas that must be rejected
- treating VEDA as a strategy-plus-execution stack
- allowing the content graph to become a workflow-steered planning surface
- presenting speculative citation-observatory ideas as active authority
- collapsing multiple observatory domains into a magical everything graph with hidden ownership

### Recommended disposition
- successor coverage already exists across the active observatory and architecture spine
- archive legacy source as historical input only

### Proposed target path(s)
- `docs/architecture/veda/observatory-models.md`
- `docs/architecture/veda/content-graph-model.md`
- `docs/systems/veda/observatory/competitor-observation.md`
- `docs/archive/post-wave2-cleanup/VEDA-GRAPH-MODEL.md`

---
### Source doc
- path: `docs/specs/VEDA-BRAND-SURFACE-REGISTRY.md`
- current folder: `docs/specs/`
- likely date/era: declared-surface identity doc with useful owned-vs-observed distinctions and strong Project V initialization drift

### Initial classification
- archive
- rehome as Project V candidate material rather than active VEDA truth

### Likely system owner
- Project V

### Boundary check
- what still fits post-Wave-2D truth?
  - project-scoped surface identity matters beyond project ID alone
  - durable identifiers for owned surfaces are useful and should not rely only on mutable display names
  - owned brand surfaces must remain distinct from observed external ecosystem surfaces
  - multiple accounts or channels on the same platform are a real modeling concern
- what conflicts with current truth?
  - the doc treats declared surface registry as part of blueprinting and project initialization, which places core ownership in Project V rather than VEDA
  - it speaks too directly about official operated surfaces as canonical registry truth inside a VEDA-branded doc
  - workflow sequencing around project creation and blueprint approval is planning-state language, not observatory ownership
- what belongs to another system?
  - declared owned-surface registry and blueprint approval belong to Project V
  - observed structural state of project content surfaces belongs to VEDA through docs like `docs/architecture/veda/content-graph-model.md`
  - observed external competitor surfaces remain separate VEDA observatory concerns

### Grounded ideas worth salvaging
- preserve the distinction between owned project surfaces and observed external surfaces
- preserve durable surface identity rather than mutable display-name identity
- preserve support for multiple accounts or channels on a single platform
- preserve the idea that project identity alone is not enough to model surface-level reality cleanly

### Ideas that must be rejected
- keeping project-initialization and blueprint workflow inside active VEDA truth
- treating declared owned-surface registry as the same thing as observed content-surface state
- allowing a VEDA-branded doc to carry Project V planning ownership by inertia

### Recommended disposition
- archive to Project V candidate bucket
- preserve identity ideas as grounded input for future Project V docs and as supporting context for active VEDA content-surface docs

### Proposed target path(s)
- `docs/archive/project-v-candidates/VEDA-BRAND-SURFACE-REGISTRY.md`
- `docs/architecture/veda/content-graph-model.md`
- `docs/architecture/veda/observatory-models.md`

---
### Source doc
- path: `docs/operations-planning/07-ADMIN-DASHBOARD-SCOPE.md`
- current folder: `docs/operations-planning/`
- likely date/era: custom admin-dashboard/CMS scope doc from mixed workflow architecture with a few durable operator-surface principles

### Initial classification
- archive
- salvage tiny operator-surface principles only

### Likely system owner
- mostly V Forge
- small cross-system operator-surface relevance

### Boundary check
- what still fits post-Wave-2D truth?
  - dashboard or operator surfaces should not bypass workflow and API rules
  - validation feedback should be visible and actionable
  - event history visibility is a durable operator-surface principle
  - publishing remains human-gated and preview should remain non-public
- what conflicts with current truth?
  - custom CMS/admin dashboard scope is not active VEDA ownership
  - draft library, entity editor, and publish queue language depends on stale content-entity and publish workflow assumptions
  - source promotion into draft entities and relationship editing are tied to removed or reclassified workflow surfaces
- what belongs to another system?
  - draft editing, publish queue, entity editing, and admin dashboard workflow belong to V Forge
  - tiny UX principles around feedback, visibility, and workflow gating can inform operator-surface docs elsewhere

### Grounded ideas worth salvaging
- keep validation failures specific and actionable
- keep success and error feedback visible in operator tools
- show event history clearly where operator review matters
- preserve non-public preview discipline and human-gated publishing

### Ideas that must be rejected
- treating custom CMS/admin dashboard scope as active VEDA truth
- reviving draft/publish workflow ownership through dashboard language
- letting stale entity-editor and publish-queue assumptions define current architecture

### Recommended disposition
- archive to V Forge candidate bucket
- retain only tiny operator-surface salvage in the extraction layer

### Proposed target path(s)
- `docs/archive/v-forge-candidates/07-ADMIN-DASHBOARD-SCOPE.md`

---
### Source doc
- path: `docs/specs/CONTENT-GRAPH-PHASES.md`
- current folder: `docs/specs/`
- likely date/era: phased implementation map for the content graph with useful sequencing discipline and obvious late-phase planning/execution drift

### Initial classification
- archive
- salvage phase discipline only

### Likely system owner
- mixed
- early phases support VEDA observatory work, later phases drift into Project V planning and broader cross-system execution concerns

### Boundary check
- what still fits post-Wave-2D truth?
  - phased discipline is useful: start with a narrow structural floor, verify it, and extend only when justified
  - Phase 1 structural graph focus is compatible with current VEDA content-graph authority
  - compute-on-read derived interpretation remains the right default for graph intelligence
  - competitor observation can align with the content graph later without collapsing boundaries
- what conflicts with current truth?
  - domination-loop language encourages strategy inflation inside VEDA
  - Phase 4 execution-planning objects do not belong in active VEDA ownership
  - Phase 5 cross-surface authority expansion is too speculative to count as active truth
  - the doc presents future sequencing as if it were still the governing roadmap for current architecture
- what belongs to another system?
  - deciding what should be built because of graph findings belongs to Project V
  - execution-side response workflows belong to V Forge
  - any future cross-surface authority planning would require explicit cross-system classification rather than automatic inheritance from this doc

### Grounded ideas worth salvaging
- keep the rule that Phase 1 should stay minimal and structurally useful
- extend graph capability in layers only after the foundation proves stable
- keep compute-on-read derived intelligence rather than persisting speculative scores
- treat competitor observation as a separate observatory concern that can later be compared against the owned content graph

### Ideas that must be rejected
- execution-planning phases inside active VEDA content-graph guidance
- treating old phase maps as current roadmap authority
- speculative cross-surface expansion as active architectural commitment
- strategy-language that turns structural observability into execution ownership

### Recommended disposition
- archive in post-Wave-2D cleanup bucket
- retain phase-discipline salvage in the extraction layer rather than creating a new active phase doc right now

### Proposed target path(s)
- `docs/archive/post-wave2-cleanup/CONTENT-GRAPH-PHASES.md`
- `docs/architecture/veda/content-graph-model.md`
- `docs/architecture/veda/observatory-models.md`
- `docs/systems/veda/observatory/competitor-observation.md`

---
### Source doc
- path: `docs/specs/VSCODE-EXTENSION-PHASE-1.md`
- current folder: `docs/specs/`
- likely date/era: legacy VS Code phase-1 implementation contract with useful thin-client discipline and stale implementation-authority assumptions

### Initial classification
- archive
- preserve grounded implementation principles through successor docs

### Likely system owner
- cross-system operator surface

### Boundary check
- what still fits post-Wave-2D truth?
  - the extension should remain a thin client shell
  - no direct DB access, no local business logic, and no silent mutation remain strong rules
  - project context visibility, lightweight activation, and read-oriented first phases are good operator-surface constraints
  - VS Code should remain an observatory and repo-native operator surface, not a generic CMS shell
- what conflicts with current truth?
  - the document still presents itself as an active implementation contract rather than legacy input
  - related-doc references include stale or archived authority surfaces
  - some implementation framing assumes the legacy extension surface is still the central build target rather than a reference input to successor docs
- what belongs to another system?
  - active VS Code implementation truth now belongs under `docs/systems/operator-surfaces/vscode/`
  - planning ownership and execution ownership remain outside this doc’s authority and stay bounded by Project V and V Forge

### Grounded ideas worth salvaging
- keep thin-client discipline
- keep read-first scope and explicit project context visibility
- keep lightweight activation and boring error handling
- keep VS Code from turning into a generic content admin surface

### Ideas that must be rejected
- treating this legacy phase spec as the current implementation authority
- letting archived related-doc references define active extension scope
- allowing implementation detail docs to blur bounded ownership

### Recommended disposition
- archive in post-Wave-2D cleanup bucket
- retain its surviving ideas through the VS Code successor docs

### Proposed target path(s)
- `docs/archive/post-wave2-cleanup/VSCODE-EXTENSION-PHASE-1.md`
- `docs/systems/operator-surfaces/vscode/phase-1-spec.md`

---
### Source doc
- path: `docs/specs/VSCODE-EXTENSION-ROADMAP.md`
- current folder: `docs/specs/`
- likely date/era: legacy VS Code roadmap doc with useful future-surface sequencing ideas and stale extension-centrality assumptions

### Initial classification
- archive
- preserve grounded sequencing ideas through successor docs

### Likely system owner
- cross-system operator surface

### Boundary check
- what still fits post-Wave-2D truth?
  - phased sequencing for VS Code surface work can be useful when attached to the successor spine
  - proposal visibility, continuity, and discoverability remain valid operator-surface concerns
  - future layers should only extend the successor surface after the foundation is stable
- what conflicts with current truth?
  - the document still acts like the legacy extension roadmap is active authority
  - related-doc references include stale surfaces and archived sources
  - roadmap language can overstate the legacy implementation as the product center instead of a successor-input surface
- what belongs to another system?
  - active roadmap direction for this lane now belongs in `docs/systems/operator-surfaces/vscode/roadmap.md`
  - planning ownership and execution ownership remain bounded elsewhere

### Grounded ideas worth salvaging
- keep phased sequencing disciplined and incremental
- keep discoverability, continuity, and proposal visibility as real roadmap concerns
- keep successor work attached to explicit operator-surface docs rather than legacy implementation gravity

### Ideas that must be rejected
- treating the legacy extension roadmap as current authority
- allowing stale references and assumptions to keep shadow control over the VS Code lane
- letting the legacy surface define architecture through inertia

### Recommended disposition
- archive in post-Wave-2D cleanup bucket
- retain its surviving ideas through the VS Code successor roadmap doc

### Proposed target path(s)
- `docs/archive/post-wave2-cleanup/VSCODE-EXTENSION-ROADMAP.md`
- `docs/systems/operator-surfaces/vscode/roadmap.md`

---
### Source doc
- path: `docs/specs/CONTENT-GRAPH-SYNC-CONTRACT.md`
- current folder: `docs/specs/`
- likely date/era: compact implementation-facing sync note for projecting owned site structure into the content-graph lane

### Initial classification
- archive
- preserve only grounded implementation ideas as historical input

### Likely system owner
- VEDA / implementation-facing historical input

### Boundary check
- what still fits post-Wave-2D truth?
  - explicit, deterministic sync/update behavior is preferable to fuzzy background mutation
  - websites can remain the source of rendered content while VEDA stores observed structural representation
  - canonical page identity should stay URL-centered rather than file-path-centered
  - explicit payload shapes for pages, links, and schema usage are sensible if a future sync contract is ever formalized
- what conflicts with current truth?
  - this doc presents a sync contract as if it were an active authority surface, but no current successor sync contract exists
  - the content graph is active architecture truth, but the exact website-to-VEDA sync mechanism is not currently established as a live contract doc
  - implementation-specific payload examples are too thin to count as durable architecture without a broader current contract around auth, validation, and ownership
- what belongs to another system?
  - rendered website implementation remains outside VEDA ownership
  - VEDA owns the observed structural model, not the entire rendering stack

### Grounded ideas worth salvaging
- keep any future sync/update contract explicit and deterministic
- keep URL-based page identity central
- keep pages, links, and schema usage as the obvious structural payload floor
- keep background-free, operator-governed mutation discipline

### Ideas that must be rejected
- treating this tiny legacy note as active sync-contract authority
- assuming a website sync path is already a current governed contract just because the content graph exists
- letting implementation payload examples masquerade as complete active architecture

### Recommended disposition
- archive in post-Wave-2D cleanup bucket
- retain the doc only as historical input in case a future explicit sync contract is intentionally created

### Proposed target path(s)
- `docs/archive/post-wave2-cleanup/CONTENT-GRAPH-SYNC-CONTRACT.md`
- `docs/architecture/veda/content-graph-model.md`
- `docs/architecture/veda/observatory-models.md`

---
### Source doc
- path: `docs/operations-planning/PHASE-1-OPTION-A-VERIFICATION-CHECKLIST.md`
- current folder: `docs/operations-planning/`
- likely date/era: detailed verification checklist for the old X capture -> reply draft -> manual post loop

### Initial classification
- archive
- historical checkpoint only

### Likely system owner
- V Forge / historical

### Boundary check
- what still fits post-Wave-2D truth?
  - no autonomous posting remains a good enduring rule
  - human-gated review and evented state changes remain structurally sound principles
  - implementation checklists can be useful historical evidence for what was once verified
- what conflicts with current truth?
  - the entire checklist depends on dead reply-draft and DraftArtifact-centered workflow surfaces removed from active VEDA truth
  - route, table, and event assumptions belong to a stale X operator loop that no longer defines current architecture
  - this is a checkpoint artifact, not an active architecture, workflow, or system contract document
- what belongs to another system?
  - any future social reply or draft workflow would belong in V Forge, not active VEDA observability truth

### Grounded ideas worth salvaging
- preserve the no-auto-posting principle
- preserve human-gated review for externally visible actions
- preserve the idea that verification checkpoints should test event side effects and operator flow explicitly

### Ideas that must be rejected
- reviving the dead X reply-draft loop as if it were current work
- treating DraftArtifact-era checklists as active authority
- keeping this file in the live operations-planning folder once its owning workflow is gone

### Recommended disposition
- archive to V Forge candidate bucket
- retain only as historical checkpoint evidence for the dead loop

### Proposed target path(s)
- `docs/archive/v-forge-candidates/PHASE-1-OPTION-A-VERIFICATION-CHECKLIST.md`

---
## Intended Outcome

By the end of this pass, each remaining legacy or semi-legacy doc should have one of four outcomes:

1. archived
2. retained but explicitly marked for rewrite
3. moved into the new docs structure
4. mined for grounded ideas and replaced by cleaner successor docs

The point is not to preserve old documents.
The point is to preserve valid ideas without letting stale architecture crawl back out of the walls.

---

## SIL Archive Resolution Notes

### Resolution summary

The active authority surface for the Search Intelligence Layer is now:
- `docs/architecture/veda/search-intelligence-layer.md`
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/ingest-discipline.md`
- current implementation under `src/lib/seo/`, `src/app/api/seo/`, `mcp/server/src/`, and `scripts/hammer/`

The following older SIL specs were archived because they continued to exert shadow-authority pressure while carrying stale implementation state, stale status claims, or superseded sequencing assumptions:
- `docs/archive/post-wave2-cleanup/SIL-1-OBSERVATION-LEDGER.md`
- `docs/archive/post-wave2-cleanup/SIL-1-INGEST-DISCIPLINE.md`
- `docs/archive/post-wave2-cleanup/SIL-8-PLAN.md`
- `docs/archive/post-wave2-cleanup/SIL-9-ALERTING-PLAN.md`

### Grounded ideas preserved
- search intelligence remains a VEDA-owned derived layer over observatory records
- compute-on-read remains the default posture unless materialization is clearly justified
- deterministic ordering, project scoping, and non-disclosure remain mandatory
- operator-facing search diagnostics should stay thin-route and pure-library oriented
- numbered SIL surfaces are useful as an implementation registry, not as a second truth surface
- alerting and volatility-oriented interpretation remain derived read surfaces, not planning or execution ownership

### Ideas explicitly rejected
- treating old SIL specs as active binding authority
- preserving obsolete implementation-state claims inside active docs
- allowing the numbered SIL model to become a planning, execution, or autonomous workflow system
- keeping shadow truth in `docs/specs/` once active architecture and implementation documentation exist elsewhere

---

## VS Code Extension Reclassification Notes

### Resolution summary

The current implementation under `vscode-extension/` is now treated as:
- a legacy implementation reference
- a grounded idea source
- a successor-input surface

It is not active operator-surface architecture truth.
It should not be modernized in place by default.

### Grounded ideas preserved
- the extension should remain an API client, never a DB client
- it should remain an operator surface, not a backdoor
- environment clarity is worth preserving
- first-run recovery matters
- next-valid-action guidance is strong operator UX discipline
- cross-panel continuity is valuable when ownership stays explicit
- command/action surfaces should stay bounded rather than becoming a generic everything shell

### Ideas explicitly rejected
- assuming the current `vscode-extension/` implementation is the product shape to rehabilitate
- letting legacy extension UX or route assumptions define active architecture
- treating stale extension docs as operator-surface authority without reclassification
- modernizing the legacy surface in place before active operator-surface docs exist

### Active direction
- define operator-surface architecture first
- classify which bounded system owns which operator-facing capabilities
- consult the legacy extension only as evidence and grounded salvage
- design any successor extension only after the active architecture is explicit

---

## Operator Surfaces Successor Resolution Notes

### Resolution summary

The active authority surface for operator-surface architecture now includes:
- `docs/systems/operator-surfaces/overview.md`
- `docs/systems/operator-surfaces/mcp/overview.md`
- `docs/systems/operator-surfaces/mcp/tooling-principles.md`
- `docs/systems/operator-surfaces/browser-capture/scope-and-behavior.md`
- `docs/systems/operator-surfaces/browser-capture/ingestion-architecture.md`
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/systems/operator-surfaces/vscode/repo-native-workflow.md`
- `docs/systems/operator-surfaces/vscode/phase-1-spec.md`
- `docs/systems/operator-surfaces/vscode/roadmap.md`

The following legacy docs remain useful only as grounded historical inputs or legacy-reference surfaces:
- `docs/archive/post-wave2-cleanup/VEDA-MCP-TOOLS-SPEC.md`
- `docs/archive/post-wave2-cleanup/VEDA-OPERATOR-SURFACES.md`
- `docs/archive/post-wave2-cleanup/VEDA-VSCODE-OPERATOR-GAP-MAP.md`
- `docs/archive/post-wave2-cleanup/VEDA-REPO-NATIVE-WORKFLOW.md`
- `docs/archive/post-wave2-cleanup/VSCODE-EXTENSION-PHASE-1.md`
- `docs/archive/post-wave2-cleanup/VSCODE-EXTENSION-ROADMAP.md`
- `docs/archive/post-wave2-cleanup/02-CHROME-EXTENSION-SCOPE-AND-BEHAVIOR.md`
- `docs/archive/post-wave2-cleanup/08-EXTENSION-INGESTION-ARCHITECTURE.md`
- `docs/VSCODE-EXTENSION-SPEC.md`
- `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
- `docs/First-run operator journey.md`
- the current `vscode-extension/` implementation as legacy-reference only

### Grounded ideas preserved
- operator surfaces are delivery surfaces, not owners
- MCP should remain an API-governed bridge to bounded system capabilities, not a control plane
- browser capture should remain human-triggered intake, not posting or execution behavior
- repo-native workflow is a real operator lane, but it must remain distinct from canonical system-state mutation
- thin-client discipline, explicit project/environment context, and no silent mutation remain strong successor rules
- proposal visibility is valuable, but proposal authority must remain review-gated
- continuity, discoverability, empty-state clarity, and next-valid-action guidance are durable operator UX principles

### Ideas explicitly rejected
- treating the legacy `vscode-extension/` implementation as active operator-surface truth
- letting old VS Code panel or command shapes define current architecture by repetition
- turning browser capture into a draft/reply/execution workflow by default
- conflating local repo changes with canonical system-state mutation
- letting MCP grow into a magical everything-interface that hides ownership
- modernizing legacy extension surfaces in place before successor-surface architecture is explicit

### Active direction
- use `docs/systems/operator-surfaces/overview.md` as the framing anchor for all operator-surface work
- use the MCP, browser-capture, and VS Code successor docs above as the active reconstruction spine
- consult legacy docs only for grounded salvage, friction evidence, and historical implementation clues
- attach future fixes and phases to the successor docs by full path rather than to stale legacy surfaces


## Observatory Intake and Audit Successor Resolution Notes

### Resolution summary

The active authority surface for observatory intake and audit behavior now includes:
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/event-auditability.md`

The following legacy docs were archived after successor docs were established:
- `docs/archive/post-wave2-cleanup/01-SOURCE-CAPTURE-AND-INBOX.md`
- `docs/archive/post-wave2-cleanup/05-EVENT-LOGGING-AND-AUDITABILITY.md`

### Grounded ideas preserved
- source capture remains provenance-first observatory intake
- inbox and triage behavior remain explicit and eventable rather than hidden automation
- event logging remains append-only observatory history for durable state changes
- actor attribution, project scope, and atomic state-plus-event behavior remain mandatory

### Ideas explicitly rejected
- preserving PsyMetric-era naming and stale examples as active truth
- treating intake or event docs as editorial or production workflow surfaces
- letting old mixed workflow assumptions keep shadow authority once successor docs exist

### Active direction
- use `docs/systems/veda/observatory/source-capture-and-inbox.md` and `docs/systems/veda/observatory/event-auditability.md` as the active observatory authority
- consult archived legacy docs only for constrained historical salvage
- attach future observatory intake and audit fixes to the successor docs by full path

---
## Shared Architecture Successor Resolution Notes

### Resolution summary

The active authority surface for the shared architecture spine now includes:
- `docs/architecture/llm-assisted-operations.md`
- `docs/architecture/platform/deployment-infrastructure-baseline.md`
- `docs/architecture/platform/vercel-neon-prisma.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/security/auth-and-actor-model.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`
- `docs/architecture/source-provenance-and-citation.md`

The following legacy docs were archived after successor docs were established:
- `docs/archive/post-wave2-cleanup/03-LLM-ASSISTED-OPERATIONS.md`
- `docs/archive/post-wave2-cleanup/06-DEPLOYMENT-AND-INFRASTRUCTURE-BASELINE.md`
- `docs/archive/post-wave2-cleanup/08-VERCEL-NEON-PRISMA-INTEGRATION.md`
- `docs/archive/post-wave2-cleanup/01-API-ENDPOINTS-AND-VALIDATION-CONTRACTS.md`
- `docs/archive/post-wave2-cleanup/02-AUTH-AND-ACTOR-MODEL.md`
- `docs/archive/post-wave2-cleanup/03-VALIDATION-RULES-AND-ERROR-TAXONOMY.md`
- `docs/archive/post-wave2-cleanup/07-CITATION-AND-SOURCE-USAGE.md`

### Grounded ideas preserved
- LLMs remain bounded assistants under propose-review-apply discipline
- deployment and platform guidance stays boring, explicit, and invariant-respecting
- API contracts remain deterministic, explicit, and boundary-enforcing
- auth and actor modeling remain human-authority-first with attributable writes
- validation and error taxonomy remain stable, explainable, and machine-usable
- provenance and citation rules remain explicit about the split between VEDA evidence and V Forge output rendering

### Ideas explicitly rejected
- preserving stale content-workflow examples as active architecture truth
- allowing old mixed contract docs to keep shadow authority after successor docs exist
- treating legacy platform and API docs as current architecture instead of historical inputs

### Active direction
- use the shared-architecture successor docs above as the active authority surface
- consult archived legacy docs only for grounded salvage or historical comparison
- attach future architecture guidance to successor docs by full path rather than to the archived sources

---



## Content Graph Successor Resolution Notes

### Resolution summary

The active authority surface for the content graph now includes:
- `docs/architecture/veda/content-graph-model.md`
- `docs/architecture/veda/observatory-models.md`
- `docs/architecture/veda/SCHEMA-REFERENCE.md`

The following legacy doc was archived after successor docs were established:
- `docs/archive/post-wave2-cleanup/CONTENT-GRAPH-DATA-MODEL.md`

### Grounded ideas preserved
- the content graph remains the project-scoped structural observatory floor for owned content surfaces
- graph interpretation remains compute-on-read by default rather than materialized strategy sludge
- explicit graph objects and junctions remain preferable to hidden relationship magic
- graph structure stays separate from planning and execution ownership

### Ideas explicitly rejected
- execution-planning phases inside VEDA content-graph docs
- turning the graph into a CMS, publish workflow engine, or roadmap authority system
- blending external competitor observation into owned graph truth without explicit reclassification

### Active direction
- use `docs/architecture/veda/content-graph-model.md` as the active content-graph successor doc
- use `docs/architecture/veda/observatory-models.md` and `docs/architecture/veda/SCHEMA-REFERENCE.md` as supporting authority
- consult the archived legacy doc only for constrained historical salvage

---

## Multi-Observatory Successor Resolution Notes

### Resolution summary

The active authority surface for VEDA multi-observatory framing now includes:
- `docs/architecture/veda/observatory-models.md`
- `docs/architecture/veda/content-graph-model.md`
- `docs/systems/veda/observatory/competitor-observation.md`
- `docs/architecture/veda/search-intelligence-layer.md`

The following legacy doc was archived after successor coverage was established:
- `docs/archive/post-wave2-cleanup/VEDA-GRAPH-MODEL.md`

### Grounded ideas preserved
- VEDA can be understood as several bounded observational lenses rather than one undifferentiated subsystem
- cross-observatory comparison is useful when it remains derived, read-oriented, and project-scoped
- search observation, content-graph structure, and competitor observation remain distinct but compatible observatory concerns
- system invariants such as compute-on-read, deterministic behavior, evented mutation, and project isolation remain mandatory across those lenses

### Ideas explicitly rejected
- treating VEDA as a strategy synthesis and execution planning hierarchy
- letting observatory framing smuggle in roadmap or tactics ownership
- treating speculative future observatories as active truth before explicit classification and implementation reality exist

### Active direction
- use `docs/architecture/veda/observatory-models.md` as the framing anchor for multi-observatory thinking inside VEDA
- use the content-graph, competitor-observation, and search-intelligence successor docs as the active domain-specific surfaces
- consult the archived legacy doc only for constrained historical salvage

---








## Root VS Code Docs Reconciliation Notes

### Resolution summary

The following root docs remain classified as keep-but-rewrite-later:
- `docs/VSCODE-EXTENSION-SPEC.md`
- `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
- `docs/First-run operator journey.md`

They remain useful as legacy-reference planning inputs and grounded UX evidence.
They are not active operator-surface architecture truth.

The active authority surface for this lane is now:
- `docs/systems/operator-surfaces/overview.md`
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/systems/operator-surfaces/vscode/repo-native-workflow.md`
- `docs/systems/operator-surfaces/vscode/phase-1-spec.md`
- `docs/systems/operator-surfaces/vscode/roadmap.md`

### Grounded ideas preserved
- the extension should remain a thin API client rather than a DB client or local business-logic engine
- project context, environment clarity, next-valid-action guidance, and empty-state recovery are durable operator UX principles
- repo-native execution remains a real operator lane distinct from canonical VEDA state mutation
- lifecycle-aware presentation can guide operators without granting autonomous control or hidden workflow mutation
- humans remain the authority for applying both VEDA changes and repo changes

### Ideas explicitly rejected
- treating the root VS Code docs as active implementation or operator-surface authority
- letting legacy extension-centric wording blur Project V, VEDA, and V Forge boundaries
- reviving stale companion docs and archived references through cross-reference inertia
- turning lifecycle UX guidance into a hidden control plane or autonomous state machine

### Active direction
- keep these root docs as rewrite-later legacy-reference material
- consult them for grounded UX ideas and continuity evidence only
- attach active implementation and roadmap work to the successor docs by full path
- avoid archiving these root docs prematurely until a deliberate root-doc rewrite pass happens
- Historical lifecycle reference mismatch resolved: docs/VSCODE-EXTENSION-LIFECYCLE-UX.md now points to docs/archive/pre-wave2/veda-project-lifecycle-workflow.md as historical input rather than to a nonexistent active doc

---




## Deferred Bucket Review Notes

### Resolution summary

The `docs/specs/deferred/` bucket was reviewed and should remain an isolated backlog bucket rather than being promoted into active architecture work.

Current contents are narrow deferral notes:
- `docs/specs/deferred/DQ-001-topic-proposals-deferred-from-phase-c1.md`
- `docs/specs/deferred/DQ-002-entity-proposals-deferred-from-phase-c1.md`
- `docs/specs/deferred/DQ-003-authority-support-proposals-deferred-from-phase-c1.md`

These documents preserve specific reasons why certain proposal-helper surfaces were deferred.
They are useful as implementation context if that lane is resumed, but they are not active architecture truth.

### Grounded ideas preserved
- narrow phases should stay narrow
- structurally ambiguous proposal types should not be promoted before the lower-ambiguity surfaces are proven stable
- tactical or execution-planning proposals should not be smuggled into early structural proposal layers
- deferral notes can preserve useful sequencing judgment without becoming roadmap authority

### Ideas explicitly rejected
- promoting deferred proposal notes into current active docs just because they still sound interesting
- treating archived or stale proposal-helper references as current architecture truth
- letting execution-planning semantics leak into active observatory surfaces by way of old deferral notes

### Active direction
- keep `docs/specs/deferred/` intact as an isolated backlog/history bucket
- revisit only if the proposal-helper implementation lane is intentionally resumed
- do not let the bucket influence current architecture or documentation by inertia

---
## Future Ideas Bucket Review Notes

### Resolution summary

The `docs/specs/future-ideas/` bucket was reviewed and should remain an isolated speculative notebook.
The existing `docs/specs/future-ideas/README.md` rules are directionally correct and should stand.

This bucket currently contains ideas around:
- algorithm update detection
- research observatory concepts
- LLM citation observatory concepts
- strategy synthesis and tactics layers
- remote MCP/provider ideas
- V Project / VEDA / CMS separation ideas
- additional speculative clusters under `docs/specs/future-ideas/veda_cleanup/` and `docs/specs/future-ideas/youtube/`

These are not active development targets and should not influence current implementation or documentation unless explicitly promoted.

### Grounded ideas preserved
- speculative ideas deserve a quarantine zone so they do not contaminate current truth
- future observatories, tactics layers, research lenses, and adjacent-system contracts may be worth revisiting later
- explicit promotion rules are good discipline

### Ideas explicitly rejected
- using future-ideas docs as justification for present architecture changes
- treating speculative V Project, LLM citation, tactics, or YouTube observatory concepts as active truth now
- allowing the `veda_cleanup/` and `youtube/` subtrees to quietly become authority surfaces through neglect

### Active direction
- keep `docs/specs/future-ideas/` intact as an explicitly non-authoritative research notebook
- consult only when a future idea is intentionally being promoted
- require explicit architectural decision, successor-path selection, and cleanup-layer updates before anything leaves this bucket

---

## Root VS Code Rewrite Plan Notes

### Resolution summary

The remaining root VS Code docs should not be treated as one rewrite batch with one outcome.
They split into three different future paths:

1. `docs/VSCODE-EXTENSION-SPEC.md`
   - preserve thin-client, API-only, environment clarity, and degraded-mode ideas
   - do **not** rehabilitate its entity/publish/admin workflow sections as active truth
   - likely long-term outcome: salvage any still-useful generic ideas, then archive the root doc

2. `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
   - preserve lifecycle-oriented presentation ideas and next-valid-action UX
   - do **not** rewrite it into active truth until a current lifecycle truth surface exists
   - current state is intentionally legacy-reference only because it depends on archived historical lifecycle input

3. `docs/First-run operator journey.md`
   - preserve first-run recovery, empty-state, blueprint discoverability, environment orientation, and cross-panel continuity ideas
   - this is the strongest candidate for a future active successor doc
   - recommended future target shape: a small operator-surface doc under `docs/systems/operator-surfaces/vscode/` rather than another root-level essay

### Grounded ideas preserved
- API-only thin-client discipline remains worth carrying forward
- environment clarity and degraded-mode honesty remain high-value operator concerns
- next-valid-action UX and signal gating are valuable, but need a real lifecycle authority surface before they become active truth
- first-run recovery, empty-state teaching, blueprint visibility, and cross-panel continuity are strong active-candidate UX ideas

### Ideas explicitly rejected
- rewriting `docs/VSCODE-EXTENSION-SPEC.md` in place as a new active root spec despite its stale entity/publish/admin assumptions
- promoting `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md` into active truth while lifecycle authority still depends on archived pre-Wave-2D material
- keeping `docs/First-run operator journey.md` as a drifting root memo instead of eventually either rewriting it into the successor spine or archiving it deliberately

### Active direction
- keep all three docs as rewrite-later legacy-reference material for now
- do not casually patch them in place to simulate freshness
- when the rewrite pass happens:
  - treat `docs/First-run operator journey.md` as the first and strongest rewrite candidate
  - treat `docs/VSCODE-EXTENSION-SPEC.md` as split-salvage then likely archive
  - treat `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md` as blocked pending a current lifecycle truth surface

---

## Hammer Doctrine Resolution Notes

### Resolution summary

A new active doctrine doc now exists at:
- `docs/architecture/testing/hammer-doctrine.md`

The hammer is explicitly defined as an invariants and integrity layer for live operational surfaces.
It is not a generic code-quality theater surface.

The SERP-disturbance hammer lane was also modularized so:
- `scripts/hammer/hammer-sil22-24.ps1` remains the stable coordinator entrypoint
- focused concerns now live under `scripts/hammer/serp-disturbances/`

### Grounded ideas preserved
- hammer purpose is to verify DB integrity, route-contract integrity, bounded ownership, project isolation, deterministic behavior, and read-only guarantees where required
- route-level hammering should test real execution and invariants, not UI theater or generic helper vanity checks
- exact contract checks are more valuable than vague field-presence checks
- when a hammer file becomes too large, split it into focused modules and keep a thin coordinator

### Ideas explicitly rejected
- turning the hammer into a generic code-hardening or style-enforcement tool
- using hammer work as permission to drift into UI or speculative feature testing
- letting large hammer files grow indefinitely when modular structure would preserve clarity better

### Active direction
- use `docs/architecture/testing/hammer-doctrine.md` as the active reference for hammer purpose and limits
- keep coordinator entrypoints stable where existing repo tooling already points at them
- modularize oversized hammer lanes by concern without changing hammer mission

---

## Phase 2.5 Hammer Hardening Resolution Notes

### Resolution summary

A follow-on hardening pass tightened the active hammer surface after the initial Wave 2D cleanup alignment.

Completed outcomes:
- scripts/hammer/hammer-source-capture.ps1 was added as an active observatory-floor module
- source capture, source-items list, and events list invariants now have direct hammer coverage
- src/app/api/source-items/capture/route.ts was corrected to use the project-scoped (projectId, url) lookup rather than a stale global-url assumption
- mutation discipline was hardened by switching active mutation routes to esolveProjectIdStrict() where fallback-to-default project behavior was invalid
- weak SKIPs were tightened where the hammer already seeded enough local data to make a real assertion
- retired hammer-core.ps1 was quarantined under old/hammer-core.ps1 so it cannot quietly drift back into the active gate

### Grounded ideas preserved
- observatory-floor mutations deserve the same hammer seriousness as deeper SIL surfaces
- weak SKIPs are a maintenance smell when local deterministic setup already exists
- project context must be explicit for mutation endpoints; fallback is acceptable for selected read surfaces only
- when a surface has already seeded deterministic local data, assertions should prefer PASS/FAIL over vague SKIP escape hatches
- retired hammer residue should be physically quarantined, not merely removed from a coordinator list

### Ideas explicitly rejected
- using fallback project resolution for mutation endpoints just because early bootstrap behavior once allowed it
- leaving stale hammer files in the active directory where future maintainers can accidentally resurrect them
- hiding real seeded-data failures behind broad or lazy SKIP branches
- treating provider-dependent SKIPs and locally-testable SKIPs as the same category

### Active direction
- keep remaining SKIPs honest: provider-dependent, environment-dependent, or genuinely richer-data-threshold constrained
- continue Phase 2 tightening only where observability invariants can be strengthened without schema or endpoint drift
- preserve the rule that hammer changes must improve truthfulness, not just total PASS count



---

## Roadmap Status Reconciliation Notes

### Resolution summary

docs/ROADMAP.md had drifted behind repo reality by continuing to mark Phase 3 — MCP Tool Surface Alignment as pending after the MCP audit/documentation lane had already completed in practice.

The reconciliation basis is the clean-repo commit trail:
- ab4a622 — document MCP as current Claude Desktop-compatible dev harness
- 2a90e81 — audit and document mcp tool surface

### Grounded ideas preserved
- roadmap phase state must follow validated repo reality, not stale earlier status text
- MCP completion here means audited API-only bounded operator-surface alignment, not permission to keep expanding MCP by inertia
- once roadmap status drift is corrected, the next execution lane remains Phase 4 — Ingestion Pipeline Validation

### Ideas explicitly rejected
- pretending Phase 3 is still pending after the audit/documentation pass already landed
- using stale roadmap text as an excuse to reopen MCP expansion without a new bounded need
- treating status reconciliation as justification for new schema, routes, or ownership drift

### Active direction
- treat Phase 3 as complete
- keep Phase 5 documentation alignment active for remaining doc-truth cleanup
- continue execution in roadmap order at Phase 4 unless new evidence forces a sequencing correction


---

## Phase 4 Ingestion Audit — Route Reference Correction

### Resolution summary

Phase 4 ingestion audit (docs/audits/phase4-ingestion-audit.md) found one mismatch: the roadmap said `POST /api/seo/ingest` but the actual runtime route is `POST /api/seo/ingest/run`. Hammer modules already targeted the correct route. No implementation bug.

### Grounded ideas preserved
- roadmap route text must match actual Next.js route shape, not an approximation of the directory structure
- hammer truth already matching runtime reality is a sign the system works; the docs were the liar, not the code
- not every mismatch is an implementation bug — sometimes the correction is a one-line doc fix
- credential provisioning (DataForSEO) is an operator decision, not a doc or code gap

### Ideas explicitly rejected
- using a route-name doc correction as justification for new ingestion architecture
- expanding the ingestion surface because the audit touched it
- treating missing DataForSEO credentials as a code blocker rather than an operator provisioning decision

### Active direction
- Phase 4 roadmap text now matches runtime reality
- Phase 4 remains pending; execution can proceed when operator is ready
- credential provisioning is orthogonal to Phase 4 structural readiness

---

## Phase 4 Completion and Ingest Hammer Self-Bootstrap Notes

### Resolution summary

Phase 4 is now complete. The earlier ingestion audit corrected the roadmap route reference from POST /api/seo/ingest to POST /api/seo/ingest/run, and the remaining execution blocker turned out to be a local hammer setup bug rather than an ingestion architecture gap. scripts/hammer/hammer-dataforseo-ingest.ps1 now self-bootstraps s3KtId when standalone or partial execution does not inherit SIL-3 coordinator state.

The current validated full-hammer baseline is:
- **PASS:** 680
- **FAIL:** 0
- **SKIP:** 10

### Grounded ideas preserved
- roadmap route text must match actual runtime route shape
- not every ingest-lane failure signal is a route or provider bug; sometimes a hammer module is incorrectly inheriting setup state
- standalone hammer modules should bootstrap their own minimum valid test state when that can be done without ownership drift
- provider rejection of a gibberish hammer query can still be a valid PASS for route-contract/error-envelope testing
- Phase 4 closeout required no schema changes and no endpoint additions

### Ideas explicitly rejected
- treating the standalone s3KtId setup bug as justification for ingestion-surface redesign
- interpreting a provider-side nonsense-query rejection as a VEDA ingest bug
- expanding the ingestion architecture because the hammer lane needed a local bootstrap correction

### Active direction
- treat Phase 4 as complete
- retain docs/audits/phase4-ingestion-audit.md as the audit record for the route-reference correction
- continue with Phase 5 — Documentation Alignment as the active next lane


---

## Phase 5 Documentation Alignment — Path-Truth Corrections

### Resolution summary

18 active docs had nesting-drift path references (using `docs/architecture/X` when the file was actually at `docs/architecture/architecture/X`). All corrected. Two duplicate canonical docs resolved: V_ECOSYSTEM.md (outer kept) and SCHEMA-REFERENCE.md (nested kept per ROADMAP authority).

### Grounded ideas preserved
- the `docs/architecture/architecture/` nesting is the current structural reality; path references must match, not assume a flatter structure
- duplicate canonical docs must be resolved to a single authoritative copy, not left for drift to re-establish
- successor docs may reference legacy repo paths in provenance sections — these are intentional and should not be "fixed" to point at nonexistent clean-repo paths
- Phase 5 is a control-surface truth lane, not a content-expansion lane

### Ideas explicitly rejected
- flattening `docs/architecture/architecture/` into `docs/architecture/` (would require moving many files + rewriting all refs again — cost exceeds benefit)
- removing legacy provenance references from successor docs (they document reconstruction lineage)
- rewriting doc content for style during a path-truth pass

### Active direction
- path references in all active docs now resolve correctly against clean-repo structure
- duplicate canonical docs are resolved
- legacy provenance refs are intentionally retained
- `docs/architecture/architecture/` nesting is documented as intentional current state
