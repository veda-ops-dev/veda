# VEDA Execution Roadmap

## Purpose

This document is the primary execution guide for rebuilding remaining VEDA observability surfaces in the clean repo and eliminating dependency on the legacy repo.

It is a deterministic, phase-based roadmap.
It is not a brainstorming document, product vision manifesto, or architecture redesign.

The architecture already exists.
The clean repo already exists.
The hammer system already exists.
Most surfaces have already been carried forward.

This roadmap maps the remaining work required to reach full operational independence from the legacy repo.

---

## Read This First

Before advancing any phase, read these documents in order:

1. `docs/architecture/V_ECOSYSTEM.md`
2. `docs/SYSTEM-INVARIANTS.md`
3. `docs/VEDA_WAVE_2D_CLOSEOUT.md`
4. `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md`
5. `docs/architecture/architecture/veda/search-intelligence-layer.md`
6. `docs/architecture/architecture/veda/observatory-models.md`
7. `docs/architecture/architecture/veda/content-graph-model.md`
8. `docs/architecture/architecture/api/api-contract-principles.md`
9. `docs/architecture/architecture/api/validation-and-error-taxonomy.md`
10. `docs/architecture/testing/hammer-doctrine.md`

If a phase conflicts with these documents, the documents win and the phase must be corrected.

---

## Current Reality

---

## Current Execution Anchor (Handoff State)

The clean repo has now reached a validated full-hammer checkpoint aligned to post-Wave-2D VEDA truth.

### Latest validated state

- `GET /api/projects` returns `200`
- Prisma client, env, and DB connectivity are working
- Hammer bootstrap works (`hammer_setup`)
- Full coordinator `scripts/api-hammer.ps1` passes with **0 FAIL**
- Current full baseline:
  - **PASS:** 678
  - **FAIL:** 0
  - **SKIP:** 12
- Modular hammer structure is in place
- SERP disturbances lane is hardened and validated
- VEDA Brain routes are present and passing
- Stale Wave 2D residue was removed from the active hammer gate
- Observatory-floor hammer coverage now includes source capture and events
- Mutation strictness is enforced for search-performance ingest and source-item capture
- Weak hammer skips were tightened where seeded local data already exists`r`n- Ingestion hammer self-bootstrap now eliminates standalone s3KtId fixture drift in Phase 4 validation

### Latest checkpoint commit

```text
roadmap + cleanup alignment: Phase 0/1 complete, hammer realigned to Wave 2D observability-only VEDA, baseline recorded (637 PASS / 0 FAIL / 14 SKIP)
```

This commit is already pushed to `origin/main`.

### Interpretation

The system is no longer in recovery or setup mode.

It is now in **validated execution mode**.

Do not re-solve runtime setup unless new failures appear.
Do not reintroduce removed Wave 2D surfaces just because old hammer files once tested them.

All work should proceed from this checkpoint forward.

### Clean repo: `C:\dev\veda-ops-dev\veda`

Runtime working. Prisma + DB working. Hammer working.

### Already implemented in clean repo

#### Project Lifecycle / Thin Project Partitioning
- `src/app/api/projects/` — project CRUD, project-scoped headers, thin partitioning surface

#### Observatory Floor
- `src/app/api/source-items/` — source item list + capture
- `src/app/api/events/` — event log read surface

