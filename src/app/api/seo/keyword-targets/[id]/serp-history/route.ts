/**
 * GET /api/seo/keyword-targets/:id/serp-history — SIL-6: SERP Time Series
 *
 * Returns a paginated, deterministic time series of SERPSnapshot observations
 * for a single KeywordTarget. Each item in the series contains the extracted
 * top-N organic results for that snapshot, enabling scroll-back visibility
 * into rank movement over time.
 *
 * Ordering: capturedAt DESC, id DESC — most recent first, stable tie-breaker.
 *
 * Cursor design:
 *   The cursor encodes the (capturedAt, id) position of the last item on the
 *   previous page. On the next call, the DB WHERE clause filters to rows that
 *   are strictly before that position in the (capturedAt DESC, id DESC) order:
 *
 *     (capturedAt < cursorCapturedAt)
 *     OR (capturedAt = cursorCapturedAt AND id < cursorId)
 *
 *   This is evaluated in Postgres via a raw-compatible Prisma OR condition,
 *   keeping the cursor self-contained and stateless. The cursor is base64url-
 *   encoded so it is opaque to callers. Decoding failure silently falls back
 *   to no cursor (returns from the start of the sorted list).
 *
 * Extraction:
 *   Uses extractOrganicResults from @/lib/seo/serp-extraction — the same
 *   function used by serp-deltas. parseWarning propagated identically.
 *   Duplicate URLs within a snapshot: first-wins (results pre-sorted rank asc,
 *   lowest rank wins). topN slice applied after dedup.
 *
 * includePayload:
 *   When true, the full rawPayload is included in each item for debugging.
 *   Default false. Not filtered by topN — returns the full payload as stored.
 *
 * Isolation: resolveProjectId(request) — headers only.
 * No writes. No EventLog. Read-only surface.
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, notFound, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { extractOrganicResults } from "@/lib/seo/serp-extraction";
import { UUID_RE } from "@/lib/constants";

// =============================================================================
// Constants
// =============================================================================


const WINDOW_DAYS_MIN  = 1;
const WINDOW_DAYS_MAX  = 365;
const LIMIT_DEFAULT    = 50;
const LIMIT_MIN        = 1;
const LIMIT_MAX        = 200;
const TOP_N_DEFAULT    = 10;
const TOP_N_MIN        = 1;
const TOP_N_MAX        = 20;

// =============================================================================
// Param parsers
// =============================================================================

function parseWindowDays(
  sp: URLSearchParams
): { windowDays: number | null } | { error: string } {
  const raw = sp.get("windowDays");
  if (raw === null) return { windowDays: null };
  if (!/^\d+$/.test(raw)) return { error: "windowDays must be an integer" };
  const n = parseInt(raw, 10);
  if (n < WINDOW_DAYS_MIN) return { error: `windowDays must be >= ${WINDOW_DAYS_MIN}` };
  if (n > WINDOW_DAYS_MAX) return { error: `windowDays must be <= ${WINDOW_DAYS_MAX}` };
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

function parseTopN(
  sp: URLSearchParams
): { topN: number } | { error: string } {
  const raw = sp.get("topN");
  if (raw === null) return { topN: TOP_N_DEFAULT };
  if (!/^\d+$/.test(raw)) return { error: "topN must be an integer" };
  const n = parseInt(raw, 10);
  if (n < TOP_N_MIN) return { error: `topN must be >= ${TOP_N_MIN}` };
  if (n > TOP_N_MAX) return { error: `topN must be <= ${TOP_N_MAX}` };
  return { topN: n };
}

function parseIncludePayload(
  sp: URLSearchParams
): { includePayload: boolean } | { error: string } {
  const raw = sp.get("includePayload");
  if (raw === null) return { includePayload: false };
  if (raw === "true")  return { includePayload: true };
  if (raw === "false") return { includePayload: false };
  return { error: "includePayload must be true or false" };
}

// =============================================================================
// Cursor encoding / decoding
// =============================================================================

interface CursorPosition {
  capturedAt: string; // ISO 8601 — round-trips exactly through Date.toISOString()
  id:         string;
}

/**
 * Encode (capturedAt ISO, id) as a base64url opaque cursor.
 * Format before encoding: "{capturedAtISO}|{id}"
 * The pipe separator is safe — ISO dates and UUIDs never contain it.
 */
function encodeCursor(pos: CursorPosition): string {
  return Buffer.from(`${pos.capturedAt}|${pos.id}`, "utf8").toString("base64url");
}

/**
 * Decode cursor. Returns null on any malformed input — caller treats as no cursor.
 */
function decodeCursor(cursor: string): CursorPosition | null {
  try {
    const raw = Buffer.from(cursor, "base64url").toString("utf8");
    const sep = raw.lastIndexOf("|");
    if (sep < 0) return null;
    const capturedAt = raw.slice(0, sep);
    const id         = raw.slice(sep + 1);
    // Validate: capturedAt must parse as a date, id must look like a UUID
    if (isNaN(Date.parse(capturedAt))) return null;
    if (!UUID_RE.test(id)) return null;
    return { capturedAt, id };
  } catch {
    return null;
  }
}

