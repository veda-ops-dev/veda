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
## Phase 7 legacy decommission

- Active reference audit run across all clean repo files: src/, scripts/, mcp/, extensions/, all configs — 0 active code/script/config leaks
- All 30 legacy path references in docs classified: historical provenance only or self-referential roadmap language
- No active workflow dependency on `C:\dev\veda` found
- `ARCHIVED.md` written to `C:\dev\veda` — explicit archival marker placed in legacy repo root
- Legacy repo is now explicitly decommissioned; it is not renamed/deleted (provenance preserved), but it is marked non-operational
- ROADMAP.md Phase 7 status updated to complete; sequencing summary updated
- Clean repo is the sole operational repository
## Roadmap consolidation — post-reconstruction

- `docs/ROADMAP.md` rewritten from reconstruction execution diary to post-reconstruction control surface
- Completed phases 0–7 compressed into short closeout summaries — outcomes preserved, implementation target lists removed
- Definition-of-done section added as explicit operational criteria (8 criteria, all currently met)
- Future work separated into: maintenance (apply when needed), optional bounded enhancements, belongs-outside-VEDA
- Drift-bait removed: stale "immediate updates required" language, intermediate checkpoint detail, repeated target lists, duplicated phase scaffolding
- Self-referential "eliminate dependency on C:\dev\veda" mission statement removed — that mission is complete
- System invariants, non-goals, and implementation pattern preserved in condensed form
- Provenance section added recording legacy repo origin coordinates
- VEDA is operationally complete per explicit definition-of-done criteria

## YouTube observatory successor docs

- Added new successor doc set under `docs/systems/veda/youtube-observatory/`
- Canonical doc names are now:
  - `overview.md`
  - `observatory-model.md`
  - `ingest-discipline.md`
  - `validation-doctrine.md`
- These docs define YouTube inside VEDA as an observability-only lane, not a publishing, planning, or execution system
- Placement rule established: future YouTube observatory docs belong only under `docs/systems/veda/youtube-observatory/`
- Naming rule established: lowercase, hyphen-separated, functional successor names only; no new root-level `VEDA-YOUTUBE-*.md` fossils
- Historical YouTube/SEO docs from `C:\dev\veda\docs` remain salvage input only, not active truth
- This is a control-surface and doctrine addition; no schema or route authority was created by these docs alone

## YouTube observatory Y1 research artifacts

- Added `docs/systems/veda/youtube-observatory/Y1-RESEARCH-BRIEF.md` — bounded research brief defining five research buckets before schema/route design
- Added `docs/systems/veda/youtube-observatory/Y1-STEP1-INSPECTION-REPORT.md` — Step 1 payload inspection report; documents live DataForSEO YouTube Organic SERP field truth
- Added `docs/systems/veda/youtube-observatory/y1-payload-findings.md` — findings note recording confirmed and unverified payload facts from live inspection
- Added `scripts/yt-payload-inspect.mjs` — inspection script for running remaining query sample passes; not production code
- These are research-phase artifacts; no schema or route authority has been established yet
- Placement rule followed: all YouTube observatory docs under `docs/systems/veda/youtube-observatory/` only

## Owned-performance observatory successor docs

- Added initial successor doc set under `docs/systems/veda/owned-performance/`
- First-pass docs (existed prior): `overview.md`, `ga4-observatory.md`, `instrumentation-and-access.md`
- Doctrine pack completed in this pass:
  - `overview.md` — revised: authority chain updated, GSC explicitly noted as deferred companion lane, new lane docs listed
  - `ga4-observatory.md` — revised: attribution model decision noted as required pre-schema step, observatory-model.md and ga4-research-brief.md cross-referenced
  - `instrumentation-and-access.md` — revised: instrumentation.ts ≠ GA4 clarification added, @next/third-parties noted as official path, vedaops.dev proving surface note added, research brief cross-referenced
  - `observatory-model.md` — created: entity model, observation model, joinability posture, time semantics, truth surface split, interpretation boundary, out-of-scope constraints
  - `ingest-discipline.md` — created: operator-triggered default, project scoping, joinability posture at boundary, raw evidence vs promoted fields, time discipline, idempotency posture, event logging/atomicity
  - `validation-doctrine.md` — created: hammer expectations, fixture-based vs live-source posture, PASS/FAIL/SKIP guidance, minimum v1 validation floor
  - `ga4-research-brief.md` — created: six priority-ranked research buckets, failure modes, bounded research sequence before schema/route judgment
- Placement rule in force: all owned-performance docs belong only under `docs/systems/veda/owned-performance/`
- Naming rule in force: lowercase, hyphen-separated, functional names
- Search Console is explicitly a deferred companion lane; no GSC docs until GA4 lane is doctrine-complete
- No schema tables or route contracts were created by any of these docs
- No live GA4 property has been accessed; the research brief defines what must happen before schema/route judgment is permitted
- `https://www.vedaops.dev/` noted as a possible small-scope proving surface for instrumentation sanity and joinability confirmation

## YouTube observatory Y1 implementation-decision artifacts

- Strict audit performed against all seven YouTube lane docs; readiness verdict: almost ready, blocked by two missing implementation-planning artifacts
- Doctrine pack confirmed strong and internally consistent; payload research confirmed sufficient for schema design
- Three new implementation-decision docs created:
  - `docs/systems/veda/youtube-observatory/y1-schema-judgment.md` — pins the three-table shape (YtSearchTarget, YtSearchSnapshot, YtSearchElement), column decisions, uniqueness keys, EventLog integration, ingest route contract, and normalizer contract
  - `docs/systems/veda/youtube-observatory/y1-hammer-story.md` — defines actual test cases across nine categories before route code exists: target-definition, snapshot ingest, element-row, project isolation, determinism/ordering, mixed-result-type, malformed input, read/write boundary, transaction atomicity
  - `docs/systems/veda/youtube-observatory/y1-implementation-plan.md` — bounded eight-step implementation sequence with done criteria; subordinate to ROADMAP as optional bounded enhancement
- Minor revision applied to `observatory-model.md`: Y1 identity posture note added (identity lives on element rows at Y1, not in a separate lookup table)
- Minor revision applied to `Y1-RESEARCH-BRIEF.md`: status annotations added to all five research buckets reflecting resolution from payload inspection
- Minimal ROADMAP.md update: one line added under Optional Bounded Enhancements referencing `y1-implementation-plan.md`
- Placement rule followed: all new docs under `docs/systems/veda/youtube-observatory/` only
- No application code written; no schema migration applied; no routes created
- These are implementation-decision artifacts bridging doctrine/research to coding posture
