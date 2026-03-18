# VEDA Tool List

## Purpose

This document is the portable VEDA tool reference for operator-surface implementations.

It exists to answer:
- which VEDA capabilities should exist as tools
- which route each tool calls
- which inputs the tool needs
- whether the tool reads or writes
- whether project scope is required
- which tools are safe to replicate in other MCP servers or operator surfaces

This is not a replacement for the MCP registry.

Use this document when building:
- additional MCP servers
- Claude Desktop-compatible dev harnesses
- other API-driven LLM operator surfaces for VEDA

The source of truth chain remains:

```text
tool surface -> HTTP/API contract -> VEDA bounded capability
```

All tools here are API-driven.
No direct DB access.
No Prisma access.
No ownership transfer.

---

## Usage rules

### 1. Project scope
Most VEDA tools are project-scoped and require the operator surface to send project scope headers.

Global exceptions:
- `list_projects`
- `get_project`
- `create_project`

### 2. Read vs write
Read tools expose observability and diagnostics.
Write tools must stay explicit and obviously mutating.
Do not hide writes behind read-sounding names.

### 3. Portability rule
If another MCP server or operator surface implements a VEDA tool from this list, it should preserve:
- the same route
- the same required inputs
- the same project-scope behavior
- the same mutation visibility
- the same bounded ownership

---

## Tool categories

### Project container tools
| Tool | Route | R/W | Project scoped? | Required inputs | Notes |
|---|---|---:|---|---|---|
| `list_projects` | `GET /api/projects` | R | No | none | Global project list |
| `get_project` | `GET /api/projects/:id` | R | No | `projectId` | Fetch single project |
| `create_project` | `POST /api/projects` | W | No | `name` | Optional `slug`, `description` |

### Observatory floor tools
| Tool | Route | R/W | Project scoped? | Required inputs | Notes |
|---|---|---:|---|---|---|
| `list_source_items` | `GET /api/source-items` | R | Yes | none | Optional `status`, `sourceType`, `platform`, pagination |
| `capture_source_item` | `POST /api/source-items/capture` | W | Yes | `sourceType`, `url`, `operatorIntent` | Optional `platform`, `notes`; logs `SOURCE_CAPTURED` |
| `list_events` | `GET /api/events` | R | Yes | none | Optional `eventType`, `entityType`, `entityId`, `actor`, `after`, `before`, pagination |
| `list_search_performance` | `GET /api/seo/search-performance` | R | Yes | none | Optional `query`, `pageUrl`, `dateStart`, `dateEnd`, pagination |

### VEDA Brain tools
| Tool | Route | R/W | Project scoped? | Required inputs | Notes |
|---|---|---:|---|---|---|
| `get_veda_brain_diagnostics` | `GET /api/veda-brain/project-diagnostics` | R | Yes | none | Compute-on-read project diagnostics |
| `get_proposals` | `GET /api/veda-brain/proposals` | R | Yes | none | Read-only proposal visibility |

### Content Graph diagnostic/read tools
| Tool | Route | R/W | Project scoped? | Required inputs | Notes |
|---|---|---:|---|---|---|
| `get_content_graph_diagnostics` | `GET /api/content-graph/project-diagnostics` | R | Yes | none | Compute-on-read CG diagnostics |
| `list_cg_surfaces` | `GET /api/content-graph/surfaces` | R | Yes | none | Pagination optional |
| `list_cg_sites` | `GET /api/content-graph/sites` | R | Yes | none | Pagination optional |
| `list_cg_pages` | `GET /api/content-graph/pages` | R | Yes | none | Optional `siteId`, pagination |
| `list_cg_topics` | `GET /api/content-graph/topics` | R | Yes | none | Pagination optional |
| `list_cg_entities` | `GET /api/content-graph/entities` | R | Yes | none | Optional `entityType`, pagination |
| `list_cg_archetypes` | `GET /api/content-graph/archetypes` | R | Yes | none | Pagination optional |
| `list_cg_internal_links` | `GET /api/content-graph/internal-links` | R | Yes | none | Optional `sourcePageId`, `targetPageId`, pagination |
| `list_cg_page_topics` | `GET /api/content-graph/page-topics` | R | Yes | none | Optional `pageId`, `topicId`, pagination |
| `list_cg_page_entities` | `GET /api/content-graph/page-entities` | R | Yes | none | Optional `pageId`, `entityId`, pagination |
| `list_cg_schema_usage` | `GET /api/content-graph/schema-usage` | R | Yes | none | Optional `pageId`, `schemaType`, pagination |

