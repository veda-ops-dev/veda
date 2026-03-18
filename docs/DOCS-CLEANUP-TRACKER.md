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
- `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md`
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


---

## Roadmap reconciliation note

- `docs/ROADMAP.md` Phase 3 has been reconciled to repo reality and is now marked `complete`
- reconciliation basis: MCP audit/documentation work was already completed in practice and recorded by commits `ab4a622` and `2a90e81`
- practical next execution lane remains Phase 4 — Ingestion Pipeline Validation
- this status reconciliation is a control-surface update, not a new architecture decision

## Phase 4 ingestion audit correction

- Phase 4 ingestion audit (docs/audits/phase4-ingestion-audit.md) found roadmap text drift only
- Route reference corrected: `POST /api/seo/ingest` → `POST /api/seo/ingest/run` in docs/ROADMAP.md
- "Already implemented" reference tightened: `src/app/api/seo/ingest/` → `src/app/api/seo/ingest/run/`
- Hammer modules and fixture scripts were already aligned to the correct route
- No implementation bug found; no code changes required
- Credential provisioning (DATAFORSEO_LOGIN/PASSWORD) is an operator decision, not a doc or code gap

## Phase 4 completion note

- Phase 4 is now complete in docs/ROADMAP.md
- retained docs/audits/phase4-ingestion-audit.md as the audit record for the route-reference correction
- route reference correction preserved: POST /api/seo/ingest → POST /api/seo/ingest/run
- scripts/hammer/hammer-dataforseo-ingest.ps1 now self-bootstraps s3KtId when standalone execution lacks SIL-3 coordinator context
- validated new full coordinator baseline: **680 PASS / 0 FAIL / 10 SKIP**
- no schema changes or endpoint additions were required to close Phase 4

## Phase 5 documentation alignment — path-truth corrections

- 18 active docs had broken path references due to nesting drift: they used `docs/architecture/X` instead of `docs/architecture/architecture/X`
- All 18 files corrected to use the actual nested paths
- Duplicate `V_ECOSYSTEM.md` resolved: `docs/architecture/V_ECOSYSTEM.md` kept as canonical; `docs/architecture/architecture/V_ECOSYSTEM.md` deleted
- Duplicate `SCHEMA-REFERENCE.md` resolved: `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md` kept as canonical (per ROADMAP "Read This First"); `docs/architecture/veda/SCHEMA-REFERENCE.md` deleted; empty `docs/architecture/veda/` directory removed
- 5 additional active docs corrected from `docs/architecture/veda/SCHEMA-REFERENCE.md` to the nested canonical path
- Legacy provenance refs (`docs/archive/`, `docs/VSCODE-EXTENSION-*.md`) in successor "Supersedes" sections left intact — they document what each doc replaced in the legacy repo
- Phase 4 status updated to complete in ROADMAP (680 PASS / 0 FAIL / 10 SKIP)
- `docs/architecture/architecture/` nesting retained as-is; path references now consistently use the correct nested form

## Phase 6 operator surface foundation

- `extensions/veda-vscode/` created as the successor VS Code extension
- This is a new structure, not a rehab of the legacy `vscode-extension/` from `C:\dev\veda`
- Extension is a thin API consumer: no Prisma, no DB, no local business logic, no hidden mutation
- Two read surfaces wired: SERP weather (project-level) and keyword volatility (focused diagnostic)
- Both surfaces use existing hammer-validated API routes
- No new routes or schema were required
- No endpoint rules or schema rules were triggered
