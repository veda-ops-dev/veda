/**
 * GET /api/seo/keyword-targets/:id/overview — SIL-15: Keyword Overview Surface
 *
 * Composite read-only endpoint. Loads SERPSnapshots once, runs all SIL sensors
 * in the keyword-overview library, and returns a single structured payload.
 *
 * Isolation:  resolveProjectId(request) — headers/cookie/default.
 * Ordering:   snapshots loaded capturedAt ASC, id ASC (deterministic).
 * No writes.  No EventLog. Read-only surface.
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, notFound, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { buildKeywordOverview } from "@/lib/seo/keyword-overview";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================


// =============================================================================
// Params promise compat (Next.js 15+)
// =============================================================================

type RouteParams = { id: string };

function isPromiseLike<T>(v: unknown): v is Promise<T> {
  return !!v && typeof (v as Record<string, unknown>).then === "function";
}

// =============================================================================
// GET /api/seo/keyword-targets/:id/overview
// =============================================================================

export async function GET(
  request: NextRequest,
  { params }: { params: RouteParams | Promise<RouteParams> }
) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const resolvedParams = isPromiseLike<RouteParams>(params) ? await params : params;
    const id = resolvedParams?.id;

    if (!id || !UUID_RE.test(id)) {
      return badRequest("id must be a valid UUID");
    }

    // ── Resolve KeywordTarget (project-scoped; 404 non-disclosure) ────────────
    const keywordTarget = await prisma.keywordTarget.findUnique({
      where:  { id },
      select: { id: true, projectId: true, query: true, locale: true, device: true },
    });

    if (!keywordTarget || keywordTarget.projectId !== projectId) {
      return notFound("KeywordTarget not found");
    }

    const { query, locale, device } = keywordTarget;

    // ── Load snapshots (deterministic: capturedAt ASC, id ASC) ───────────────
    const rawSnapshots = await prisma.sERPSnapshot.findMany({
      where: { projectId, query, locale, device },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      select: {
        id:               true,
        capturedAt:       true,
        aiOverviewStatus: true,
        rawPayload:       true,
      },
    });

    // ── Delegate to pure library ──────────────────────────────────────────────
    const overview = buildKeywordOverview({
      keywordTargetId: id,
      query,
      locale,
      device,
      snapshots: rawSnapshots.map((s) => ({
        id:               s.id,
        capturedAt:       s.capturedAt,
        aiOverviewStatus: s.aiOverviewStatus,
        rawPayload:       s.rawPayload,
      })),
    });

    return successResponse(overview);
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/overview error:", err);
    return serverError();
  }
}
