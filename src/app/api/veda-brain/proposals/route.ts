/**
 * GET /api/veda-brain/proposals
 *
 * Returns Phase C1 proposals derived from VEDA Brain diagnostics.
 * Read-only. No mutations. No EventLog writes.
 */
import { NextRequest } from "next/server";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { computeVedaBrainDiagnostics } from "@/lib/veda-brain/veda-brain-diagnostics";
import { computeProposals } from "@/lib/veda-brain/proposals";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const diagnostics = await computeVedaBrainDiagnostics(projectId);
    const { proposals, summary } = computeProposals(diagnostics);

    return successResponse({ projectId, proposals, summary });
  } catch (err) {
    console.error("GET /api/veda-brain/proposals error:", err);
    return serverError();
  }
}
