# VS Code Repo-Native Workflow

## Purpose

This document defines the intended repo-native operator workflow for local implementation work in the V Ecosystem.

It exists to answer:

```text
When local repository work is involved, what is VS Code for, what does it connect to, and how do repo changes stay distinct from bounded system state?
```

This is an active cross-system operator-surface document.
It is not a product spec, not a mandate that VS Code is the only important surface, and not a permission slip to collapse system ownership into one editor-shaped blob.

---

## Core Framing

VS Code is a repo-native operator surface.

It is valuable when an operator is working in a local repository and needs continuity between:
- project context
- observatory/diagnostic signals
- local file context
- proposal review
- implementation work under normal diff discipline

VS Code is not itself a bounded system.
It is a delivery surface sitting on top of bounded systems plus local repo tooling.

The bounded-system rule still applies:
- Project V plans
- VEDA observes
- V Forge executes

VS Code may help an operator move between those lanes.
It does not erase ownership.

---

## What Repo-Native Workflow Means

A repo-native workflow is any operator flow where local repository context matters to the work being done.

Typical examples include:
- inspecting a route or page in a local codebase
- reviewing a proposed content or code change as a diff
- connecting observed search or project signals to concrete files
- moving from diagnostics into implementation work without leaving the local workspace context

The key phrase is **repo-native**.
The workflow is anchored in local files and diffs, not just in remote system state.

---

## What VS Code Is For

In this context, VS Code is best treated as a place for:
- local repo context
- file- and route-aware operator continuity
- proposal review against actual files
- bounded transitions from diagnostics into implementation work
- normal human review before applying file changes

That makes it especially useful for:
- repository-backed project surfaces
- local implementation work
- diff-based review discipline
- workflows where page or route context matters

---

## What VS Code Is Not For

VS Code should not become:
- the owner of system truth
- a silent mutation backdoor into VEDA, Project V, or V Forge
- the only operator surface that matters
- a place where local repo edits and canonical system state are treated as interchangeable

A repo-native workflow can be important without becoming the center of the universe. Editors are powerful, but they do not get to annex architecture by vibe.

---

## Core Workflow Shape

A healthy repo-native workflow usually looks like this:

```text
1. operator opens a local repository in VS Code
2. operator resolves the active project context
3. operator reads relevant bounded-system state through governed surfaces
4. operator inspects local file / route / page context
5. diagnostics, context, or proposals inform local work
6. proposed file changes are reviewed through normal diff discipline
7. operator accepts, edits, rejects, or reworks the local changes
8. commit / push / deploy remain explicit human-controlled repo actions
```

That is the important pattern:
- bounded system state stays bounded
- repo work stays repo work
- the operator moves between them intentionally

---

## Role Split

### Project V

Project V may provide:
- project context
- planning state
- next-valid-action guidance when planning-owned
- sequencing/orchestration visibility

Project V does not become the local file editor.

### VEDA

VEDA may provide:
- observatory state
- Search Intelligence Layer diagnostics
- read-only evidence-backed proposals where they belong with observation
- project-scoped signals that help explain what is happening

VEDA does not own local file edits just because its diagnostics informed them.

### V Forge

V Forge may provide execution-oriented context where relevant, such as:
- draft/execution state
- output-related workflow context
- production readiness signals

V Forge still owns execution truth, not VS Code itself.

### VS Code

VS Code provides:
- local repository context
- file and editor context
- route/page adjacency where that is repo-derived
- diff-oriented review of local changes
- continuity between bounded system surfaces and local implementation work

### LLM assistance

LLMs may assist with:
- reading context
- summarization
- interpretation
- proposal drafting
- explaining diffs or local implications

LLMs do not get to silently mutate either repo files or canonical system state.

### Human operator

The human operator owns:
- review
- acceptance/rejection of changes
- commits
- pushes
- deploy actions
- any explicit system-state mutation requiring review

---

## Distinct Lanes Rule

Repo-native workflow only stays healthy if two lanes remain distinct:

### System-state lane
This includes:
- project state
- observatory state
- execution state
- governed API interactions
- canonical bounded-system records

### Repo-work lane
This includes:
- local files
- edits
- diffs
- commits
- pushes
- deploy mechanics

These lanes may influence each other.
They are still not the same thing.

A local patch is not the same as mutating bounded system state.
A bounded system mutation is not the same as editing a file.
Conflating them is how you get spectacularly confusing operator workflows.

---

## Review Discipline

Repo-native workflow should preserve ordinary human review discipline.

That means:
- file changes are visible as diffs
- accepted changes are explicit
- commit and deployment remain intentional
- local repo tooling stays legible
- system-state mutations, where they exist, remain separately governed

This is the editor equivalent of:

```text
Propose -> Review -> Apply
```

No haunted auto-apply nonsense.

---

## Why VS Code Still Matters

A clean operator-surface architecture does not mean every workflow should be forced into web UI.

When local repository work is the actual work, VS Code has natural strengths:
- immediate file context
- diff review
- page/route adjacency
- local execution/testing context
- lower friction for real implementation work

That does not make VS Code the universal answer.
It just means repo-native work should be allowed to remain repo-native.

---

## Why VS Code Is Not the Only Important Surface

Web and other operator surfaces still matter for things like:
- onboarding
- cross-project review
- broad dashboards
- high-level proposal visibility
- workflows that do not require local repo context
- bounded-system tasks where local files are not the center of gravity

A healthy operator ecosystem is multi-surface.
The goal is fit, not editor imperialism.

---

## Current Reconstruction Guidance

For the current repo phase:
- preserve the repo-native workflow concept
- do not treat the current `vscode-extension/` implementation as the active truth surface
- keep extracting grounded workflow lessons from legacy VS Code materials
- define operator-surface architecture first
- let any future successor extension inherit the workflow principles without inheriting stale ownership assumptions

That is the clean path:

```text
classify -> document -> design successor -> implement
```

---

## Related Docs

This document should be read with:
- `docs/systems/operator-surfaces/overview.md`
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/systems/operator-surfaces/mcp/overview.md`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/veda/search-intelligence-layer.md`
- `docs/archive/post-wave2-cleanup/VEDA-REPO-NATIVE-WORKFLOW.md`

`docs/archive/post-wave2-cleanup/VEDA-REPO-NATIVE-WORKFLOW.md` remains useful as grounded historical input for the workflow shape.
It is not active authority by itself.

