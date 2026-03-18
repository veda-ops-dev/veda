/**
 * api-client.ts — Thin HTTP transport for the VEDA operator surface.
 *
 * Responsibilities:
 * - Resolve active environment base URL
 * - Carry project context via x-project-id header
 * - Surface transport errors clearly
 * - Return parsed JSON or structured error
 *
 * Responsibilities explicitly excluded:
 * - Domain logic
 * - Policy invention
 * - Local replacement of server-side truth
 * - Direct DB access
 */

import { getActiveEnvironment, getActiveProject } from "./state";

export interface ApiResult<T = unknown> {
  ok: boolean;
  status: number;
  data: T | null;
  error: string | null;
}

export async function apiGet<T = unknown>(
  path: string,
  opts?: { projectId?: string }
): Promise<ApiResult<T>> {
  const env = getActiveEnvironment();
  if (!env) {
    return { ok: false, status: 0, data: null, error: "No active environment configured" };
  }

  const project = opts?.projectId ?? getActiveProject()?.id;
  const headers: Record<string, string> = {
    Accept: "application/json",
  };
  if (project) {
    headers["x-project-id"] = project;
  }

  const url = `${env.baseUrl.replace(/\/+$/, "")}${path}`;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30_000);

    const response = await fetch(url, {
      method: "GET",
      headers,
      signal: controller.signal,
    });

    clearTimeout(timeout);

    const text = await response.text();
    let parsed: unknown = null;
    try {
      parsed = JSON.parse(text);
    } catch {
      // non-JSON response
    }

    if (response.ok && parsed && typeof parsed === "object" && "data" in (parsed as Record<string, unknown>)) {
      return {
        ok: true,
        status: response.status,
        data: (parsed as { data: T }).data,
        error: null,
      };
    }

    return {
      ok: false,
      status: response.status,
      data: null,
      error: typeof parsed === "object" && parsed !== null && "error" in (parsed as Record<string, unknown>)
        ? String((parsed as { error: unknown }).error)
        : `HTTP ${response.status}: ${response.statusText}`,
    };
  } catch (err) {
    const message =
      err instanceof Error
        ? err.name === "AbortError"
          ? "Request timed out (30s)"
          : err.message
        : "Unknown transport error";
    return { ok: false, status: 0, data: null, error: message };
  }
}
