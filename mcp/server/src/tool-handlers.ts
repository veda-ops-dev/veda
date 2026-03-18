/**
 * Tool Call Handlers - VEDA Observatory and Search Intelligence
 *
 * Grounded by:
 * - docs/architecture/V_ECOSYSTEM.md
 * - docs/architecture/api/api-contract-principles.md
 * - docs/architecture/veda/search-intelligence-layer.md
 * - docs/systems/operator-surfaces/mcp/overview.md
 * - docs/systems/operator-surfaces/mcp/tooling-principles.md
 *
 * Active tool registry: docs/systems/operator-surfaces/mcp/tool-registry.md
 *
 * Rules:
 * - All handlers call HTTP/API endpoints only. No Prisma. No DB access.
 * - Project scoping is preserved by ApiClient headers throughout.
 * - Write handlers are clearly labeled and call mutating routes explicitly.
 * - No blueprint, draft, editorial, publishing, or execution workflow handlers.
 */

import { McpError, ErrorCode } from "@modelcontextprotocol/sdk/types.js";
import { ApiClient } from "./api-client.js";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d{3})?Z)?$/;

interface ApiErrorBody {
  error?: {
    code?: string;
    message?: string;
  };
}

/**
 * Validate UUID format
 */
function validateUuid(value: string, paramName: string): void {
  if (!UUID_RE.test(value)) {
    throw new McpError(
      ErrorCode.InvalidParams,
      `${paramName} must be a valid UUID`
    );
  }
}

/**
 * Validate ISO date format
 */
function validateIsoDate(value: string, paramName: string): void {
  if (!ISO_DATE_RE.test(value)) {
    throw new McpError(
      ErrorCode.InvalidParams,
      `${paramName} must be ISO 8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss.sssZ)`
    );
  }
}

/**
 * Clamp pagination parameters to valid ranges
 */
function clampPagination(params: Record<string, unknown>): { page: number; limit: number } {
  const page = Math.max(1, Math.floor(Number(params.page ?? 1)));
  const limit = Math.max(1, Math.min(100, Math.floor(Number(params.limit ?? 20))));
  return { page, limit };
}

/**
 * Build query string from parameters
 */
function buildQueryString(params: Record<string, unknown>): string {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) {
      query.append(key, String(value));
    }
  }
  const qs = query.toString();
  return qs ? `?${qs}` : "";
}

/**
 * Handle API errors and map to MCP errors
 */
async function handleApiError(response: Response): Promise<never> {
  let errorBody: ApiErrorBody | null = null;
  try {
    errorBody = await response.json() as ApiErrorBody;
  } catch {
    // Non-JSON error response
  }

  const backendMessage = errorBody?.error?.message ?? response.statusText;

  switch (response.status) {
    case 400:
      throw new McpError(ErrorCode.InvalidParams, backendMessage);
    case 401:
      throw new McpError(ErrorCode.InvalidRequest, backendMessage);
    case 403:
      throw new McpError(ErrorCode.InvalidRequest, backendMessage);
    case 404:
      throw new McpError(ErrorCode.InternalError, backendMessage);
    case 409:
      throw new McpError(ErrorCode.InvalidRequest, backendMessage);
    default:
      throw new McpError(ErrorCode.InternalError, backendMessage);
  }
}

/**
 * Format tool result with structured content + compact JSON text
 */
function formatToolResult(data: unknown) {
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(data),
      },
    ],
    isError: false,
  };
}

/**
 * Main tool call dispatcher
 */
