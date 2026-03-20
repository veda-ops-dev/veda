# VEDA Roadmap

## Status

**Reconstruction complete. VEDA is operationally complete in the clean repo.**

All Phases 0–7 are done. The clean repo `C:\dev\veda-ops-dev\veda` is the sole operational repository.
The legacy repo `C:\dev\veda` is archived.

---

## Authority Documents

Before making any changes to VEDA, read these in order:

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

If a proposed change conflicts with these documents, the documents win.

---

## Definition of Done — Current Operational State

VEDA is operationally complete when all of the following are true. They are all currently true.

- **VEDA is observability-only.** No drafts, editorial workflow, publishing, blueprint, or distribution surfaces exist or are planned inside VEDA.
- **Clean repo is the sole operational repository.** `C:\dev\veda-ops-dev\veda` is the only repo used for active work. Legacy repo `C:\dev\veda` is archived with `ARCHIVED.md` in its root.
- **Hammer baseline is green.** Full coordinator `scripts/api-hammer.ps1` passes at 680 PASS / 0 FAIL / 10 SKIP.
- **All active VEDA observability surfaces are hammer-validated.** SIL 1–24, content graph, VEDA brain, observatory floor, ingestion pipeline, and source capture all pass.
- **Docs align to repo truth.** All path references in active docs resolve correctly. No doc references legacy repo paths as active truth.
- **MCP operator surface is validated.** MCP server is HTTP-only, no direct DB access, tool definitions aligned to live API routes.
- **VS Code operator surface foundation exists.** `extensions/veda-vscode/` is a thin API consumer with explicit environment/project context and four validated read surfaces: SERP weather, keyword volatility, keyword overview (picker → `GET /api/seo/keyword-targets/{id}/overview`), and project investigation summary (`GET /api/seo/volatility-summary`). No local business logic, no DB access, no mutation.
- **No active bounded-ownership drift.** All VEDA surfaces are project-scoped. All mutations require explicit project context. No cross-project leakage.

---

## Reconstruction Summary — Phases 0–7

All phases are complete. The following is a record of what was done, not a to-do list.

### Phase 0 — Hammer Baseline Validation
Established the green hammer baseline after removing stale Wave 2D / entity-era / blueprint-era residue from the active gate. Result: 678 PASS / 0 FAIL / 12 SKIP.

### Phase 1 — VEDA Brain Route Reconstruction
Rebuilt missing `src/app/api/veda-brain/` route handlers as thin read-only surfaces over the existing `src/lib/veda-brain/` pure libraries. Routes: `project-diagnostics`, `proposals`.

### Phase 2 — Observatory Floor Hammer Hardening
Added direct observatory-floor hammer coverage (`hammer-source-capture.ps1`). Fixed project-scoped `(projectId, url)` lookup semantics in source capture. Enforced strict project context on mutation routes. Quarantined retired `hammer-core.ps1`. Result: 678 PASS / 0 FAIL / 12 SKIP.

### Phase 3 — MCP Tool Surface Alignment
Audited MCP tool definitions against all live API routes. Documented MCP as the current Claude Desktop-compatible dev harness. Created `docs/systems/operator-surfaces/mcp/tool-registry.md` and `veda-tool-list.md`.

### Phase 4 — Ingestion Pipeline Validation
Confirmed DataForSEO ingestion pipeline and fixture replay system work end-to-end. Added self-bootstrap to `hammer-dataforseo-ingest.ps1`. Validated deterministic persistence, EventLog co-writes, and cross-project isolation. Result: 680 PASS / 0 FAIL / 10 SKIP.

### Phase 5 — Documentation Alignment
Corrected 18 docs with nesting-drift path references. Resolved duplicate `V_ECOSYSTEM.md` and `SCHEMA-REFERENCE.md`. Updated SIL registry with 5 missing active surfaces. Confirmed legacy provenance refs in successor docs are intentional.

### Phase 6 — Operator Surface Foundation
Created `extensions/veda-vscode/` — a new successor VS Code extension, not a legacy rehab. Thin HTTP client, explicit environment/project context, two read surfaces (SERP weather via SIL-16–24, keyword volatility via SIL-3). No Prisma, no DB, no local business logic, no mutation.

