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

## Current Reconstruction Update

### Hammer realignment checkpoint

The active hammer surface has now been realigned to post-Wave-2D VEDA truth.

Completed changes:
- `scripts/api-hammer.ps1` no longer registers or runs `hammer-core.ps1`
- `scripts/hammer/hammer-project-bootstrap.ps1` no longer contains blueprint workflow expectations
- `scripts/hammer/hammer-seo.ps1` no longer contains quotable-block expectations
- stale entity / audits / draft-artifact / promotion / blueprint / quotable-block expectations are no longer part of the active VEDA gate
- full coordinator baseline after alignment is now:`r`n  - **PASS:** 678`r`n  - **FAIL:** 0`r`n  - **SKIP:** 12

Interpretation:
- the hammer now reflects active VEDA observability truth instead of inherited mixed-era residue
- blueprint workflow remains outside VEDA ownership and must not be reintroduced here
- stale hammer expectations are now classified as resolved cleanup residue, not pending implementation gaps

### Roadmap state update`r`n`r`n`docs/ROADMAP.md` has been updated to reflect:`r`n- Phase 0 complete`r`n- Phase 1 complete`r`n- Phase 2 active`r`n- Phase 5 active`r`n- current execution anchor updated to the 677 / 0 / 13 full-hammer checkpoint`r`n- stale Wave 2D residue removal recorded as a current-reality resolution`r`n- observatory-floor hammer hardening and strict mutation resolution recorded as current repo reality`r`n- Phase 2 observatory-floor hardening is now complete at 678 / 0 / 12`r`n`r`n### Phase 2.5 hardening checkpoint`r`n`r`nCompleted changes:`r`n- new `scripts/hammer/hammer-source-capture.ps1` added to the active hammer gate`r`n- `src/app/api/source-items/capture/route.ts` fixed to respect project-scoped `(projectId, url)` uniqueness`r`n- `src/app/api/source-items/capture/route.ts` and `src/app/api/seo/search-performance/ingest/route.ts` switched to `resolveProjectIdStrict()` for mutation discipline`r`n- weak skip paths in `hammer-seo.ps1`, `hammer-w5-persistence.ps1`, `hammer-sil19.ps1`, and `hammer-source-capture.ps1` were tightened into real PASS/FAIL checks where local seeded data already exists`r`n- retired `scripts/hammer/hammer-core.ps1` moved to `old/hammer-core.ps1``r`n`r`nInterpretation:`r`n- Phase 2 is no longer just about adding coverage; it now includes skip-discipline hardening`r`n- remaining SKIPs are expected to be provider-dependent, environment-dependent, or genuine richer-data-threshold conditions`r`n- the active hammer surface is cleaner, stricter, and less vulnerable to stale assumptions

---

## Successor Doc Naming Rule

Only new or rewritten active docs should be renamed or normalized.

Do **not** spend time renaming archived legacy docs just to make the fossil shelf prettier.

### Naming rules for new active VEDA docs
- lowercase only
- hyphen-separated
- name by durable purpose, not temporary phase
- let the folder path carry system context
- avoid legacy branding and inflated language
- avoid filenames that imply ownership outside the bounded system

### Preferred examples
- `observation-ledger.md`
- `ingest-discipline.md`
- `source-capture-and-inbox.md`
- `event-auditability.md`
- `content-graph-model.md`
- `observatory-models.md`

### Avoid
- `PHASE-1-*`
- `FINAL-*`
- `VEDA-*` when the path already provides context
- `COMMAND-CENTER-*`
- filenames based on stale ownership or old system vocabulary

---

## Root Docs Classification

### Canonical truth
- `docs/SYSTEM-INVARIANTS.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md`

### Keep, rewrite later
- `docs/ROADMAP.md`
- `docs/VSCODE-EXTENSION-SPEC.md`
- `docs/VSCODE-EXTENSION-LIFECYCLE-UX.md`
- `docs/First-run operator journey.md`

### Vision-only
- `docs/VISION-VEDA-COMMAND-CENTER.md`

### Archive
- `docs/SEO-INGEST-WORKFLOWS.md`
- `docs/SEO-SUBSYSTEM-FINAL-CONVERGENCE.md`

### Major cleanup outputs already completed
- `docs/SYSTEM-INVARIANTS.md` — rewritten truth-layer doc
- `docs/architecture/veda/SCHEMA-REFERENCE.md` — created as truth-layer doc
- `docs/systems/veda/observatory/EVENT-VOCABULARY.md` — created as truth-layer doc
- active hammer gate now aligned to Wave 2D bounded ownership

