# LLM-Assisted Operations

## Purpose

This document defines how LLM assistance should operate across the V Ecosystem.

It exists to keep LLM use useful, bounded, auditable, and aligned with system ownership.
The goal is to accelerate analysis, drafting, summarization, and proposal generation without letting model convenience mutate canonical state or blur authority.

This is a cross-system architecture and governance document.
It does not redefine bounded ownership.
It defines how LLM assistance should behave when interacting with Project V, VEDA, and V Forge through approved operator and API paths.

If this document conflicts with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/security/auth-and-actor-model.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`

those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document defines:
- the role of LLMs in the ecosystem
- allowed classes of LLM-assisted work
- how proposals should flow into reviewed actions
- how LLMs should interact with APIs and operator surfaces
- what LLMs must never do
- how attribution and auditability should work

---

## What This Doc Is Not

This document is not:
- a model-vendor policy sheet
- a prompt library
- a UI spec
- a grant of autonomous authority
- a replacement for system-specific workflow docs

It answers a narrower question:

```text
How should LLM assistance behave so the ecosystem remains useful, safe, and resistant to drift?
```

---

## Ownership

This document is cross-system governance.

It applies across the ecosystem, but it does not collapse system ownership.

The bounded-system rule remains:
- Project V plans
- VEDA observes
- V Forge executes

LLMs may assist each system differently, but the owner of the underlying state does not change just because an LLM is involved.

---

## Core Principle

The governing rule for LLM-assisted operations is:

```text
Propose -> Review -> Apply
```

That rule is the default for any LLM contribution that may affect canonical state, implementation direction, or external-facing outputs.

LLMs are powerful assistance systems.
They are not the source of authority.

---

## Role of LLMs in the Ecosystem

LLMs are best used as bounded reasoning and drafting tools.

They are good at:
- summarizing
- classifying
- extracting structure
- drafting documentation
- drafting implementation proposals
- drafting production artifacts for human review
- translating system state into readable operator context

They are not authority sources.
They should not be treated as if probability distribution equals governance.

---

## Allowed LLM Assistance

LLMs may assist with work such as:

### Analysis
- summarizing captured sources
- identifying likely patterns in observatory data
- explaining validation results
- surfacing possible risks or opportunities

### Classification
- suggesting source categories
- suggesting graph labels or structural mappings
- proposing event or taxonomy candidates for review

### Documentation
- drafting or revising docs from current truth
- reorganizing docs into clearer structures
- proposing active docs from current architecture

### Planning support
- proposing next steps for operator review
- comparing implementation options
- translating observations into candidate actions for Project V review

### Execution support
- drafting content, copy, code, or operational text for review
- producing structured proposals that a human can inspect and accept or reject

### Operator support
- helping an operator recover context
- summarizing what changed
- surfacing next valid actions
- explaining system constraints in plain language

These are assistance roles.
They do not transfer authority.

---

## Disallowed LLM Behavior

LLMs must not:
- silently mutate canonical state
- bypass authentication or authorization
- bypass validation rules
- invent sources and present them as real evidence
- fabricate citations and present them as grounded truth
- post, publish, or distribute externally without an explicitly approved human-governed path
- create cross-project mutations outside approved scope
- redefine system ownership in implementation or docs by suggestion pressure
- treat internal tools or connectors as backdoors

If a model can perform the action without review, clear scope, and accountable attribution, the system should assume the action is unsafe by default.

---

## LLM Assistance by Bounded System

### Project V

LLMs may help Project V by:
- summarizing current project state
- proposing sequencing options
- generating roadmap drafts
- organizing operator notes into clearer planning artifacts

LLMs must not own lifecycle truth or silently advance planning state.

### VEDA

LLMs may help VEDA by:
- summarizing captured sources
- suggesting classifications or interpretations of observatory data
- drafting observatory docs
- helping explain events, validation failures, or observed patterns

LLMs must not silently rewrite observatory truth, collapse observations into strategy, or take on execution-state responsibilities.

### V Forge

LLMs may help V Forge by:
- drafting output artifacts
- proposing revisions
- assisting editorial or production-facing preparation
- structuring reviewable execution proposals

LLMs must not become autonomous publishers or external action agents.

---

## Canonical State Rule

Canonical state may only be changed through approved, attributable system paths.

LLM assistance must remain one of these:
- non-persistent analysis
- draft generation
- proposal generation
- explicitly reviewed and approved mutation through an approved path

The default assumption should be:

```text
LLM output is a proposal until accepted through a governed action.
```

That rule prevents drift in both code and docs.

---

## Interaction with Operator Surfaces

Operator surfaces such as the web UI, VS Code extension, browser-capture tools, and MCP-connected flows should expose LLM assistance as an aid, not as a hidden mutation engine.

### Required rules

- the surface should make proposed actions visible
- the surface should preserve review before apply where required
- the surface should not disguise LLM-authored content as operator-authored content
- the surface should not bypass the API boundary or database safety rules

A good operator surface makes LLM help legible.
A bad one turns AI behavior into spooky action at a distance.

---

## Interaction with APIs and Tools

LLMs may interact with the ecosystem only through approved tools and contracts.

### Required rules

- LLM tool use must respect API contracts
- LLM tool use must respect system ownership
- LLM tool use must respect project scope and non-disclosure rules
- LLM tool use must respect auth and actor rules
- LLM tool use must not bypass validation or event expectations

The API boundary remains authoritative even when the caller is an LLM-assisted tool path.

---

## Review Requirements

The level of review should match the sensitivity of the outcome.

### Low-risk assistance
Examples:
- summaries
- internal explanations
- non-persistent analysis

These may require only ordinary operator inspection.

### Medium-risk assistance
Examples:
- doc drafts
- code change proposals
- structured classification suggestions
- candidate graph edits

These should require human review before persistence or merge.

### High-risk assistance
Examples:
- configuration changes
- schema changes
- project-wide mutation
- destructive actions
- external-facing publish or distribution actions

These require explicit human approval and should remain tightly bounded even after approval.

When in doubt, increase review rather than pretending convenience is certainty.

---

## Attribution and Auditability

Meaningful LLM-assisted operations should remain attributable.

The system should preserve enough context to answer:
- was the action LLM-assisted or LLM-initiated?
- which approved path was used?
- which human or service authority allowed it?
- what project or scope did it affect?
- what changed, if anything?

Where canonical state changes occur, attribution should align with:
- `docs/architecture/security/auth-and-actor-model.md`
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`
- `docs/systems/veda/observatory/event-auditability.md`

