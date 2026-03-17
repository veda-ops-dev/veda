# VS Code Successor Surface Roadmap

## Purpose

This document defines the roadmap for a future VS Code successor surface.

It exists to answer:

```text
If a VS Code successor surface is built under current architecture, what should happen first, what should wait, and what rules must govern each phase?
```

This is an active cross-system operator-surface roadmap document.
It is not a promise to modernize the current `vscode-extension/` implementation in place.
It is a sequencing document for successor-surface thinking after architecture is explicit.

---

## Read This First

Before planning or extending any VS Code successor phase, read these documents in order:

1. `docs/architecture/V_ECOSYSTEM.md`
2. `docs/VEDA_WAVE_2D_CLOSEOUT.md`
3. `docs/SYSTEM-INVARIANTS.md`
4. `docs/ROADMAP.md`
5. `docs/systems/operator-surfaces/overview.md`
6. `docs/systems/operator-surfaces/mcp/overview.md`
7. `docs/systems/operator-surfaces/mcp/tooling-principles.md`
8. `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
9. `docs/systems/operator-surfaces/vscode/repo-native-workflow.md`
10. `docs/systems/operator-surfaces/vscode/phase-1-spec.md`
11. `docs/architecture/veda/search-intelligence-layer.md`
12. `docs/architecture/api/api-contract-principles.md`
13. `docs/architecture/api/validation-and-error-taxonomy.md`
14. `docs/architecture/llm-assisted-operations.md`
15. `docs/VSCODE-EXTENSION-SPEC.md`
16. `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
17. `docs/First-run operator journey.md`
18. `docs/archive/post-wave2-cleanup/VSCODE-EXTENSION-ROADMAP.md`

The documents at the end of the list remain grounded historical input.
They are not active authority by themselves.

---

## Core Framing

A future VS Code successor surface should be treated as:
- a repo-native operator surface
- a thin API-governed client
- a continuity layer between bounded system reads and local implementation work
- a place where human review remains explicit

It should not be treated as:
- the owner of system truth
- a silent mutation lane
- a reason to collapse Project V, VEDA, and V Forge into one editor shell
- a compulsory destination for every operator workflow

The bounded-system rule still applies:
- Project V plans
- VEDA observes
- V Forge executes

The VS Code surface may expose capabilities from those systems.
It does not absorb their ownership.

---

## Roadmap Rules

### 1. Successor first, legacy second

Plan against the successor-surface docs, not against the internal shape of the current `vscode-extension/` implementation.

The legacy extension may be consulted as:
- implementation evidence
- friction evidence
- grounded idea salvage

It is not the default modernization target.

### 2. Full-path references only

All roadmap items and related planning notes should reference docs by full repo-relative path, such as:
- `docs/systems/operator-surfaces/vscode/phase-1-spec.md`
- `docs/systems/operator-surfaces/vscode/repo-native-workflow.md`
- `docs/architecture/veda/search-intelligence-layer.md`

This keeps future LLMs and humans anchored to the right surfaces instead of guessing from vibes.

### 3. Read before phase growth

No later phase should be advanced unless the earlier required docs have been read and the ownership boundary still makes sense.

### 4. Thin shell stays non-negotiable

If a planned phase requires local business logic, DB access, silent mutation, or hidden background orchestration, the roadmap item is malformed.

### 5. Repo work and system-state work stay distinct

Every phase should preserve the distinction between:
- local repo changes
- bounded system-state reads
- any later governed system-state mutations

If a phase blurs those lanes, stop and reclassify.

---

## Current Stance

Right now, the ecosystem has enough active operator-surface architecture to stop treating the legacy VS Code implementation as active truth.

That means the current roadmap is not:
- patch legacy panel text forever
- keep extending the old shell because it exists

The current roadmap is:
- define the successor shape clearly
- preserve the useful workflow lessons
- sequence future work conservatively

---

## Phase 1 — Successor Foundation

### Goal

Prove a narrow, trustworthy repo-native operator loop under current architecture.

### Scope

Phase 1 should follow `docs/systems/operator-surfaces/vscode/phase-1-spec.md` and stay focused on:
- environment context
- explicit project context
- one project-level read surface
- one focused diagnostic read surface
- lightweight rendering of bounded results
- thin transport/state layers only

### Why this phase exists

Without a small, explicit foundation, later expansion turns into editor sprawl with architecture drift painted on top.

### Done when

Phase 1 is done when the successor surface can prove:
- explicit environment and project context
- bounded read access to relevant system surfaces
- no local business logic
- no direct DB access
- no hidden mutation
- clear distinction between repo work and system-state work

### Required docs