### Root archive wave acknowledged
A major root-level archive wave already happened before the remaining subfolder pass.
That wave included pre-Wave-2D, PsyMetric-era, Claude-prompt, audit, and mixed stale architecture docs now moved under archive buckets.
This tracker does not list every archived fossil individually, but that archive wave is part of the cleanup record.

---

## Folder: docs/specs/

| Doc | Status | Likely owner | Planned outcome | Notes |
|---|---|---|---|---|
| COMPETITOR-CONTENT-OBSERVATORY.md | reviewed, archive-planned | VEDA | successor doc created | active replacement created at `docs/systems/veda/observatory/competitor-observation.md`; legacy doc can move to `docs/archive/post-wave2-cleanup/` during archive pass |
| CONTENT-GRAPH-DATA-MODEL.md | reviewed, archive-planned | VEDA | successor doc created | moved to `docs/archive/post-wave2-cleanup/CONTENT-GRAPH-DATA-MODEL.md`; active replacement created at `docs/architecture/veda/content-graph-model.md` with support from `docs/architecture/veda/observatory-models.md` |
| CONTENT-GRAPH-LAYER.md | reviewed, archive-planned | mixed | archived | moved to `docs/archive/post-wave2-cleanup/` |
| CONTENT-GRAPH-PHASES.md | reviewed, archive-planned | mixed | archived with salvage notes | moved to `docs/archive/post-wave2-cleanup/CONTENT-GRAPH-PHASES.md`; phase discipline retained in extraction layer, while active graph authority remains `docs/architecture/veda/content-graph-model.md`, `docs/architecture/veda/observatory-models.md`, and `docs/systems/veda/observatory/competitor-observation.md` |
| CONTENT-GRAPH-SYNC-CONTRACT.md | reviewed, archive-planned | VEDA / implementation | archived with salvage notes | moved to docs/archive/post-wave2-cleanup/CONTENT-GRAPH-SYNC-CONTRACT.md; useful explicit-sync ideas retained as historical input, but no active sync contract authority exists yet |
| SEARCH-INTELLIGENCE-LAYER.md | reviewed, archive-planned | mixed | archived | moved to `docs/archive/post-wave2-cleanup/`; active authority created at `docs/architecture/veda/search-intelligence-layer.md` |
| SERP-TO-CONTENT-GRAPH-PROPOSALS.md | reviewed, archive-planned | mixed | archived | moved to `docs/archive/post-wave2-cleanup/` |
| SIL-1-INGEST-DISCIPLINE.md | reviewed, archive-planned | historical VEDA residue | archived | moved to `docs/archive/post-wave2-cleanup/`; active authority replaced by `docs/systems/veda/observatory/ingest-discipline.md` and `docs/architecture/veda/search-intelligence-layer.md` |
| SIL-1-OBSERVATION-LEDGER.md | reviewed, archive-planned | historical VEDA residue | archived | moved to `docs/archive/post-wave2-cleanup/`; active authority replaced by `docs/systems/veda/observatory/observation-ledger.md` and `docs/architecture/veda/search-intelligence-layer.md` |
| phase-1-mcp-tools.md | reviewed, archive-planned | historical only | archived | moved to `docs/archive/post-wave2-cleanup/` |
| VEDA-MCP-TOOLS-SPEC.md | reviewed, archive-planned | mixed | successor docs created | moved to `docs/archive/post-wave2-cleanup/VEDA-MCP-TOOLS-SPEC.md`; grounded principles now carried by `docs/systems/operator-surfaces/mcp/overview.md` and `docs/systems/operator-surfaces/mcp/tooling-principles.md` |
| VEDA-OPERATOR-SURFACES.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/VEDA-OPERATOR-SURFACES.md`; active replacement created at `docs/systems/operator-surfaces/overview.md` |
| VEDA-VSCODE-OPERATOR-GAP-MAP.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/VEDA-VSCODE-OPERATOR-GAP-MAP.md`; active replacement created at `docs/systems/operator-surfaces/vscode/operator-gap-map.md` |
| VEDA-REPO-NATIVE-WORKFLOW.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/VEDA-REPO-NATIVE-WORKFLOW.md`; active replacement created at `docs/systems/operator-surfaces/vscode/repo-native-workflow.md` |
| VSCODE-EXTENSION-PHASE-1.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/VSCODE-EXTENSION-PHASE-1.md`; active replacement created at `docs/systems/operator-surfaces/vscode/phase-1-spec.md` |
| VSCODE-EXTENSION-ROADMAP.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/VSCODE-EXTENSION-ROADMAP.md`; active replacement created at `docs/systems/operator-surfaces/vscode/roadmap.md` |
| current vscode-extension/ implementation | reviewed, legacy-reference | cross-system | do not modernize in place | use for grounded ideas, anti-drift cleanup, and successor input only; not active operator-surface truth |
| SIL-8-PLAN.md | reviewed, archive-planned | historical SIL residue | archived | moved to `docs/archive/post-wave2-cleanup/`; implementation now documented through `docs/architecture/veda/search-intelligence-layer.md` and active code surfaces |
| SIL-9-ALERTING-PLAN.md | reviewed, archive-planned | historical SIL residue | archived | moved to `docs/archive/post-wave2-cleanup/`; implementation now documented through `docs/architecture/veda/search-intelligence-layer.md` and active code surfaces |
| VEDA-BRAND-SURFACE-REGISTRY.md | reviewed, archive-planned | Project V | archived to Project V candidates | moved to `docs/archive/project-v-candidates/VEDA-BRAND-SURFACE-REGISTRY.md`; owned-surface identity ideas partially reflected in `docs/architecture/veda/content-graph-model.md` and `docs/architecture/veda/observatory-models.md`, but workflow ownership belongs to Project V |
| PROJECT-BLUEPRINT-SPEC.md | reviewed, archive-planned | Project V | archived to Project V candidates | moved to `docs/archive/project-v-candidates/` |
| VEDA-CREATE-PROJECT-WORKFLOW.md | reviewed, archive-planned | Project V | archived to Project V candidates | moved to `docs/archive/project-v-candidates/` |
| VEDA-GRAPH-MODEL.md | reviewed, archive-planned | mixed | successor docs created | moved to `docs/archive/post-wave2-cleanup/VEDA-GRAPH-MODEL.md`; active replacements are `docs/architecture/veda/observatory-models.md`, `docs/architecture/veda/content-graph-model.md`, and `docs/systems/veda/observatory/competitor-observation.md` |
| VSCODE-PAGE-COMMAND-CENTER.md | reviewed, archive-planned | V Forge / cross-system | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |
| deferred/ | reviewed, legacy-reference | historical backlog | keep isolated backlog bucket | contains narrow proposal-deferral notes; revisit only if the proposal-helper implementation lane is intentionally resumed |
| future-ideas/ | reviewed, historical-only | speculative research notebook | keep isolated future-ideas bucket | preserve as explicitly non-authoritative idea space; do not let it influence current architecture unless explicitly promoted |

---

## Folder: docs/site-architecture/

| Doc | Status | Likely owner | Planned outcome | Notes |
|---|---|---|---|---|
| 01-SITE-ARCHITECTURE-OVERVIEW.md | reviewed, archive-planned | V Forge | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |
| 02-URL-AND-ROUTING-STRATEGY.md | reviewed, archive-planned | V Forge | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |
| 03-WIKI-CONTENT-TYPES-AND-PAGE-ANATOMY.md | reviewed, archive-planned | V Forge | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |
| 04-INTERNAL-LINKING-AND-RELATIONSHIP-RENDERING.md | reviewed, archive-planned | V Forge | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |
| 05-PUBLISHING-AND-INDEXING-RULES.md | reviewed, archive-planned | V Forge | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |
| 06-SCHEMA-AND-METADATA-PLAN.md | reviewed, archive-planned | V Forge | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |
| 07-CITATION-AND-SOURCE-USAGE.md | reviewed, archive-planned | mixed | successor doc created | moved to `docs/archive/post-wave2-cleanup/07-CITATION-AND-SOURCE-USAGE.md`; active replacement created at `docs/architecture/source-provenance-and-citation.md` |
| 08-SEO-AND-RESEARCH-HOOKS.md | reviewed, archive-planned | Project V | archived to Project V candidates | moved to `docs/archive/project-v-candidates/08-SEO-AND-RESEARCH-HOOKS.md`; useful strategy/prioritization principles retained as Project V candidate material |
| 09-MEDIA-AND-ASSETS.md | reviewed, archive-planned | V Forge | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |

Folder summary:
- mostly V Forge candidate material
- `07` now has an active shared-architecture successor at `docs/architecture/source-provenance-and-citation.md` and the legacy source moved to `docs/archive/post-wave2-cleanup/`
- no remaining site-architecture docs are held for rewrite/rehome; `08` moved to `docs/archive/project-v-candidates/` as Project V candidate material

---

## Folder: docs/operations-planning/

| Doc | Status | Likely owner | Planned outcome | Notes |
|---|---|---|---|---|
| 01-SOURCE-CAPTURE-AND-INBOX.md | reviewed, archive-planned | VEDA | successor doc created | moved to `docs/archive/post-wave2-cleanup/01-SOURCE-CAPTURE-AND-INBOX.md`; active replacement created at `docs/systems/veda/observatory/source-capture-and-inbox.md` |
| 02-CHROME-EXTENSION-SCOPE-AND-BEHAVIOR.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/02-CHROME-EXTENSION-SCOPE-AND-BEHAVIOR.md`; active replacement created at `docs/systems/operator-surfaces/browser-capture/scope-and-behavior.md` |
| 03-LLM-ASSISTED-OPERATIONS.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/03-LLM-ASSISTED-OPERATIONS.md`; active replacement created at `docs/architecture/llm-assisted-operations.md` |
| 04-PUBLISH-REVIEW-AND-GATING.md | reviewed, archive-planned | V Forge | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |
| 05-EVENT-LOGGING-AND-AUDITABILITY.md | reviewed, archive-planned | VEDA / governance | successor doc created | moved to `docs/archive/post-wave2-cleanup/05-EVENT-LOGGING-AND-AUDITABILITY.md`; active replacement created at `docs/systems/veda/observatory/event-auditability.md` |
| 06-DEPLOYMENT-AND-INFRASTRUCTURE-BASELINE.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/06-DEPLOYMENT-AND-INFRASTRUCTURE-BASELINE.md`; active replacement created at `docs/architecture/platform/deployment-infrastructure-baseline.md` |
| 07-ADMIN-DASHBOARD-SCOPE.md | reviewed, archive-planned | V Forge / mixed | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/07-ADMIN-DASHBOARD-SCOPE.md`; preserve only tiny operator-surface principles such as visible event history, actionable validation feedback, and no workflow bypass |
| 08-EXTENSION-INGESTION-ARCHITECTURE.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/08-EXTENSION-INGESTION-ARCHITECTURE.md`; active replacement created at `docs/systems/operator-surfaces/browser-capture/ingestion-architecture.md` |
| 08-VERCEL-NEON-PRISMA-INTEGRATION.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/08-VERCEL-NEON-PRISMA-INTEGRATION.md`; active replacement created at `docs/architecture/platform/vercel-neon-prisma.md` |
| 09-SOCIAL-REPLY-DRAFT-SYSTEM.md | reviewed, archive-planned | V Forge | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |
| PHASE-1-OPTION-A-VERIFICATION-CHECKLIST.md | reviewed, archive-planned | V Forge / historical | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/PHASE-1-OPTION-A-VERIFICATION-CHECKLIST.md`; useful only as historical checkpoint for the dead X reply-draft loop, not active truth |
| PHASE-1-SLICE-DISTRIBUTION-AND-METRICS-READ-APIS.md | reviewed, archive-planned | historical mixed | archived | moved to `docs/archive/post-wave2-cleanup/` |
| PHASE-1-SLICE-DISTRIBUTION-AND-METRICS.md | reviewed, archive-planned | historical mixed | archived | moved to `docs/archive/post-wave2-cleanup/` |
| PHASE-1-SLICE-PUBLISH-LIFECYCLE.md | reviewed, archive-planned | V Forge / historical | archived to V Forge candidates | moved to `docs/archive/v-forge-candidates/` |