### Content Graph write tools
| Tool | Route | R/W | Project scoped? | Required inputs | Notes |
|---|---|---:|---|---|---|
| `create_cg_surface` | `POST /api/content-graph/surfaces` | W | Yes | `type`, `key` | Optional `label`, `canonicalIdentifier`, `canonicalUrl`, `enabled` |
| `create_cg_site` | `POST /api/content-graph/sites` | W | Yes | `surfaceId`, `domain` | Optional `framework`, `isCanonical`, `notes` |
| `create_cg_page` | `POST /api/content-graph/pages` | W | Yes | `siteId`, `url`, `title` | Optional `contentArchetypeId`, `canonicalUrl`, `publishingState`, `isIndexable` |
| `create_cg_topic` | `POST /api/content-graph/topics` | W | Yes | `key`, `label` | Registers topic vocabulary |
| `create_cg_entity` | `POST /api/content-graph/entities` | W | Yes | `key`, `label`, `entityType` | Registers entity vocabulary |
| `create_cg_archetype` | `POST /api/content-graph/archetypes` | W | Yes | `key`, `label` | Registers content archetype vocabulary |
| `create_cg_internal_link` | `POST /api/content-graph/internal-links` | W | Yes | `sourcePageId`, `targetPageId` | Optional `anchorText`, `linkRole` |
| `create_cg_page_topic` | `POST /api/content-graph/page-topics` | W | Yes | `pageId`, `topicId` | Optional `role` |
| `create_cg_page_entity` | `POST /api/content-graph/page-entities` | W | Yes | `pageId`, `entityId` | Optional `role` |
| `create_cg_schema_usage` | `POST /api/content-graph/schema-usage` | W | Yes | `pageId`, `schemaType` | Optional `isPrimary` |

### Keyword-target / SIL read tools
| Tool | Route | R/W | Project scoped? | Required inputs | Notes |
|---|---|---:|---|---|---|
| `get_keyword_overview` | `GET /api/seo/keyword-targets/:id/overview` | R | Yes | `keywordTargetId` | SIL-15 composite overview |
| `get_keyword_volatility` | `GET /api/seo/keyword-targets/:id/volatility` | R | Yes | `keywordTargetId` | Volatility profile |
| `get_change_classification` | `GET /api/seo/keyword-targets/:id/change-classification` | R | Yes | `keywordTargetId` | SIL-12 classification |
| `get_event_timeline` | `GET /api/seo/keyword-targets/:id/event-timeline` | R | Yes | `keywordTargetId` | SIL-13 timeline |
| `get_event_causality` | `GET /api/seo/keyword-targets/:id/event-causality` | R | Yes | `keywordTargetId` | SIL-14 causality |
| `get_intent_drift` | `GET /api/seo/keyword-targets/:id/intent-drift` | R | Yes | `keywordTargetId` | Intent bucket drift |
| `get_feature_volatility` | `GET /api/seo/keyword-targets/:id/feature-volatility` | R | Yes | `keywordTargetId` | Feature-family volatility |
| `get_domain_dominance` | `GET /api/seo/keyword-targets/:id/domain-dominance` | R | Yes | `keywordTargetId` | Domain dominance |
| `get_serp_similarity` | `GET /api/seo/keyword-targets/:id/serp-similarity` | R | Yes | `keywordTargetId` | Structural similarity |
| `get_serp_delta` | `GET /api/seo/serp-deltas` | R | Yes | `keywordTargetId` | Auto-selects latest pair when IDs omitted |
| `get_volatility_breakdown` | `GET /api/seo/keyword-targets/:id/volatility-breakdown` | R | Yes | `keywordTargetId` | URL-level contributors |
| `get_volatility_spikes` | `GET /api/seo/keyword-targets/:id/volatility-spikes` | R | Yes | `keywordTargetId` | Highest-volatility pairs |
| `get_operator_insight` | `GET /api/seo/operator-insight` | R | Yes | `keywordTargetId` | Synthesized keyword insight |

### Composite / project-level VEDA tools
| Tool | Route(s) | R/W | Project scoped? | Required inputs | Notes |
|---|---|---:|---|---|---|
| `get_project_diagnostic` | composite over summary + alerts + risk attribution | R | Yes | none | MCP composite, not a single backend route |
| `get_top_volatile_keywords` | `GET /api/seo/volatility-alerts` | R | Yes | none | Optional `limit` |
| `get_keyword_diagnostic` | composite over overview + timeline + causality | R | Yes | `keywordTargetId` | Compact triage packet |
| `get_spike_delta` | composite over spikes + serp-deltas | R | Yes | `keywordTargetId` | Worst spike -> exact delta |
| `run_project_investigation` | composite over project-level SEO routes + per-keyword reads | R | Yes | none | Full observatory briefing |
| `get_operator_reasoning` | `GET /api/seo/operator-reasoning` | R | Yes | none | Project reasoning output |
| `get_operator_briefing` | `GET /api/seo/operator-briefing` | R | Yes | none | Project briefing |
| `get_risk_attribution_summary` | `GET /api/seo/risk-attribution-summary` | R | Yes | none | Project risk signal breakdown |

