# MCP Overview

## Purpose

This document defines how MCP fits into the current operator-surface architecture.

It exists to answer:

```text
What is MCP in the V Ecosystem, what does it expose, and what must it never become?
```

This is an active cross-system operator-surface document.
It is not a tool inventory, not a product spec, and not a license to let LLMs quietly act like owners.

---

## Core Framing

MCP is an operator surface.
It is a controlled interface between assistants and bounded system capabilities.

MCP is not:
- a bounded domain
- a source of truth
- a control plane
- a shortcut around API rules
- a justification for silent mutation

The bounded-system rule still applies:
- Project V plans
- VEDA observes
- V Forge executes

MCP may expose capabilities from those systems.
It does not take ownership away from them.

---

## What MCP Is For

MCP exists to let assistants help operators with tasks such as:
- inspecting project-scoped system state
- reading observatory and diagnostic outputs
- surfacing evidence-backed proposals
- narrating, summarizing, and comparing bounded system outputs
- helping the operator move between related surfaces without collapsing ownership

In the current repo phase, MCP is primarily valuable as a safe read-oriented bridge into VEDA’s observatory and search-intelligence surfaces.

---

## What MCP Is Not For

MCP must not become:
- a hidden mutation path
- a direct DB client
- a bypass around HTTP/API validation
- an authority source independent of system APIs
- an excuse to merge repo tooling, local execution, and canonical system mutation into one blur

The durable rule remains:

```text
Propose -> Review -> Apply
```

Assistants may help analyze, summarize, classify, and propose.
They do not get to silently change canonical state.

---

## Ownership Through MCP

### Project V capabilities through MCP

When Project V capabilities are later exposed through MCP, they remain Project V owned.
That can include things like:
- project context
- planning state
- next-valid-action guidance when planning-owned
- orchestration and sequencing views

### VEDA capabilities through MCP

VEDA-owned MCP capabilities include:
- observatory state
- project-scoped search intelligence
- alerts, volatility, causality, and diagnostic read surfaces
- evidence-backed read-only proposals where proposal visibility belongs with observation

### V Forge capabilities through MCP

If execution surfaces are later exposed through MCP, they remain V Forge owned.
That can include:
- draft state
- review state
- publishing state
- production artifacts

MCP does not flatten these into one owner.

---


## Current Development Harness

In the current repo phase, the MCP server also functions as a Claude Desktop-compatible development harness.

This is a practical testing surface, not the final ecosystem-wide deployment model.

It allows bounded assistant workflows to be exercised against real HTTP/API surfaces without immediately shifting all testing to paid API-driven execution.

This helps validate:
- tool descriptions
- project scoping
- API contract alignment
- read/write discipline
- bounded ownership behavior

The long-term direction remains broader API-driven LLM access across the three bounded systems:
- Project V
- VEDA
- V Forge

But the current Claude Desktop-compatible MCP server is the cheapest and most practical dev/testing path.
## Current MCP Stance in This Repo

In the current repo phase, MCP should be treated as:
- an API-governed operator surface
- a safe assistant-facing read interface
- a bounded bridge to observatory and diagnostic outputs
- a place where proposal visibility can exist without granting mutation authority

It should not be treated as:
- a magic intelligence shell
- a replacement for system architecture
- a replacement for review discipline

---

## Current Strengths Worth Preserving

The current MCP direction contains good durable rules:
- API-only interaction
- project-scoped behavior
- deterministic outputs where possible
- no direct DB access
- no silent mutation
- human-gated review discipline
- clear separation between VEDA-state access and repo/file execution workflows

These are worth preserving because they keep the surface understandable instead of turning it into wizard smoke.

---

## Relationship to APIs

MCP sits on top of system APIs.
It should not invent alternate contracts.

The intended relationship is:

```text
assistant -> MCP -> HTTP/API -> bounded system capability
```

That means:
- API validation still governs
- API error handling still governs
- project scope still governs
- system ownership still governs

If a capability is not safe or coherent through the API, MCP should not bypass the problem.
The fix belongs in the underlying architecture or API surface first.

---

## Relationship to Repo-Native Tooling

MCP and repo-native tooling are related, but not identical.

MCP is for bounded system access.
Repo-native tooling is for local files, code, diffs, commits, and execution in the repo environment.

These may appear in the same operator workflow, but they are not the same lane.
Conflating them creates two classic messes:
- silent canonical mutation
- ownership blur between system state and repo work

MCP should remain the system-state side of the bridge, not the everything-side of the bridge.

---

## Relationship to Search Intelligence

In current practice, MCP is especially important for exposing VEDA’s Search Intelligence Layer.
That includes surfaces such as:
- keyword overview
- volatility
- change classification
- event timeline
- event causality
- intent drift
- feature volatility
- domain dominance
- project-level diagnostics
- operator reasoning and operator briefing surfaces

These remain VEDA-owned derived read surfaces.
MCP helps assistants access them safely.
MCP does not turn them into autonomous action authority.

---

## Verification Expectations

A healthy MCP surface should be checked for:
- project-scoped behavior
- non-disclosure across projects
- deterministic response structure where appropriate
- alignment with HTTP/API contracts
- absence of hidden mutation paths
- bounded tool descriptions that do not overclaim ownership or capability

The MCP layer should be boring enough that an audit can follow the chain without needing ceremonial incense.

---

## What This Means Right Now

For the current reconstruction phase:
- MCP should continue to be documented as a bounded operator surface
- MCP tool descriptions should align with active architecture, not stale specs
- MCP should keep exposing VEDA read surfaces safely
- future expansion should wait for explicit ownership classification when a tool crosses into planning or execution territory

The right default is not “add more MCP because it sounds powerful.”
The right default is “classify the owner, check the boundary, then expose only what stays coherent.”

---

## Related Docs

This document should be read with:
- `docs/systems/operator-surfaces/overview.md`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`
- `docs/architecture/veda/search-intelligence-layer.md`
- `docs/architecture/llm-assisted-operations.md`
- `docs/archive/post-wave2-cleanup/VEDA-MCP-TOOLS-SPEC.md`

`docs/archive/post-wave2-cleanup/VEDA-MCP-TOOLS-SPEC.md` remains useful as grounded historical input for tool grouping and interaction discipline.
It is not the active architecture authority by itself.


