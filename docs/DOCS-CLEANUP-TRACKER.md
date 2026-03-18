# Docs Cleanup Tracker

## Purpose

This document tracks the cleanup status of remaining docs during the post-Wave-2D alignment pass.

It exists so we can answer, at any point:

- what has been reviewed
- what was classified
- what is being rewritten
- what is being archived
- what successor docs are needed
- what ideas were extracted into the grounded salvage layer

This is a workflow tracker, not canonical architecture truth.

Canonical truth remains:

- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`

Related working doc:
- `docs/DOCS-CLEANUP-GROUNDED-IDEAS-EXTRACTION.md`

---

## Status Legend

- `pending` — not yet reviewed
- `reviewed` — read and classified
- `rewrite-needed` — useful but stale; replacement or rewrite needed
- `move-planned` — has a likely target in the new docs structure
- `archive-planned` — should be archived after extraction/classification
- `active-survivor` — appears to survive as an active doc after rewrite/move
- `historical-only` — retain only as archive/history
- `legacy-reference` — implementation or doc remains useful as evidence/input, but is not active architecture truth

---

## VEDA tool list note

- added `docs/systems/operator-surfaces/mcp/veda-tool-list.md` as the portable VEDA tool reference for building additional MCP servers and other API-driven operator surfaces
- this complements the MCP registry by focusing on the VEDA capability list, required inputs, scope behavior, and portability rules rather than just the current server inventory

---

## Audit notes — what to watch for

These are recurring patterns identified during MCP tool audits.  
They are not tool-specific bugs, but structural risks that must be preserved or monitored across implementations.

### 1. Shared handler coupling (junction writes)

Applies to:
- create_cg_page_topic
- create_cg_page_entity

Both rely on a shared handler pattern (handleCreateCgJunction).

What to watch:
- handler assumes identical body shape across routes
- handler assumes identical optional role behavior
- handler assumes identical validation expectations

If any route diverges (extra fields, different defaults, different invariants),
the shared handler must be split or adjusted.

---

### 2. Enum drift between MCP and API

Applies to:
- page roles
- link roles
- publishing states

What to watch:
- MCP input enums must match server Zod enums exactly
- no extra values in MCP
- no missing values from API

If enums diverge, MCP becomes a silent source of invalid requests.

---

### 3. Optional field semantics (undefined vs empty)

Applies broadly to write tools.

What to watch:
- undefined means "not provided"
- empty string must not bypass validation
- handlers must use explicit checks (e.g. !== undefined)

---

### 4. Cross-project non-disclosure

Applies to all project-scoped writes.

What to watch:
- cross-project references must return 404
- not 403
- not descriptive errors

---

### 5. Uniqueness invariants enforced at API layer

Examples:
- pageId + entityId
- pageId + topicId
- pageId + schemaType

What to watch:
- MCP must not attempt to enforce uniqueness
- API is the source of truth
- MCP only forwards valid shape

---

These rules are part of the VEDA system invariants and must be preserved across all operator surfaces.
