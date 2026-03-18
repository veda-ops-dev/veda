# MCP Tool Registry

## Purpose

This document is the active tracking registry for all MCP tools in the V Ecosystem.

It exists to answer at any point:
- what tools currently exist
- what API route each tool calls
- which bounded system owns it
- whether it reads or writes
- whether it is active, deferred, or intentionally absent

This is the ground truth for the MCP tool surface.
It replaces any stale tool inventories in archived specs.

---

## Registry Rules

### All MCP tools are API-driven, not DB-driven

Every tool calls an HTTP/API endpoint.
No tool uses Prisma, accesses the database directly, or bypasses API validation.

The chain is always:

```text
assistant -> MCP tool -> HTTP/API contract -> bounded system capability
```

### MCP does not own system truth

MCP tools expose capabilities that are owned by bounded systems:
- Project V plans
- VEDA observes
- V Forge executes

MCP is an operator surface, not a system owner.
A tool that reads VEDA data is still VEDA-owned capability.
A tool that creates a project is still Project V-bootstrapped capability through the VEDA API.

### Project scoping is mandatory

All project-scoped tools enforce project scope through ApiClient request headers.
No tool may access or leak data across project boundaries.
Global tools (e.g. `list_projects`) explicitly do not send project headers.

### Write tools are explicit

Write tools are annotated with "WRITE —" in their description.
They call mutating API routes only where:
- the API route already exists and is bounded
- the mutation is explicitly documented
- project scoping is preserved
- the tool description does not overclaim

---

## Current Development Harness Note

In the current repo phase, the MCP server also functions as a **Claude Desktop-compatible development harness**.

This allows bounded assistant workflows to be tested against real HTTP/API surfaces cheaply, before any broader paid API-driven usage is required.

This is a practical testing posture, not the final ecosystem-wide deployment model.
The long-term direction remains broader API-driven LLM access across Project V, VEDA, and V Forge.
The Claude Desktop dev harness is the cheapest and most practical current path.

---

## Tool Registry

