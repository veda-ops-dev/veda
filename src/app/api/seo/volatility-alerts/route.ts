/**
 * GET /api/seo/volatility-alerts — SIL-5: Operator Alert Surface
 *
 * Returns the most actionable KeywordTargets for the current project:
 * those whose volatilityScore >= alertThreshold AND maturity >= minMaturity
 * AND sampleSize >= 1 (no alerts without evidence).
 *
 * Design decisions:
 *
 *   Filter-first, not score-all:
 *     This is an alerts endpoint. Items that do not exceed the threshold are
 *     excluded from the response entirely (not just flagged). This keeps
 *     payload small and operator-focused. exceedsThreshold is always true
 *     for every returned item by construction.
 *
 *   Sort: volatilityScore DESC, query ASC, keywordTargetId ASC
 *     Highest-urgency first. Tie-breaks are deterministic and stable across
 *     repeated calls on the same snapshot set.
 *
 *   Cursor pagination:
 *     cursor is an opaque base64url string encoding "{paddedScore}:{query}:{id}".
 *     paddedScore is zero-padded to 9 chars (e.g. "073.45000") so lexicographic
 *     sort on the encoded string is safe. Decoded at read time; the after-position
 *     filter is applied in-memory after sorting (volumes per project are small).
 *     Cursor is stable: same snapshot set + same params always produces the
 *     same cursor for the same position.
 *
 *   Two DB queries max:
 *     1. KeywordTargets for the project (all, deterministic order)
 *     2. SERPSnapshots for the project within the optional window
 *     Groups and computes in memory — same O(K×S) pattern as SIL-4.
 *
 *   Isolation: resolveProjectId(request) — headers only.
 *   No writes. No EventLog. Read-only surface.
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { computeVolatility, classifyMaturity, classifyRegime, VolatilityMaturity, VolatilityRegime } from "@/lib/seo/volatility-service";

// =============================================================================
// Constants
// =============================================================================

const WINDOW_DAYS_MIN         = 1;
const WINDOW_DAYS_MAX         = 365;
const ALERT_THRESHOLD_DEFAULT = 60;
const ALERT_THRESHOLD_MIN     = 0;
const ALERT_THRESHOLD_MAX     = 100;
const LIMIT_DEFAULT           = 20;
const LIMIT_MIN               = 1;
const LIMIT_MAX               = 50;
const MATURITY_DEFAULT: VolatilityMaturity = "developing";

/** Numeric rank for maturity comparison. Higher = more mature. */
const MATURITY_RANK: Record<VolatilityMaturity, number> = {
  preliminary: 0,
  developing:  1,
  stable:      2,
};

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

function parseAlertThreshold(
  sp: URLSearchParams
): { alertThreshold: number } | { error: string } {
  const raw = sp.get("alertThreshold");
  if (raw === null) return { alertThreshold: ALERT_THRESHOLD_DEFAULT };
  if (!/^-?\d+$/.test(raw)) return { error: "alertThreshold must be an integer" };
  const n = parseInt(raw, 10);
  if (n < ALERT_THRESHOLD_MIN) return { error: `alertThreshold must be >= ${ALERT_THRESHOLD_MIN}` };
  if (n > ALERT_THRESHOLD_MAX) return { error: `alertThreshold must be <= ${ALERT_THRESHOLD_MAX}` };
  return { alertThreshold: n };
}

