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

The clean repo has already reached a validated checkpoint.

### Latest validated state

- `GET /api/projects` returns `200`
- Prisma client, env, and DB connectivity are working
- Hammer bootstrap works (`hammer_setup`)
- `hammer_run_module` for `sil22-24` passed `15/15`
- Modular hammer structure is in place
- SERP disturbances lane is hardened and validated

### Latest checkpoint commit

```text
harden serp disturbances route and modularize hammer lane
```

This commit is already pushed to `origin/main`.

### Interpretation

The system is no longer in recovery or setup mode.

It is now in **incremental hardening and completion mode**.

Do not re-solve runtime setup unless new failures appear.

All work should proceed from this checkpoint forward.

### Clean repo: `C:\dev\veda-ops-dev\veda`

Runtime working. Prisma + DB working. Hammer working.

### Already implemented in clean repo

#### Project Lifecycle
- `src/app/api/projects/` — project CRUD, bootstrap, project-scoped headers

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
- `src/app/api/seo/ingest/` — DataForSEO ingestion

#### Pure Libraries
- `src/lib/seo/` — all SIL pure library functions (serp-extraction, volatility-service, change-classification, event-timeline, event-causality, keyword-overview, page-command-center, domain-dominance, intent-drift, feature-volatility, serp-similarity, serp-disturbance, serp-event-attribution, serp-weather, serp-weather-forecast, serp-weather-alerts, serp-alert-briefing, serp-keyword-impact, serp-operator-hints, operator-insight, reasoning/, briefing/)
- `src/lib/content-graph/` — content graph intelligence libraries (archetype-distribution, topic-coverage, entity-coverage, schema-coverage, internal-authority, content-graph-diagnostics)
- `src/lib/veda-brain/` — VEDA brain libraries (diagnostics, proposals, keyword-page-mapping, gap analyses, readiness, opportunities)

#### Content Graph
- `src/app/api/content-graph/` — full CRUD (surfaces, sites, pages, topics, entities, page-topics, page-entities, internal-links, archetypes, schema-usage, project-diagnostics)

#### MCP
- `mcp/server/src/` — MCP server (api-client, tools, tool-handlers, index)

#### Hammer Suite
- `scripts/api-hammer.ps1` — coordinator with 40+ registered modules
- `scripts/hammer/` — all hammer modules (core, seo, sil2–sil11+briefing, feature-history, feature-volatility, domain-dominance, intent-drift, serp-similarity, change-classification, event-timeline, event-causality, dataforseo-ingest, realdata-fixtures, keyword-overview, page-command-center, sil16–sil22-24, content-graph-phase1, content-graph-intelligence, veda-brain-phase1, project-bootstrap, veda-brain-proposals, w5-persistence)

### Known gap in clean repo

| Gap | Detail |
| --- | --- |
| `src/app/api/veda-brain/` routes | Library code exists in `src/lib/veda-brain/`. Route handlers for `project-diagnostics/` and `proposals/` are missing. Legacy repo has them at `src/app/api/veda-brain/`. |

### Legacy repo: `C:\dev\veda` (reference only)

Branch: `feature/veda-command-center`, commit `31a8deb`.

The legacy repo also contains `vscode-extension/`, `src/app/dashboard/`, `docs/archive/`, `docs/specs/deferred/`, and other surfaces explicitly excluded from carry-forward per `CARRY_FORWARD_MANIFEST.txt`.

---

## Constraints

All phases must preserve:

1. VEDA observability-only bounded domain ownership
2. Wave 2D constraints — no editorial, draft, or publishing workflow
3. Compute-on-read default — no background jobs, no caching layers
4. Transactional mutation with co-located EventLog writes
5. Multi-project isolation at both application and DB trigger layers
6. Deterministic ordering with explicit tie-breakers
7. Pure library pattern for all SIL layers
8. Thin route handlers — fetch data, call library, return response
9. Hammer-first validation before any surface is considered complete

No phase may:

- Introduce new schema changes unless explicitly instructed
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

Initial state:

| Phase | Status |
|------|--------|
| Phase 0 — Hammer Baseline Validation | active |
| Phase 1 — VEDA Brain Route Reconstruction | pending |
| Phase 2 — Observatory Floor Hammer Hardening | pending |
| Phase 3 — MCP Tool Surface Alignment | pending |
| Phase 4 — Ingestion Pipeline Validation | pending |
| Phase 5 — Documentation Alignment | pending |
| Phase 6 — Operator Surface Foundation | pending |
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

Confirm every carried-forward surface in the clean repo passes its hammer module. Establish the green baseline that all subsequent phases build on.

### System Scope

VEDA (all surfaces)

### Surfaces / Lanes

All existing API routes and library functions already present in the clean repo.

### Source of Truth Docs

- `docs/architecture/testing/hammer-doctrine.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/api/api-contract-principles.md`

### Implementation Targets

No new code. This phase is validation-only.