### Phase 7 — Legacy Decommission
Audited all clean repo files — 0 active code/script/config leaks referencing `C:\dev\veda`. All legacy path mentions confirmed as historical provenance only. Wrote `ARCHIVED.md` to legacy repo root. Legacy repo is preserved for provenance but is not operationally required.

---

## System Invariants

These constraints apply to all future work in VEDA. They are not suggestions.

1. VEDA is observability-only — no editorial, draft, blueprint, or publishing workflow
2. All observatory rows are project-scoped unless explicitly global
3. All mutations require explicit project context — no silent fallback
4. Compute-on-read — no background jobs, no caching layers
5. Transactional mutation with co-located EventLog writes where required
6. Deterministic ordering with explicit tie-breakers
7. Pure library pattern for all SIL and computation layers
8. Thin route handlers — resolve scope, validate, delegate, return
9. Hammer-first validation before any surface is considered done
10. Schema changes only when explicitly justified against schema rules
11. Endpoint additions only when explicitly justified against endpoint rules
12. No new bounded systems inside VEDA

See `docs/SYSTEM-INVARIANTS.md` for the full invariant definitions.

---

## Implementation Pattern

All new VEDA work must follow this pattern:

```text
1. thin route handler (resolve scope, validate, delegate)
2. pure library function (deterministic, side-effect-free, explicit inputs)
3. hammer module (contract, isolation, ordering, read-only verification)
4. full coordinator run (no regressions)
```

Do not deviate from this pattern.

---

## Maintenance Rules

These rules apply in maintenance mode.

- If a hammer test fails, fix the regression before doing anything else.
- If a new observability surface is needed, it must satisfy the observability pattern: `entity + observation + time + interpretation`.
- If a doc path reference breaks, correct it and update the cleanup tracker.
- If the system invariants are at risk, stop and reassess before continuing.
- If the cleanup intelligence layer is out of date with repo truth, update it.

---

## Non-Goals

VEDA does not own and will not add:

- Drafts, editorial workflow, publishing workflow
- Reply drafting or blueprint workflow
- Distribution events or owned content assets
- Background job infrastructure
- Caching layers
- Dashboard or web UI
- Rich planning/orchestration truth (belongs to Project V)
- Content execution surfaces (belongs to V Forge)

If a proposed change touches any of the above, it belongs in a different bounded system.

---

## Future Work Separation

### Maintenance (apply when needed, not scheduled)
- Hammer coverage for any new observability surface that is added
- Doc path corrections if nesting or structure changes
- MCP tool definitions for any new API routes
- Cleanup intelligence layer updates in lockstep with any structural change

### Optional Bounded Enhancements (non-blocking, not required for VEDA operational completeness)
- VS Code extension Phase 2+ per `docs/systems/operator-surfaces/vscode/roadmap.md`
- Additional MCP tool coverage for surfaces not yet exposed
- Search performance ingest hardening if real ingestion gaps surface
- Any additional SIL surfaces if new observability requirements are established
- YouTube Search Observatory Y1 observation floor per `docs/systems/veda/youtube-observatory/y1-implementation-plan.md`

### Belongs Outside VEDA
- Project V planning and orchestration surfaces
- V Forge drafting, editorial, and publishing surfaces
- Cross-system LLM access model (not yet defined — governed by V Ecosystem boundary rules)

---

## Cleanup Intelligence Companions

These documents must stay in sync with repo truth:

- `docs/DOCS-CLEANUP-TRACKER.md`
- `docs/DOCS-CLEANUP-GROUNDED-IDEAS-EXTRACTION.md`

If a change to VEDA surfaces, docs, or structure causes any of the following, both tracker docs must be updated:
- new successor doc creation
- doc reclassification or archival
- structural changes to system surfaces
- new hammer modules or operator rules
- changes to the definition-of-done criteria above

---

## Provenance

The reconstruction roadmap (Phases 0–7) was executed against clean repo `C:\dev\veda-ops-dev\veda`.
Legacy repo source: `C:\dev\veda`, branch `feature/veda-command-center`, commit `31a8deb`.
Carry-forward scope: `CARRY_FORWARD_MANIFEST.txt`.
