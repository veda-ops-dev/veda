/**
 * GET /api/seo/keyword-targets/:id/domain-dominance
 *
 * Returns per-snapshot domain dominance summaries for a single KeywordTarget.
 * Each snapshot row contains: totalResults, uniqueDomains, dominanceIndex, topDomains[].
 *
 * Ordering: snapshots capturedAt ASC, id ASC.
 * No writes. No EventLog. Read-only surface.
 *
 * Isolation:  resolveProjectId() -- headers only; cross-project KT -> 404.
 * Determinism: identical params + snapshot set -> identical response.
 *              No wall-clock fields in response body.
 *
 * Query params:
 *   windowDays  optional int 1-365
 *   limit       optional int 1-200, default 50
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, notFound, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { computeDomainDominance } from "@/lib/seo/domain-dominance";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================

const WINDOW_MIN   = 1;
const WINDOW_MAX   = 365;
const LIMIT_DEFAULT = 50;
const LIMIT_MIN    = 1;
const LIMIT_MAX    = 200;

// =============================================================================
// Param parsers
// =============================================================================

type RouteParams = { id: string };

function isPromise<T>(v: unknown): v is Promise<T> {
  return !!v && typeof (v as Record<string, unknown>).then === "function";
}

function parseWindowDays(sp: URLSearchParams): { windowDays: number | null } | { error: string } {
  const raw = sp.get("windowDays");
  if (raw === null) return { windowDays: null };
  if (!/^\d+$/.test(raw)) return { error: "windowDays must be an integer" };
  const n = parseInt(raw, 10);
  if (n < WINDOW_MIN) return { error: `windowDays must be >= ${WINDOW_MIN}` };
  if (n > WINDOW_MAX) return { error: `windowDays must be <= ${WINDOW_MAX}` };
  return { windowDays: n };
}

function parseLimit(sp: URLSearchParams): { limit: number } | { error: string } {
  const raw = sp.get("limit");
  if (raw === null) return { limit: LIMIT_DEFAULT };
  if (!/^\d+$/.test(raw)) return { error: "limit must be an integer" };
  const n = parseInt(raw, 10);
  if (n < LIMIT_MIN) return { error: `limit must be >= ${LIMIT_MIN}` };
  if (n > LIMIT_MAX) return { error: `limit must be <= ${LIMIT_MAX}` };
  return { limit: n };
}

// =============================================================================
// GET handler
// =============================================================================

export async function GET(
  request: NextRequest,
  context: { params: RouteParams | Promise<RouteParams> }
) {
  try {
    const { projectId, error: projectError } = await resolveProjectId(request);
    if (projectError) return badRequest(projectError);

    const params = isPromise(context.params) ? await context.params : context.params;
    const { id } = params;

    if (!UUID_RE.test(id)) return badRequest("id must be a valid UUID");

    const sp = new URL(request.url).searchParams;

    const windowResult = parseWindowDays(sp);
    if ("error" in windowResult) return badRequest(windowResult.error);
    const windowDays = windowResult.windowDays;

    const limitResult = parseLimit(sp);
    if ("error" in limitResult) return badRequest(limitResult.error);
    const limit = limitResult.limit;

    const requestTime = new Date();
    const windowStart: Date | null =
      windowDays !== null
        ? new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000)
        : null;

    const keywordTarget = await prisma.keywordTarget.findUnique({
      where:  { id },
      select: { id: true, projectId: true, query: true, locale: true, device: true },
    });
    if (!keywordTarget || keywordTarget.projectId !== projectId) {
      return notFound("KeywordTarget not found");
    }

    const { query, locale, device } = keywordTarget;

    const rawSnapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        query,
        locale,
        device,
        ...(windowStart !== null ? { capturedAt: { gte: windowStart } } : {}),
      },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      take:    limit,
      select: {
        id:         true,
        capturedAt: true,
        rawPayload: true,
      },
    });

    const snapshots = rawSnapshots.map((snap) => {
      const summary = computeDomainDominance(snap.rawPayload);
      return {
        snapshotId:     snap.id,
        capturedAt:     snap.capturedAt.toISOString(),
        totalResults:   summary.totalResults,
        uniqueDomains:  summary.uniqueDomains,
        dominanceIndex: summary.dominanceIndex,
        topDomains:     summary.topDomains,
      };
    });

    return successResponse({
      keywordTargetId: id,
      query,
      locale,
      device,
      windowDays,
      snapshotCount: snapshots.length,
      snapshots,
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/domain-dominance error:", err);
    return serverError();
  }
}
