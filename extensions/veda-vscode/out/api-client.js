"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.apiGet = apiGet;
const state_1 = require("./state");
async function apiGet(path, opts) {
    const env = (0, state_1.getActiveEnvironment)();
    if (!env) {
        return { ok: false, status: 0, data: null, error: "No active environment configured" };
    }
    const project = opts?.projectId ?? (0, state_1.getActiveProject)()?.id;
    const headers = {
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
        let parsed = null;
        try {
            parsed = JSON.parse(text);
        }
        catch {
            // non-JSON response
        }
        if (response.ok && parsed && typeof parsed === "object" && "data" in parsed) {
            return {
                ok: true,
                status: response.status,
                data: parsed.data,
                error: null,
            };
        }
        return {
            ok: false,
            status: response.status,
            data: null,
            error: typeof parsed === "object" && parsed !== null && "error" in parsed
                ? String(parsed.error)
                : `HTTP ${response.status}: ${response.statusText}`,
        };
    }
    catch (err) {
        const message = err instanceof Error
            ? err.name === "AbortError"
                ? "Request timed out (30s)"
                : err.message
            : "Unknown transport error";
        return { ok: false, status: 0, data: null, error: message };
    }
}
//# sourceMappingURL=api-client.js.map