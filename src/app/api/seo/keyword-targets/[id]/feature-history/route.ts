/**
 * GET /api/seo/keyword-targets/:id/feature-history
 *
 * Returns a paginated, deterministic history of SERP feature signals for a
 * single KeywordTarget. Each row covers one SERPSnapshot and includes the
 * full FeatureSignals output (rawTypesSorted, familiesSorted, flags, parseWarning).
 *
 * Ordering: capturedAt ASC, id ASC (chronological, stable tie-breaker).
 *
 * Keyset pagination on (capturedAt ASC, id ASC):
 *   cursorCapturedAt + cursorId encode the position of the last row on the
 *   previous page. The next page starts at the first row strictly after that
 *   position:
 *     (capturedAt > cursorCapturedAt)
 *     OR (capturedAt = cursorCapturedAt AND id > cursorId)
 *
 *   cursorCapturedAt must be a valid ISO-8601 datetime string.
 *   cursorId must be a valid UUID.
 *   Both must be present together or both absent; mixing is a 400.
 *
 * windowDays filters capturedAt >= (requestTime - windowDays * 86400s) at DB level.
 *
 * Isolation:  resolveProjectId() -- headers only; cross-project KT -> 404.
 * Determinism: identical params + snapshot set -> identical response.
 *              No wall-clock fields in response body.
 * No writes. No EventLog. Read-only surface.
 */
import { Prisma } from "@prisma/client";
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, notFound, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { extractFeatureSignals } from "@/lib/seo/serp-extraction";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================

const ISO_DATE_RE    = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/;
const WINDOW_MIN     = 1;
const WINDOW_MAX     = 365;
const LIMIT_DEFAULT  = 50;
const LIMIT_MIN      = 1;
const LIMIT_MAX      = 200;

// =============================================================================
// Param parsers
// =============================================================================

type RouteParams = { id: string };

function isPromise<T>(v: unknown): v is Promise<T> {
  return !!v && typeof (v as Record<string, unknown>).then === "function";
}

function parseWindowDays(
  sp: URLSearchParams
): { windowDays: number | null } | { error: string } {
  const raw = sp.get("windowDays");
  if (raw === null) return { windowDays: null };
  if (!/^\d+$/.test(raw)) return { error: "windowDays must be an integer" };
  const n = parseInt(raw, 10);
  if (n < WINDOW_MIN) return { error: `windowDays must be >= ${WINDOW_MIN}` };
  if (n > WINDOW_MAX) return { error: `windowDays must be <= ${WINDOW_MAX}` };
  return { windowDays: n };
}

function parseLimit(
  sp: URLSearchParams
): { limit: number } | { error: string } {
  const raw = sp.get("limit");
  if (raw === null) return { limit: LIMIT_DEFAULT };
  if (!/^\d+$/.test(raw)) return { error: "limit must be an integer" };
  const n = parseInt(raw, 10);
  if (n < LIMIT_MIN) return { error: `limit must be >= ${LIMIT_MIN}` };
  if (n > LIMIT_MAX) return { error: `limit must be <= ${LIMIT_MAX}` };
  return { limit: n };
}

interface CursorParams {
  cursorCapturedAt: Date;
  cursorId: string;
}