Read before advancing or implementing this phase:
- `docs/systems/operator-surfaces/vscode/phase-1-spec.md`
- `docs/systems/operator-surfaces/vscode/repo-native-workflow.md`
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`

---

## Phase 1.5 — Continuity and Discoverability Hardening

### Goal

Reduce operator confusion without changing the core thin-shell architecture.

### Scope

Likely candidates include:
- stronger empty-state clarity
- better environment/reachability explanation
- clearer next-step hints
- improved continuity from diagnostic surfaces to the next useful operator move
- lightweight discoverability improvements for important destinations

### Why this phase exists

A technically correct surface that leaves the operator confused is still a broken surface, just with better manners.

### Done when

This phase is done when the highest-value gaps from `docs/systems/operator-surfaces/vscode/operator-gap-map.md` are either:
- mitigated in successor design
- intentionally deferred with justification

### Required docs

Read before advancing or implementing this phase:
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
- `docs/First-run operator journey.md`
- `docs/systems/operator-surfaces/overview.md`

---

## Phase 2 — Page- and Route-Aware Repo Context

### Goal

Connect bounded read surfaces more naturally to local file, route, or page context when repo-native work actually benefits from it.

### Scope

Possible successor-surface capabilities may include:
- route-aware context
- file-aware context
- stronger linkage between diagnostics and the relevant local implementation surface
- clearer transitions from high-level observatory reads into local page work

### Why this phase exists

Repo-native workflow becomes truly useful when the local implementation surface and the bounded diagnostic surface can meet without pretending to be the same thing.

### Done when

Phase 2 is done when local page/route context improves operator continuity without:
- local re-computation of bounded diagnostics
- hidden orchestration
- ownership blur

### Required docs

Read before advancing or implementing this phase:
- `docs/systems/operator-surfaces/vscode/repo-native-workflow.md`
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/architecture/veda/search-intelligence-layer.md`
- `docs/systems/operator-surfaces/browser-capture/scope-and-behavior.md`
- `docs/systems/operator-surfaces/browser-capture/ingestion-architecture.md`

---

## Later Phase — Proposal Visibility and Review Loop

### Goal

Make proposal surfaces visible in the repo-native operator loop without turning proposals into hidden authority.

### Scope

Potential later work may include:
- visible proposal summaries
- explicit review entry points
- clearer continuity between bounded system proposals and local repo review
- stronger explanation of what is proposal, what is evidence, and what is still human decision

### Why this phase exists

Proposal visibility is valuable.
Proposal invisibility causes missed opportunities.
Proposal authority without review is how you build an expensive haunted house.

### Done when

This phase is done when proposal visibility exists without:
- hidden apply behavior
- ownership blur
- confusing proposal state with canonical truth

### Required docs

Read before advancing or implementing this phase:
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/systems/operator-surfaces/mcp/overview.md`
- `docs/systems/operator-surfaces/mcp/tooling-principles.md`
- `docs/architecture/llm-assisted-operations.md`

---

## Future Phase — Explicitly Governed Mutation Support

### Goal

Only after the earlier phases are coherent, evaluate whether any repo-native or system-state mutation surface should exist at all.

### Scope

This is future-only and not active.
Any later mutation support would require:
- explicit owner classification
- explicit review requirements
- explicit auditability and validation behavior
- no silent application
- clear distinction between repo mutation and canonical system-state mutation

### Why this phase is late

Because mutation is where “useful tool” turns into “what in the fluorescent hell did we just permit?”

### Required docs

Read before advancing or implementing this phase:
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`
- `docs/architecture/llm-assisted-operations.md`
- `docs/architecture/V_ECOSYSTEM.md`

---

## Explicit Non-Goals

This roadmap does not authorize:
- modernizing the current `vscode-extension/` implementation in place by default
- extension-side observatory/business logic
- DB access from the editor surface
- silent background polling or orchestration
- generic CMS/admin explorer sprawl
- automatic patch application
- turning VS Code into the owner of planning, observability, or execution truth

If a future idea starts sounding like “the editor should just do everything,” that is not innovation. That is architecture drift wearing cologne.

---

## Decision Rule

Before adding a new VS Code successor-roadmap item, ask:

1. Does it preserve bounded ownership?
2. Does it keep the surface thin and API-governed?
3. Does it keep repo work distinct from canonical system-state work?
4. Does it rely on active docs referenced by full path?
5. Does it solve a real operator-continuity problem instead of just making the editor look busier?

If the answer to any of these is no, the item is probably not roadmap-ready.

---

## Summary

The VS Code roadmap should progress in deliberate layers:

1. successor foundation
2. continuity/discoverability hardening
3. page- and route-aware repo context
4. proposal visibility and review loop
5. only then consider any later governed mutation support

This keeps the repo-native operator surface useful, legible, and aligned with the actual ecosystem instead of with legacy extension inertia.