| Tool name | Owner system | Route(s) | R/W | Status | Project scoped? | Notes |
|---|---|---|---|---|---|---|
| `list_projects` | VEDA / cross-system | `GET /api/projects` | R | Active | No (global) | Global list; no project header sent |
| `get_project` | VEDA / cross-system | `GET /api/projects/:id` | R | Active | No (global) | Fetch single project by UUID |
| `create_project` | VEDA / cross-system | `POST /api/projects` | W | Active | No (global) | Creates project container; no project header needed |
| `list_search_performance` | VEDA | `GET /api/seo/search-performance` | R | Active | Yes | GSC performance records with date/query/url filters |
| `list_source_items` | VEDA | `GET /api/source-items` | R | Active | Yes | Observatory source intake list; status/sourceType/platform filters |
| `capture_source_item` | VEDA | `POST /api/source-items/capture` | W | Active | Yes | Capture or recapture a source URL; logs SOURCE_CAPTURED event atomically |
| `list_events` | VEDA | `GET /api/events` | R | Active | Yes | EventLog read surface; eventType/entityType/actor/timestamp filters |
| `get_veda_brain_diagnostics` | VEDA | `GET /api/veda-brain/project-diagnostics` | R | Active | Yes | Compute-on-read VEDA Brain Phase 1 diagnostics |
| `get_proposals` | VEDA | `GET /api/veda-brain/proposals` | R | Active | Yes | Phase C1 SERP-to-Content-Graph proposals |
| `get_content_graph_diagnostics` | VEDA | `GET /api/content-graph/project-diagnostics` | R | Active | Yes | Compute-on-read Content Graph diagnostics |
| `list_cg_surfaces` | VEDA | `GET /api/content-graph/surfaces` | R | Active | Yes | Content Graph surface list |
| `list_cg_sites` | VEDA | `GET /api/content-graph/sites` | R | Active | Yes | Content Graph site list |
| `list_cg_pages` | VEDA | `GET /api/content-graph/pages` | R | Active | Yes | Content Graph page list; optional siteId filter |
| `list_cg_topics` | VEDA | `GET /api/content-graph/topics` | R | Active | Yes | Content Graph topic list |
| `list_cg_entities` | VEDA | `GET /api/content-graph/entities` | R | Active | Yes | Content Graph entity list; optional entityType filter |
| `list_cg_archetypes` | VEDA | `GET /api/content-graph/archetypes` | R | Active | Yes | Content Graph content archetype list |
| `list_cg_internal_links` | VEDA | `GET /api/content-graph/internal-links` | R | Active | Yes | Internal link list; optional sourcePageId/targetPageId filters |
| `list_cg_page_topics` | VEDA | `GET /api/content-graph/page-topics` | R | Active | Yes | Page-topic junction list; optional pageId/topicId filters |
| `list_cg_page_entities` | VEDA | `GET /api/content-graph/page-entities` | R | Active | Yes | Page-entity junction list; optional pageId/entityId filters |
| `list_cg_schema_usage` | VEDA | `GET /api/content-graph/schema-usage` | R | Active | Yes | Schema usage list; optional pageId/schemaType filters |
| `create_cg_surface` | VEDA | `POST /api/content-graph/surfaces` | W | Active | Yes | Register a CG surface; key canonicalized server-side; logs CG_SURFACE_CREATED |
| `create_cg_site` | VEDA | `POST /api/content-graph/sites` | W | Active | Yes | Register a CG site within an existing enabled surface; logs CG_SITE_CREATED |
| `create_cg_page` | VEDA | `POST /api/content-graph/pages` | W | Active | Yes | Register a CG page within an existing site; logs CG_PAGE_CREATED |
| `create_cg_topic` | VEDA | `POST /api/content-graph/topics` | W | Active | Yes | Register a CG topic (key+label); logs CG_TOPIC_CREATED |
| `create_cg_entity` | VEDA | `POST /api/content-graph/entities` | W | Active | Yes | Register a CG entity (key+label+entityType); logs CG_ENTITY_CREATED |
| `create_cg_archetype` | VEDA | `POST /api/content-graph/archetypes` | W | Active | Yes | Register a CG content archetype (key+label); logs CG_ARCHETYPE_CREATED |
| `create_cg_internal_link` | VEDA | `POST /api/content-graph/internal-links` | W | Active | Yes | Register a directed internal link between two project pages; logs CG_INTERNAL_LINK_CREATED |
| `create_cg_page_topic` | VEDA | `POST /api/content-graph/page-topics` | W | Active | Yes | Register a topic on a page; logs CG_PAGE_TOPIC_CREATED |
| `create_cg_page_entity` | VEDA | `POST /api/content-graph/page-entities` | W | Active | Yes | Register an entity on a page; logs CG_PAGE_ENTITY_CREATED |
| `create_cg_schema_usage` | VEDA | `POST /api/content-graph/schema-usage` | W | Active | Yes | Register a schema type on a page; logs CG_SCHEMA_USAGE_CREATED |
| `get_keyword_overview` | VEDA | `GET /api/seo/keyword-targets/:id/overview` | R | Active | Yes | SIL-15 composite overview for a keyword target |
| `get_keyword_volatility` | VEDA | `GET /api/seo/keyword-targets/:id/volatility` | R | Active | Yes | Volatility score, regime, maturity, and attribution components |
| `get_change_classification` | VEDA | `GET /api/seo/keyword-targets/:id/change-classification` | R | Active | Yes | SIL-12 change classification and confidence |
| `get_event_timeline` | VEDA | `GET /api/seo/keyword-targets/:id/event-timeline` | R | Active | Yes | SIL-13 classification transition stream |
| `get_event_causality` | VEDA | `GET /api/seo/keyword-targets/:id/event-causality` | R | Active | Yes | SIL-14 adjacent causal transition pairs |
| `get_intent_drift` | VEDA | `GET /api/seo/keyword-targets/:id/intent-drift` | R | Active | Yes | Per-snapshot intent distributions and bucket transitions |
| `get_feature_volatility` | VEDA | `GET /api/seo/keyword-targets/:id/feature-volatility` | R | Active | Yes | SERP feature family presence transitions |
| `get_domain_dominance` | VEDA | `GET /api/seo/keyword-targets/:id/domain-dominance` | R | Active | Yes | Domain dominance index and top domains for latest snapshot |
| `get_serp_similarity` | VEDA | `GET /api/seo/keyword-targets/:id/serp-similarity` | R | Active | Yes | Jaccard similarity scores across consecutive snapshot pairs |
| `get_project_diagnostic` | VEDA | `GET /api/seo/volatility-summary`, `GET /api/seo/volatility-alerts`, `GET /api/seo/risk-attribution-summary` | R | Active | Yes | MCP composite: fans out 3 parallel reads into compact triage packet |
| `get_top_volatile_keywords` | VEDA | `GET /api/seo/volatility-alerts` | R | Active | Yes | Ranked triage list of highest-volatility keywords |
| `get_keyword_diagnostic` | VEDA | `GET /api/seo/keyword-targets/:id/overview`, `event-timeline`, `event-causality` | R | Active | Yes | MCP composite: 3 parallel reads merged into single diagnostic packet |
| `get_serp_delta` | VEDA | `GET /api/seo/serp-deltas` | R | Active | Yes | Rank delta between two most recent snapshots; backend auto-selects pair |
| `get_volatility_breakdown` | VEDA | `GET /api/seo/keyword-targets/:id/volatility-breakdown` | R | Active | Yes | URL-level rank shift contributors |
| `get_volatility_spikes` | VEDA | `GET /api/seo/keyword-targets/:id/volatility-spikes` | R | Active | Yes | Top-N highest-volatility snapshot pairs |
| `get_operator_insight` | VEDA | `GET /api/seo/operator-insight` | R | Active | Yes | Synthesized per-keyword regime/maturity/risk narrative |
| `get_spike_delta` | VEDA | `GET /api/seo/keyword-targets/:id/volatility-spikes`, `GET /api/seo/serp-deltas` | R | Active | Yes | MCP composite: worst spike → SERP delta for that exact pair |
| `run_project_investigation` | VEDA | `GET /api/seo/volatility-summary`, `volatility-alerts`, `risk-attribution-summary`, `operator-reasoning`, per-keyword `overview` + `event-causality` | R | Active | Yes | Full observatory briefing; maturity fallback built in |
| `get_operator_reasoning` | VEDA | `GET /api/seo/operator-reasoning` | R | Active | Yes | Synthesized project SEO intelligence |
| `get_operator_briefing` | VEDA | `GET /api/seo/operator-briefing` | R | Active | Yes | Structured current SEO state summary |
| `get_risk_attribution_summary` | VEDA | `GET /api/seo/risk-attribution-summary` | R | Active | Yes | Risk signal breakdown across monitored keywords |

