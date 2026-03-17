# MCP Tooling Principles

## Purpose

This document defines the durable principles that should govern MCP tools in the V Ecosystem.

It exists to answer:

```text
What rules should MCP tools follow so they remain bounded, safe, and useful during reconstruction and later growth?
```

This is an active operator-surface architecture document.
It is not a tool catalog and not a backlog of speculative powers.

---

## Core Rule

MCP tools are interfaces.
They are not owners, not sources of truth, and not shortcuts around bounded system rules.

Every MCP tool should preserve this chain:

```text
assistant -> MCP tool -> HTTP/API contract -> bounded system capability
```

If a tool breaks that chain, it is probably trying to be clever in the bad way.

---

## Principle 1: Ownership stays explicit

Every MCP tool should map to a clearly owned capability.

That means a tool should be understandable as one of:
- Project V owned
- VEDA owned
- V Forge owned
- cross-system operator navigation with explicit underlying ownership

A tool must not hide mixed ownership behind vague labels like:
- command center
- workspace brain
- unified control
- intelligent orchestration

Those names are catnip for architectural drift.

---

## Principle 2: API-only access

MCP tools should interact through governed APIs.
They should not:
- query the database directly
- bypass validation
- bypass auth or scope checks
- invent alternate contracts outside the API layer

If a tool needs data the API does not expose safely, fix the API or architecture first.
Do not tunnel around it like a tiny raccoon with admin credentials.

---

## Principle 3: Project scope is mandatory

Project-scoped tools must behave as project-scoped tools.
That means:
- explicit scope resolution
- no cross-project leakage
- no silent fallback to another project
- no “best effort” blending across project boundaries

A tool that leaks between projects is not being helpful. It is doing identity theft with extra steps.

---

## Principle 4: Read is the default

During the current reconstruction phase, MCP should default to read-oriented tools.
This is especially true for VEDA-owned surfaces.

Read-oriented MCP tools are appropriate for:
- observatory state
- search-intelligence diagnostics
- evidence-backed proposal visibility
- project-level summaries
- operator briefings and reasoning surfaces

Mutation should be rare, explicit, bounded, and human-gated.

---

## Principle 5: No silent mutation

MCP tools must never silently mutate canonical state.
If a mutation exists, it must be:
- explicit in the tool contract
- attributable
- reviewable
- bounded by owner rules
- aligned with `Propose -> Review -> Apply`

This applies even when a mutation feels “small” or “obvious.”
Small hidden mutations grow into large haunted systems.

---

## Principle 6: Deterministic outputs where possible

MCP tools should prefer deterministic, structured outputs.
That means:
- stable field names
- clear ordering rules
- explicit nullability
- minimal ambiguity about what the tool returns

Narrative synthesis is allowed where appropriate, but the underlying result shape should still be inspectable.
The assistant can add explanation on top. The tool should not hand back shapeless soup.

---

## Principle 7: Tool descriptions must not overclaim

Tool descriptions should explain:
- what the tool returns
- what scope it uses
- whether it reads or mutates
- what important constraints apply

Tool descriptions should not imply:
- ownership the tool does not have
- automation the system does not perform
- workflow authority the underlying system does not own

A misleading description is drift in prose form.

---

## Principle 8: Proposal visibility is allowed; proposal authority is not

MCP is a good surface for showing:
- candidate interpretations
- evidence-backed proposals
- recommended next inspections
- review packets

MCP is not the place to quietly convert proposals into canonical decisions.
The proposal can be visible without becoming truth.

---

## Principle 9: Repo work and system-state work must stay distinguishable

MCP may exist alongside repo-native tooling, but the lanes must remain legible.

System-state work includes:
- reading bounded system data
- triggering governed API behavior
- reviewing owned system outputs

Repo-native work includes:
- reading files
- editing files
- diffs
- commits
- local execution

A workflow may involve both.
A tool should still make it obvious which lane it belongs to.

---

## Principle 10: Verification matters

Important MCP tools should be verifiable for:
- scope correctness
- non-disclosure
- API alignment
- stable response structure
- absence of hidden side effects

A tool that cannot be explained or tested cleanly is probably overreaching.

---

## Current Priority Guidance

In the current repo phase, MCP tooling should prioritize:
- VEDA observatory read surfaces
- Search Intelligence Layer read surfaces
- project-scoped diagnostics
- operator briefing and reasoning surfaces that remain read-only
- bounded proposal visibility

Do not prioritize broad mutation surfaces until ownership, API contracts, and review discipline are explicit.

---

## Anti-Patterns

Avoid MCP tools that behave like:
- secret admin endpoints
- generic “do everything” tools
- hidden multi-owner workflows
- repo mutation disguised as VEDA work
- autonomous apply tools
- tool descriptions that read like product fantasy novels

If a tool sounds impressive but its owner is fuzzy, that is not sophistication. That is a future incident report.

---

## What This Means for Legacy MCP Specs

Older MCP specs may still contain useful ideas about:
- grouping tools
- read-vs-mutate discipline
- operator-facing summaries
- API-only behavior

Those ideas can be salvaged.
The old spec does not automatically become active truth.
Current active docs and current implementation win.

---

## Related Docs

This document should be read with:
- `docs/systems/operator-surfaces/overview.md`
- `docs/systems/operator-surfaces/mcp/overview.md`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`
- `docs/architecture/llm-assisted-operations.md`
- `docs/architecture/veda/search-intelligence-layer.md`
