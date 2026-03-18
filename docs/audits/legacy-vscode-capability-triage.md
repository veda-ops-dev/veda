# Legacy VS Code Extension Capability Triage Audit

Audited: 2026-03-18
Legacy: C:\dev\veda\vscode-extension
Successor: C:\dev\veda-ops-dev\veda\extensions\veda-vscode

---

## 1. Legacy Capability Inventory

### Infrastructure
- **Environment switching** — switch between API environments (local, staging)
- **Project selection** — pick active project from API
- **Status bar context** — shows active environment + project
- **Refresh context** — re-fetch project state

### Sidebar Views (8 tree views in activity bar)
- **Project Context** — active project display in sidebar
- **Editor Context** — derives file context (route hint, page relevance) from active editor
- **Investigation Summary** — project-level volatility summary
- **Top Alerts** — alert list with click-to-diagnose
- **Keywords** — keyword target list with click-to-diagnose
- **Recent Page Workflow** — session memory of page-context investigations
- **SERP Observatory** — SERP disturbance/weather display
- **VEDA Brain** — project diagnostics + proposals

### Commands (investigation/diagnostic)
- **Investigate Project** — project-level investigation in webview panel
- **Keyword Diagnostic** — keyword overview in webview panel (pick from list)
- **Open Page Command Center** — page-level diagnostic from current editor file
- **Choose Project Keyword Diagnostic** — keyword pick filtered to current page context
- **Risk Keyword from Page Context** — drill from page to at-risk keyword
- **Summary Keyword Diagnostic** — drill from investigation summary to keyword
- **Alert Item Selected** — drill from alert to keyword diagnostic
- **Keyword Item Selected** — drill from keyword list to diagnostic
- **Brain → Page Command Center** — cross-panel link from VEDA Brain to page diagnostic

### Workflow / Setup
- **Open Project Blueprint Workflow** — opens local doc `docs/First-run operator journey.md`
- **Open Project Setup Workflow** — opens same local doc
- **View Proposals** — focuses VEDA Brain panel's proposals section
- **Replay Workflow Entry** — re-runs a recent page/keyword investigation from memory

### Utilities
- **Page heuristics** — derives route hints and page relevance from file paths
- **Page workflow memory** — in-session memory of recent page/keyword investigations (not persisted)
- **Results panel** — webview panel rendering investigation, keyword diagnostic, and page context results

---

## 2. Capability Triage Matrix

### Infrastructure

| Capability | Legacy anchor | Owner | Clean API? | Classification | Reason |
|---|---|---|---|---|---|
| Environment switching | commands/switchEnvironment.ts | Operator surface | Yes | **KEEP NOW** | Already in successor. Core infrastructure. |
| Project selection | commands/selectProject.ts | Operator surface | Yes (GET /api/projects) | **KEEP NOW** | Already in successor. Core infrastructure. |
| Status bar context | registerCommands.ts | Operator surface | N/A | **KEEP NOW** | Already in successor. |
| Refresh context | commands/refreshContext.ts | Operator surface | N/A | **KEEP NOW** | Trivial — already implicit in successor. |

### Sidebar Views

| Capability | Legacy anchor | Owner | Clean API? | Classification | Reason |
|---|---|---|---|---|---|
| Project Context (sidebar) | providers/projectContextProvider.ts | Operator surface | Yes | **KEEP LATER** | Useful but successor Phase 1 uses command palette + status bar, not sidebar trees. Sidebar views are Phase 2+ scope. |
| Editor Context | providers/editorContextProvider.ts | Operator surface | N/A (local) | **KEEP LATER** | Derives file-to-route context from local editor. No API needed. Valuable for page-scoped workflows. Phase 2+. |
| Investigation Summary | providers/investigationSummaryProvider.ts | VEDA | Yes (GET /api/seo/volatility-summary) | **KEEP LATER** | Useful sidebar summary. Already-stable API. Phase 2 scope. |
| Top Alerts | providers/alertsProvider.ts | VEDA | Yes (GET /api/seo/alerts) | **KEEP LATER** | Click-to-diagnose alert list. Already-stable API. Phase 2 scope. |
| Keywords | providers/keywordsProvider.ts | VEDA | Yes (GET /api/seo/keyword-targets) | **KEEP LATER** | Keyword list with click-to-diagnose. Already-stable API. Phase 2 scope. |
| Recent Page Workflow | providers/recentPageWorkflowProvider.ts | Operator surface | N/A (local memory) | **KEEP LATER** | Session continuity for page-context work. Depends on Editor Context + page heuristics. Phase 2+. |
| SERP Observatory | providers/serpObservatoryProvider.ts | VEDA | Yes (GET /api/seo/serp-disturbances) | **KEEP LATER** | Successor already has SERP weather as a command. Sidebar tree version is Phase 2+. |
| VEDA Brain | providers/vedaBrainProvider.ts | VEDA | Yes (GET /api/veda-brain/project-diagnostics, /proposals) | **KEEP LATER** | Project diagnostics + proposals. Already-stable APIs. Phase 2+. |

### Commands (Investigation/Diagnostic)