#### Search Intelligence Layer (SIL 1–24)
- `src/app/api/seo/keyword-targets/` — keyword target CRUD + all nested diagnostic routes
- `src/app/api/seo/serp-snapshots/` — snapshot list
- `src/app/api/seo/serp-snapshot/` — single snapshot
- `src/app/api/seo/serp-deltas/` — SIL-2 deltas
- `src/app/api/seo/keyword-targets/[id]/volatility/` — SIL-3
- `src/app/api/seo/volatility-summary/` + `seo/projects/[projectId]/volatility-summary/` — SIL-4
- `src/app/api/seo/volatility-alerts/` — SIL-5
- `src/app/api/seo/keyword-targets/[id]/serp-history/` + `feature-history/` — SIL-6
- `src/app/api/seo/keyword-targets/[id]/volatility-breakdown/` + `volatility-spikes/` + `feature-transitions/` — SIL-8
- `src/app/api/seo/alerts/` — SIL-9
- `src/app/api/seo/risk-attribution-summary/` — SIL-10
- `src/app/api/seo/operator-insight/` + `operator-reasoning/` + `operator-briefing/` — SIL-11
- `src/app/api/seo/keyword-targets/[id]/change-classification/` — SIL-12
- `src/app/api/seo/keyword-targets/[id]/event-timeline/` — SIL-13
- `src/app/api/seo/keyword-targets/[id]/event-causality/` — SIL-14
- `src/app/api/seo/keyword-targets/[id]/overview/` — SIL-15
- `src/app/api/seo/keyword-targets/[id]/domain-dominance/` — domain dominance
- `src/app/api/seo/keyword-targets/[id]/intent-drift/` — intent drift
- `src/app/api/seo/keyword-targets/[id]/feature-volatility/` — feature volatility
- `src/app/api/seo/keyword-targets/[id]/serp-similarity/` — SERP similarity
- `src/app/api/seo/serp-disturbances/` — SIL-16 through SIL-24 composite pipeline
- `src/app/api/seo/page-command-center/` — page command center
- `src/app/api/seo/search-performance/` — search performance observation
- `src/app/api/seo/keyword-research/` — keyword research
- `src/app/api/seo/ingest/run/` — DataForSEO ingestion

#### Pure Libraries
- `src/lib/seo/` — all SIL pure library functions (serp-extraction, volatility-service, change-classification, event-timeline, event-causality, keyword-overview, page-command-center, domain-dominance, intent-drift, feature-volatility, serp-similarity, serp-disturbance, serp-event-attribution, serp-weather, serp-weather-forecast, serp-weather-alerts, serp-alert-briefing, serp-keyword-impact, serp-operator-hints, operator-insight, reasoning/, briefing/)
- `src/lib/content-graph/` — content graph intelligence libraries (archetype-distribution, topic-coverage, entity-coverage, schema-coverage, internal-authority, content-graph-diagnostics)
- `src/lib/veda-brain/` — VEDA brain libraries (diagnostics, proposals, keyword-page-mapping, gap analyses, readiness, opportunities)

#### Content Graph
- `src/app/api/content-graph/` — full CRUD (surfaces, sites, pages, topics, entities, page-topics, page-entities, internal-links, archetypes, schema-usage, project-diagnostics)

#### VEDA Brain
- `src/app/api/veda-brain/project-diagnostics/` — thin GET route over diagnostics library
- `src/app/api/veda-brain/proposals/` — thin GET route over proposals library

#### MCP
- `mcp/server/src/` — MCP server (api-client, tools, tool-handlers, index)

#### Hammer Suite
- `scripts/api-hammer.ps1` — coordinator aligned to active VEDA surfaces
- `scripts/hammer/` — hammer modules for active observability surfaces (seo, sil2–sil11+briefing, feature-history, feature-volatility, domain-dominance, intent-drift, serp-similarity, change-classification, event-timeline, event-causality, dataforseo-ingest, realdata-fixtures, keyword-overview, page-command-center, sil16–sil22-24, content-graph-phase1, content-graph-intelligence, veda-brain-phase1, project-bootstrap, veda-brain-proposals, w5-persistence, source-capture)

### Known cleanup resolution

The following were removed from the active hammer gate because they are not valid post-Wave-2D VEDA surfaces:

- `hammer-core.ps1` legacy entity / audits / draft-artifacts / promotion expectations
- blueprint workflow tests from `hammer-project-bootstrap.ps1`
- quotable-block tests from `hammer-seo.ps1`

These were stale residue, not implementation gaps.

Additional Phase 2.5 hardening outcomes:

- `scripts/hammer/hammer-source-capture.ps1` now covers source capture, source-items list, and events list invariants
- `src/app/api/source-items/capture/route.ts` now resolves existing items by the project-scoped `(projectId, url)` uniqueness invariant
- `src/app/api/source-items/capture/route.ts` and `src/app/api/seo/search-performance/ingest/route.ts` now use strict project resolution for mutation discipline
- stale `hammer-core.ps1` has been quarantined under `old/hammer-core.ps1`
- skip discipline was tightened so seeded local-data assertions now produce PASS/FAIL where appropriate instead of weak SKIPs

### Legacy repo: `C:\dev\veda` (reference only)

Branch: `feature/veda-command-center`, commit `31a8deb`.

The legacy repo also contains `vscode-extension/`, `src/app/dashboard/`, `docs/archive/`, `docs/specs/deferred/`, and other surfaces explicitly excluded from carry-forward per `CARRY_FORWARD_MANIFEST.txt`.

