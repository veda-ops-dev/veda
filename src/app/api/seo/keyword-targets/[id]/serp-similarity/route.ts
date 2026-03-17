/**
 * GET /api/seo/keyword-targets/:id/serp-similarity
 *
 * Returns a timeline of Jaccard similarity scores between consecutive SERP
 * snapshots for a single KeywordTarget.
 *
 * Each pair reports:
 *   domainSimilarity   -- Jaccard on organic domain sets
 *   familySimilarity   -- Jaccard on feature family sets
 *   combinedSimilarity -- (domain + family) / 2
 *
 * Ordering: pairs capturedAt ASC, toSnapshotId ASC.
 * No writes. No EventLog. Read-only surface.
 *
 * Isolation:  resolveProjectId() -- headers only; cross-project KT -> 404.
 * Determinism: identical params + snapshot set -> identical response.
 *
 * Query params:
 *   windowDays  optional int 1-365
 *   limit       optional int 1-200, default 50
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, notFound, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { extractFeatureSignals } from "@/lib/seo/serp-extraction";
import { computeSerpSimilarity } from "@/lib/seo/serp-similarity";
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

    // Load limit+1 snapshots so the similarity window covers `limit` pairs
    const rawSnapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        query,
        locale,
        device,
        ...(windowStart !== null ? { capturedAt: { gte: windowStart } } : {}),
      },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      take:    limit + 1,
      select: {
        id:         true,
        capturedAt: true,
        rawPayload: true,
      },
    });

    const input = rawSnapshots.map((snap) => ({
      snapshotId: snap.id,
      capturedAt: snap.capturedAt,
      rawPayload: snap.rawPayload,
      signals:    extractFeatureSignals(snap.rawPayload),
    }));

    const { pairCount, pairs } = computeSerpSimilarity(input);

    return successResponse({
      keywordTargetId: id,
      query,
      locale,
      device,
      windowDays,
      pairCount,
      pairs,
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/serp-similarity error:", err);
    return serverError();
  }
}