- Run full `scripts/api-hammer.ps1` against the clean repo
- Identify any FAIL results
- Triage failures into: carry-forward bug vs missing seed data vs test-environment issue

### Hammer Validation

- Run full coordinator: `.\scripts\api-hammer.ps1`
- Every registered module must produce a result (PASS, FAIL, or SKIP)
- Target: 0 FAIL across all modules
- SKIP results are acceptable only for tests that depend on seed data not yet present

### Exit Criteria

- Full hammer run completes with 0 FAIL
- All SKIP results are documented with reason
- Baseline PASS/SKIP/FAIL counts recorded as the Phase 0 snapshot

### Legacy Replacement Mapping

N/A — this phase validates existing carry-forward, not new implementation.

---

## Phase 1 — VEDA Brain Route Reconstruction

### Objective

Rebuild the missing `src/app/api/veda-brain/` route handlers. The pure library code already exists in `src/lib/veda-brain/`. This phase adds the thin API routes that expose those libraries.

### System Scope

VEDA

### Surfaces / Lanes

| Route | Purpose | Library anchor |
| --- | --- | --- |
| `GET /api/veda-brain/project-diagnostics` | Cross-graph diagnostic summary for a project | `src/lib/veda-brain/veda-brain-diagnostics.ts` |
| `GET /api/veda-brain/proposals` | Actionable proposal generation from graph + search intelligence | `src/lib/veda-brain/proposals.ts` |

### Source of Truth Docs

- `docs/architecture/architecture/veda/content-graph-model.md`
- `docs/architecture/architecture/veda/search-intelligence-layer.md`
- `docs/architecture/architecture/api/api-contract-principles.md`
- `docs/architecture/architecture/api/validation-and-error-taxonomy.md`
- `docs/SYSTEM-INVARIANTS.md`

### Implementation Targets

- `src/app/api/veda-brain/project-diagnostics/route.ts` — thin GET handler, resolves project scope, calls `veda-brain-diagnostics.ts`, returns contract-compliant response
- `src/app/api/veda-brain/proposals/route.ts` — thin GET handler, resolves project scope, calls `proposals.ts`, returns contract-compliant response

