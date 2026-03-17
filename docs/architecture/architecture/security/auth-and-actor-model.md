# Auth and Actor Model

## Purpose

This document defines who is allowed to act, how write authority is enforced, and how actions are attributed across the V Ecosystem.

It exists to keep authority boundaries explicit during successor-doc reconstruction and to prevent AI-assisted workflows from quietly mutating canonical state without accountable ownership.

This is a cross-system security and governance document.
It applies to platform and API behavior across Project V, VEDA, and future V Forge surfaces.
It does not redefine bounded-system ownership.

If this document conflicts with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- current schema and enforced implementation behavior

those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document defines the baseline model for:
- authentication
- authorization
- actor attribution
- human-gated control
- LLM-assisted and LLM-initiated write behavior
- system-initiated mutation rules
- operator-surface trust boundaries

---

## What This Doc Is Not

This document is not:
- a vendor-specific auth setup guide
- a UI spec
- a permission-matrix for future multi-user teams
- a replacement for system-specific workflow docs
- a justification for autonomous mutation

It answers a narrower question:

```text
Who can act, under what authority, and how do we know who actually caused a state change?
```

---

## Ownership

This document is cross-system governance.

It supports all bounded systems, but it does not collapse them.

The bounded-system rule still applies:
- Project V plans
- VEDA observes
- V Forge executes

This document governs how actors interact with those systems.
It does not decide what each system owns.

---

## Core Principles

### 1. Humans hold authority

Humans are the authoritative source of intent for meaningful state changes.

A human operator may:
- initiate work
- approve or reject proposals
- authorize irreversible actions
- choose whether suggested changes should be applied

### 2. LLMs assist within bounded paths

LLMs may analyze, classify, summarize, draft, and propose changes.

LLMs do not become sovereign little goblins with silent write power just because they are useful.

An LLM may only contribute to persisted state through an approved, attributable path.

### 3. Systems enforce rules but do not invent intent

Deterministic system behavior may:
- validate requests
- enforce authorization
- perform governed internal mutations
- emit audit records
- execute approved workflows

System code must not invent strategic, editorial, or publishing intent on its own.

### 4. Every meaningful write must be attributable

If canonical state changes, the system should be able to answer:
- who or what initiated the change
- under what authenticated authority it happened
- which project or scope it belonged to
- when it happened

### 5. Human-gated control remains the default

The governing posture remains:

```text
Propose -> Review -> Apply
```

Automation may exist, but it must not quietly erase human accountability or blur the source of authority.

---

## Actor Families

The actor model distinguishes between who initiated an action and what authenticated authority allowed it to happen.

Current actor families are:
- `human`
- `llm`
- `system`

These align with the current VEDA event vocabulary and should remain consistent across broader ecosystem governance.

### `human`

A real operator acting through an authenticated surface.

Examples:
- capturing a source manually
- creating a keyword target
- approving an applied change
- updating system configuration through an authorized interface

Humans are the default authority holders for intentional write behavior.

### `llm`

An LLM that directly initiates an allowed state change through an approved tool path.

Examples:
- an LLM invoking an approved tool that creates a governed record after the required authorization gate is satisfied
- an LLM-mediated operator flow where the persisted action is intentionally attributed to the LLM as initiator rather than merely marked as assisted

Important note:
`llm` is an actor category for attribution.
It is not a grant of independent unlimited authority.

### `system`

Deterministic internal system behavior acting through a governed code path.

Examples:
- idempotent ingest replay handling
- automated maintenance transitions
- scheduled but approved observatory capture routines
- event emission tied to committed mutations

System actors may execute allowed logic.
They do not originate human meaning or strategy.

---

## Authentication Model

### Baseline assumption

The current baseline assumes authenticated operator access for internal write surfaces.

The system must be able to identify the acting operator or service context before permitting mutation.

### Required properties

Authentication must support:
- protected internal write endpoints
- session or token-backed operator identity
- scoped service access where required
- audit-friendly identity resolution

### Non-negotiable rule

No anonymous write path is allowed for canonical state.

If state changes and the system cannot identify the authenticated authority behind it, that is a bug, not a feature.

---

## Authorization Model

Authentication answers who is present.
Authorization answers what that actor is allowed to do.

### Default rule

All write endpoints require authenticated, authorized access.

### Public access

Public or anonymous access may be permitted for explicitly public read-only surfaces.
Public access must not imply mutation authority.

### Internal writes

Internal writes must be authorized according to:
- authenticated identity
- system ownership boundaries
- project scope
- action sensitivity

### Irreversible or high-impact actions

Actions that materially change canonical state, project configuration, or future execution should remain explicitly human-gated unless a narrower documented rule says otherwise.

That is especially important in AI-assisted flows, where convenience is always trying to dress up as wisdom.

---

## Attribution Model

Authentication and attribution are related but not identical.

A safe model distinguishes at least these layers:
- authenticated authority
- initiating actor
- optional assistance metadata

### 1. Authenticated authority

The identity or service context that was authorized to perform the request.

Examples:
- operator session
- short-lived scoped token
- internal service identity

### 2. Initiating actor

The actor category that actually initiated the mutation:
- `human`
- `llm`
- `system`

This is the layer represented in current VEDA event logs.

### 3. Assistance metadata

Additional context may record that a human-authenticated write was LLM-assisted without changing the initiating actor category.

