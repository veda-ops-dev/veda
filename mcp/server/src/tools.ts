/**
 * MCP Tool Definitions - VEDA Observatory and Search Intelligence
 *
 * Grounded by:
 * - `docs/architecture/V_ECOSYSTEM.md`
 * - `docs/architecture/api/api-contract-principles.md`
 * - `docs/architecture/veda/search-intelligence-layer.md`
 * - `docs/systems/operator-surfaces/mcp/overview.md`
 * - `docs/systems/operator-surfaces/mcp/tooling-principles.md`
 *
 * Active tool registry: docs/systems/operator-surfaces/mcp/tool-registry.md
 *
 * Rules:
 * - All tools are HTTP/API-only. No DB access. No Prisma.
 * - Project scoping is enforced via ApiClient headers.
 * - Write tools are explicit, annotated with "WRITE —", and mutate canonical state.
 * - No blueprint, draft, editorial, publishing, or execution workflow tools.
 * - No speculative tools for routes that do not currently exist.
 */

export const toolDefinitions = [
  // ── Project bootstrap tools ──────────────────────────────────────────────
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
  {
    name: "create_project",
    description:
      "WRITE — Create a new VEDA project container. Returns the created project record. The project starts in 'created' lifecycle state. Slug is auto-derived from name if not provided.",
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
  // ── Search performance tools ─────────────────────────────────────────────
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
  // ── Source item tools ────────────────────────────────────────────────────
  {
    name: "list_source_items",
    description:
      "List SourceItems for the active project. Supports filtering by status, sourceType, and platform. Returns items ordered by createdAt descending.",
    inputSchema: {
      type: "object",
      properties: {
        status: {
          type: "string",
          description: "Filter by item status (e.g. ingested, processed, skipped)",
        },
        sourceType: {
          type: "string",
          description: "Filter by source type (e.g. article, video, podcast)",
        },
        platform: {
          type: "string",
          description: "Filter by platform (e.g. youtube, twitter, other)",
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
  {
    name: "capture_source_item",
    description:
      "WRITE — Capture a new SourceItem URL for the active project, or re-capture an existing one. New captures are created with status=ingested and a SOURCE_CAPTURED event is logged. Recaptures also log SOURCE_CAPTURED and optionally append notes. Requires explicit project scope.",
    inputSchema: {
      type: "object",
      properties: {
        sourceType: {
          type: "string",
          description: "Source type (e.g. article, video, podcast)",
        },
        url: {
          type: "string",
          description: "URL of the source item",
        },
        operatorIntent: {
          type: "string",
          description: "Brief description of why this source is being captured",
        },
        platform: {
          type: "string",
          description: "Platform (optional, defaults to 'other')",
        },
        notes: {
          type: "string",
          description: "Optional operator notes",
        },
      },
      required: ["sourceType", "url", "operatorIntent"],
      additionalProperties: false,
    },
  },
  // ── Event log tools ──────────────────────────────────────────────────────
  {
    name: "list_events",
    description:
      "List EventLog entries for the active project. Supports filtering by eventType, entityType, entityId, actor, and timestamp range. Returns events ordered by timestamp descending.",
    inputSchema: {
      type: "object",
      properties: {
        eventType: {
          type: "string",
          description: "Filter by event type (must be a valid EventType enum value)",
        },
        entityType: {
          type: "string",
          description: "Filter by entity type (must be a valid EntityType enum value)",
        },
        entityId: {
          type: "string",
          description: "Filter by entity UUID",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        actor: {
          type: "string",
          description: "Filter by actor type (must be a valid ActorType enum value)",
        },
        after: {
          type: "string",
          description: "Return events after this ISO 8601 timestamp",
        },
        before: {
          type: "string",
          description: "Return events before this ISO 8601 timestamp",
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
  // ── VEDA Brain tools ─────────────────────────────────────────────────────
  {
    name: "get_veda_brain_diagnostics",
    description:
      "Returns compute-on-read VEDA Brain Phase 1 diagnostics for the active project. Includes content graph health signals, coverage gaps, and alignment assessments. Read-only.",
    inputSchema: {
      type: "object",
      properties: {},
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
  // ── Content Graph read tools ─────────────────────────────────────────────
  {
    name: "get_content_graph_diagnostics",
    description:
      "Returns compute-on-read Content Graph intelligence signals for the active project. Includes structural coverage, linking health, and schema usage signals. Read-only.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: "list_cg_surfaces",
    description:
      "List Content Graph surfaces for the active project. A surface represents an owned or observed publishing channel (e.g. a website, YouTube channel). Returns surfaces ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
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
  {
    name: "list_cg_sites",
    description:
      "List Content Graph sites for the active project. A site represents a domain within a surface. Returns sites ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
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
  {
    name: "list_cg_pages",
    description:
      "List Content Graph pages for the active project. Optionally filter by siteId. Returns pages ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
        siteId: {
          type: "string",
          description: "Filter by site UUID (optional)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
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
  {
    name: "list_cg_topics",
    description:
      "List Content Graph topics for the active project. Returns topics ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
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
  {
    name: "list_cg_entities",
    description:
      "List Content Graph entities for the active project. Optionally filter by entityType. Returns entities ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
        entityType: {
          type: "string",
          description: "Filter by entity type (optional)",
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
  {
    name: "list_cg_archetypes",
    description:
      "List Content Graph content archetypes for the active project. Returns archetypes ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
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
  {
    name: "list_cg_internal_links",
    description:
      "List Content Graph internal links for the active project. Optionally filter by sourcePageId or targetPageId. Returns links ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
        sourcePageId: {
          type: "string",
          description: "Filter by source page UUID (optional)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        targetPageId: {
          type: "string",
          description: "Filter by target page UUID (optional)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
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
  {
    name: "list_cg_page_topics",
    description:
      "List Content Graph page-topic registrations for the active project. Optionally filter by pageId or topicId. Returns registrations ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
        pageId: {
          type: "string",
          description: "Filter by page UUID (optional)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        topicId: {
          type: "string",
          description: "Filter by topic UUID (optional)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
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
  {
    name: "list_cg_page_entities",
    description:
      "List Content Graph page-entity registrations for the active project. Optionally filter by pageId or entityId. Returns registrations ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
        pageId: {
          type: "string",
          description: "Filter by page UUID (optional)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        entityId: {
          type: "string",
          description: "Filter by entity UUID (optional)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
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
  {
    name: "list_cg_schema_usage",
    description:
      "List Content Graph schema usages for the active project. Optionally filter by pageId or schemaType. Returns usages ordered by createdAt ascending.",
    inputSchema: {
      type: "object",
      properties: {
        pageId: {
          type: "string",
          description: "Filter by page UUID (optional)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        schemaType: {
          type: "string",
          description: "Filter by schema type string (optional)",
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
  // ── Content Graph write tools ────────────────────────────────────────────
  {
    name: "create_cg_surface",
    description:
      "WRITE — Register a new Content Graph surface for the active project. A surface represents an owned or observed publishing channel. Supported types are website, wiki, blog, x, and youtube. Key is canonicalized to lowercase-hyphen form. Logs CG_SURFACE_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        type: {
          type: "string",
          description: "Surface type",
          enum: ["website", "wiki", "blog", "x", "youtube"],
        },
        key: {
          type: "string",
          description: "Operator key for this surface (canonicalized to lowercase-hyphen; must be unique within project)",
        },
        label: {
          type: "string",
          description: "Human-readable label (optional)",
        },
        canonicalIdentifier: {
          type: "string",
          description: "Canonical external identifier, e.g. normalized host, YouTube channel ID, or X handle (optional; must be unique per type within project if provided)",
        },
        canonicalUrl: {
          type: "string",
          description: "Canonical URL for the surface (optional; must be a valid URL)",
        },
        enabled: {
          type: "boolean",
          description: "Whether the surface is enabled (default true)",
        },
      },
      required: ["type", "key"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cg_site",
    description:
      "WRITE — Register a new Content Graph site (domain) within an existing surface for the active project. The surface must exist and be enabled. Disabled surfaces reject new sites. Domain must be unique within project. Logs CG_SITE_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        surfaceId: {
          type: "string",
          description: "Surface UUID (must belong to the active project and be enabled)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        domain: {
          type: "string",
          description: "Domain for this site (must be unique within project)",
          minLength: 1,
          maxLength: 255,
        },
        framework: {
          type: "string",
          description: "Framework or CMS (optional, e.g. nextjs, wordpress)",
        },
        isCanonical: {
          type: "boolean",
          description: "Whether this is the canonical site for the surface (default true)",
        },
        notes: {
          type: "string",
          description: "Optional operator notes",
        },
      },
      required: ["surfaceId", "domain"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cg_page",
    description:
      "WRITE — Register a new Content Graph page within an existing site for the active project. URL must be unique within project. Optionally assign a content archetype. Logs CG_PAGE_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        siteId: {
          type: "string",
          description: "Site UUID (must belong to the active project)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        url: {
          type: "string",
          description: "Page URL (must be unique within project)",
        },
        title: {
          type: "string",
          description: "Page title",
        },
        contentArchetypeId: {
          type: "string",
          description: "Content archetype UUID (optional; must belong to the active project)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        canonicalUrl: {
          type: "string",
          description: "Canonical URL if different from url (optional)",
        },
        publishingState: {
          type: "string",
          description: "Publishing state (optional, default 'draft')",
          enum: ["draft", "published", "archived"],
        },
        isIndexable: {
          type: "boolean",
          description: "Whether the page is indexable (default true)",
        },
      },
      required: ["siteId", "url", "title"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cg_topic",
    description:
      "WRITE — Register a new Content Graph topic for the active project. Key must be unique within project. Logs CG_TOPIC_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        key: {
          type: "string",
          description: "Unique topic key within project",
        },
        label: {
          type: "string",
          description: "Human-readable label for the topic",
        },
      },
      required: ["key", "label"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cg_entity",
    description:
      "WRITE — Register a new Content Graph entity (product, technology, concept, org, etc.) for the active project. Key must be unique within project. Logs CG_ENTITY_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        key: {
          type: "string",
          description: "Unique entity key within project",
          minLength: 1,
          maxLength: 100,
        },
        label: {
          type: "string",
          description: "Human-readable label for the entity",
          minLength: 1,
        },
        entityType: {
          type: "string",
          description: "Entity type (e.g. product, technology, concept, organization)",
          minLength: 1,
          maxLength: 100,
        },
      },
      required: ["key", "label", "entityType"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cg_archetype",
    description:
      "WRITE — Register a new Content Graph content archetype for the active project. Key must be unique within project. Logs CG_ARCHETYPE_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        key: {
          type: "string",
          description: "Unique archetype key within project",
        },
        label: {
          type: "string",
          description: "Human-readable label for the archetype",
        },
      },
      required: ["key", "label"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cg_internal_link",
    description:
      "WRITE — Register a new Content Graph internal link between two pages in the active project. Both pages must belong to the active project. The pair must not already be linked. Logs CG_INTERNAL_LINK_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        sourcePageId: {
          type: "string",
          description: "Source page UUID (must belong to the active project)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        targetPageId: {
          type: "string",
          description: "Target page UUID (must belong to the active project; must differ from sourcePageId)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        anchorText: {
          type: "string",
          description: "Anchor text for the link (optional)",
        },
        linkRole: {
          type: "string",
          description: "Link role (optional, default 'support')",
          enum: ["hub", "support", "navigation"],
        },
      },
      required: ["sourcePageId", "targetPageId"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cg_page_topic",
    description:
      "WRITE — Register a topic on a page in the active project. Both page and topic must belong to the active project. The pairing must not already exist. Logs CG_PAGE_TOPIC_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        pageId: {
          type: "string",
          description: "Page UUID (must belong to the active project)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        topicId: {
          type: "string",
          description: "Topic UUID (must belong to the active project)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        role: {
          type: "string",
          description: "Topic role on this page (optional, default 'supporting')",
          enum: ["primary", "supporting", "reviewed", "compared", "navigation"],
        },
      },
      required: ["pageId", "topicId"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cg_page_entity",
    description:
      "WRITE — Register an entity on a page in the active project. Both page and entity must belong to the active project. The pairing must not already exist. Logs CG_PAGE_ENTITY_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        pageId: {
          type: "string",
          description: "Page UUID (must belong to the active project)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        entityId: {
          type: "string",
          description: "Entity UUID (must belong to the active project)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        role: {
          type: "string",
          description: "Entity role on this page (optional, default 'supporting')",
          enum: ["primary", "supporting", "reviewed", "compared", "navigation"],
        },
      },
      required: ["pageId", "entityId"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cg_schema_usage",
    description:
      "WRITE — Register a schema type on a page in the active project. The page must belong to the active project. The page+schemaType pairing must not already exist. Logs CG_SCHEMA_USAGE_CREATED event.",
    inputSchema: {
      type: "object",
      properties: {
        pageId: {
          type: "string",
          description: "Page UUID (must belong to the active project)",
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        },
        schemaType: {
          type: "string",
          description: "Schema.org type string (e.g. Article, FAQPage, HowTo)",
        },
        isPrimary: {
          type: "boolean",
          description: "Whether this is the primary schema type for the page (default false)",
        },
      },
      required: ["pageId", "schemaType"],
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
] as const;
