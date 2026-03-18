# Browser Capture Scope and Behavior

## Purpose

This document defines the scope, behavior, and constraints for browser-based capture surfaces in the V Ecosystem.

It exists to answer:

```text
What should browser capture surfaces do, what should they never do, and how do they fit the bounded-system architecture?
```

This is an active cross-system operator-surface document.
It is not a product pitch, not a mobile/browser support matrix, and not a permission slip for autonomous behavior.

---

## Core Framing

Browser capture is an operator surface.
It exists to reduce friction for intentional human capture of external material into governed system flows.

Browser capture is not:
- a bounded system
- a publishing surface
- an automation agent
- a social bot
- a hidden execution lane

The bounded-system rule still applies:
- Project V plans
- VEDA observes
- V Forge executes

A browser capture surface may feed one or more bounded systems, but it does not take ownership away from them.

---

## What Browser Capture Is For

Browser capture exists to help an operator:
- capture selected external material intentionally
- preserve source context at the moment of capture
- record why the capture matters
- move that capture into governed ingestion flows
- reduce clipboard-and-tabs chaos without reducing human accountability

That means browser capture is primarily about:
- source capture
- provenance
- context preservation
- operator intent recording

---

## What Browser Capture Is Not For

Browser capture must not become:
- autonomous posting
- auto-reply behavior
- background monitoring
- silent scraping
- an LLM agent acting on behalf of the user
- a hidden mutation path into canonical system state

If a proposed feature sounds like “the extension just handles it,” that is usually the moment to stop and classify ownership before the goblin escapes.

---

## Ownership Rules

### VEDA-owned capture behavior

VEDA owns browser-capture behavior when the result is:
- source capture
- observatory intake
- provenance-preserving ingest
- project-scoped observation input
- read-oriented downstream analysis over captured material

That includes things like:
- creating project-scoped captured-source records
- preserving capture context and operator intent
- routing captured material into inbox/ingest discipline

### Project V interaction with captured material

Project V may later use captured material for:
- planning context
- project research context
- sequencing decisions
- identifying what should happen next

But browser capture itself does not become Project V just because planning may later consume the result.

### V Forge interaction with captured material

V Forge may later use captured material during execution or production workflows.
But browser capture itself is not a publishing or production action.

---

## Core Behavioral Rules

### 1. Human-triggered only

Capture must be operator-triggered.
No background capture.
No ambient monitoring.
No silent collection.

### 2. Intent must stay human-authored

The operator must provide or confirm the reason for capture.
The system should not invent intent silently.

### 3. Preserve immediate context

At capture time, the surface should preserve enough context to make the material useful later, such as:
- selected text or visible content excerpt
- URL
- page title where available
- capture time
- platform or source hint where useful
- operator note or intent

### 4. No posting behavior

Browser capture does not post.
It does not reply.
It does not act on external platforms.
It does not impersonate the operator.

### 5. No hidden execution escalation

Capture is capture.
Any later drafting, planning, or execution must remain explicitly owned by the correct bounded system and explicitly reviewed by the operator.

---

## Capture Model

Browser capture should default to minimal intentional capture, not maximal extraction theater.

That means:
- capture what the operator selected or explicitly chose to capture
- avoid assuming whole-page ingestion by default
- preserve visible context needed for later understanding
- prefer explicit fields over mysterious inferred blobs where practical

The point is to retain useful evidence, not vacuum the universe into JSON sludge.

---

## Operator Intent Requirement

A browser capture surface should require a short reason or intent for capture.
This matters because later systems need to distinguish:
- why the operator captured the material
- whether it is observational, planning-relevant, or execution-relevant context
- whether it should be triaged, analyzed, or ignored

Useful examples include:
- a question worth investigating
- a misconception worth tracking
- a signal worth monitoring
- a phrasing pattern worth studying
- a competitor claim worth preserving

The system should preserve operator intent as metadata, not replace it with invented certainty.

---

## Compliance and Safety Guarantees

Browser capture surfaces must preserve these guarantees:
- no automated posting
- no use of external-platform credentials for hidden actions
- no background scraping jobs triggered by the capture surface itself
- no silent collection without operator awareness
- no hidden LLM action on behalf of the operator

These are not decorative rules.
They are the difference between a capture tool and a little policy-violating chaos machine.

---

## Relationship to Ingest Discipline

Browser capture should feed governed ingest flows rather than bypass them.

That means:
- captured material should enter a known intake path
- project scope should remain explicit
- provenance should remain visible
- downstream analysis should happen after capture, not inside a magical browser-side black box

Browser capture is the front door to intake, not a side tunnel under the foundation.

---

## LLM Interaction Rule

A browser capture surface may coexist with LLM-assisted workflows, but the boundary must remain clear.

The capture surface itself should not silently become an LLM agent.
In particular:
- capture does not require autonomous drafting
- capture does not justify autonomous action
- later LLM assistance must remain reviewable
- any proposal generated from captured material remains a proposal until reviewed

The durable rule still applies:

```text
Propose -> Review -> Apply
```

---

## Anti-Patterns

Avoid browser capture features that drift into:
- one-click posting
- auto-reply buttons
- background feed watching
- invisible capture on page load
- silent enrichment that changes canonical state
- blended capture-plus-execution flows with no ownership boundary

Those are not clever conveniences.
They are how systems become a compliance and architecture mud pit.

---

## What This Means Right Now

For the current reconstruction phase:
- browser capture should be documented as an operator surface, not a system owner
- capture should remain conservative and intentional
- VEDA-aligned capture should feed observatory/source-intake flows
- execution and publishing behavior should remain outside the capture surface
- legacy extension/browser docs may be used as grounded inputs, but not as active authority by themselves

---

## Related Docs

This document should be read with:
- `docs/systems/operator-surfaces/overview.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/ingest-discipline.md`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/llm-assisted-operations.md`
- `docs/archive/post-wave2-cleanup/02-CHROME-EXTENSION-SCOPE-AND-BEHAVIOR.md`
- `docs/archive/post-wave2-cleanup/08-EXTENSION-INGESTION-ARCHITECTURE.md`

The two legacy documents above are useful as grounded historical inputs for capture discipline and safety constraints.
They are not active authority by themselves.