Examples:
- a human saves a record after reviewing an LLM suggestion
- request metadata notes the assisting model or workflow

This distinction matters because not every AI-touched action is honestly attributed as `llm`.
Sometimes the LLM assisted; sometimes it directly initiated an allowed tool action. The system should not lie about which happened.

---

## LLM Write Rules

LLM behavior needs special handling because it is useful, powerful, and occasionally as trustworthy as a raccoon near a shiny latch.

### Rule 1: no unconstrained standalone LLM authority

LLMs must not have broad, long-lived, free-roaming write authority over canonical state.

### Rule 2: approved tool paths only

If an LLM participates in a persisted write, it must do so through an approved path with:
- explicit scope
- bounded capability
- attribution
- review or prior policy gating where required

### Rule 3: direct LLM-initiated writes are exceptional and constrained

A write may be attributed as `llm` only when the LLM directly initiated the state change through an approved path.

That does not mean the LLM independently owns authority.
It means the system intentionally allowed that narrow action and recorded it honestly.

### Rule 4: assistance-only flows should remain assistance-only in attribution

If a human reviews, edits, and saves suggested output, the write should normally remain attributed to `human`, with optional metadata indicating LLM assistance.

### Rule 5: LLMs must not bypass review for sensitive actions

LLMs must not be allowed to silently perform high-impact actions such as:
- changing security-sensitive configuration
- broad destructive deletion
- cross-project mutation
- publishing or distribution actions in future execution systems
- any other irreversible act lacking an explicit approved policy gate

---

## System Write Rules

System-initiated writes are allowed only where the behavior is deterministic, scoped, and explainable.

Valid examples include:
- event emission coupled to a committed mutation
- idempotent replay resolution
- governed maintenance tasks
- background processing with clear ownership and auditability

Invalid examples include:
- system-generated strategic intent
- silent cross-system authority jumps
- background mutation that bypasses authenticated governance expectations

The system is allowed to execute rules.
It is not allowed to hallucinate mission.

---

## Operator Surfaces and Trust Boundaries

Operator surfaces such as the VS Code extension, browser capture tools, dashboard interfaces, and internal clients must behave as API clients, not backdoors.

### Required rules

- operator surfaces authenticate through approved application paths
- operator surfaces do not talk to the database directly
- operator surfaces do not bypass validation or authorization
- operator surfaces do not gain hidden mutation rights just because they are “internal”

### Extension and browser-capture stance

Capture-oriented surfaces may use:
- authenticated browser session context
- short-lived scoped tokens
- explicit capture-only permissions where appropriate

They should remain narrowly scoped and should not become stealth admin tunnels.

---

## Project Scope and Non-Disclosure

Authorization must respect project boundaries.

That means:
- writes must resolve project context explicitly where required
- access to one project must not imply access to another
- a request must not leak whether a cross-project record exists

If a record belongs to another project, the system should behave as though it does not exist unless an explicitly authorized global surface says otherwise.

This is both a security rule and an invariant-preservation rule.

---

## Event and Audit Expectations

Meaningful writes should remain auditable.

At minimum, the system should preserve enough information to reconstruct:
- initiating actor family
- authenticated authority or service context
- affected scope or project
- timestamp
- relevant details needed to explain the change

For VEDA-specific mutations, this should remain aligned with the canonical `EventLog` model and current `ActorType` vocabulary.

Auditability should be truthful, append-friendly, and boring.
Editable history theater is not security.
It is cosplay.

---

## Service Identities and Tokens

Service identities, API tokens, or short-lived action tokens may exist where implementation requires them.

When they do, they should follow these rules:
- minimum necessary scope
- explicit purpose
- revocable lifetime where practical
- no silent privilege escalation
- no substitution for human authority on sensitive actions

A token should grant a narrow capability, not a secret second constitution.

---

## Deferred Complexity

The current baseline does not require full treatment of:
- multi-user teams
- role hierarchies
- third-party API integrations with broad write scopes
- delegated enterprise permission models
- fine-grained approval chains across many operators

Those may be added later.
They should be added explicitly rather than implied through accidental complexity.

---

## Invariants

The following are non-negotiable baseline invariants:

- no anonymous writes
- no unauditable writes
- no cross-project authorization leakage
- no unconstrained standalone LLM write authority
- no operator surface acting as a DB backdoor
- no sensitive mutation path that bypasses required human gating
- no system-initiated mutation that invents intent outside approved rules

Violations are architectural and security bugs.
They are not clever shortcuts.

---

## Relationship to Other Docs

This document should be read alongside:
- `docs/architecture/platform/vercel-neon-prisma.md`
- `docs/architecture/platform/deployment-infrastructure-baseline.md`
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`
- `docs/systems/veda/observatory/event-auditability.md`

Together these docs establish:
- where the system runs
- how state is protected
- how actors are classified
- how meaningful changes remain attributable over time

---

## Maintenance Note

If future work tries to reinterpret this model as permission for:
- autonomous LLM control of canonical state
- hidden service backdoors
- vague attribution
- public mutation by convenience
- cross-system authority blur

that is an architectural warning sign.

The desired model is simple:
- humans hold authority
- LLMs assist through bounded paths
- systems enforce and execute governed rules
- meaningful writes remain attributable

That is how you keep an AI-assisted system useful without letting it turn feral.