Attribution should clarify behavior, not muddy it.

---

## Validation and Truthfulness

LLM assistance must remain subordinate to validation and evidence.

### Required rules

- evidence-backed claims should remain traceable to real sources or real system state
- validation failures should not be hand-waved away by fluent prose
- a model explanation is not a substitute for a passing contract or valid data
- uncertainty should be stated when the model lacks grounds for certainty

Fluency is not truth.
The system should never forget that little party trick.

---

## Anti-Drift Rule for Docs and Architecture Work

When LLMs help write architecture or active docs, they must optimize for fresh-reader clarity.

### Required rule

Active docs should be written so that a new LLM or human reader can infer current truth directly from the active surface.

That means active docs should:
- define current ownership directly
- describe present-tense system behavior
- avoid unnecessary historical narration
- avoid teaching stale shapes through defensive repetition

Historical notes belong in historical, cleanup, or archive materials rather than the active truth surface.

Another LLM will believe what the active docs teach.
So the active docs must teach only current truth.

---

## Failure Handling

When LLM output is wrong, the system should prefer visible correction over silent acceptance.

Typical failure modes include:
- fabricated facts
- boundary drift
- invented references
- invalid API assumptions
- overconfident planning claims
- hidden ownership blur

The proper response is:
- reject
- revise
- explain
- re-run through a governed path if needed

Not:
- “the wording sounded smart so we merged it anyway.”

That is how repos become cursed.

---

## Invariants

A compliant LLM-assisted workflow must preserve these invariants:
- LLMs assist but do not become default authority
- canonical state changes remain attributable
- approved boundaries outrank model suggestions
- APIs and validation remain authoritative
- project scope and system ownership remain enforced
- operator surfaces remain reviewable and legible
- active docs teach current truth rather than drift

If an LLM-assisted workflow weakens those invariants, it is not a safe workflow.

---

## Relationship to Other Docs

This document should be read alongside:
- `docs/architecture/security/auth-and-actor-model.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`
- `docs/ROADMAP.md`

System-specific docs may define narrower LLM-assisted patterns later, but they should inherit the governance doctrine defined here.

---

## Maintenance Note

If future work tries to reinterpret LLM assistance as permission for:
- silent mutation
- vague attribution
- architectural drift by suggestion
- external autoposting or autopublishing
- hidden operator-surface backdoors

that is an architectural warning sign.

The durable model is simple:
- humans hold authority
- LLMs propose and assist
- systems enforce governed rules
- active docs teach current truth clearly

That is how the ecosystem stays useful without becoming a probabilistic swamp creature.
