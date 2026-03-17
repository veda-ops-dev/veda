/**
 * Configuration and API Client
 *
 * Validates environment variables and creates HTTP client
 * with project scoping headers.
 *
 * Env var preference order (VEDA_* first, PSYMETRIC_* fallback):
 *   VEDA_BASE_URL         ?? PSYMETRIC_BASE_URL
 *   VEDA_PROJECT_ID       ?? PSYMETRIC_PROJECT_ID
 *   VEDA_PROJECT_SLUG     ?? PSYMETRIC_PROJECT_SLUG
 *   VEDA_TIMEOUT_MS       ?? PSYMETRIC_TIMEOUT_MS
 */

export interface ServerConfig {
  baseUrl: string;
  projectScope: {
    type: "id" | "slug";
    value: string;
  };
  timeoutMs: number;
}

export interface ApiClient {
  fetch: (path: string, init?: RequestInit) => Promise<Response>;
  config: ServerConfig;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Validate required environment variables.
 * Exits process if configuration is invalid (fail fast).
 *
 * Reads VEDA_* first; falls back to PSYMETRIC_* for backward compatibility.
 */
export function validateConfig(): ServerConfig {
  const baseUrl =
    process.env.VEDA_BASE_URL ??
    process.env.PSYMETRIC_BASE_URL;

  if (!baseUrl) {
    console.error("[VEDA MCP] FATAL: VEDA_BASE_URL is required (PSYMETRIC_BASE_URL also accepted for backward compatibility)");
    process.exit(1);
  }

  // Project scope: exactly one of project ID or slug must be provided
  const projectId =
    process.env.VEDA_PROJECT_ID ??
    process.env.PSYMETRIC_PROJECT_ID;

  const projectSlug =
    process.env.VEDA_PROJECT_SLUG ??
    process.env.PSYMETRIC_PROJECT_SLUG;

  if (!projectId && !projectSlug) {
    console.error(
      "[VEDA MCP] FATAL: Either VEDA_PROJECT_ID or VEDA_PROJECT_SLUG must be set"
    );
    console.error("[VEDA MCP] (PSYMETRIC_PROJECT_ID and PSYMETRIC_PROJECT_SLUG are also accepted for backward compatibility)");
    console.error("[VEDA MCP] No silent fallback to DEFAULT_PROJECT_ID - project scope is required");
    process.exit(1);
  }

  if (projectId && projectSlug) {
    console.error(
      "[VEDA MCP] FATAL: Cannot set both a project ID and a project slug (VEDA_* or PSYMETRIC_*)"
    );
    process.exit(1);
  }

  let projectScope: { type: "id" | "slug"; value: string };

  if (projectId) {
    if (!UUID_RE.test(projectId)) {
      console.error(
        `[VEDA MCP] FATAL: Project ID must be a valid UUID, got: ${projectId}`
      );
      process.exit(1);
    }
    projectScope = { type: "id", value: projectId };
  } else {
    projectScope = { type: "slug", value: projectSlug! };
  }

  const timeoutRaw =
    process.env.VEDA_TIMEOUT_MS ??
    process.env.PSYMETRIC_TIMEOUT_MS ??
    "30000";

  const timeoutMs = parseInt(timeoutRaw, 10);
  if (isNaN(timeoutMs) || timeoutMs <= 0) {
    console.error(
      `[VEDA MCP] FATAL: Timeout must be a positive number, got: ${timeoutRaw}`
    );
    process.exit(1);
  }

  return {
    baseUrl,
    projectScope,
    timeoutMs,
  };
}

/**
 * Create API client with project scoping headers.
 */
export function createApiClient(config: ServerConfig): ApiClient {
  return {
    config,
    fetch: async (path: string, init?: RequestInit) => {
      const url = `${config.baseUrl}${path}`;
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), config.timeoutMs);

      try {
        // Build headers with project scope
        const headers: Record<string, string> = {
          "Content-Type": "application/json",
          ...((init?.headers as Record<string, string>) ?? {}),
        };

        // Skip project headers for list_projects (global endpoint)
        if (!path.startsWith("/api/projects?") && path !== "/api/projects") {
          if (config.projectScope.type === "id") {
            headers["x-project-id"] = config.projectScope.value;
          } else {
            headers["x-project-slug"] = config.projectScope.value;
          }
        }

        const response = await fetch(url, {
          ...init,
          headers,
          signal: controller.signal,
        });

        return response;
      } catch (error) {
        if (error instanceof Error && error.name === "AbortError") {
          throw new Error("Tool execution timeout");
        }
        throw error;
      } finally {
        clearTimeout(timeoutId);
      }
    },
  };
}