function parseMinMaturity(
  sp: URLSearchParams
): { minMaturity: VolatilityMaturity } | { error: string } {
  const raw = sp.get("minMaturity");
  if (raw === null) return { minMaturity: MATURITY_DEFAULT };
  if (raw !== "preliminary" && raw !== "developing" && raw !== "stable") {
    return { error: "minMaturity must be one of: preliminary, developing, stable" };
  }
  return { minMaturity: raw as VolatilityMaturity };
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

// =============================================================================
// Cursor encoding / decoding
// =============================================================================

interface CursorPosition {
  score: number;
  query: string;
  id:    string;
}

/**
 * Encode a cursor from the last item in the returned page.
 * Format (before base64url): "{score_padded_9}:{query}:{id}"
 * score is formatted to 5 decimal places and zero-padded to 9 total chars.
 */
function encodeCursor(pos: CursorPosition): string {
  const paddedScore = pos.score.toFixed(5).padStart(9, "0");
  const raw = `${paddedScore}:${pos.query}:${pos.id}`;
  return Buffer.from(raw, "utf8").toString("base64url");
}

/**
 * Decode a cursor. Returns null if malformed — caller treats null as no cursor
 * (safe fallback: return from beginning of sorted list).
 */
function decodeCursor(cursor: string): CursorPosition | null {
  try {
    const raw = Buffer.from(cursor, "base64url").toString("utf8");
    // Split on first two colons only — query text may itself contain colons
    const firstColon  = raw.indexOf(":");
    if (firstColon < 0) return null;
    const secondColon = raw.indexOf(":", firstColon + 1);
    if (secondColon < 0) return null;
    const scorePart = raw.slice(0, firstColon);
    const queryPart = raw.slice(firstColon + 1, secondColon);
    const idPart    = raw.slice(secondColon + 1);
    const score = parseFloat(scorePart);
    if (isNaN(score) || !idPart) return null;
    return { score, query: queryPart, id: idPart };
  } catch {
    return null;
  }
}

// =============================================================================
// Result item type
// =============================================================================

interface AlertItem {
  keywordTargetId:           string;
  query:                     string;
  locale:                    string;
  device:                    string;
  volatilityScore:           number;
  rankVolatilityComponent:   number;
  aiOverviewComponent:       number;
  featureVolatilityComponent: number;
  maturity:                  VolatilityMaturity;
  volatilityRegime:          VolatilityRegime;
  sampleSize:                number;
  alertThreshold:            number;
  exceedsThreshold:          true; // always true — items that don't exceed are excluded
}

// =============================================================================
// GET /api/seo/volatility-alerts
// =============================================================================

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const sp = new URL(request.url).searchParams;

    // --- Parse all params before any DB work ---
    const windowResult = parseWindowDays(sp);
    if ("error" in windowResult) return badRequest(windowResult.error);
    const windowDays = windowResult.windowDays;

    const thresholdResult = parseAlertThreshold(sp);
    if ("error" in thresholdResult) return badRequest(thresholdResult.error);
    const alertThreshold = thresholdResult.alertThreshold;

    const maturityResult = parseMinMaturity(sp);
    if ("error" in maturityResult) return badRequest(maturityResult.error);
    const minMaturity = maturityResult.minMaturity;

    const limitResult = parseLimit(sp);
    if ("error" in limitResult) return badRequest(limitResult.error);
    const limit = limitResult.limit;

    const rawCursor = sp.get("cursor") ?? null;
    // Malformed cursor: silently ignore, treat as no cursor (safe fallback)
    const cursorPos = rawCursor !== null ? decodeCursor(rawCursor) : null;

    // Fix requestTime once for a stable window boundary across this request
    const requestTime = new Date();
    const windowStart: Date | null = windowDays !== null
      ? new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000)
      : null;

    // ── Query 1: KeywordTargets ───────────────────────────────────────────────
    const targets = await prisma.keywordTarget.findMany({
      where:   { projectId },
      orderBy: [{ query: "asc" }, { id: "asc" }],
      select:  { id: true, query: true, locale: true, device: true },
    });

    if (targets.length === 0) {
      return successResponse({ items: [], nextCursor: null });
    }

    // ── Query 2: SERPSnapshots (window-filtered, project-scoped) ─────────────
    const allSnapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        ...(windowStart !== null ? { capturedAt: { gte: windowStart } } : {}),
      },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      select: {
        id:               true,
        query:            true,
        locale:           true,
        device:           true,
        capturedAt:       true,
        aiOverviewStatus: true,
        rawPayload:       true,
      },
    });

    // ── Group snapshots by natural key ────────────────────────────────────────
    type SnapRow = {
      id:               string;
      capturedAt:       Date;
      aiOverviewStatus: string;
      rawPayload:       unknown;
    };
    const snapshotMap = new Map<string, SnapRow[]>();
    for (const snap of allSnapshots) {
      const key = `${snap.query}\0${snap.locale}\0${snap.device}`;
      let bucket = snapshotMap.get(key);
      if (!bucket) { bucket = []; snapshotMap.set(key, bucket); }
      bucket.push({
        id:               snap.id,
        capturedAt:       snap.capturedAt,
        aiOverviewStatus: snap.aiOverviewStatus,
        rawPayload:       snap.rawPayload,
      });
    }

    // ── Compute, filter, collect ──────────────────────────────────────────────
    const minMaturityRank = MATURITY_RANK[minMaturity];
    const allItems: AlertItem[] = [];

    for (const target of targets) {
      const key       = `${target.query}\0${target.locale}\0${target.device}`;
      const snapshots = snapshotMap.get(key) ?? [];
      const profile   = computeVolatility(snapshots);

      // sampleSize=0 → no evidence → never alert
      if (profile.sampleSize < 1) continue;

      const maturity = classifyMaturity(profile.sampleSize);
      if (MATURITY_RANK[maturity] < minMaturityRank) continue;

      if (profile.volatilityScore < alertThreshold) continue;

      allItems.push({
        keywordTargetId:           target.id,
        query:                     target.query,
        locale:                    target.locale,
        device:                    target.device,
        volatilityScore:           profile.volatilityScore,
        rankVolatilityComponent:   profile.rankVolatilityComponent,
        aiOverviewComponent:       profile.aiOverviewComponent,
        featureVolatilityComponent: profile.featureVolatilityComponent,
        maturity,
        volatilityRegime:          classifyRegime(profile.volatilityScore),
        sampleSize:                profile.sampleSize,
        alertThreshold,
        exceedsThreshold:          true,
      });
    }

    // ── Sort: volatilityScore DESC, query ASC, keywordTargetId ASC ───────────
    allItems.sort((a, b) => {
      if (b.volatilityScore !== a.volatilityScore) return b.volatilityScore - a.volatilityScore;
      const qCmp = a.query.localeCompare(b.query);
      if (qCmp !== 0) return qCmp;
      return a.keywordTargetId.localeCompare(b.keywordTargetId);
    });

    // ── Apply cursor (after-position filter in sorted order) ─────────────────
    let startIndex = 0;
    if (cursorPos !== null) {
      // Walk forward until we find an item strictly after the cursor position
      let found = false;
      for (let i = 0; i < allItems.length; i++) {
        const item = allItems[i];
        const afterByScore = item.volatilityScore < cursorPos.score;
        const tiedScore    = item.volatilityScore === cursorPos.score;
        const afterByQuery = tiedScore && item.query.localeCompare(cursorPos.query) > 0;
        const tiedQuery    = tiedScore && item.query === cursorPos.query;
        const afterById    = tiedQuery && item.keywordTargetId > cursorPos.id;

        if (afterByScore || afterByQuery || afterById) {
          startIndex = i;
          found = true;
          break;
        }
      }
      // If no item is strictly after the cursor, we're past the end → empty page
      if (!found) startIndex = allItems.length;
    }

    const page      = allItems.slice(startIndex, startIndex + limit);
    const hasMore   = startIndex + limit < allItems.length;
    const nextCursor: string | null = hasMore
      ? encodeCursor({
          score: page[page.length - 1].volatilityScore,
          query: page[page.length - 1].query,
          id:    page[page.length - 1].keywordTargetId,
        })
      : null;

    return successResponse({ items: page, nextCursor });
  } catch (err) {
    console.error("GET /api/seo/volatility-alerts error:", err);
    return serverError();
  }
}