// =============================================================================
// Next.js 16 params promise pattern
// =============================================================================

type RouteParams = { id: string };

function isPromiseLike<T>(v: unknown): v is Promise<T> {
  return !!v && typeof (v as Record<string, unknown>).then === "function";
}

// =============================================================================
// GET /api/seo/keyword-targets/:id/serp-history
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

    // --- Parse query params before any DB work ---
    const sp = new URL(request.url).searchParams;

    const windowResult = parseWindowDays(sp);
    if ("error" in windowResult) return badRequest(windowResult.error);
    const windowDays = windowResult.windowDays;

    const limitResult = parseLimit(sp);
    if ("error" in limitResult) return badRequest(limitResult.error);
    const limit = limitResult.limit;

    const topNResult = parseTopN(sp);
    if ("error" in topNResult) return badRequest(topNResult.error);
    const topN = topNResult.topN;

    const includePayloadResult = parseIncludePayload(sp);
    if ("error" in includePayloadResult) return badRequest(includePayloadResult.error);
    const includePayload = includePayloadResult.includePayload;

    const rawCursor = sp.get("cursor") ?? null;
    const cursorPos = rawCursor !== null ? decodeCursor(rawCursor) : null;
    // Malformed cursor → silently treat as no cursor (safe, not a 400)

    // Fix requestTime once for a stable window boundary
    const requestTime = new Date();
    const windowStart: Date | null = windowDays !== null
      ? new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000)
      : null;

    // --- Resolve KeywordTarget (project-scoped, 404 non-disclosure) ---
    const keywordTarget = await prisma.keywordTarget.findUnique({
      where:  { id },
      select: { id: true, projectId: true, query: true, locale: true, device: true },
    });

    if (!keywordTarget || keywordTarget.projectId !== projectId) {
      return notFound("KeywordTarget not found");
    }

    const { query, locale, device } = keywordTarget;

    // --- Load SERPSnapshots with cursor + window applied in DB ---
    //
    // Ordering: capturedAt DESC, id DESC (most-recent first, deterministic tie-break).
    //
    // Cursor WHERE (strictly before cursor position in DESC order):
    //   (capturedAt < cursorCapturedAt)
    //   OR (capturedAt = cursorCapturedAt AND id < cursorId)
    //
    // Prisma does not support row-value comparisons natively, so we use
    // an OR condition with two branches — equivalent to the tuple comparison
    // and fully evaluated by the Postgres index on (projectId, query, locale, device, capturedAt).

    const cursorDate = cursorPos !== null ? new Date(cursorPos.capturedAt) : null;

    const snapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        query,
        locale,
        device,
        ...(windowStart !== null ? { capturedAt: { gte: windowStart } } : {}),
        ...(cursorPos !== null && cursorDate !== null
          ? {
              OR: [
                { capturedAt: { lt: cursorDate } },
                { capturedAt: cursorDate, id: { lt: cursorPos.id } },
              ],
            }
          : {}),
      },
      orderBy: [{ capturedAt: "desc" }, { id: "desc" }],
      // Fetch limit+1 to detect whether a next page exists
      take: limit + 1,
      select: {
        id:               true,
        capturedAt:       true,
        aiOverviewStatus: true,
        rawPayload:       true,
      },
    });

    const hasMore        = snapshots.length > limit;
    const pageSnapshots  = hasMore ? snapshots.slice(0, limit) : snapshots;

    // --- Build response items ---
    const items = pageSnapshots.map((snap) => {
      const { results, parseWarning } = extractOrganicResults(snap.rawPayload);

      // Dedup by URL (first-wins; results already sorted rank asc — lowest rank wins)
      const seen    = new Set<string>();
      const deduped = results.filter((r) => {
        if (seen.has(r.url)) return false;
        seen.add(r.url);
        return true;
      });

      // topN slice
      const topResults = deduped.slice(0, topN).map((r) => ({
        rank: r.rank,
        url:  r.url,
      }));

      const item: Record<string, unknown> = {
        snapshotId:          snap.id,
        capturedAt:          snap.capturedAt.toISOString(),
        aiOverviewStatus:    snap.aiOverviewStatus,
        payloadParseWarning: parseWarning,
        topResults,
      };

      if (includePayload) {
        item.rawPayload = snap.rawPayload;
      }

      return item;
    });

    // --- Cursor for next page ---
    const nextCursor: string | null = hasMore
      ? encodeCursor({
          capturedAt: pageSnapshots[pageSnapshots.length - 1].capturedAt.toISOString(),
          id:         pageSnapshots[pageSnapshots.length - 1].id,
        })
      : null;

    return successResponse({
      keywordTargetId: id,
      query,
      locale,
      device,
      windowDays,
      items,
      nextCursor,
    });
  } catch (err) {
    console.error("GET /api/seo/keyword-targets/:id/serp-history error:", err);
    return serverError();
  }
}