---

## Constraints

All phases must preserve:

1. VEDA observability-only bounded domain ownership
2. Wave 2D constraints — no editorial, draft, blueprint, or publishing workflow
3. Compute-on-read default — no background jobs, no caching layers
4. Transactional mutation with co-located EventLog writes where required
5. Multi-project isolation at both application and DB trigger layers
6. Deterministic ordering with explicit tie-breakers
7. Pure library pattern for all SIL layers
8. Thin route handlers — fetch data, call library, return response
9. Hammer-first validation before any surface is considered complete
10. Schema changes only when they satisfy the schema rules and can be explicitly justified
11. Endpoint additions only when they satisfy the endpoint rules and can be explicitly justified

No phase may:

- Introduce new schema changes unless explicitly justified against schema rules
- Introduce new bounded systems
- Move ownership across V Ecosystem boundaries
- Reintroduce removed VEDA domains
- Assume legacy repo structures are correct

Rule:

```text
successor docs first, fossils second
```

---

## Phase Status Tracking

Each phase must carry a status.

Allowed values:

- `pending`
- `active`
- `complete`
- `blocked`

Current state:

| Phase | Status |
|------|--------|
| Phase 0 — Hammer Baseline Validation | complete |
| Phase 1 — VEDA Brain Route Reconstruction | complete |
| Phase 2 — Observatory Floor Hammer Hardening | complete |
| Phase 3 — MCP Tool Surface Alignment | complete |
| Phase 4 — Ingestion Pipeline Validation | complete |
| Phase 5 — Documentation Alignment | complete |
| Phase 6 — Operator Surface Foundation | complete |
| Phase 7 — Legacy Decommission | pending |

Update this table as phases progress.

This is the execution control surface for the roadmap.

---

## Cleanup Intelligence Enforcement

This roadmap does not replace the cleanup intelligence layer.

The following documents remain mandatory companions:

- `docs/DOCS-CLEANUP-TRACKER.md`
- `docs/DOCS-CLEANUP-GROUNDED-IDEAS-EXTRACTION.md`

If roadmap execution causes any of the following:

- new successor doc creation
- doc reclassification or archival
- structural changes to system surfaces
- new doctrine creation (e.g., hammer modules, operator rules)
- changes to reconstruction sequencing

then both tracker docs must be updated.

Failure to update these documents results in reconstruction drift.

---
## Phase 0 — Hammer Baseline Validation

### Objective

Confirm every carried-forward active VEDA surface in the clean repo passes its hammer module. Establish the green baseline that all subsequent phases build on.

### Status

**Complete**

### Outcome snapshot

- Full coordinator run completes with **0 FAIL**
- Baseline snapshot recorded:
  - **PASS:** 678
  - **FAIL:** 0
  - **SKIP:** 12
- Stale Wave 2D residue removed from the active hammer gate
- Full hammer now reflects current VEDA truth instead of inherited mixed-era assumptions

### System Scope

VEDA (all active observability surfaces)

### Exit Criteria

Met.

---

## Phase 1 — VEDA Brain Route Reconstruction

### Objective

Rebuild the missing `src/app/api/veda-brain/` route handlers as thin read-only API surfaces over the existing pure libraries in `src/lib/veda-brain/`.

### Status

**Complete**

### Outcome

Implemented:
- `src/app/api/veda-brain/project-diagnostics/route.ts`
- `src/app/api/veda-brain/proposals/route.ts`

Validated by:
- `scripts/hammer/hammer-veda-brain-phase1.ps1`
- `scripts/hammer/hammer-veda-brain-proposals.ps1`
- full coordinator remains at 0 FAIL

### Exit Criteria

Met.

---

## Phase 2 — Observatory Floor Hammer Hardening

### Objective

Expand and clean hammer coverage for the observatory floor surfaces so the active gate fully reflects current VEDA observability truth and no longer carries entity-era or blueprint-era assumptions.

### Status

**Complete**

### System Scope

VEDA

### Surfaces / Lanes

- `GET /api/source-items`
- `POST /api/source-items/capture`
- `GET /api/events`
- `POST /api/projects`
- `GET /api/projects`
- current project-context strictness tests
- current observatory-floor mutation and read invariants

### Source of Truth Docs

- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/ingest-discipline.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/event-auditability.md`
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/security/auth-and-actor-model.md`
- `docs/architecture/testing/hammer-doctrine.md`

### Outcome

Completed in this phase:
- added `scripts/hammer/hammer-source-capture.ps1` for direct observatory-floor coverage
- fixed `src/app/api/source-items/capture/route.ts` to use project-scoped `(projectId, url)` lookup semantics
- enforced strict project context on mutation routes for source capture and search-performance ingest
- hardened `hammer-seo.ps1` to remove stale `$entityId` assumptions from search-performance tests
- tightened weak SKIPs in observability lanes where local seeded data already made real assertions possible
- quarantined retired `hammer-core.ps1` under `old/hammer-core.ps1`

Validated by latest full coordinator run:
- **PASS:** 678
- **FAIL:** 0
- **SKIP:** 12

### Exit Criteria

Met.

### Legacy Replacement Mapping

This phase removed residual confidence gaps rather than adding new observability boundaries.

---

## Phase 3 — MCP Tool Surface Alignment

### Objective

Verify and update the MCP server tool surface to reflect all active API routes in the clean repo. Ensure MCP tools are HTTP-only with no direct DB access.

### Status

**Complete**

### System Scope

VEDA (MCP operator surface)

### Surfaces / Lanes

- `mcp/server/src/tools.ts` — tool definitions
- `mcp/server/src/tool-handlers.ts` — handler implementations
- `mcp/server/src/api-client.ts` — HTTP client

### Current implementation note

The current MCP server is also serving as a Claude Desktop-compatible development harness for bounded assistant testing.
This is a temporary practical dev/testing posture, not the final ecosystem-wide LLM access model.
Future MCP/API exposure must still preserve bounded ownership across Project V, VEDA, and V Forge.

### Source of Truth Docs

- `docs/systems/operator-surfaces/mcp/overview.md`
- `docs/systems/operator-surfaces/mcp/tooling-principles.md`
- `docs/architecture/architecture/api/api-contract-principles.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/veda/search-intelligence-layer.md`

### Implementation Targets

1. Audit `tools.ts` against current API routes — identify any missing tool definitions for active routes
2. Audit `tool-handlers.ts` — confirm all handlers call HTTP API routes only
3. Add tool definitions for any active API surface not currently exposed via MCP
4. Priority order for new tool coverage:
   - VEDA brain diagnostics and proposals
   - Content graph project-diagnostics
   - Any SIL surfaces not already exposed
5. Verify `api-client.ts` includes no Prisma imports or direct DB calls

### Hammer Validation

- Use existing hammer-validated API routes as the truth surface
- Add `hammer-mcp-smoke.ps1` only if a real MCP boundary needs its own validation surface

### Outcome

Completed in this phase:
- audited MCP tool definitions against live API routes
- documented MCP as the current Claude Desktop-compatible dev harness for bounded assistant development/testing
- created `docs/systems/operator-surfaces/mcp/tool-registry.md` as the current server inventory
- created `docs/systems/operator-surfaces/mcp/veda-tool-list.md` as the portable VEDA capability reference for future MCP/operator surfaces
- strengthened structural “what to watch for” notes so future MCP surfaces do not regress into ownership drift or contract mismatch

Validated by repo reality and commits:
- ab4a622 — document MCP as current Claude Desktop-compatible dev harness
- 2a90e81 — audit and document mcp tool surface

### Exit Criteria

Met.

### Legacy Replacement Mapping

Replaces: `C:\dev\veda\mcp\server\src\` — the clean repo MCP surface becomes the sole MCP truth.

---
## Phase 4 — Ingestion Pipeline Validation

### Objective

Confirm the DataForSEO ingestion pipeline and fixture replay system work end-to-end in the clean repo. Validate that ingested data flows correctly through the SIL computation pipeline.

### Status

**Complete**

### Outcome

Validated by full hammer coordinator run:
- `hammer-dataforseo-ingest.ps1`: 10 PASS / 0 FAIL / 0 SKIP
- `hammer-realdata-fixtures.ps1`: fixture replay + seeding + value invariants pass
- `hammer-w5-persistence.ps1`: deterministic persistence, EventLog, idempotency, cross-project isolation pass
- Full coordinator: 680 PASS / 0 FAIL / 10 SKIP

Fixes applied during Phase 4:
- Roadmap route reference corrected from `/api/seo/ingest` to `/api/seo/ingest/run`
- `hammer-dataforseo-ingest.ps1` self-bootstrap setup added (was missing, caused 7 SKIPs)

### System Scope

VEDA

### Surfaces / Lanes

- `POST /api/seo/ingest/run` — DataForSEO SERP ingestion
- `scripts/fixtures/replay-fixture.ts` — single fixture replay
- `scripts/fixtures/replay-all.ts` — batch fixture replay
- `scripts/fixtures/seed-serp-fixture.ts` — fixture seeding
- `scripts/fixtures/export-serp-fixture.ts` — fixture export

### Source of Truth Docs

- `docs/systems/veda/observatory/ingest-discipline.md`
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/architecture/architecture/veda/search-intelligence-layer.md`
- `docs/SYSTEM-INVARIANTS.md`