---

## Intentionally Deferred Tools

These tools were considered during Phase 3 and explicitly not added.

| Capability | Route | Reason deferred |
|---|---|---|
| `list_keyword_targets` | `GET /api/seo/keyword-targets` (if exists) | Keyword targets are accessed by UUID through all SIL tools. A standalone list endpoint has not been confirmed and is not needed for current workflows. |
| `get_seo_alerts` | `GET /api/seo/alerts` | SIL-9 compute-on-read alert surface. Requires `windowDays`; supports cursor pagination and `triggerTypes` filter. Not needed for current operator workflows; `get_project_diagnostic` and `get_top_volatile_keywords` cover primary alert visibility. |
| `get_serp_disturbances` | `GET /api/seo/serp-disturbances` | SIL-16–24 composite. Accepts optional `include` layer gating. High-value but wide response surface; deferred until a specific operator use case demands it. |
| `get_page_command_center` | `GET /api/seo/page-command-center` | Requires a `url` query param. Useful for page-specific deep-dives but not yet needed in current MCP operator workflows. |

---

## Write Tool Governance Summary

Currently active write tools:

| Tool | Route | What it mutates | Governed by |
|---|---|---|---|
| `create_project` | `POST /api/projects` | Creates a new Project record | API validation; no project scope header needed |
| `capture_source_item` | `POST /api/source-items/capture` | Creates SourceItem + SOURCE_CAPTURED EventLog atomically | `resolveProjectIdStrict`; Zod; transactional |
| `create_cg_surface` | `POST /api/content-graph/surfaces` | Creates CgSurface + CG_SURFACE_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional; key canonicalized |
| `create_cg_site` | `POST /api/content-graph/sites` | Creates CgSite + CG_SITE_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional; surface ownership verified |
| `create_cg_page` | `POST /api/content-graph/pages` | Creates CgPage + CG_PAGE_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional; site + archetype ownership verified |
| `create_cg_topic` | `POST /api/content-graph/topics` | Creates CgTopic + CG_TOPIC_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional |
| `create_cg_entity` | `POST /api/content-graph/entities` | Creates CgEntity + CG_ENTITY_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional |
| `create_cg_archetype` | `POST /api/content-graph/archetypes` | Creates CgContentArchetype + CG_ARCHETYPE_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional |
| `create_cg_internal_link` | `POST /api/content-graph/internal-links` | Creates CgInternalLink + CG_INTERNAL_LINK_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional; both page IDs verified within project |
| `create_cg_page_topic` | `POST /api/content-graph/page-topics` | Creates CgPageTopic + CG_PAGE_TOPIC_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional; page + topic ownership verified |
| `create_cg_page_entity` | `POST /api/content-graph/page-entities` | Creates CgPageEntity + CG_PAGE_ENTITY_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional; page + entity ownership verified |
| `create_cg_schema_usage` | `POST /api/content-graph/schema-usage` | Creates CgSchemaUsage + CG_SCHEMA_USAGE_CREATED EventLog | `resolveProjectIdStrict`; Zod; transactional; page ownership verified |

All write tools: call mutating routes explicitly, are annotated "WRITE —" in tool descriptions, enforce project scope via ApiClient headers, and delegate all validation and ownership checks to the API.

---

## Related Docs

- `docs/systems/operator-surfaces/mcp/overview.md`
- `docs/systems/operator-surfaces/mcp/tooling-principles.md`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/api/api-contract-principles.md`
