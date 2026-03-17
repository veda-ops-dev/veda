/**
 * GET /api/seo/keyword-targets/:id/intent-drift
 *
 * Returns per-snapshot intent distributions and consecutive-pair intent
 * transitions for a single KeywordTarget.
 *
 * A transition is emitted when the dominant intent bucket changes between
 * consecutive snapshots, or any bucket's percentage shifts >= significanceThreshold.
 *
 * Ordering: snapshots capturedAt ASC, id ASC (transitions inherit this order).
 * No writes. No EventLog. Read-only surface.
 *
 * Isolation:  resolveProjectId() -- headers only; cross-project KT -> 404.
 * Determinism: identical params + snapshot set -> identical response.
 *
 * Query params:
 *   windowDays             optional int 1-365
 *   significanceThreshold  optional int 1-100, default 34
 *   limitTransitions       optional int 1-200, default 50
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, notFound, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { extractFeatureSignals } from "@/lib/seo/serp-extraction";
import { computeIntentDrift } from "@/lib/seo/intent-drift";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================

const WINDOW_MIN            = 1;
const WINDOW_MAX            = 365;
const SIG_DEFAULT           = 34;
const SIG_MIN               = 1;
const SIG_MAX               = 100;
const LIMIT_DEFAULT         = 50;
const LIMIT_MIN             = 1;
const LIMIT_MAX             = 200;

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

function parseSignificanceThreshold(sp: URLSearchParams): { sig: number } | { error: string } {
  const raw = sp.get("significanceThreshold");
  if (raw === null) return { sig: SIG_DEFAULT };
  if (!/^\d+$/.test(raw)) return { error: "significanceThreshold must be an integer" };
  const n = parseInt(raw, 10);
  if (n < SIG_MIN) return { error: `significanceThreshold must be >= ${SIG_MIN}` };
  if (n > SIG_MAX) return { error: `significanceThreshold must be <= ${SIG_MAX}` };
  return { sig: n };
}

function parseLimitTransitions(sp: URLSearchParams): { limit: number } | { error: string } {
  const raw = sp.get("limitTransitions");
  if (raw === null) return { limit: LIMIT_DEFAULT };
  if (!/^\d+$/.test(raw)) return { error: "limitTransitions must be an integer" };
  const n = parseInt(raw, 10);
  if (n < LIMIT_MIN) return { error: `limitTransitions must be >= ${LIMIT_MIN}` };
  if (n > LIMIT_MAX) return { error: `limitTransitions must be <= ${LIMIT_MAX}` };
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

    const sigResult = parseSignificanceThreshold(sp);
    if ("error" in sigResult) return badRequest(sigResult.error);
    const significanceThreshold = sigResult.sig;

    const limitResult = parseLimitTransitions(sp);
    if ("error" in limitResult) return badRequest(limitResult.error);
    const limitTransitions = limitResult.limit;

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
      select: {
        id:         true,
        capturedAt: true,
        rawPayload: true,
      },
    });

    const input = rawSnapshots.map((snap) => ({
      snapshotId: snap.id,
      capturedAt: snap.capturedAt,
      signals:    extractFeatureSignals(snap.rawPayload),
    }));

    const { snapshots, transitions: allTransitions } = computeIntentDrift(
      input,
      significanceThreshold
    );

    const transitions = allTransitions.slice(0, limitTransitions);

    return successResponse({
      keywordTargetId:       id,
      query,
      locale,
      device,
      windowDays,
      significanceThreshold,
      snapshotCount:         snapshots.length,
      transitionCount:       allTransitions.length,
      snapshots,
      transitions,
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/intent-drift error:", err);
    return serverError();
  }
}