Pattern: read legacy route handlers from `C:\dev\veda\src\app\api\veda-brain\` as reference, but implement against current clean repo conventions.

### Hammer Validation

- `scripts/hammer/hammer-veda-brain-phase1.ps1` — must pass (already registered in coordinator)
- `scripts/hammer/hammer-veda-brain-proposals.ps1` — must pass (already registered in coordinator)
- If hammer modules reference routes that don't yet exist, route creation must satisfy those expectations

### Exit Criteria

- Both routes return 200 with valid project context
- Both routes return appropriate error for missing/invalid project context
- Both hammer modules pass (0 FAIL)
- Routes are read-only — no EventLog writes, no mutation
- Full coordinator re-run remains at 0 FAIL

### Legacy Replacement Mapping

Replaces: `C:\dev\veda\src\app\api\veda-brain\project-diagnostics\route.ts`, `C:\dev\veda\src\app\api\veda-brain\proposals\route.ts`

---

## Phase 2 — Observatory Floor Hammer Hardening

### Objective

Expand hammer coverage for the observatory floor surfaces (source capture, event log, project lifecycle) to match the coverage depth of the SIL and content graph surfaces.

### System Scope

VEDA

### Surfaces / Lanes

- `GET /api/source-items` — list with project scope
- `POST /api/source-items/capture` — capture with project scope, EventLog co-location
- `GET /api/events` — event log read
- `POST /api/projects` — project creation
- `GET /api/projects` — project list

### Source of Truth Docs

- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/ingest-discipline.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/event-auditability.md`
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/security/auth-and-actor-model.md`

### Implementation Targets

- Review existing `hammer-core.ps1` and `hammer-project-bootstrap.ps1` for coverage gaps
- Add tests for: cross-project source-item non-disclosure, capture EventLog atomicity, event log deterministic ordering, project-scoped event log filtering, invalid capture rejection
- New hammer module if needed: `hammer-source-capture.ps1`

### Hammer Validation

- `hammer-core.ps1` — extended or confirmed sufficient
- `hammer-project-bootstrap.ps1` — extended or confirmed sufficient
- New `hammer-source-capture.ps1` if gap warrants it
- All modules registered in coordinator parse-check and run sections

### Exit Criteria

- Source capture produces EventLog entry atomically (verified by hammer)
- Cross-project source-item access returns 404 (verified by hammer)
- Event log ordering is deterministic (verified by hammer)
- Invalid capture payloads are rejected with correct error shape (verified by hammer)
- Full coordinator: 0 FAIL

### Legacy Replacement Mapping

Replaces confidence gap in observatory floor coverage from legacy. No new routes — hardening only.

---

## Phase 3 — MCP Tool Surface Alignment

### Objective

Verify and update the MCP server tool surface to reflect all active API routes in the clean repo. Ensure MCP tools are HTTP-only with no direct DB access.

### System Scope

VEDA (MCP operator surface)

### Surfaces / Lanes

- `mcp/server/src/tools.ts` — tool definitions
- `mcp/server/src/tool-handlers.ts` — handler implementations
- `mcp/server/src/api-client.ts` — HTTP client

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
   - VEDA brain diagnostics and proposals (once Phase 1 completes)
   - Content graph project-diagnostics
   - Any SIL surfaces not already exposed
5. Verify `api-client.ts` includes no Prisma imports or direct DB calls

### Hammer Validation

- `scripts/hammer/hammer-provider-smoke.ps1` — if it exists, confirm it covers MCP tool smoke tests
- If no MCP-specific hammer exists, create `hammer-mcp-smoke.ps1` that verifies MCP server starts and responds to tool listing
- Manual verification: MCP tool list matches active API surface inventory

### Exit Criteria

- Every active read-only API route has a corresponding MCP tool definition
- No MCP tool handler performs direct DB access
- MCP server starts cleanly and lists all tools
- Tool definitions match current API response contracts
- Full coordinator: 0 FAIL

### Legacy Replacement Mapping

Replaces: `C:\dev\veda\mcp\server\src\` — the clean repo MCP surface becomes the sole MCP truth.

---

## Phase 4 — Ingestion Pipeline Validation

### Objective

Confirm the DataForSEO ingestion pipeline and fixture replay system work end-to-end in the clean repo. Validate that ingested data flows correctly through the SIL computation pipeline.

### System Scope

VEDA

### Surfaces / Lanes

- `POST /api/seo/ingest` — DataForSEO SERP ingestion
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

### Implementation Targets

1. Audit all doc references to file paths — confirm each referenced path exists in clean repo
2. Resolve the duplicate `V_ECOSYSTEM.md` (exists at both `docs/architecture/V_ECOSYSTEM.md` and `docs/architecture/architecture/V_ECOSYSTEM.md`) — keep one canonical location
3. Resolve nested `docs/architecture/architecture/` structure — flatten if warranted or document the nesting intent
4. Review `DOCS-CLEANUP-TRACKER.md` for any open items
5. Update `search-intelligence-layer.md` registry if any implementation anchors have shifted during carry-forward
6. Verify `ROADMAP.md` (this document) doc path references remain valid

### Hammer Validation

No hammer module — documentation changes do not produce executable surfaces.

Manual verification: every doc path referenced in this roadmap resolves to a real file in the clean repo.

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
- One bounded read surface (e.g., project-level volatility summary or SERP weather)
- One focused diagnostic read surface (e.g., keyword-target diagnostic detail)
- Thin HTTP client — no Prisma, no DB, no local analytics, no polling

### Hammer Validation

No direct hammer module — VS Code extension is an API consumer.

Validation path: extension surfaces must consume the same API endpoints already validated by existing hammer modules. If the extension requires an API shape change, that change must be validated by hammer first.

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
5. Rename clean repo path from `C:\dev\veda-ops-dev\veda` to `C:\dev\veda` if desired
6. Update any deployment, CI, or hosting configuration to point to the sole repo

### Hammer Validation

- Final full coordinator run: `.\scripts\api-hammer.ps1`
- 0 FAIL required
- PASS count should meet or exceed Phase 0 baseline

### Exit Criteria

- Legacy repo is archived and no longer referenced by any active workflow
- Clean repo is the sole operational repository
- All active documentation, scripts, and configurations reference only the clean repo
- Full hammer suite: 0 FAIL
- Operator can perform all VEDA observability work without touching the legacy repo

### Legacy Replacement Mapping

This phase completes the replacement. The legacy repo `C:\dev\veda` at branch `feature/veda-command-center` commit `31a8deb` is fully superseded.

---

## Phase Sequencing Summary

```text
Phase 0  Hammer Baseline Validation
  │
  ▼
Phase 1  VEDA Brain Route Reconstruction
  │
  ▼
Phase 2  Observatory Floor Hammer Hardening
  │
  ▼
Phase 3  MCP Tool Surface Alignment
  │
  ▼
Phase 4  Ingestion Pipeline Validation
  │
  ▼
Phase 5  Documentation Alignment
  │
  ▼
Phase 6  Operator Surface Foundation
  │
  ▼
Phase 7  Legacy Decommission
```

Phases 0–4 are core VEDA observability work and must be sequential.

Phase 5 (documentation) can run in parallel with Phases 3–4 if convenient.

Phase 6 (operator surface) depends on Phases 0–4 being complete.

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

This pattern has been validated through SIL-2 through SIL-24, content graph, and VEDA brain library implementations.

Do not deviate from this pattern unless explicitly instructed.

---

## Explicit Non-Goals

This roadmap does not authorize:

- Schema changes
- New enum additions
- New bounded systems
- Reintroduction of removed VEDA domains (drafts, editorial, publishing, distribution)
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