Folder summary:
- mixed but salvage-heavy
- active successor docs now exist for `01`, `03`, `05`, `06`, and `08-VERCEL-NEON-PRISMA-INTEGRATION`; legacy sources moved to `docs/archive/post-wave2-cleanup/`
- `02-CHROME-EXTENSION-SCOPE-AND-BEHAVIOR.md` and `08-EXTENSION-INGESTION-ARCHITECTURE.md` now live in `docs/archive/post-wave2-cleanup/` with active browser-capture successors under `docs/systems/operator-surfaces/browser-capture/`
- `07-ADMIN-DASHBOARD-SCOPE.md` now lives in `docs/archive/v-forge-candidates/` with only small operator-surface salvage retained in the extraction layer
- clear archive set includes publish/reply/distribution slices

---

## Folder: docs/operations-planning-api/

| Doc | Status | Likely owner | Planned outcome | Notes |
|---|---|---|---|---|
| 01-API-ENDPOINTS-AND-VALIDATION-CONTRACTS.md | reviewed, archive-planned | mixed | successor doc created | moved to `docs/archive/post-wave2-cleanup/01-API-ENDPOINTS-AND-VALIDATION-CONTRACTS.md`; active replacement created at `docs/architecture/api/api-contract-principles.md` |
| 02-AUTH-AND-ACTOR-MODEL.md | reviewed, archive-planned | cross-system | successor doc created | moved to `docs/archive/post-wave2-cleanup/02-AUTH-AND-ACTOR-MODEL.md`; active replacement created at `docs/architecture/security/auth-and-actor-model.md` |
| 03-VALIDATION-RULES-AND-ERROR-TAXONOMY.md | reviewed, archive-planned | mixed | successor doc created | moved to `docs/archive/post-wave2-cleanup/03-VALIDATION-RULES-AND-ERROR-TAXONOMY.md`; active replacement created at `docs/architecture/api/validation-and-error-taxonomy.md` |
| 04-ADMIN-DASHBOARD-UI-CONTRACT.md | reviewed, archive-planned | V Forge / mixed | archive or split hard | mostly CMS/editor/publish queue contract |
| 05-VIDEO-SEO-WORKFLOW-CONTRACT.md | reviewed, archive-planned | V Forge | archive to V Forge candidates | execution workflow, not VEDA observability truth |

