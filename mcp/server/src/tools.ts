/**
 * MCP Tool Definitions - VEDA Observatory and Search Intelligence
 *
 * Grounded by:
 * - `docs/architecture/V_ECOSYSTEM.md`
 * - `docs/architecture/api/api-contract-principles.md`
 * - `docs/architecture/veda/search-intelligence-layer.md`
 *
 * Observatory-scoped and search-intelligence tools.
 * Entity/editorial tools were removed during Wave 2D.
 */

export const toolDefinitions = [
  {
    name: "list_projects",
    description:
      "List all projects accessible to the current user. Returns projects in alphabetical order by slug.",
    inputSchema: {
      type: "object",
      properties: {
        page: {
          type: "number",
          description: "Page number (1-indexed, default 1, min 1)",
          minimum: 1,
        },
        limit: {
          type: "number",
          description: "Results per page (default 20, min 1, max 100)",
          minimum: 1,
          maximum: 100,
        },
      },
      additionalProperties: false,
    },
  },
  {
    name: "list_search_performance",
    description:
      "List Google Search Console performance records for the project. Returns records ordered by date descending, then by query and page URL.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Filter by search query (case-insensitive substring match)",
        },
        pageUrl: {
          type: "string",
          description: "Filter by page URL (case-insensitive substring match)",
        },
        dateStart: {
          type: "string",
          description: "Filter by date range start (ISO 8601: YYYY-MM-DD or YYYY-MM-DDTHH:mm:ssZ)",
        },
        dateEnd: {
          type: "string",
          description: "Filter by date range end (ISO 8601: YYYY-MM-DD or YYYY-MM-DDTHH:mm:ssZ)",
        },
        page: {
          type: "number",
          description: "Page number (1-indexed, default 1)",
          minimum: 1,
        },
        limit: {
          type: "number",
          description: "Results per page (default 20, max 100)",
          minimum: 1,
          maximum: 100,
        },
      },
      additionalProperties: false,
    },
  },
  // ── Keyword-level observatory tools ───────────────────────────────────────
  {
    name: "get_keyword_overview",
    description:
      "Returns a composite SIL-15 overview for a keyword target: volatility, classification, timeline, causality, intent drift, feature volatility, domain dominance, and SERP similarity — all in one payload.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_keyword_volatility",
    description:
      "Returns the volatility profile for a keyword target: score (0–100), regime, maturity, and SIL-7 attribution components (rank, AI overview, feature volatility).",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_change_classification",
    description:
      "Returns the SIL-12 change classification for a keyword target: label (algorithm_shift, competitor_surge, intent_shift, feature_turbulence, ai_overview_disruption, or stable), confidence score, and contributing signals.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_event_timeline",
    description:
      "Returns the SIL-13 event timeline for a keyword target: a minimal ordered stream of SERP classification transitions (only emits on classification changes).",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_event_causality",
    description:
      "Returns the SIL-14 event causality patterns for a keyword target: recognized adjacent event transition pairs (e.g. feature_turbulence → algorithm_shift).",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_intent_drift",
    description:
      "Returns intent drift analysis for a keyword target: per-snapshot intent distributions and transitions between dominant intent buckets (informational, video, transactional, local, news).",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_feature_volatility",
    description:
      "Returns SERP feature volatility for a keyword target: transitions in feature family presence (featured snippet, PAA, local pack, etc.) and a ranked summary of the most volatile features.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_domain_dominance",
    description:
      "Returns domain dominance analysis for a keyword target: which domains dominate the latest SERP snapshot, top domains by result count, and the dominance index.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_serp_similarity",
    description:
      "Returns SERP structural similarity analysis for a keyword target: consecutive-pair Jaccard similarity scores on domain sets and feature family sets.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  // ── Project-level diagnostic tools ────────────────────────────────────────
  {
    name: "get_project_diagnostic",
    description:
      "Compact project-level diagnostic packet. Fans out in parallel to volatility-summary, volatility-alerts, and risk-attribution-summary, then assembles a single operator-facing triage view: overall project volatility score, stability distribution, top alert keywords, and risk attribution percentages (rank vs AI overview vs feature). Use this as the first tool when diagnosing the health of a project.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: "get_top_volatile_keywords",
    description:
      "Returns a compact triage list of the most volatile keywords in the project, sorted by volatility score descending. Calls the volatility-alerts endpoint and trims to the requested limit. Each entry includes keywordTargetId, query, volatility score, severity (regime label), and attribution components. Use this when you need a ranked list for triage without the full project diagnostic.",
    inputSchema: {
      type: "object",
      properties: {
        limit: {
          type: "number",
          description: "Maximum number of keywords to return (default 10, min 1, max 50)",
          minimum: 1,
          maximum: 50,
        },
      },
      additionalProperties: false,
    },
  },
  // ── Composite diagnostic tools ──────────────────────────────────────────
  {
    name: "get_keyword_diagnostic",
    description:
      "Compact operator diagnostic for a single keyword target. Fans out to overview, event timeline, and event causality in parallel and returns a single merged packet. Use this instead of calling those three tools individually to reduce tool chatter and token usage.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  // ── Deep-dive keyword tools ────────────────────────────────────────────────
  {
    name: "get_serp_delta",
    description:
      "Returns the rank delta between the two most recent SERP snapshots for a keyword target: which URLs moved, entered, or exited the SERP, rank changes per URL, and AI Overview state change. The backend auto-selects the latest two snapshots — no snapshot IDs required.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_volatility_breakdown",
    description:
      "Returns which specific URLs are driving rank volatility for a keyword target. Each URL is scored by total absolute rank shift and average shift across consecutive snapshot pairs. Sorted by totalAbsShift descending — the top entry is the single biggest contributor to rank instability.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_volatility_spikes",
    description:
      "Returns the top-N highest-volatility consecutive snapshot pairs ('spikes') for a keyword target. Each spike includes pairVolatilityScore, rank shift magnitude, feature change count, and whether AI Overview flipped. Use this to pinpoint *when* disruption happened before calling get_serp_delta or get_spike_delta.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_operator_insight",
    description:
      "Returns a synthesized operator insight for a single keyword target: volatility regime, maturity, dominant risk driver, spike evidence, feature transition count, and a structured recommendation. This is the closest to a pre-reasoned narrative assessment the system produces for a keyword.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  {
    name: "get_spike_delta",
    description:
      "Composite tool: finds the single worst volatility spike for a keyword target, then fetches the full SERP rank delta for that exact snapshot pair. Returns the spike metadata and the moved/entered/exited URL diff in one call. Use this instead of calling get_volatility_spikes + get_serp_delta separately.",
    inputSchema: {
      type: "object",
      properties: {
        keywordTargetId: {
          type: "string",
          description: "KeywordTarget UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["keywordTargetId"],
      additionalProperties: false,
    },
  },
  // ── Project investigation composite tool ──────────────────────────────────
  {
    name: "run_project_investigation",
    description:
      "Run a full VEDA project investigation and return a structured observatory briefing. " +
      "Orchestrates project diagnostic, volatility alerts, per-keyword overview and causality, " +
      "and operator reasoning into a single compact packet. Read-only. " +
      "Response field alertsSource indicates the alert data origin: " +
      "\"alerts\" = volatility-alerts endpoint returned mature results; " +
      "\"fallback\" = no mature alerts found, preliminary-maturity volatile keywords used instead. " +
      "Fallback alert items include maturity and source fields; primary items include source: \"alerts\".",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  // ── Operator-level observatory tools ─────────────────────────────────────
  {
    name: "get_operator_reasoning",
    description:
      "Returns operator reasoning output for the project: synthesized SEO intelligence derived from SERP signals, volatility, and classification data.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: "get_operator_briefing",
    description:
      "Returns the operator briefing for the project: a structured summary of current SEO state, top risks, and recommended focus areas.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: "get_risk_attribution_summary",
    description:
      "Returns the risk attribution summary for the project: ranked breakdown of volatility contributors and risk signals across all monitored keywords.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  // ── Project bootstrap tools ──────────────────────────────────────────────
  {
    name: "create_project",
    description:
      "Create a new VEDA project container. Returns the created project record. The project starts in 'created' lifecycle state. Slug is auto-derived from name if not provided.",
    inputSchema: {
      type: "object",
      properties: {
        name: {
          type: "string",
          description: "Project name (1-200 characters)",
          minLength: 1,
          maxLength: 200,
        },
        slug: {
          type: "string",
          description:
            "URL-safe slug (optional, auto-derived from name if omitted). Lowercase alphanumeric with hyphens.",
          minLength: 2,
          maxLength: 100,
        },
        description: {
          type: "string",
          description: "Optional project description (max 2000 characters)",
          maxLength: 2000,
        },
      },
      required: ["name"],
      additionalProperties: false,
    },
  },
  {
    name: "get_project",
    description:
      "Retrieve a single project by ID with full details including lifecycleState.",
    inputSchema: {
      type: "object",
      properties: {
        projectId: {
          type: "string",
          description: "Project UUID",
          pattern:
            "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
      },
      required: ["projectId"],
      additionalProperties: false,
    },
  },
  // ── Proposal surface tools ────────────────────────────────────────────────
  {
    name: "get_proposals",
    description:
      "Returns Phase C1 SERP-to-Content-Graph proposals for the active project: archetype alignment proposals and schema gap proposals. Each proposal is evidence-backed, deterministic, and read-only. Returns archetypeProposals, schemaProposals, and summary counts.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
] as const;
