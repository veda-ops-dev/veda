# Operator Surfaces Overview

## Purpose

This document defines how operator-facing surfaces are framed in the current V Ecosystem.

It exists to answer:

```text
What counts as an operator surface, who owns it, and how should legacy operator implementations be treated during reconstruction?
```

This is an active architecture document for cross-system operator surfaces.
It is not a product roadmap, not a UI spec, and not a license to collapse bounded systems into one control blob.

---

## Core Framing

Operator surfaces are how a human interacts with the ecosystem.
They are not a bounded domain by themselves.
They are delivery surfaces that sit on top of bounded systems.

The bounded-system rule still applies:

- Project V plans
- VEDA observes
- V Forge executes

An operator surface may expose functionality from one or more of those systems, but it does not erase ownership.

---

## What an Operator Surface Is

An operator surface is any intentional human-facing interface used to:
- inspect system state
- review proposals
- trigger bounded actions
- move between related workflows
- recover from empty or error states
- maintain continuity across planning, observation, and execution work

Examples can include:
- MCP tools
- a VS Code extension
- browser capture tooling
- future bounded web or desktop operator views

The surface is not the owner.
The underlying bounded system remains the owner of the capability being exposed.

---

## Ownership Rules

### Project V ownership through operator surfaces

Project V-owned operator interactions include:
- project creation and identification
- project lifecycle context
- next-valid-action guidance when it is planning-owned
- blueprint and planning workflows
- sequencing and orchestration decisions

### VEDA ownership through operator surfaces

VEDA-owned operator interactions include:
- observatory state
- derived search intelligence
- alerts, volatility, and diagnostic read surfaces
- search-observation review
- evidence-backed proposal visibility where the proposal remains read-only

### V Forge ownership through operator surfaces

V Forge-owned operator interactions include:
- drafts
- revisions
- publishing workflow
- execution status
- production assets
- distribution actions

### Cross-system operator surfaces

Some surfaces will be cross-system because they help the operator move between bounded systems.
That is allowed.
What is not allowed is hiding ownership or silently merging ownership behind one theatrical UI label.

---

## Current Reconstruction Rule

During the current reconstruction phase, operator surfaces must be treated in this order:

1. preserve bounded ownership
2. remove stale authority pressure
3. document the active architecture first
4. only then design or rebuild operator surfaces against current truth

This prevents legacy UI/code surfaces from becoming accidental architecture authorities.

---

## Current VS Code Extension Stance

The current implementation under `vscode-extension/` should be treated as:
- a legacy implementation reference
- a grounded idea source
- a successor-input surface

It should **not** be treated as the active truth surface for operator architecture.

That means:
- do not keep polishing it as if it were the current product by default
- do not let its internal assumptions define current system architecture
- do not treat its existing UX copy, routes, or panel model as authoritative without reclassification

Small anti-drift cleanup and hazard removal can be justified.
Broad modernization-in-place is the wrong default.

---

## Why the Current VS Code Extension Is Not Active Truth

The repo was reconstructed after major architecture cleanup.
The current extension implementation still reflects older assumptions about:
- what VEDA is
- what VEDA owns
- how operator workflows should be sequenced
- where project setup and blueprint work live
- how cross-panel continuity should be framed

That makes it useful as evidence, but risky as authority.

A legacy surface with good ideas is still a legacy surface.
The ecosystem should not inherit its shape accidentally.

---

## What to Preserve from the Legacy Extension Surface

The current extension still contains grounded ideas worth preserving, including:
- API-client-only discipline
- no DB access from the operator surface
- environment clarity
- first-run recovery thinking
- next-valid-action guidance
- cross-panel continuity
- operator-first workflow discipline
- bounded command/action surfaces rather than a generic backdoor

These are principles to carry forward.
They are not proof that the current extension implementation should survive intact.

---

## Successor Rule

Any successor VS Code extension or other operator surface should be built only after:
- active operator-surface docs exist
- ownership boundaries are clear
- current planning, observability, and execution surfaces are classified
- legacy implementation assumptions have been demoted to reference status

The right sequence is:

```text
classify -> document -> design successor -> implement
```

Not:

```text
keep patching the old surface and hope it becomes current truth
```

---

## What This Means Right Now

For the current repo phase:
- the old VS Code extension implementation is not the thing to modernize by default
- the current job is to define operator-surface architecture cleanly
- successor docs should describe how operator surfaces relate to Project V, VEDA, and V Forge
- legacy implementation can be consulted for grounded ideas, but not followed blindly

---

## Related Docs

This document should be read with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/ROADMAP.md`
- `docs/architecture/architecture/veda/search-intelligence-layer.md`
- `docs/VSCODE-EXTENSION-SPEC.md`
- `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
- `docs/First-run operator journey.md`
- `docs/DOCS-CLEANUP-TRACKER.md`
- `docs/DOCS-CLEANUP-GROUNDED-IDEAS-EXTRACTION.md`

The extension docs listed above are useful as grounded inputs and legacy references.
They are not, by themselves, active truth for the operator-surface architecture.
