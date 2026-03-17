/**
 * GET /api/content-graph/project-diagnostics
 *
 * Returns compute-on-read Content Graph intelligence signals for a project.
 * Read-only. No mutations. No EventLog writes.
 *
 * Per docs/specs/CONTENT-GRAPH-PHASES.md Phase 2
 */
import { NextRequest } from "next/server";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { computeContentGraphDiagnostics } from "@/lib/content-graph/content-graph-diagnostics";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const diagnostics = await computeContentGraphDiagnostics(projectId);

    return successResponse({ projectId, diagnostics });
  } catch (err) {
    console.error("GET /api/content-graph/project-diagnostics error:", err);
    return serverError();
  }
}