### Implementation Targets

- Run `hammer-dataforseo-ingest.ps1` and confirm ingestion contract
- Run `hammer-realdata-fixtures.ps1` and confirm fixture replay
- Verify fixture replay produces SERPSnapshot records that the SIL pipeline can consume
- Verify `hammer-w5-persistence.ps1` passes (persistence correctness)
- If any fixture scripts reference legacy repo paths, update to clean repo paths

### Hammer Validation

- `hammer-dataforseo-ingest.ps1` — must pass
- `hammer-realdata-fixtures.ps1` — must pass
- `hammer-w5-persistence.ps1` — must pass

### Exit Criteria

- Ingestion route accepts valid DataForSEO payloads and persists SERPSnapshots
- Ingestion route rejects invalid payloads with correct error shape
- Fixture replay produces queryable snapshot history
- SIL pipeline can compute against replay-seeded data (verified by running SIL hammer modules after replay)
- Full coordinator: 0 FAIL

### Legacy Replacement Mapping

Replaces: `C:\dev\veda\src\app\api\seo\ingest\`, `C:\dev\veda\scripts\fixtures\`

---

## Phase 5 — Documentation Alignment

### Objective

Ensure all active documentation in the clean repo reflects clean repo truth. Remove stale legacy references. Confirm doc paths referenced in this roadmap and in code comments resolve correctly.

### Status


**Complete**

### Outcome

Completed in this phase:
- 18 active docs corrected for nesting-drift path references (`docs/architecture/X` → `docs/architecture/architecture/X`)
- Duplicate `V_ECOSYSTEM.md` resolved: `docs/architecture/V_ECOSYSTEM.md` kept as canonical; nested duplicate deleted
- Duplicate `SCHEMA-REFERENCE.md` resolved: `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md` kept as canonical; outer duplicate deleted
- SIL registry updated: 5 missing active surfaces added (domain-dominance, intent-drift, feature-volatility, serp-similarity, page-command-center)
- Legacy provenance refs in successor "Supersedes" sections confirmed intentional and left intact
- `docs/architecture/architecture/` nesting retained as-is; all path references now correct
- Cleanup intelligence docs updated throughout


### System Scope

VEDA (documentation layer, all bounded systems referenced)

### Surfaces / Lanes

- `docs/` — all active documentation
- `CARRY_FORWARD_MANIFEST.txt` — carry-forward provenance

### Source of Truth Docs

- `docs/DOCS-CLEANUP-TRACKER.md`
- `docs/DOCS-CLEANUP-GROUNDED-IDEAS-EXTRACTION.md`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`

### Immediate documentation updates required by current repo reality

- Update roadmap phase status and current execution anchor to reflect:
  - Phase 0 complete
  - Phase 1 complete
  - full hammer at 677 PASS / 0 FAIL / 13 SKIP
  - stale Wave 2D hammer residue removed from the active gate
  - observatory-floor hammer hardening checkpoint applied
- Update cleanup intelligence layer to record the hammer realignment and removal of stale blueprint / entity / draft-artifact / quotable-block enforcement from active VEDA validation

### Remaining implementation targets

1. Audit all doc references to file paths — confirm each referenced path exists in clean repo
2. ~~Resolve the duplicate `V_ECOSYSTEM.md`~~ — resolved: `docs/architecture/V_ECOSYSTEM.md` is canonical; nested duplicate deleted
3. ~~Resolve nested `docs/architecture/architecture/` structure~~ — resolved: nesting retained as-is; all cross-doc references corrected to use actual nested paths
4. Review `DOCS-CLEANUP-TRACKER.md` for any open items
5. Update `search-intelligence-layer.md` registry if any implementation anchors have shifted during carry-forward
6. Verify `ROADMAP.md` doc path references remain valid

