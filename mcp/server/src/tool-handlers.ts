/**
 * Tool Call Handlers - VEDA Observatory and Search Intelligence
 *
 * Grounded by:
 * - docs/architecture/V_ECOSYSTEM.md
 * - docs/architecture/api/api-contract-principles.md
 * - docs/architecture/veda/search-intelligence-layer.md
 *
 * Maps MCP tool invocations to VEDA API endpoints and formats responses
 * with context-efficient results (structured + compact JSON text).
 *
 * Observatory-scoped and search-intelligence handlers only.
 * Entity/editorial handlers were removed during Wave 2D.
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

  // Map HTTP status codes to MCP error codes
  switch (response.status) {
    case 400:
      throw new McpError(ErrorCode.InvalidParams, backendMessage);
    case 401:
      throw new McpError(ErrorCode.InvalidRequest, backendMessage);
    case 403:
      throw new McpError(ErrorCode.InvalidRequest, backendMessage);
    case 404:
      // Preserve 404 non-disclosure: backend message is intentionally vague
      throw new McpError(ErrorCode.InternalError, backendMessage);
    case 409:
      throw new McpError(ErrorCode.InvalidRequest, backendMessage);
    default:
      // 5xx and other errors
      throw new McpError(ErrorCode.InternalError, backendMessage);
  }
}

/**
 * Format tool result with structured content + compact JSON text
 * (context-efficient per Anthropic guidance)
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
    case "list_projects":
      return handleListProjects(args, apiClient);
    case "list_search_performance":
      return handleListSearchPerformance(args, apiClient);
    // ── Keyword-level observatory tools ───────────────────────────────
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
    // ── Project-level diagnostic tools ───────────────────────────────
    case "get_project_diagnostic":
      return handleProjectDiagnostic(apiClient);
    case "get_top_volatile_keywords":
      return handleTopVolatileKeywords(args, apiClient);
    // ── Composite diagnostic tools ─────────────────────────────────
    case "get_keyword_diagnostic":
      return handleKeywordDiagnostic(args, apiClient);
    // ── Deep-dive keyword tools ─────────────────────────────────────────
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
    case "run_project_investigation":
      return handleProjectInvestigation(apiClient);
    // ── Operator-level observatory tools ─────────────────────────────
    case "get_operator_reasoning":
      return handleOperatorEndpoint(apiClient, "/api/seo/operator-reasoning");
    case "get_operator_briefing":
      return handleOperatorEndpoint(apiClient, "/api/seo/operator-briefing");
    case "get_risk_attribution_summary":
      return handleOperatorEndpoint(apiClient, "/api/seo/risk-attribution-summary");
    // ── Project bootstrap tools ─────────────────────────────────────────
    case "create_project":
      return handleCreateProject(args, apiClient);
    case "get_project":
      return handleGetProject(args, apiClient);
    // ── Proposal surface tools ────────────────────────────────────────────
    case "get_proposals":
      return handleGetProposals(apiClient);
    default:
      throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${toolName}`);
  }
}

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

  if (!response.ok) {
    await handleApiError(response);
  }

  const data = await response.json();
  return formatToolResult(data);
}

/**
 * list_search_performance: GET /api/seo/search-performance
 */