---

## Intentionally absent for now

| Tool | Reason |
|---|---|
| `list_keyword_targets` | No confirmed `GET /api/seo/keyword-targets` list route has been adopted as an MCP surface yet. Current workflows use operator-supplied keyword target UUIDs. |
| `get_seo_alerts` | SIL-9 compute-on-read alert surface. Requires `windowDays`; supports cursor pagination and `triggerTypes`. Not needed for current operator workflows; project diagnostic and volatility-alerts cover primary alert visibility. |
| `get_serp_disturbances` | SIL-16–24 composite. Accepts optional `include` layer gating. Deferred until a specific operator use case demands it. |
| `get_page_command_center` | Requires a `url` query param. Useful for page-specific deep-dives but not yet needed in current workflows. |

---

## Audit notes — what to watch for

These are recurring patterns identified during MCP tool audits.
They are not tool-specific bugs, but structural risks that must be preserved or monitored across implementations.

### 1. Shared handler coupling (junction writes)

Applies to:
- `create_cg_page_topic`
- `create_cg_page_entity`

Both rely on a shared handler pattern (`handleCreateCgJunction`).

What to watch:
- handler assumes identical body shape across routes
- handler assumes identical optional role behavior
- handler assumes identical validation expectations

If any route diverges (extra fields, different defaults, different invariants),
the shared handler must be split or adjusted.

### 2. Enum drift between MCP and API

Applies to:
- page roles
- link roles
- publishing states
- surface types

What to watch:
- MCP input enums must match server Zod enums exactly
- no extra values in MCP
- no missing values from API

If enums diverge, MCP becomes a silent source of invalid requests.

### 3. Optional field semantics (undefined vs empty)

Applies broadly to write tools.

What to watch:
- `undefined` means "not provided"
- empty string must not bypass validation
- handlers must use explicit checks (e.g. `!== undefined`)

### 4. Cross-project non-disclosure

Applies to all project-scoped writes.

What to watch:
- cross-project references must return 404
- not 403
- not descriptive errors

### 5. Uniqueness invariants enforced at API layer

Examples:
- `pageId + entityId`
- `pageId + topicId`
- `pageId + schemaType`
- `projectId + domain`
- `projectId + key`
- `projectId + url` (pages)
- `sourcePageId + targetPageId` (internal links)

What to watch:
- MCP must not attempt to enforce uniqueness
- API is the source of truth
- MCP only forwards valid shape

### 6. Flexible string fields should still be bounded

Applies to:
- `schemaType`
- `entityType`
- other open-ended structured string inputs

What to watch:
- keep flexible inputs flexible when the API intentionally allows many values
- still mirror simple API bounds such as `minLength` and `maxLength` where safe
- avoid turning flexible API strings into fake enums in MCP

### 7. Semantic drift in flexible classification fields

Applies to:
- `entityType`
- future classification-like string fields

What to watch:
- structurally valid strings can still decay into semantically useless categories
- examples: `product`, `Product`, `products`, `tool`, `software`, `saas`
- this is not a schema bug by itself
- do not rush to solve it with fake enums or schema churn
- govern the vocabulary upstream through operating discipline, review, and docs unless a real invariant later emerges

### 8. Parent-state constraints belong to the API contract

Applies to:
- `create_cg_site` on disabled surfaces
- future nested writes with parent readiness rules

What to watch:
- MCP can describe parent-state rejection clearly
- API remains the source of truth for whether a parent can currently accept children
- do not duplicate parent-state business logic in MCP

### 9. Global route header suppression scope

Applies to:
- `get_project`
- `create_project`
- any future global (non-project-scoped) tools

What to watch:
- the api-client suppresses project scope headers only for the plain project list route (`/api/projects`)
- `get_project` and `create_project` receive the project header but those routes do not read it
- this is safe today because those routes do not resolve project scope
- if a future global route validates or rejects unexpected project headers, add it to the suppression condition in `api-client.ts` explicitly
- do not assume "project scoped: No" in the registry guarantees the header is absent

---

## How to use this doc

When building another VEDA operator surface or MCP server:
1. start with this tool list
2. confirm route contract still matches the API
3. preserve project-scope behavior
4. preserve read/write explicitness
5. do not add tools for routes that do not exist
6. do not add direct DB behavior

If a tool changes meaningfully here, update:
- this file
- `docs/systems/operator-surfaces/mcp/tool-registry.md`
- cleanup intelligence docs if the active reconstruction map changes

---

## Related docs

- `docs/systems/operator-surfaces/mcp/overview.md`
- `docs/systems/operator-surfaces/mcp/tool-registry.md`
- `docs/systems/operator-surfaces/mcp/tooling-principles.md`
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