Folder summary:
- mostly salvageable contract/governance material
- governance and contract successor docs now exist for `01`, `02`, and `03`; legacy sources moved to `docs/archive/post-wave2-cleanup/`
- `04`, `05` are not active VEDA docs

---

## Successor Docs Created So Far

These are active replacement docs already created during the reconstruction pass.
They should be preferred over stale legacy docs when there is a conflict.

### Search intelligence and observatory spine
- `docs/architecture/veda/search-intelligence-layer.md`
- `docs/systems/veda/observatory/ingest-discipline.md`
- `docs/systems/veda/observatory/observation-ledger.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/systems/veda/observatory/event-auditability.md`
- `docs/architecture/veda/observatory-models.md`
- `docs/architecture/veda/content-graph-model.md`

### Operator-surfaces spine
- `docs/systems/operator-surfaces/overview.md`
- `docs/systems/operator-surfaces/mcp/overview.md`
- `docs/systems/operator-surfaces/mcp/tooling-principles.md`
- `docs/systems/operator-surfaces/browser-capture/scope-and-behavior.md`
- `docs/systems/operator-surfaces/browser-capture/ingestion-architecture.md`
- `docs/systems/operator-surfaces/vscode/operator-gap-map.md`
- `docs/systems/operator-surfaces/vscode/repo-native-workflow.md`
- `docs/systems/operator-surfaces/vscode/phase-1-spec.md`
- `docs/systems/operator-surfaces/vscode/roadmap.md`