async function handleListSearchPerformance(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const { page, limit } = clampPagination(args);

  // Validate optional date parameters
  if (args.dateStart) {
    validateIsoDate(args.dateStart as string, "dateStart");
  }
  if (args.dateEnd) {
    validateIsoDate(args.dateEnd as string, "dateEnd");
  }

  const queryParams: Record<string, unknown> = { page, limit };
  if (args.query) queryParams.query = args.query;
  if (args.pageUrl) queryParams.pageUrl = args.pageUrl;
  if (args.dateStart) queryParams.dateStart = args.dateStart;
  if (args.dateEnd) queryParams.dateEnd = args.dateEnd;

  const queryString = buildQueryString(queryParams);
  const response = await apiClient.fetch(`/api/seo/search-performance${queryString}`);

  if (!response.ok) {
    await handleApiError(response);
  }

  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleKeywordSubresource -- shared handler for all keyword-level observatory tools.
 *
 * GET /api/seo/keyword-targets/:keywordTargetId/:subresource
 *
 * Validates keywordTargetId UUID, then calls the backend subresource endpoint.
 * Project scoping is handled entirely by the ApiClient headers — never by the caller.
 */
async function handleKeywordSubresource(
  args: Record<string, unknown>,
  apiClient: ApiClient,
  subresource: string
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) {
    throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  }

  validateUuid(keywordTargetId, "keywordTargetId");

  const response = await apiClient.fetch(
    `/api/seo/keyword-targets/${keywordTargetId}/${subresource}`
  );

  if (!response.ok) {
    await handleApiError(response);
  }

  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleProjectDiagnostic -- compact project-level triage packet.
 *
 * Fans out three parallel API calls:
 *   GET /api/seo/volatility-summary
 *   GET /api/seo/volatility-alerts   (limit=5 — top alerts only)
 *   GET /api/seo/risk-attribution-summary
 *
 * Assembles a compact operator packet:
 *   projectVolatility  — overall score, counts, distribution
 *   alerts             — count of keywords in alert + top 5 items
 *   riskAttribution    — top3 risk keywords + rank/ai/feature percentages
 *                        from the most recent non-null bucket
 *
 * Project scoping is handled entirely by ApiClient headers.
 * No DB access. HTTP API only.
 */
async function handleProjectDiagnostic(
  apiClient: ApiClient
): Promise<unknown> {
  // Fan out in parallel — three independent reads
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

  // Pick the last bucket that has non-null attribution shares (most recent)
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
 * create_project: POST /api/projects
 *
 * Creates a new VEDA project container. No project scoping header required.
 * Returns the created project record.
 */
async function handleCreateProject(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const name = args.name as string;
  if (!name) {
    throw new McpError(ErrorCode.InvalidParams, "name is required");
  }

  const body: Record<string, unknown> = { name };
  if (args.slug) body.slug = args.slug;
  if (args.description) body.description = args.description;

  const response = await apiClient.fetch("/api/projects", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    await handleApiError(response);
  }

  const data = await response.json();
  return formatToolResult(data);
}

/**
 * get_project: GET /api/projects/:id
 *
 * Retrieves a single project by ID. No project scoping header required.
 */
async function handleGetProject(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const projectId = args.projectId as string;
  if (!projectId) {
    throw new McpError(ErrorCode.InvalidParams, "projectId is required");
  }
  validateUuid(projectId, "projectId");

  const response = await apiClient.fetch(`/api/projects/${projectId}`);

  if (!response.ok) {
    await handleApiError(response);
  }

  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleTopVolatileKeywords -- compact triage list of highest-volatility keywords.
 *
 * Calls:
 *   GET /api/seo/volatility-alerts?limit=:limit
 *
 * The alerts endpoint natively supports `limit` (1–50) and sorts by
 * volatilityScore DESC, query ASC, keywordTargetId ASC — no client-side
 * sorting required.
 *
 * Each item in the response already carries volatilityRegime (severity label).
 * `classification` is NOT present on this endpoint — omitted per spec.
 *
 * Project scoping is handled entirely by ApiClient headers.
 * No DB access. HTTP API only.
 */
async function handleTopVolatileKeywords(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  // Clamp limit: default 10, min 1, max 50 (alerts endpoint ceiling)
  const rawLimit = args.limit !== undefined ? Number(args.limit) : 10;
  if (!Number.isFinite(rawLimit) || rawLimit < 1 || rawLimit > 50) {
    throw new McpError(ErrorCode.InvalidParams, "limit must be between 1 and 50");
  }
  const limit = Math.floor(rawLimit);

  const response = await apiClient.fetch(
    `/api/seo/volatility-alerts?limit=${limit}`
  );

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

/**
 * handleKeywordDiagnostic -- composite diagnostic packet.
 *
 * Fans out three parallel API calls:
 *   GET /api/seo/keyword-targets/:id/overview
 *   GET /api/seo/keyword-targets/:id/event-timeline
 *   GET /api/seo/keyword-targets/:id/event-causality
 *
 * Assembles a compact operator packet from the results:
 *   - overview.data.latestSnapshot     (point-in-time summary)
 *   - overview.data.volatility         (score, regime, maturity)
 *   - overview.data.classification     (label + confidence)
 *   - timeline.data.timeline           (event stream)
 *   - causality.data.patterns          (causal transitions)
 *
 * Fails fast if any fetch returns a non-OK status.
 * Project scoping is handled entirely by ApiClient headers.
 */
async function handleKeywordDiagnostic(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) {
    throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  }
  validateUuid(keywordTargetId, "keywordTargetId");

  const base = `/api/seo/keyword-targets/${keywordTargetId}`;

  // Fan out in parallel — three independent reads
  const [overviewRes, timelineRes, causalityRes] = await Promise.all([
    apiClient.fetch(`${base}/overview`),
    apiClient.fetch(`${base}/event-timeline`),
    apiClient.fetch(`${base}/event-causality`),
  ]);

  // Fail fast on any non-OK response
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

  // Compact packet — only what an operator needs for fast triage
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

/**
 * handleSerpDelta -- GET /api/seo/serp-deltas?keywordTargetId=:id
 *
 * Backend auto-selects the latest two snapshots when no snapshot IDs are
 * supplied. Returns moved/entered/exited URL sets + AI Overview state change.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleSerpDelta(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) {
    throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  }
  validateUuid(keywordTargetId, "keywordTargetId");

  const response = await apiClient.fetch(
    `/api/seo/serp-deltas?keywordTargetId=${keywordTargetId}`
  );

  if (!response.ok) await handleApiError(response);

  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleOperatorInsight -- GET /api/seo/operator-insight?keywordTargetId=:id
 *
 * Returns synthesized insight: regime, maturity, dominant risk driver,
 * spike evidence, feature transition count, and structured recommendation.
 * Project scoping via ApiClient headers. HTTP API only.
 */
async function handleOperatorInsight(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) {
    throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  }
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
 *         Extract fromSnapshotId + toSnapshotId from the top spike.
 * Step 2: GET /api/seo/serp-deltas?keywordTargetId=:id&fromSnapshotId=:from&toSnapshotId=:to
 *
 * Returns { keywordTargetId, spike, delta }.
 * If sampleSize < 2 (no spikes), returns { keywordTargetId, spike: null, delta: null,
 * insufficient_snapshots: true } without erroring.
 *
 * Project scoping via ApiClient headers. HTTP API only. Sequential by design
 * (step 2 depends on step 1 output).
 */
async function handleSpikeDelta(
  args: Record<string, unknown>,
  apiClient: ApiClient
): Promise<unknown> {
  const keywordTargetId = args.keywordTargetId as string;
  if (!keywordTargetId) {
    throw new McpError(ErrorCode.InvalidParams, "keywordTargetId is required");
  }
  validateUuid(keywordTargetId, "keywordTargetId");

  // Step 1: fetch the single worst spike
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

  // No pairs available — return gracefully without error
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

  // Step 2: fetch the SERP delta for that exact pair
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

/**
 * get_proposals: GET /api/veda-brain/proposals
 *
 * Returns Phase C1 SERP-to-Content-Graph proposals for the active project.
 * Project scoping is handled entirely by ApiClient headers.
 * Read-only. No arguments required.
 */
async function handleGetProposals(
  apiClient: ApiClient
): Promise<unknown> {
  const response = await apiClient.fetch("/api/veda-brain/proposals");

  if (!response.ok) {
    await handleApiError(response);
  }

  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleOperatorEndpoint -- shared handler for project-level operator tools.
 *
 * GET :path (no dynamic segments)
 *
 * Project scoping is handled entirely by the ApiClient headers.
 */
async function handleOperatorEndpoint(
  apiClient: ApiClient,
  path: string
): Promise<unknown> {
  const response = await apiClient.fetch(path);

  if (!response.ok) {
    await handleApiError(response);
  }

  const data = await response.json();
  return formatToolResult(data);
}

/**
 * handleProjectInvestigation -- full project observatory briefing.
 *
 * Orchestration sequence:
 *   Step 1 (parallel): GET /api/seo/project-diagnostic
 *                      GET /api/seo/volatility-alerts?limit=10
 *                      GET /api/seo/operator-reasoning
 *   Step 2: Select top 3 keywords by volatilityScore from alerts.
 *   Step 3 (parallel per keyword):
 *                      GET /api/seo/keyword-targets/:id/overview
 *                      GET /api/seo/keyword-targets/:id/event-causality
 *
 * Returns a compact investigation packet:
 *   project        -- keywordCount, activeKeywordCount, weightedProjectVolatilityScore,
 *                     volatilityConcentrationRatio
 *   alerts         -- top 10 alert keywords (keywordTargetId, query, volatilityScore, regime)
 *   investigations -- per-keyword overview + causality for top 3
 *   reasoning      -- operator reasoning output
 *
 * Read-only. No DB access. HTTP API only.
 * Project scoping is handled entirely by ApiClient headers.
 */
async function handleProjectInvestigation(
  apiClient: ApiClient
): Promise<unknown> {
  // Step 1: parallel fan-out — mirror the same backend routes used by
  // handleProjectDiagnostic. /api/seo/project-diagnostic does not exist as
  // a backend route; it is an MCP composite only.
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

  const s      = summaryBody.data;
  const r      = riskBody.data;

  // Pick the last bucket with non-null shares (most recent) — same logic as
  // handleProjectDiagnostic.
  const lastActiveBucket = [...(r.buckets ?? [])]
    .reverse()
    .find((b) => b.rankShare !== null) ?? null;

  // Step 2: Resolve alert list — with maturity fallback.
  //
  // The alerts endpoint defaults to minMaturity=developing. In early projects
  // many keywords are still "preliminary" (insufficient snapshots to graduate).
  // When the primary call returns empty, fall back to
  // volatility-alerts?minMaturity=preliminary to surface those keywords instead
  // of leaving the investigation packet empty. The fallback result is marked
  // source:"fallback" so the operator understands why maturity-gated alerts
  // are absent but volatile keywords are still listed.
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
    // If fallback also fails or is empty, alerts stays [] and alertsSource stays "alerts".
  }

  // Step 3: select top 3 by volatilityScore (already sorted DESC by backend)
  const top3 = alerts.slice(0, 3);

  // Step 3: parallel per-keyword deep-dive
  const investigations = await Promise.all(
    top3.map(async (item) => {
      const base = `/api/seo/keyword-targets/${item.keywordTargetId}`;
      const [overviewRes, causalityRes] = await Promise.all([
        apiClient.fetch(`${base}/overview`),
        apiClient.fetch(`${base}/event-causality`),
      ]);

      // Per-keyword errors are surfaced individually, not silently swallowed.
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

  // volatilityConcentrationRatio: fraction of alert keywords vs total keywords.
  // Measures how concentrated risk is. 0 = no alerts, 1 = all keywords in alert.
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

