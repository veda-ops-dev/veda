/**
 * GET /api/seo/keyword-targets/:id/feature-volatility
 *
 * Analyzes how SERP feature families change over time for a single KeywordTarget.
 * Complements SIL-3 (rank volatility) and SIL-8 (feature transitions aggregate).
 * Uses extractFeatureSignals for payload extraction and computeFeatureVolatility
 * for consecutive-pair transition analysis.
 *
 * No writes. No EventLog. No mutations. Read-only surface.
 *
 * Isolation:  resolveProjectId() -- headers only; cross-project KT -> 404.
 * Determinism: identical params + snapshot set -> identical response.
 *              No wall-clock fields in response body.
 *
 * Query params:
 *   windowDays        optional int 1-365
 *   limitTransitions  optional int 1-200, default 50
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, notFound, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { extractFeatureSignals } from "@/lib/seo/serp-extraction";
import { computeFeatureVolatility, type FeatureSnapshot } from "@/lib/seo/feature-volatility";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================

const WINDOW_MIN            = 1;
const WINDOW_MAX            = 365;
const LIMIT_TRANSITIONS_DEFAULT = 50;
const LIMIT_TRANSITIONS_MIN     = 1;
const LIMIT_TRANSITIONS_MAX     = 200;

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

function parseLimitTransitions(
  sp: URLSearchParams
): { limitTransitions: number } | { error: string } {
  const raw = sp.get("limitTransitions");
  if (raw === null) return { limitTransitions: LIMIT_TRANSITIONS_DEFAULT };
  if (!/^\d+$/.test(raw)) return { error: "limitTransitions must be an integer" };
  const n = parseInt(raw, 10);
  if (n < LIMIT_TRANSITIONS_MIN) return { error: `limitTransitions must be >= ${LIMIT_TRANSITIONS_MIN}` };
  if (n > LIMIT_TRANSITIONS_MAX) return { error: `limitTransitions must be <= ${LIMIT_TRANSITIONS_MAX}` };
  return { limitTransitions: n };
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

    const limitResult = parseLimitTransitions(sp);
    if ("error" in limitResult) return badRequest(limitResult.error);
    const limitTransitions = limitResult.limitTransitions;

    // Anchor requestTime once
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

    // Load snapshots ordered capturedAt ASC, id ASC (deterministic)
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

    // Convert snapshots to FeatureSnapshot using extractFeatureSignals
    // Snapshots with parseWarning=true contribute familiesSorted=[] (no features)
    // which is correct -- unrecognized payloads look like "no features present"
    const featureSnapshots: FeatureSnapshot[] = rawSnapshots.map((snap) => {
      const signals = extractFeatureSignals(snap.rawPayload);
      return {
        snapshotId:     snap.id,
        capturedAt:     snap.capturedAt,
        familiesSorted: signals.familiesSorted,
      };
    });

    // Compute transitions (snapshots already in capturedAt ASC, id ASC order)
    const { transitions: allTransitions, summary } = computeFeatureVolatility(featureSnapshots);

    // Truncate transitions to limitTransitions (summary.transitionCount reflects total)
    const transitions = allTransitions.slice(0, limitTransitions);

    return successResponse({
      keywordTargetId:  id,
      query,
      locale,
      device,
      windowDays,
      snapshotCount:    summary.snapshotCount,
      transitionCount:  summary.transitionCount,
      transitions,
      summary: {
        snapshotCount:        summary.snapshotCount,
        transitionCount:      summary.transitionCount,
        mostVolatileFeatures: summary.mostVolatileFeatures,
      },
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/feature-volatility error:", err);
    return serverError();
  }
}