### Shared architecture spine
- `docs/architecture/llm-assisted-operations.md`
- `docs/architecture/platform/deployment-infrastructure-baseline.md`
- `docs/architecture/platform/vercel-neon-prisma.md`
- `docs/architecture/security/auth-and-actor-model.md`
- `docs/architecture/api/api-contract-principles.md`
- `docs/architecture/api/validation-and-error-taxonomy.md`
- `docs/architecture/source-provenance-and-citation.md`

### Still-possible future successor docs

- possible roadmap fold-ins for phased notes
- possible split of owned-vs-observed surface identity guidance

---

## Working Rule

A doc counts as "rewritten" only when one of these happens:

1. a replacement doc is created in the new structure
2. the old doc is rewritten in place against current truth
3. the old doc is archived and its grounded ideas are captured in a successor doc or the extraction layer

Until then, it is only reviewed/classified — not finished.

---

## Testing / Hammer Notes

### Active doctrine doc
- `docs/architecture/testing/hammer-doctrine.md` — active shared-architecture testing doctrine for hammer purpose, scope boundaries, and maintenance rules

### Current implementation note
- `scripts/hammer/hammer-sil22-24.ps1` now remains a thin coordinator and composes focused modules under `scripts/hammer/serp-disturbances/`
- this modularization is intentional maintenance work, not a change in hammer mission
- hammer purpose remains invariant protection for live operational surfaces, especially DB integrity, route-contract integrity, read-only guarantees, and project isolation
- active hammer gate now explicitly excludes stale Wave 2D residue (`hammer-core.ps1`, blueprint enforcement, quotable-blocks enforcement)`r`n- retired `hammer-core.ps1` is quarantined under `old/hammer-core.ps1` rather than left in the active hammer directory`r`n- current full active baseline: **677 PASS / 0 FAIL / 13 SKIP**