| Capability | Legacy anchor | Owner | Clean API? | Classification | Reason |
|---|---|---|---|---|---|
| Investigate Project | commands/investigateProject.ts | VEDA | Yes (volatility-summary) | **KEEP NOW** | Successor has SERP weather; a broader project investigation command using volatility-summary is a natural next surface. |
| Keyword Diagnostic (pick) | commands/keywordDiagnostic.ts | VEDA | Yes (keyword-targets + overview) | **KEEP NOW** | Successor has keyword volatility by UUID. Adding a keyword picker from the targets list is the obvious improvement. |
| Page Command Center | commands/investigateCurrentPage.ts | VEDA | Yes (GET /api/seo/page-command-center) | **KEEP LATER** | Requires editor context + page heuristics. Depends on file-to-route derivation. Phase 2 scope. |
| Page Keyword Diagnostic | commands/pageKeywordDiagnostic.ts | VEDA | Yes (page-command-center + keyword overview) | **KEEP LATER** | Depends on page context. Phase 2. |
| Risk Keyword from Page Context | registerCommands.ts | VEDA | Yes (keyword overview) | **KEEP LATER** | Drill-through from page to keyword. Depends on page context. Phase 2. |
| Summary Keyword Diagnostic | registerCommands.ts | VEDA | Yes (keyword overview) | **KEEP LATER** | Drill-through from summary to keyword. Depends on sidebar summary view. Phase 2. |
| Alert → Keyword Diagnostic | registerCommands.ts | VEDA | Yes (keyword overview) | **KEEP LATER** | Drill-through from alert to keyword. Depends on sidebar alert view. Phase 2. |
| Keyword Item → Diagnostic | registerCommands.ts | VEDA | Yes (keyword overview) | **KEEP LATER** | Drill-through from keyword list. Depends on sidebar keyword view. Phase 2. |
| Brain → Page Command Center | registerCommands.ts | VEDA | Yes (page-command-center) | **KEEP LATER** | Cross-panel linking. Depends on Brain view + page context. Phase 2+. |

### Workflow / Setup

| Capability | Legacy anchor | Owner | Clean API? | Classification | Reason |
|---|---|---|---|---|---|
| Open Project Blueprint Workflow | registerCommands.ts | Project V | N/A (local file) | **REHOME** | Opens `docs/First-run operator journey.md`. This is Project V planning workflow, not VEDA observability. Belongs in a Project V operator surface. |
| Open Project Setup Workflow | registerCommands.ts | Project V | N/A (local file) | **REHOME** | Same doc as blueprint. Project V scope. |
| View Proposals | registerCommands.ts | VEDA | Yes (GET /api/veda-brain/proposals) | **KEEP LATER** | Useful but depends on Brain sidebar view. Phase 2. |
| Replay Workflow Entry | registerCommands.ts | Operator surface | N/A (local memory) | **KEEP LATER** | Session continuity. Depends on page workflow memory. Phase 2. |

### Utilities

| Capability | Legacy anchor | Owner | Clean API? | Classification | Reason |
|---|---|---|---|---|---|
| Page heuristics | utils/pageHeuristics.ts | Operator surface | N/A (local) | **KEEP LATER** | Derives route hints from file paths. No API needed. Foundation for page-context commands. Phase 2. |
| Page workflow memory | services/pageWorkflowMemory.ts | Operator surface | N/A (local) | **KEEP LATER** | In-session memory. No DB. No hidden mutation. Clean local-only pattern. Phase 2. |
| Results panel (webview) | views/resultsPanel.ts | Operator surface | N/A | **KEEP LATER** | Webview rendering for investigation/diagnostic results. Already partially in successor (inline HTML panels). Phase 2 would make this richer. |

---

## 3. Successor-Surface Recommendations

### Definitely keep (already in successor or immediate next slice)
- Environment switching ✓
- Project selection ✓
- Status bar context ✓
- SERP weather (project-level) ✓
- Keyword volatility (focused diagnostic) ✓
- **Add next:** keyword picker (list targets → select → show overview, not just UUID input)
- **Add next:** project investigation command (volatility-summary in a webview)

### Explicitly avoid
- Blueprint/setup workflow commands — these are Project V scope, not VEDA
- Any local business logic or derived analytics computation
- Direct DB access or Prisma imports
- Background polling or auto-refresh loops
- Sidebar tree views in the current foundation phase — these are Phase 2

### Move to later phases
- All 8 sidebar tree views (Phase 2)
- Editor context / page heuristics (Phase 2)
- Page command center access (Phase 2)
- Cross-panel drill-throughs (Phase 2)
- Workflow replay memory (Phase 2)
- VEDA Brain diagnostics + proposals sidebar (Phase 2)

---

## 4. Rehome Recommendations

| Capability | Current home | Better home | Reason |
|---|---|---|---|
| Open Project Blueprint Workflow | Legacy VEDA extension | Project V operator surface | This is planning workflow, not observability. Wave 2D explicitly removed blueprint/planning from VEDA. |
| Open Project Setup Workflow | Legacy VEDA extension | Project V operator surface | Same as above — project creation/setup is Project V scope. |

These two capabilities reference `docs/First-run operator journey.md` which is a Project V planning doc. They should not be carried into the VEDA-bounded successor extension. If a Project V operator surface is built, they belong there.

---

## 5. Minimal Next-Step Plan

The smallest valuable next slice for the successor extension is:

### Slice A — Keyword picker (replaces manual UUID input)
- Use `GET /api/seo/keyword-targets?limit=100` to fetch the project's keyword list
- Present as a QuickPick menu (query + locale + device)
- On selection, fetch `GET /api/seo/keyword-targets/{id}/overview` (not just volatility)
- Render in a webview panel

This replaces the current "enter UUID manually" flow with the same pick-from-list flow the legacy extension had. One command change, one new API call, no new routes needed.

### Slice B — Project investigation command
- Use `GET /api/seo/volatility-summary?windowDays=7`
- Render project-level volatility summary in a webview panel
- Complements the existing SERP weather command

Both slices use already-stable, hammer-validated API routes. No new endpoints. No schema changes. No sidebar views. No local business logic. Thin transport only.