export async function handleToolCall(
  toolName: string,
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  switch (toolName) {
    // ── Project bootstrap ────────────────────────────────────────────────
    case "list_projects":
      return handleListProjects(args, apiClient);
    case "get_project":
      return handleGetProject(args, apiClient);
    case "create_project":
      return handleCreateProject(args, apiClient);
    // ── Search performance ────────────────────────────────────────────────
    case "list_search_performance":
      return handleListSearchPerformance(args, apiClient);
    // ── Source items ──────────────────────────────────────────────────────
    case "list_source_items":
      return handleListSourceItems(args, apiClient);
    case "capture_source_item":
      return handleCaptureSourceItem(args, apiClient);
    // ── Events ────────────────────────────────────────────────────────────
    case "list_events":
      return handleListEvents(args, apiClient);
    // ── VEDA Brain ────────────────────────────────────────────────────────
    case "get_veda_brain_diagnostics":
      return handleVedaBrainDiagnostics(apiClient);
    // ── Proposals ─────────────────────────────────────────────────────────
    case "get_proposals":
      return handleGetProposals(apiClient);
    // ── Content Graph read ────────────────────────────────────────────────
    case "get_content_graph_diagnostics":
      return handleContentGraphDiagnostics(apiClient);
    case "list_cg_surfaces":
      return handleListCgResource(args, apiClient, "/api/content-graph/surfaces");
    case "list_cg_sites":
      return handleListCgResource(args, apiClient, "/api/content-graph/sites");
    case "list_cg_pages":
      return handleListCgPages(args, apiClient);
    case "list_cg_topics":
      return handleListCgResource(args, apiClient, "/api/content-graph/topics");
    case "list_cg_entities":
      return handleListCgEntities(args, apiClient);
    case "list_cg_archetypes":
      return handleListCgResource(args, apiClient, "/api/content-graph/archetypes");
    case "list_cg_internal_links":
      return handleListCgInternalLinks(args, apiClient);
    case "list_cg_page_topics":
      return handleListCgPageTopics(args, apiClient);
    case "list_cg_page_entities":
      return handleListCgPageEntities(args, apiClient);
    case "list_cg_schema_usage":
      return handleListCgSchemaUsage(args, apiClient);
    // ── Content Graph write ───────────────────────────────────────────────
    case "create_cg_surface":
      return handleCreateCgSurface(args, apiClient);
    case "create_cg_site":
      return handleCreateCgSite(args, apiClient);
    case "create_cg_page":
      return handleCreateCgPage(args, apiClient);
    case "create_cg_topic":
      return handleCreateCgSimple(args, apiClient, "/api/content-graph/topics", ["key", "label"]);
    case "create_cg_entity":
      return handleCreateCgEntity(args, apiClient);
    case "create_cg_archetype":
      return handleCreateCgSimple(args, apiClient, "/api/content-graph/archetypes", ["key", "label"]);
    case "create_cg_internal_link":
      return handleCreateCgInternalLink(args, apiClient);
    case "create_cg_page_topic":
      return handleCreateCgJunction(args, apiClient, "/api/content-graph/page-topics", "pageId", "topicId", "role");
    case "create_cg_page_entity":
      return handleCreateCgJunction(args, apiClient, "/api/content-graph/page-entities", "pageId", "entityId", "role");
    case "create_cg_schema_usage":
      return handleCreateCgSchemaUsage(args, apiClient);
    // ── Keyword-level observatory ─────────────────────────────────────────
    case "get_keyword_overview":
      return handleKeywordSubresource(args, apiClient, "overview");
    case "get_keyword_volatility":
      return handleKeywordSubresource(args, apiClient, "volatility");
    case "get_change_classification":
      return handleKeywordSubresource(args, apiClient, "change-classification");
    case "get_event_timeline":
      return handleKeywordSubresource(args, apiClient, "event-timeline");
    case "get_event_causality":
      return handleKeywordSubresource(args, apiClient, "event-causality");
    case "get_intent_drift":
      return handleKeywordSubresource(args, apiClient, "intent-drift");
    case "get_feature_volatility":
      return handleKeywordSubresource(args, apiClient, "feature-volatility");
    case "get_domain_dominance":
      return handleKeywordSubresource(args, apiClient, "domain-dominance");
    case "get_serp_similarity":
      return handleKeywordSubresource(args, apiClient, "serp-similarity");
    // ── Project-level diagnostics ─────────────────────────────────────────
    case "get_project_diagnostic":
      return handleProjectDiagnostic(apiClient);
    case "get_top_volatile_keywords":
      return handleTopVolatileKeywords(args, apiClient);
    // ── Composite diagnostics ─────────────────────────────────────────────
    case "get_keyword_diagnostic":
      return handleKeywordDiagnostic(args, apiClient);
    // ── Deep-dive keyword ─────────────────────────────────────────────────
    case "get_serp_delta":
      return handleSerpDelta(args, apiClient);
    case "get_volatility_breakdown":
      return handleKeywordSubresource(args, apiClient, "volatility-breakdown");
    case "get_volatility_spikes":
      return handleKeywordSubresource(args, apiClient, "volatility-spikes");
    case "get_operator_insight":
      return handleOperatorInsight(args, apiClient);
    case "get_spike_delta":
      return handleSpikeDelta(args, apiClient);
    // ── Project investigation ─────────────────────────────────────────────
    case "run_project_investigation":
      return handleProjectInvestigation(apiClient);
    // ── Operator-level observatory ────────────────────────────────────────
    case "get_operator_reasoning":
      return handleOperatorEndpoint(apiClient, "/api/seo/operator-reasoning");
    case "get_operator_briefing":
      return handleOperatorEndpoint(apiClient, "/api/seo/operator-briefing");
    case "get_risk_attribution_summary":
      return handleOperatorEndpoint(apiClient, "/api/seo/risk-attribution-summary");
    default:
      throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${toolName}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Project bootstrap handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * list_projects: GET /api/projects
 */
async function handleListProjects(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);
  const queryString = buildQueryString({ page, limit });
  const response = await apiClient.fetch(`/api/projects${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ───────────────────────────────────────────────────────────────────────────────
// Content Graph additional read handlers
// ───────────────────────────────────────────────────────────────────────────────

/**
 * list_cg_internal_links: GET /api/content-graph/internal-links
 *
 * Supports optional sourcePageId and targetPageId filters.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleListCgInternalLinks(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  if (args.sourcePageId) validateUuid(args.sourcePageId as string, "sourcePageId");
  if (args.targetPageId) validateUuid(args.targetPageId as string, "targetPageId");

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.sourcePageId) queryParams.sourcePageId = args.sourcePageId;
  if (args.targetPageId) queryParams.targetPageId = args.targetPageId;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/content-graph/internal-links${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * list_cg_page_topics: GET /api/content-graph/page-topics
 *
 * Supports optional pageId and topicId filters.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleListCgPageTopics(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  if (args.pageId) validateUuid(args.pageId as string, "pageId");
  if (args.topicId) validateUuid(args.topicId as string, "topicId");

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.pageId) queryParams.pageId = args.pageId;
  if (args.topicId) queryParams.topicId = args.topicId;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/content-graph/page-topics${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * list_cg_page_entities: GET /api/content-graph/page-entities
 *
 * Supports optional pageId and entityId filters.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleListCgPageEntities(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  if (args.pageId) validateUuid(args.pageId as string, "pageId");
  if (args.entityId) validateUuid(args.entityId as string, "entityId");

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.pageId) queryParams.pageId = args.pageId;
  if (args.entityId) queryParams.entityId = args.entityId;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/content-graph/page-entities${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * list_cg_schema_usage: GET /api/content-graph/schema-usage
 *
 * Supports optional pageId and schemaType filters.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleListCgSchemaUsage(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  if (args.pageId) validateUuid(args.pageId as string, "pageId");

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.pageId) queryParams.pageId = args.pageId;
  if (args.schemaType) queryParams.schemaType = args.schemaType;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/content-graph/schema-usage${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ───────────────────────────────────────────────────────────────────────────────
// Content Graph write handlers
// ───────────────────────────────────────────────────────────────────────────────

/**
 * create_cg_surface: POST /api/content-graph/surfaces
 *
 * WRITE — Registers a new CG surface. Key is canonicalized server-side.
 * Project scoping via ApiClient headers (resolveProjectIdStrict on server side).
 * Logs CG_SURFACE_CREATED event atomically. HTTP API only.
 */
async function handleCreateCgSurface(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const type = args.type as string;
  const key = args.key as string;
  if (!type) throw new McpError(ErrorCode.InvalidParams, "type is required");
  if (!key) throw new McpError(ErrorCode.InvalidParams, "key is required");

  const body: Record<string, unknown> = { type, key };
  if (args.label !== undefined) body.label = args.label;
  if (args.canonicalIdentifier !== undefined) body.canonicalIdentifier = args.canonicalIdentifier;
  if (args.canonicalUrl !== undefined) body.canonicalUrl = args.canonicalUrl;
  if (args.enabled !== undefined) body.enabled = args.enabled;

  const response = await apiClient.fetch("/api/content-graph/surfaces", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * create_cg_site: POST /api/content-graph/sites
 *
 * WRITE — Registers a new CG site within an existing surface.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleCreateCgSite(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const surfaceId = args.surfaceId as string;
  const domain = args.domain as string;
  if (!surfaceId) throw new McpError(ErrorCode.InvalidParams, "surfaceId is required");
  if (!domain) throw new McpError(ErrorCode.InvalidParams, "domain is required");
  validateUuid(surfaceId, "surfaceId");

  const body: Record<string, unknown> = { surfaceId, domain };
  if (args.framework !== undefined) body.framework = args.framework;
  if (args.isCanonical !== undefined) body.isCanonical = args.isCanonical;
  if (args.notes !== undefined) body.notes = args.notes;

  const response = await apiClient.fetch("/api/content-graph/sites", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * create_cg_page: POST /api/content-graph/pages
 *
 * WRITE — Registers a new CG page within an existing site.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleCreateCgPage(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const siteId = args.siteId as string;
  const url = args.url as string;
  const title = args.title as string;
  if (!siteId) throw new McpError(ErrorCode.InvalidParams, "siteId is required");
  if (!url) throw new McpError(ErrorCode.InvalidParams, "url is required");
  if (!title) throw new McpError(ErrorCode.InvalidParams, "title is required");
  validateUuid(siteId, "siteId");
  if (args.contentArchetypeId !== undefined) validateUuid(args.contentArchetypeId as string, "contentArchetypeId");

  const body: Record<string, unknown> = { siteId, url, title };
  if (args.contentArchetypeId !== undefined) body.contentArchetypeId = args.contentArchetypeId;
  if (args.canonicalUrl !== undefined) body.canonicalUrl = args.canonicalUrl;
  if (args.publishingState !== undefined) body.publishingState = args.publishingState;
  if (args.isIndexable !== undefined) body.isIndexable = args.isIndexable;

  const response = await apiClient.fetch("/api/content-graph/pages", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleCreateCgSimple — shared handler for key+label write tools.
 *
 * Used by: create_cg_topic, create_cg_archetype
 *
 * WRITE — Project scoping via ApiClient headers. HTTP API only.
 */
async function handleCreateCgSimple(
  args: Record<string, unknown>,
  apiClient: ApiClient,
  path: string,
  requiredFields: string[]
): Promise<unknown> {
  for (const field of requiredFields) {
    if (!args[field]) throw new McpError(ErrorCode.InvalidParams, `${field} is required`);
  }

  const body: Record<string, unknown> = {};
  for (const field of requiredFields) {
    body[field] = args[field];
  }

  const response = await apiClient.fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * create_cg_entity: POST /api/content-graph/entities
 *
 * WRITE — Registers a new CG entity.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleCreateCgEntity(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const key = args.key as string;
  const label = args.label as string;
  const entityType = args.entityType as string;
  if (!key) throw new McpError(ErrorCode.InvalidParams, "key is required");
  if (!label) throw new McpError(ErrorCode.InvalidParams, "label is required");
  if (!entityType) throw new McpError(ErrorCode.InvalidParams, "entityType is required");

  const response = await apiClient.fetch("/api/content-graph/entities", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ key, label, entityType }),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * create_cg_internal_link: POST /api/content-graph/internal-links
 *
 * WRITE — Registers a directed internal link between two pages.
 * Both pages must belong to the active project. Self-links rejected by API.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleCreateCgInternalLink(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const sourcePageId = args.sourcePageId as string;
  const targetPageId = args.targetPageId as string;
  if (!sourcePageId) throw new McpError(ErrorCode.InvalidParams, "sourcePageId is required");
  if (!targetPageId) throw new McpError(ErrorCode.InvalidParams, "targetPageId is required");
  validateUuid(sourcePageId, "sourcePageId");
  validateUuid(targetPageId, "targetPageId");

  if (sourcePageId === targetPageId) {
    throw new McpError(ErrorCode.InvalidParams, "sourcePageId and targetPageId must be different");
  }

  const body: Record<string, unknown> = { sourcePageId, targetPageId };
  if (args.anchorText !== undefined) body.anchorText = args.anchorText;
  if (args.linkRole !== undefined) body.linkRole = args.linkRole;

  const response = await apiClient.fetch("/api/content-graph/internal-links", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleCreateCgJunction — shared handler for page-topic and page-entity junction writes.
 *
 * Used by: create_cg_page_topic, create_cg_page_entity
 *
 * WRITE — Both foreign keys must belong to the active project.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleCreateCgJunction(
  args: Record<string, unknown>,
  apiClient: ApiClient,
  path: string,
  keyA: string,
  keyB: string,
  roleField: string
): Promise<unknown> {
  const valA = args[keyA] as string;
  const valB = args[keyB] as string;
  if (!valA) throw new McpError(ErrorCode.InvalidParams, `${keyA} is required`);
  if (!valB) throw new McpError(ErrorCode.InvalidParams, `${keyB} is required`);
  validateUuid(valA, keyA);
  validateUuid(valB, keyB);

  const body: Record<string, unknown> = { [keyA]: valA, [keyB]: valB };
  if (args[roleField] !== undefined) body[roleField] = args[roleField];

  const response = await apiClient.fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * create_cg_schema_usage: POST /api/content-graph/schema-usage
 *
 * WRITE — Registers a schema type on a page.
 * The page must belong to the active project.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleCreateCgSchemaUsage(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const pageId = args.pageId as string;
  const schemaType = args.schemaType as string;
  if (!pageId) throw new McpError(ErrorCode.InvalidParams, "pageId is required");
  if (!schemaType) throw new McpError(ErrorCode.InvalidParams, "schemaType is required");
  validateUuid(pageId, "pageId");

  const body: Record<string, unknown> = { pageId, schemaType };
  if (args.isPrimary !== undefined) body.isPrimary = args.isPrimary;

  const response = await apiClient.fetch("/api/content-graph/schema-usage", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * get_project: GET /api/projects/:id
 */
async function handleGetProject(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const projectId = args.projectId as string;
  if (!projectId) throw new McpError(ErrorCode.InvalidParams, "projectId is required");
  validateUuid(projectId, "projectId");
  const response = await apiClient.fetch(`/api/projects/${projectId}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * create_project: POST /api/projects
 *
 * WRITE — Creates a new project. No project scoping header required.
 */
async function handleCreateProject(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const name = args.name as string;
  if (!name) throw new McpError(ErrorCode.InvalidParams, "name is required");

  const body: Record<string, unknown> = { name };
  if (args.slug) body.slug = args.slug;
  if (args.description) body.description = args.description;

  const response = await apiClient.fetch("/api/projects", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ─────────────────────────────────────────────────────────────────────────────
// Search performance handler
// ─────────────────────────────────────────────────────────────────────────────

/**
 * list_search_performance: GET /api/seo/search-performance
 */
async function handleListSearchPerformance(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  if (args.dateStart) validateIsoDate(args.dateStart as string, "dateStart");
  if (args.dateEnd) validateIsoDate(args.dateEnd as string, "dateEnd");

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.query) queryParams.query = args.query;
  if (args.pageUrl) queryParams.pageUrl = args.pageUrl;
  if (args.dateStart) queryParams.dateStart = args.dateStart;
  if (args.dateEnd) queryParams.dateEnd = args.dateEnd;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/seo/search-performance${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ─────────────────────────────────────────────────────────────────────────────
// Source item handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * list_source_items: GET /api/source-items
 *
 * Project scoping via ApiClient headers. Supports optional filters for
 * status, sourceType, and platform. HTTP API only.
 */
async function handleListSourceItems(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.status) queryParams.status = args.status;
  if (args.sourceType) queryParams.sourceType = args.sourceType;
  if (args.platform) queryParams.platform = args.platform;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/source-items${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * capture_source_item: POST /api/source-items/capture
 *
 * WRITE — Captures a new SourceItem or recaptures an existing one.
 * Project scoping via ApiClient headers (resolveProjectIdStrict on server side).
 * Logs SOURCE_CAPTURED event atomically. HTTP API only.
 */
async function handleCaptureSourceItem(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const sourceType = args.sourceType as string;
  const url = args.url as string;
  const operatorIntent = args.operatorIntent as string;

  if (!sourceType) throw new McpError(ErrorCode.InvalidParams, "sourceType is required");
  if (!url) throw new McpError(ErrorCode.InvalidParams, "url is required");
  if (!operatorIntent) throw new McpError(ErrorCode.InvalidParams, "operatorIntent is required");

  const body: Record<string, unknown> = { sourceType, url, operatorIntent };
  if (args.platform) body.platform = args.platform;
  if (args.notes) body.notes = args.notes;

  const response = await apiClient.fetch("/api/source-items/capture", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ─────────────────────────────────────────────────────────────────────────────
// Event log handler
// ─────────────────────────────────────────────────────────────────────────────

/**
 * list_events: GET /api/events
 *
 * Project scoping via ApiClient headers. Supports optional filters for
 * eventType, entityType, entityId, actor, and timestamp range. HTTP API only.
 */
async function handleListEvents(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  // Validate entityId UUID if provided
  if (args.entityId) validateUuid(args.entityId as string, "entityId");

  // Validate timestamp strings if provided
  if (args.after) validateIsoDate(args.after as string, "after");
  if (args.before) validateIsoDate(args.before as string, "before");

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.eventType) queryParams.eventType = args.eventType;
  if (args.entityType) queryParams.entityType = args.entityType;
  if (args.entityId) queryParams.entityId = args.entityId;
  if (args.actor) queryParams.actor = args.actor;
  if (args.after) queryParams.after = args.after;
  if (args.before) queryParams.before = args.before;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/events${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ─────────────────────────────────────────────────────────────────────────────
// VEDA Brain handler
// ─────────────────────────────────────────────────────────────────────────────

/**
 * get_veda_brain_diagnostics: GET /api/veda-brain/project-diagnostics
 *
 * Returns compute-on-read VEDA Brain diagnostics for the active project.
 * Project scoping via ApiClient headers. Read-only. HTTP API only.
 */
async function handleVedaBrainDiagnostics(
  apiClient: ApiClient
): Promise<unknown> {
  const response = await apiClient.fetch("/api/veda-brain/project-diagnostics");
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ─────────────────────────────────────────────────────────────────────────────
// Proposal handler
// ─────────────────────────────────────────────────────────────────────────────

/**
 * get_proposals: GET /api/veda-brain/proposals
 *
 * Returns Phase C1 SERP-to-Content-Graph proposals for the active project.
 * Project scoping via ApiClient headers. Read-only. HTTP API only.
 */
async function handleGetProposals(
  apiClient: ApiClient
): Promise<unknown> {
  const response = await apiClient.fetch("/api/veda-brain/proposals");
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ─────────────────────────────────────────────────────────────────────────────
// Content Graph handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * get_content_graph_diagnostics: GET /api/content-graph/project-diagnostics
 *
 * Returns compute-on-read Content Graph diagnostics for the active project.
 * Project scoping via ApiClient headers. Read-only. HTTP API only.
 */
async function handleContentGraphDiagnostics(
  apiClient: ApiClient
): Promise<unknown> {
  const response = await apiClient.fetch("/api/content-graph/project-diagnostics");
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleListCgResource -- shared handler for paginated Content Graph list endpoints
 * with no additional filters beyond page/limit.
 *
 * Used by: list_cg_surfaces, list_cg_sites, list_cg_topics
 *
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleListCgResource(
  args: Record<string, unknown>,
  apiClient: ApiClient,
  path: string
): Promise<unknown> {
  const { page, limit } = clampPagination(args);
  const queryString = buildQueryString({ page, limit });
  const response = await apiClient.fetch(`${path}${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * list_cg_pages: GET /api/content-graph/pages
 *
 * Supports optional siteId filter. Project scoping via ApiClient headers. HTTP API only.
 */
async function handleListCgPages(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  if (args.siteId) validateUuid(args.siteId as string, "siteId");

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.siteId) queryParams.siteId = args.siteId;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/content-graph/pages${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * list_cg_entities: GET /api/content-graph/entities
 *
 * Supports optional entityType filter. Project scoping via ApiClient headers. HTTP API only.
 */
async function handleListCgEntities(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.entityType) queryParams.entityType = args.entityType;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/content-graph/entities${queryString}`);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyword-level observatory handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * handleKeywordSubresource -- shared handler for all keyword-level observatory tools.
 *
 * GET /api/seo/keyword-targets/:keywordTargetId/:subresource
 *
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleKeywordSubresource(
  args: Record<string, unknown>,
  apiClient: ApiClient,
  subresource: string
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  validateUuid(keywordTargetId, "keywordTargetId");

  const response = await apiClient.fetch(
    `/api/seo/keyword-targets/${keywordTargetId}/${subresource}`
  );
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

// ─────────────────────────────────────────────────────────────────────────────
// Project-level diagnostic handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * handleProjectDiagnostic -- compact project-level triage packet.
 *
 * Fans out three parallel API calls:
 *   GET /api/seo/volatility-summary
 *   GET /api/seo/volatility-alerts   (limit=5)
 *   GET /api/seo/risk-attribution-summary
 *
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleProjectDiagnostic(
  apiClient: ApiClient
): Promise<unknown> {
  const [summaryRes, alertsRes, riskRes] = await Promise.all([
    apiClient.fetch("/api/seo/volatility-summary"),
    apiClient.fetch("/api/seo/volatility-alerts?limit=5"),
    apiClient.fetch("/api/seo/risk-attribution-summary"),
  ]);

  if (!summaryRes.ok) await handleApiError(summaryRes);
  if (!alertsRes.ok)  await handleApiError(alertsRes);
  if (!riskRes.ok)    await handleApiError(riskRes);

  interface SummaryBody {
    data: {
      keywordCount:                   number;
      activeKeywordCount:             number;
      weightedProjectVolatilityScore: number;
      highVolatilityCount:            number;
      mediumVolatilityCount:          number;
      lowVolatilityCount:             number;
      stableCount:                    number;
      alertKeywordCount:              number;
      top3RiskKeywords:               unknown[];
    };
  }
  interface AlertsBody {
    data: {
      items: Array<{
        keywordTargetId: string;
        query:           string;
        volatilityScore: number;
        volatilityRegime: string;
        maturity:        string;
        rankVolatilityComponent:    number;
        aiOverviewComponent:        number;
        featureVolatilityComponent: number;
      }>;
    };
  }
  interface RiskBody {
    data: {
      buckets: Array<{
        rankShare:    number | null;
        aiShare:      number | null;
        featureShare: number | null;
      }>;
    };
  }

  const [summaryBody, alertsBody, riskBody] = await Promise.all([
    summaryRes.json() as Promise<SummaryBody>,
    alertsRes.json()  as Promise<AlertsBody>,
    riskRes.json()    as Promise<RiskBody>,
  ]);

  const s = summaryBody.data;
  const a = alertsBody.data;
  const r = riskBody.data;

  const lastActiveBucket = [...(r.buckets ?? [])]
    .reverse()
    .find((b) => b.rankShare !== null) ?? null;

  const packet = {
    projectVolatility: {
      keywordCount:                   s.keywordCount,
      activeKeywordCount:             s.activeKeywordCount,
      weightedProjectVolatilityScore: s.weightedProjectVolatilityScore,
      stabilityDistribution: {
        high:   s.highVolatilityCount,
        medium: s.mediumVolatilityCount,
        low:    s.lowVolatilityCount,
        stable: s.stableCount,
      },
    },
    alerts: {
      count:     s.alertKeywordCount,
      topAlerts: (a.items ?? []).map((item) => ({
        keywordTargetId: item.keywordTargetId,
        query:           item.query,
        volatilityScore: item.volatilityScore,
        severity:        item.volatilityRegime,
        maturity:        item.maturity,
      })),
    },
    riskAttribution: {
      top3RiskKeywords: s.top3RiskKeywords,
      rankPercent:    lastActiveBucket?.rankShare    ?? null,
      aiPercent:      lastActiveBucket?.aiShare      ?? null,
      featurePercent: lastActiveBucket?.featureShare ?? null,
    },
  };

  return formatToolResult(packet);
}

/**
 * handleTopVolatileKeywords -- compact triage list of highest-volatility keywords.
 *
 * GET /api/seo/volatility-alerts?limit=:limit
 *
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleTopVolatileKeywords(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const rawLimit = args.limit !== undefined ? Number(args.limit) : 10;
  if (!Number.isFinite(rawLimit) || rawLimit < 1 || rawLimit > 50) {
    throw new McpError(ErrorCode.InvalidParams, "limit must be between 1 and 50");
  }
  const limit = Math.floor(rawLimit);

  const response = await apiClient.fetch(`/api/seo/volatility-alerts?limit=${limit}`);
  if (!response.ok) await handleApiError(response);

  interface AlertsBody {
    data: {
      items: Array<{
        keywordTargetId:            string;
        query:                      string;
        volatilityScore:            number;
        volatilityRegime:           string;
        maturity:                   string;
        rankVolatilityComponent:    number;
        aiOverviewComponent:        number;
        featureVolatilityComponent: number;
      }>;
    };
  }

  const body = await response.json() as AlertsBody;
  const items = body.data?.items ?? [];

  const packet = {
    count:    items.length,
    keywords: items.map((item) => ({
      keywordTargetId:            item.keywordTargetId,
      query:                      item.query,
      volatilityScore:            item.volatilityScore,
      severity:                   item.volatilityRegime,
      maturity:                   item.maturity,
      rankVolatilityComponent:    item.rankVolatilityComponent,
      aiOverviewComponent:        item.aiOverviewComponent,
      featureVolatilityComponent: item.featureVolatilityComponent,
    })),
  };

  return formatToolResult(packet);
}

// ─────────────────────────────────────────────────────────────────────────────
// Composite diagnostic handler
// ─────────────────────────────────────────────────────────────────────────────

/**
 * handleKeywordDiagnostic -- composite diagnostic packet.
 *
 * Fans out three parallel API calls:
 *   GET /api/seo/keyword-targets/:id/overview
 *   GET /api/seo/keyword-targets/:id/event-timeline
 *   GET /api/seo/keyword-targets/:id/event-causality
 *
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleKeywordDiagnostic(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  validateUuid(keywordTargetId, "keywordTargetId");

  const base = `/api/seo/keyword-targets/${keywordTargetId}`;

  const [overviewRes, timelineRes, causalityRes] = await Promise.all([
    apiClient.fetch(`${base}/overview`),
    apiClient.fetch(`${base}/event-timeline`),
    apiClient.fetch(`${base}/event-causality`),
  ]);

  if (!overviewRes.ok)   await handleApiError(overviewRes);
  if (!timelineRes.ok)   await handleApiError(timelineRes);
  if (!causalityRes.ok)  await handleApiError(causalityRes);

  const [overviewBody, timelineBody, causalityBody] = await Promise.all([
    overviewRes.json()  as Promise<{ data: Record<string, unknown> }>,
    timelineRes.json()  as Promise<{ data: Record<string, unknown> }>,
    causalityRes.json() as Promise<{ data: Record<string, unknown> }>,
  ]);

  const o = overviewBody.data;
  const t = timelineBody.data;
  const c = causalityBody.data;

  const packet = {
    keywordTargetId,
    query:          o.query,
    locale:         o.locale,
    device:         o.device,
    snapshotCount:  o.snapshotCount,
    latestSnapshot: o.latestSnapshot,
    volatility:     o.volatility,
    classification: o.classification,
    timeline:       t.timeline,
    causality:      c.patterns,
  };

  return formatToolResult(packet);
}

// ─────────────────────────────────────────────────────────────────────────────
// Deep-dive keyword handlers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * handleSerpDelta: GET /api/seo/serp-deltas?keywordTargetId=:id
 *
 * Backend auto-selects the latest two snapshots. Project scoping via ApiClient headers.
 */
async function handleSerpDelta(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  validateUuid(keywordTargetId, "keywordTargetId");

  const response = await apiClient.fetch(
    `/api/seo/serp-deltas?keywordTargetId=${keywordTargetId}`
  );
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleOperatorInsight: GET /api/seo/operator-insight?keywordTargetId=:id
 *
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleOperatorInsight(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  validateUuid(keywordTargetId, "keywordTargetId");

  const response = await apiClient.fetch(
    `/api/seo/operator-insight?keywordTargetId=${keywordTargetId}`
  );
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleSpikeDelta -- composite: worst spike → SERP delta for that pair.
 *
 * Step 1: GET /api/seo/keyword-targets/:id/volatility-spikes?topN=1
 * Step 2: GET /api/seo/serp-deltas?keywordTargetId=:id&fromSnapshotId=:from&toSnapshotId=:to
 *
 * Project scoping via ApiClient headers. HTTP API only. Sequential by design.
 */
async function handleSpikeDelta(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  validateUuid(keywordTargetId, "keywordTargetId");

  const spikesRes = await apiClient.fetch(
    `/api/seo/keyword-targets/${keywordTargetId}/volatility-spikes?topN=1`
  );
  if (!spikesRes.ok) await handleApiError(spikesRes);

  interface SpikesBody {
    data: {
      sampleSize: number;
      spikes: Array<{
        fromSnapshotId: string;
        toSnapshotId:   string;
        [key: string]:  unknown;
      }>;
    };
  }

  const spikesBody = await spikesRes.json() as SpikesBody;
  const spikesData = spikesBody.data;

  if (!spikesData.spikes || spikesData.spikes.length === 0) {
    return formatToolResult({
      keywordTargetId,
      insufficient_snapshots: true,
      spike: null,
      delta: null,
    });
  }

  const topSpike = spikesData.spikes[0];
  const { fromSnapshotId, toSnapshotId } = topSpike;

  const deltaRes = await apiClient.fetch(
    `/api/seo/serp-deltas?keywordTargetId=${keywordTargetId}` +
    `&fromSnapshotId=${fromSnapshotId}&toSnapshotId=${toSnapshotId}`
  );
  if (!deltaRes.ok) await handleApiError(deltaRes);

  const deltaBody = await deltaRes.json() as { data: unknown };

  return formatToolResult({
    keywordTargetId,
    spike: topSpike,
    delta: deltaBody.data,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Project investigation composite handler
// ─────────────────────────────────────────────────────────────────────────────

/**
 * handleProjectInvestigation -- full project observatory briefing.
 *
 * Orchestration:
 *   Step 1 (parallel): volatility-summary, volatility-alerts, risk-attribution-summary,
 *                      operator-reasoning
 *   Step 2: maturity fallback if alerts empty
 *   Step 3 (parallel per keyword): overview + event-causality for top 3 by volatilityScore
 *
 * Project scoping via ApiClient headers. Read-only. HTTP API only.
 */
async function handleProjectInvestigation(
  apiClient: ApiClient
): Promise<unknown> {
  const [summaryRes, alertsRes, riskRes, reasoningRes] = await Promise.all([
    apiClient.fetch("/api/seo/volatility-summary"),
    apiClient.fetch("/api/seo/volatility-alerts?limit=10"),
    apiClient.fetch("/api/seo/risk-attribution-summary"),
    apiClient.fetch("/api/seo/operator-reasoning"),
  ]);

  if (!summaryRes.ok)   await handleApiError(summaryRes);
  if (!alertsRes.ok)    await handleApiError(alertsRes);
  if (!riskRes.ok)      await handleApiError(riskRes);
  if (!reasoningRes.ok) await handleApiError(reasoningRes);

  interface SummaryBody {
    data: {
      keywordCount:                   number;
      activeKeywordCount:             number;
      weightedProjectVolatilityScore: number;
      alertKeywordCount:              number;
      highVolatilityCount:            number;
      mediumVolatilityCount:          number;
      lowVolatilityCount:             number;
      stableCount:                    number;
    };
  }
  interface AlertItem {
    keywordTargetId:  string;
    query:            string;
    volatilityScore:  number;
    volatilityRegime: string;
    maturity?:        string;
  }
  interface AlertsBody {
    data: { items: AlertItem[] };
  }
  interface RiskBody {
    data: {
      buckets: Array<{
        rankShare:    number | null;
        aiShare:      number | null;
        featureShare: number | null;
      }>;
    };
  }

  const [summaryBody, alertsBody, riskBody, reasoningBody] = await Promise.all([
    summaryRes.json()   as Promise<SummaryBody>,
    alertsRes.json()    as Promise<AlertsBody>,
    riskRes.json()      as Promise<RiskBody>,
    reasoningRes.json() as Promise<unknown>,
  ]);

  const s = summaryBody.data;
  const r = riskBody.data;

  const lastActiveBucket = [...(r.buckets ?? [])]
    .reverse()
    .find((b) => b.rankShare !== null) ?? null;

  let alerts: AlertItem[] = alertsBody.data?.items ?? [];
  let alertsSource: "alerts" | "fallback" = "alerts";

  if (alerts.length === 0) {
    const fallbackRes = await apiClient.fetch(
      "/api/seo/volatility-alerts?limit=10&minMaturity=preliminary"
    );
    if (fallbackRes.ok) {
      const fallbackBody = await fallbackRes.json() as AlertsBody;
      const fallbackItems = fallbackBody.data?.items ?? [];
      if (fallbackItems.length > 0) {
        alerts = fallbackItems;
        alertsSource = "fallback";
      }
    }
  }

  const top3 = alerts.slice(0, 3);

  const investigations = await Promise.all(
    top3.map(async (item) => {
      const base = `/api/seo/keyword-targets/${item.keywordTargetId}`;
      const [overviewRes, causalityRes] = await Promise.all([
        apiClient.fetch(`${base}/overview`),
        apiClient.fetch(`${base}/event-causality`),
      ]);

      if (!overviewRes.ok)  await handleApiError(overviewRes);
      if (!causalityRes.ok) await handleApiError(causalityRes);

      const [overviewBody, causalityBody] = await Promise.all([
        overviewRes.json()  as Promise<{ data: unknown }>,
        causalityRes.json() as Promise<{ data: { patterns?: unknown[] } }>,
      ]);

      return {
        keywordTargetId: item.keywordTargetId,
        overview:        overviewBody.data,
        causality:       causalityBody.data?.patterns ?? [],
      };
    })
  );

  const concentrationRatio =
    s.keywordCount > 0 ? s.alertKeywordCount / s.keywordCount : 0;

  const packet = {
    project: {
      keywordCount:                   s.keywordCount,
      activeKeywordCount:             s.activeKeywordCount,
      weightedProjectVolatilityScore: s.weightedProjectVolatilityScore,
      volatilityConcentrationRatio:   Math.round(concentrationRatio * 10000) / 10000,
      riskAttribution: {
        rankPercent:    lastActiveBucket?.rankShare    ?? null,
        aiPercent:      lastActiveBucket?.aiShare      ?? null,
        featurePercent: lastActiveBucket?.featureShare ?? null,
      },
    },
    alertsSource,
    alerts: alerts.map((item) => ({
      keywordTargetId: item.keywordTargetId,
      query:           item.query,
      volatilityScore: item.volatilityScore,
      regime:          item.volatilityRegime,
      ...(alertsSource === "fallback" ? { maturity: item.maturity ?? "preliminary", source: "fallback" } : { source: "alerts" }),
    })),
    investigations,
    reasoning: (reasoningBody as { data?: unknown })?.data ?? reasoningBody,
  };

  return formatToolResult(packet);
}

// ─────────────────────────────────────────────────────────────────────────────
// Operator-level observatory handler
// ─────────────────────────────────────────────────────────────────────────────

/**
 * handleOperatorEndpoint -- shared handler for project-level operator tools.
 *
 * GET :path (no dynamic segments)
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleOperatorEndpoint(
  apiClient: ApiClient,
  path: string
): Promise<unknown> {
  const response = await apiClient.fetch(path);
  if (!response.ok) await handleApiError(response);
  const data = await response.json();
  return formatToolResult(data);
}