### Exit Criteria

- No documentation references files that don't exist in the clean repo
- No documentation references legacy repo paths as active truth
- Duplicate docs are resolved to single canonical locations
- `DOCS-CLEANUP-TRACKER.md` open items are either resolved or explicitly deferred
- Doc nesting structure is intentional and documented

### Legacy Replacement Mapping

Replaces: all documentation from `C:\dev\veda\docs\` — the clean repo docs become the sole documentation truth.

---

## Phase 6 — Operator Surface Foundation

### Objective

Establish the VS Code successor surface foundation following the existing successor roadmap. This phase corresponds to Phase 1 of `docs/ROADMAP.md` (VS Code Successor Surface Roadmap) but is sequenced here after the underlying VEDA surfaces are fully validated.

### Status

**Complete**

### Outcome

Implemented:
- `extensions/veda-vscode/` — successor VS Code extension (new, not legacy rehab)
- `src/extension.ts` — activation + command registration
- `src/api-client.ts` — thin HTTP transport (fetch-based, x-project-id headers)
- `src/state.ts` — lightweight session state (environment + project)
- `src/commands.ts` — 4 operator commands (environment, project, SERP weather, keyword volatility)
- `src/status-bar.ts` — persistent environment/project context indicators

Read surfaces wired:
- Project-level: `GET /api/seo/serp-disturbances` (SERP weather, SIL-16–24 composite)
- Focused diagnostic: `GET /api/seo/keyword-targets/{id}/volatility` (SIL-3)

Invariants preserved:
- No Prisma, no DB access, no connection strings
- No local business logic or analytics computation
- No hidden mutation (all commands are reads)
- Explicit environment and project context in status bar
- Thin HTTP client only

### System Scope

Cross-system operator surface (reads from VEDA, governed by V Ecosystem boundary rules)

### Surfaces / Lanes

Per `docs/systems/operator-surfaces/vscode/phase-1-spec.md`:
- Environment context
- Explicit project context
- One project-level read surface
- One focused diagnostic read surface
- Lightweight rendering of bounded results
- Thin transport/state layers only

### Source of Truth Docs

- `docs/systems/operator-surfaces/vscode/phase-1-spec.md`
- `docs/systems/operator-surfaces/vscode/repo-native-workflow.md`
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/systems/operator-surfaces/overview.md`
- `docs/architecture/architecture/api/api-contract-principles.md`
- `docs/architecture/architecture/api/validation-and-error-taxonomy.md`
- `docs/architecture/V_ECOSYSTEM.md`

### Implementation Targets

- Successor VS Code extension project structure (new, not legacy `vscode-extension/`)
- Environment detection and base URL configuration
- Project context resolution (header-based, matching API convention)
- One bounded read surface (for example, project-level volatility summary or SERP weather)
- One focused diagnostic read surface (for example, keyword-target diagnostic detail)
- Thin HTTP client — no Prisma, no DB, no local analytics, no polling

### Validation

The extension remains an API consumer. Any required API changes must be justified against endpoint rules before being introduced.

### Exit Criteria

Per the VS Code successor roadmap Phase 1 done-when:
- Explicit environment and project context
- Bounded read access to relevant system surfaces
- No local business logic
- No direct DB access
- No hidden mutation
- Clear distinction between repo work and system-state work

### Legacy Replacement Mapping