function parseCursor(
  sp: URLSearchParams
): { cursor: CursorParams | null } | { error: string } {
  const rawAt = sp.get("cursorCapturedAt");
  const rawId = sp.get("cursorId");

  // Both absent: no cursor (first page)
  if (rawAt === null && rawId === null) return { cursor: null };

  // Exactly one present: malformed
  if (rawAt === null || rawId === null) {
    return { error: "cursorCapturedAt and cursorId must be provided together" };
  }

  // Validate ISO string
  if (!ISO_DATE_RE.test(rawAt)) {
    return { error: "cursorCapturedAt must be an ISO-8601 datetime string ending in Z" };
  }

  // Validate UUID
  if (!UUID_RE.test(rawId)) {
    return { error: "cursorId must be a valid UUID" };
  }

  const dt = new Date(rawAt);
  if (isNaN(dt.getTime())) {
    return { error: "cursorCapturedAt is not a valid date" };
  }

  return { cursor: { cursorCapturedAt: dt, cursorId: rawId } };
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

    // Resolve dynamic route param (Next.js 15 async params)
    const params = isPromise(context.params) ? await context.params : context.params;
    const { id } = params;

    if (!UUID_RE.test(id)) return badRequest("id must be a valid UUID");

    // Parse query params
    const sp = new URL(request.url).searchParams;

    const windowResult = parseWindowDays(sp);
    if ("error" in windowResult) return badRequest(windowResult.error);
    const windowDays = windowResult.windowDays;

    const limitResult = parseLimit(sp);
    if ("error" in limitResult) return badRequest(limitResult.error);
    const limit = limitResult.limit;

    const cursorResult = parseCursor(sp);
    if ("error" in cursorResult) return badRequest(cursorResult.error);
    const cursor = cursorResult.cursor;

    // Anchor requestTime once -- window boundary stable for this request
    const requestTime = new Date();
    const windowStart: Date | null =
      windowDays !== null
        ? new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000)
        : null;

    // Resolve KeywordTarget -- 404 on cross-project (non-disclosure)
    const keywordTarget = await prisma.keywordTarget.findUnique({
      where:  { id },
      select: { id: true, projectId: true, query: true, locale: true, device: true },
    });
    if (!keywordTarget || keywordTarget.projectId !== projectId) {
      return notFound("KeywordTarget not found");
    }

    const { query, locale, device } = keywordTarget;

    // Build Prisma where clause
    const baseWhere: Prisma.SERPSnapshotWhereInput = {
      projectId,
      query,
      locale,
      device,
      ...(windowStart !== null ? { capturedAt: { gte: windowStart } } : {}),
    };

    // Apply keyset cursor: rows strictly after (cursorCapturedAt, cursorId) ASC
    const where: Prisma.SERPSnapshotWhereInput =
      cursor !== null
        ? {
            AND: [
              baseWhere,
              {
                OR: [
                  { capturedAt: { gt: cursor.cursorCapturedAt } },
                  {
                    capturedAt: { equals: cursor.cursorCapturedAt },
                    id: { gt: cursor.cursorId },
                  },
                ],
              },
            ],
          }
        : baseWhere;

    // Fetch limit+1 to detect hasMore
    const rawSnapshots = await prisma.sERPSnapshot.findMany({
      where,
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      take:    limit + 1,
      select: {
        id:               true,
        capturedAt:       true,
        aiOverviewStatus: true,
        rawPayload:       true,
      },
    });

    const hasMore = rawSnapshots.length > limit;
    const pageSnapshots = hasMore ? rawSnapshots.slice(0, limit) : rawSnapshots;

    // Build response rows
    const snapshots = pageSnapshots.map((snap) => {
      const signals = extractFeatureSignals(snap.rawPayload);
      return {
        snapshotId:        snap.id,
        capturedAt:        snap.capturedAt.toISOString(),
        familiesSorted:    signals.familiesSorted,
        rawTypesSorted:    signals.rawTypesSorted,
        flags:             signals.flags,
        parseWarning:      signals.parseWarning,
      };
    });

    // Build nextCursor from last row's (capturedAt, id)
    const nextCursor =
      hasMore && pageSnapshots.length > 0
        ? {
            cursorCapturedAt: pageSnapshots[pageSnapshots.length - 1].capturedAt.toISOString(),
            cursorId:         pageSnapshots[pageSnapshots.length - 1].id,
          }
        : null;

    return successResponse({
      keywordTargetId: id,
      query,
      locale,
      device,
      windowDays,
      pageSize: pageSnapshots.length,
      nextCursor,
      snapshots,
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/feature-history error:", err);
    return serverError();
  }
}
