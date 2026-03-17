# VS Code Operator Gap Map

## Purpose

This document maps known operator-friction gaps onto the current VS Code extension surface and any likely successor surface.

It exists to answer:

```text
Where does the operator experience still break down, what kind of gap is it, and where should future fixes attach without treating the legacy extension as active architecture truth?
```

This is an active cross-system operator-surface document.
It is not a feature spec, not a redesign charter, and not a justification for modernizing the current `vscode-extension/` implementation in place.

---

## Core Framing

A gap map is a continuity tool.

Its job is to stop known operator-friction problems from disappearing into chat fog, repo folklore, or future “didn’t we already learn this?” loops.

The gap map does **not** say:
- the legacy extension is the active product surface
- every identified gap deserves a code change right now
- a future successor must preserve the same panel structure
- operator-surface architecture should be inferred from old UI shapes

Instead, it says:
- these are the recurring operator-friction points
- this is where they appeared in the legacy surface
- this is the likely kind of successor surface they belong in
- this is whether the issue is continuity, discoverability, empty-state behavior, environment clarity, or proposal visibility

---

## Why This Doc Exists

The current `vscode-extension/` implementation is now treated as:
- a legacy implementation reference
- a grounded idea source
- a successor-input surface

That means extension-specific operator gaps still matter, but they must be handled carefully.

Without a gap map, two bad things happen:
- useful operator-friction lessons get lost
- legacy implementation assumptions quietly become architecture truth by repetition

This document preserves the lesson without worshipping the fossil.

---

## What Kind of Gaps Belong Here

This document should track gaps such as:
- first-run dead ends
- no-project recovery failures
- environment confusion
- empty states that do not explain next action
- diagnostics that do not point to the next useful step
- proposal visibility gaps
- continuity gaps between related operator surfaces
- naming and discoverability problems that make good capabilities feel hidden

This document should **not** become:
- a panel inventory
- a command catalog
- a design comp substitute
- a backlog of random UI wishes

---

## Relationship to the Legacy VS Code Surface

The legacy extension remains a useful source of evidence about:
- where operators got stuck
- which panels or commands naturally carried continuity load
- which empty states were harmful
- which jumps between surfaces were strong or weak

That evidence matters.
But the legacy surface still does **not** become the active authority surface.

The right use of this map is:

```text
observe legacy friction -> classify the gap -> preserve the lesson -> attach future fixes to active operator-surface architecture
```

Not:

```text
observe legacy friction -> patch legacy extension forever -> accidentally call that architecture
```

---

## Gap Categories

A useful operator gap map should classify each gap by type.

### Onboarding and recovery
Examples:
- no projects found
- no environment configured
- environment unreachable
- no obvious starting point

### Continuity and next-step clarity
Examples:
- a diagnostic is visible but the next action is not
- the operator can see a panel but not why it matters
- a workflow stops at “here is state” instead of “here is the next valid move”

### Discoverability
Examples:
- useful surfaces are semi-hidden
- naming is too mysterious
- the operator cannot tell what a command or panel is for

### Proposal visibility
Examples:
- proposal-generating capabilities exist in API/MCP surfaces but are absent from the operator loop
- review surfaces do not clearly show where proposals fit

### Environment and context clarity
Examples:
- switching environments is possible but poorly contextualized
- local/server status is unclear
- operators cannot tell emptiness from connectivity failure

---

## How to Use This Map

For each tracked gap, this document should help answer:
- what the operator pain actually was
- what category of gap it is
- whether the issue is already mitigated, partially addressed, or still missing
- where a future fix would most naturally attach
- whether the issue belongs to VS Code specifically, or to operator surfaces more broadly

The key word is **attach**.
This document is not where the fix is designed in full.
It is where the gap is placed so future work does not drift.

---

## Rules for Future Gap Entries

Each gap entry should identify:
- the operator pain in plain language
- the likely surface where the issue appears
- whether it is a continuity, discoverability, recovery, proposal, or environment issue
- current status: missing / partial / mitigated / legacy-only
- whether a future successor surface should carry the fix

Each entry should avoid:
- turning a gap into a redesign mandate by rhetoric alone
- assuming the legacy panel layout is sacred
- prescribing implementation detail too early
- mixing architecture ownership with UI convenience

---

## Current High-Value Gap Themes

The current high-value themes worth preserving from the legacy VS Code evidence are:
- first-run and no-project recovery
- environment clarity and reachability explanation
- `Project Context`-style next-valid-action guidance
- continuity from diagnostics to the next useful surface
- proposal visibility in the operator loop
- better discoverability for Page Command Center-like destinations
- empty states that teach purpose, not just absence

These are the enduring lessons.
The exact legacy implementation shell is not.

---

## What This Means Right Now

For the current reconstruction phase:
- use this document to preserve operator-friction lessons from the legacy VS Code surface
- do not use it as permission to keep polishing the legacy extension by default
- attach future fixes to the active operator-surface architecture first
- let a future successor surface inherit the lessons, not the stale assumptions

The gap map preserves the problems worth solving.
It does not crown the old solution.

---

## Related Docs

This document should be read with:
- `docs/systems/operator-surfaces/overview.md`
- `docs/ROADMAP.md`
- `docs/VSCODE-EXTENSION-SPEC.md`
- `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
- `docs/First-run operator journey.md`
- `docs/archive/post-wave2-cleanup/VEDA-VSCODE-OPERATOR-GAP-MAP.md`

`docs/archive/post-wave2-cleanup/VEDA-VSCODE-OPERATOR-GAP-MAP.md` remains useful as grounded historical input for gap categories and legacy examples.
It is not active authority by itself.

