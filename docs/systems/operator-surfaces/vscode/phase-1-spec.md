# VS Code Phase 1 Successor Surface Spec

## Purpose

This document defines the intended Phase 1 scope for a future VS Code successor surface.

It exists to answer:

```text
What is the smallest useful repo-native operator surface we would intentionally build under current architecture, and what must it avoid becoming?
```

This is an active cross-system operator-surface document.
It is not a commitment to rehabilitate the current `vscode-extension/` implementation in place.
It is a scoped successor target written against current ecosystem boundaries.

---

## Core Framing

A future VS Code Phase 1 surface should prove a narrow repo-native operator loop.

That loop is:

```text
repo context -> explicit project context -> bounded system read surfaces -> operator review -> local implementation work
```

This Phase 1 surface should remain:
- thin
- API-governed
- read-oriented by default
- explicit about ownership
- hostile to hidden mutation and local business logic

The bounded-system rule still applies:
- Project V plans
- VEDA observes
- V Forge executes

The VS Code surface may expose capabilities from those systems.
It does not become their owner.

---

## Phase 1 Goal

Deliver a minimal, trustworthy repo-native operator surface that proves an operator can:
- resolve environment and project context
- understand what system context they are in
- inspect relevant read surfaces from bounded systems
- connect those read surfaces to local repository work
- review and act on local changes under ordinary diff discipline

The goal is not to build a full command center kingdom in one swing.
The goal is to prove the lane without summoning a feature hydra.

---

## Non-Negotiable Constraints

### 1. Thin client only

The Phase 1 VS Code surface may:
- render UI
- collect explicit operator input
- call governed APIs or MCP tools
- render returned data
- maintain lightweight session state needed for continuity

It may not:
- query the database directly
- compute domain/business logic locally
- invent derived observatory analytics locally
- silently mutate canonical system state
- act as a hidden repo automation agent

### 2. Read-first surface

Phase 1 should be read-oriented.
If any mutation exists later, it must be separately justified and explicitly governed.

For Phase 1, the safe default is:
- system-state reads
- local repo reads
- operator-reviewed local edits outside the bounded system state lane

### 3. Project context must stay explicit

The operator should never have to guess:
- which environment they are using
- which project is active
- whether they are looking at bounded system state or local repo context

### 4. No local ownership inflation

The VS Code surface must not quietly become:
- a planning owner
- an observability owner
- an execution owner
- an architecture authority just because it is convenient to demo

### 5. Activation should remain narrow

The successor surface should activate only when needed.
Avoid eager startup drag, background churn, and spooky side behavior.

---

## Intended Phase 1 Scope

A future Phase 1 successor should stay intentionally small.
The highest-value surfaces are:

### A. Environment context

A lightweight, visible environment indicator and switch path so the operator can tell where requests are going.

Phase 1 expectation:
- explicit active environment
- quick environment switching
- clear handling for unreachable vs empty vs unselected contexts

### B. Project context anchor

A persistent project-context surface that tells the operator:
- active project
- high-level project state if available
- why the surface matters
- the next useful operator move when that guidance is available

This is continuity infrastructure, not decoration.

### C. Project-level investigation / observatory read surface

A project-level diagnostic entry point that can surface bounded read data such as:
- observatory summaries
- search-intelligence summaries
- high-level project diagnostic packets

This should come from governed APIs or MCP-backed composites, not local re-computation.

### D. Keyword / focused diagnostic read surface

A narrower diagnostic entry point for investigating a keyword, route, page, or similarly bounded unit when that context is available.

The exact shape may evolve, but the principle is the same:
- the editor does not compute the diagnosis
- the surface retrieves it and renders it clearly

---

## Out of Scope for Phase 1

The following should stay out unless explicitly reclassified later:
- generic mutation workflows
- hidden apply flows into canonical system state
- local business-logic engines
- complex panel sprawl for the sake of theater
- dense CMS-style trees
- background polling loops
- automatic patch application
- opaque multi-step orchestration hidden behind one button
- execution-state ownership disguised as editor convenience

Phase 1 is meant to prove discipline, not ambition cosplay.

---

## Candidate Command / Surface Shape

A successor Phase 1 surface will likely need a small set of commands or surface entries such as:
- switch environment
- resolve/select active project
- refresh visible context
- open project-level investigation
- open a focused diagnostic for the current operator task

The exact names can change.
The important thing is that they stay:
- bounded
- legible
- tied to explicit operator intent

---

## Results Rendering Rules

A successor Phase 1 results surface should be:
- readable
- deterministic enough to inspect
- explicit about source command or source surface
- explicit about active project/environment context
- free of hidden mutation controls

The rendering can be lightweight.
It does not need a cathedral of client-side framework drama to be useful.

---

## Transport Rules

The successor surface should use a single transport/client layer for governed reads.

Responsibilities may include:
- resolving active environment
- carrying project context where required
- surfacing bounded transport errors clearly
- preserving API/MCP alignment

Responsibilities should not include:
- domain logic
- policy invention
- local replacement of server-side truth

---

## State Model Rules

The local state model should stay tiny.
Useful responsibilities may include:
- active environment
- active project
- lightweight cached choices for the current session
- references to active panels/views where needed

It should not become:
- a local database
- an offline truth mirror
- a hidden mutation queue
- a second observatory cache with delusions of grandeur

---

## Repo-Native Review Discipline

Phase 1 should preserve ordinary repo hygiene.
That means:
- local file changes remain reviewable as diffs
- local acceptance/rejection remains explicit
- commit / push / deploy remain human-controlled
- local repo changes remain distinguishable from canonical system-state changes

This is the editor-side version of:

```text
Propose -> Review -> Apply
```

---

## Relationship to Other Surfaces

The successor VS Code Phase 1 surface should complement, not replace:
- web/onboarding surfaces
- MCP surfaces
- future bounded operator surfaces in other environments

VS Code is especially strong when local repo context is central.
It is not the only operator surface that matters.

---

## Phase 1 Success Criteria

Phase 1 is successful when all of the following are true:

1. the operator can clearly resolve environment and project context
2. the operator can inspect a project-level bounded read surface without leaving repo context
3. the operator can inspect a narrower focused diagnostic without local re-computation
4. the UI keeps project/environment context explicit
5. the surface performs no direct DB access and no hidden business logic
6. local repo work remains distinct from canonical system-state mutation
7. the surface stays small enough that ownership remains legible

---

## Relationship to Legacy Docs

This document should be read with:
- `docs/systems/operator-surfaces/overview.md`
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/systems/operator-surfaces/vscode/repo-native-workflow.md`
- `docs/VSCODE-EXTENSION-SPEC.md`
- `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
- `docs/archive/post-wave2-cleanup/VSCODE-EXTENSION-PHASE-1.md`

The older docs remain useful as grounded historical input for:
- thin-client discipline
- read-oriented Phase 1 scope
- continuity concerns
- environment/project context visibility

They are not active authority by themselves.

---

## Summary

A future VS Code Phase 1 successor should prove a narrow, trustworthy repo-native operator loop.

It should:
- stay thin
- stay API-governed
- stay read-first
- keep ownership explicit
- preserve diff-based human review

If it starts trying to be a whole ecosystem operating system in editor clothing, Phase 1 has already wandered off into the swamp.