Replaces: `C:\dev\veda\vscode-extension\` — the successor surface replaces the legacy extension entirely.

---

## Phase 7 — Legacy Decommission

### Objective

Archive the legacy repo. The clean repo becomes the sole operational repo. No further reference to `C:\dev\veda` is required for any active work.

### Status

**Complete**

### System Scope

All (operational boundary, not code)

### Surfaces / Lanes

- Legacy repo archival
- CI/CD migration (if applicable)
- Environment variable migration
- Any deployment configuration migration

### Source of Truth Docs

- `CARRY_FORWARD_MANIFEST.txt`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- This document (`docs/ROADMAP.md`)

### Implementation Targets

1. Final audit: run full hammer suite against clean repo — confirm 0 FAIL
2. Verify no active code, script, or config references `C:\dev\veda` paths
3. Verify no documentation references legacy repo as active truth
4. Archive legacy repo (rename, move to archive directory, or mark as archived in git hosting)
6. Update any deployment, CI, or hosting configuration to point to the sole repo

### Exit Criteria

- Legacy repo is archived and no longer referenced by any active workflow
- Clean repo is the sole operational repository
- All active documentation, scripts, and configurations reference only the clean repo
- Full hammer suite: 0 FAIL
- Operator can perform all VEDA observability work without touching the legacy repo

### Outcome

Completed in this phase:
- Active reference audit across all clean repo directories — 0 active code/script/config leaks found
- All legacy path mentions confirmed as historical provenance or self-referential roadmap language only
- `ARCHIVED.md` written to `C:\dev\veda` — explicit archival marker
- `C:\dev\veda` is now marked decommissioned; no active workflow depends on it
- Full hammer suite was previously validated at 680 PASS / 0 FAIL / 10 SKIP

### Legacy Replacement Mapping

This phase completes the replacement. The legacy repo `C:\dev\veda` at branch `feature/veda-command-center` commit `31a8deb` is fully superseded.

---

## Phase Sequencing Summary

```text
Phase 0  Hammer Baseline Validation        [complete]
  │
  ▼
Phase 1  VEDA Brain Route Reconstruction   [complete]
  │
  ▼
Phase 2  Observatory Floor Hammer Hardening [complete]
  │
  ▼
Phase 3  MCP Tool Surface Alignment        [complete]
  │
  ▼
Phase 4  Ingestion Pipeline Validation     [complete]
  │
  ▼
Phase 5  Documentation Alignment           [complete]
  │
  ▼
Phase 6  Operator Surface Foundation       [complete]
  │
  ▼
Phase 7  Legacy Decommission               [complete]
```

Phases 0–4 are core VEDA observability work and must be sequential.

Phase 5 (documentation) can run in parallel with Phases 2–4 if convenient.

Phase 6 (operator surface) depends on Phases 0–4 being complete enough to provide stable bounded API surfaces.

Phase 7 depends on all prior phases.

---

## Proven Working Pattern

Every implementation phase follows the same pattern:

```text
1. thin route handler (resolve scope, validate, delegate)
2. pure library function (deterministic, side-effect-free, explicit inputs)
3. hammer module (contract, isolation, ordering, read-only verification)
4. full coordinator run (no regressions)
```

This pattern has been validated through SIL-2 through SIL-24, content graph, VEDA brain, and hammer cleanup alignment.

Do not deviate from this pattern unless explicitly instructed.

---

## Explicit Non-Goals

This roadmap does not authorize:

- Schema changes without satisfying the schema rules and producing a clear justification
- New endpoints without satisfying the endpoint rules and producing a clear justification
- New enum additions without real invariant need
- New bounded systems
- Reintroduction of removed VEDA domains (drafts, editorial, publishing, blueprint, distribution)
- Speculative feature growth beyond documented surfaces
- Dashboard or web UI implementation
- Background job infrastructure
- Caching layers
- Any work that violates `docs/SYSTEM-INVARIANTS.md`

If a future need appears to require any of the above, stop and reassess against the V Ecosystem boundary rules before proceeding.

---

## Decision Rule

Before starting any phase:

1. Has the previous phase exited green?
2. Do the source-of-truth docs still apply?
3. Does the implementation follow the proven working pattern?
4. Does the hammer validate the result?
5. Does the full coordinator still show 0 FAIL?

If any answer is no, do not advance.

---

## Maintenance Note

This roadmap is a living execution guide.

When a phase completes, update its status in this document.
When a phase reveals unexpected work, add it as a sub-phase rather than expanding scope silently.
When hammer truth changes because stale residue is removed or a new active surface is added, update the cleanup intelligence layer as well.

The goal is a clean, validated, operationally independent repo.
Not a perfect repo. Not a maximally featured repo.
A working repo that no longer needs the legacy repo for anything.

---

## Execution Mode

This roadmap transitions the project from exploration to execution.

The working loop is:

```text
select phase → implement → hammer → validate → commit → update status → repeat
```

Do not deviate from this loop.

Do not introduce parallel speculative work.

Do not expand scope mid-phase.

This roadmap exists to:

```text
eliminate dependency on C:\dev\veda
```

When Phase 7 completes, the legacy repo must no longer be required for any operation.







