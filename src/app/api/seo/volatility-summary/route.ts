/**
 * GET /api/seo/volatility-summary — SIL-4: Project Volatility Aggregation
 *
 * Aggregates volatility scores across all KeywordTargets in the current project.
 * Read-only. No writes. No EventLog. No schema changes.
 *
 * SIL-8 B2 additions (patch — no existing semantics modified):
 *   weightedProjectVolatilityScore — SUM(score_i * sampleSize_i) / SUM(sampleSize_i)
 *     Only active keywords (sampleSize > 0) included. Returns 0.00 if no active keywords.
 *   volatilityConcentrationRatio — top3VolatilitySum / totalVolatilitySum (active only).
 *     Returns null if totalVolatilitySum = 0. Rounded to 4 decimals.
 *   top3RiskKeywords — up to 3 active keywords sorted: volatilityScore DESC, query ASC,
 *     keywordTargetId ASC. Per-item: keywordTargetId, query, volatilityScore,
 *     volatilityRegime, volatilityMaturity, exceedsThreshold.
 *
 * All three metrics computed in the existing O(K*S) loop — no new DB queries.
 *
 * windowDays:
 *   Optional integer query param (1–365). When supplied, only snapshots with
 *   capturedAt >= (requestTime - windowDays * 86400s) are included in the
 *   single batch snapshot query. The WHERE clause is applied in the DB, not
 *   in memory, so the capturedAt index is used.
 *   windowDays is echoed in the response. requestTime is fixed once at the
 *   top of the request handler.
 *
 * Isolation: resolveProjectId(request) — headers only, no URL path param.
 * Complexity: O(1) DB queries, O(K×S) memory + compute where S is the
 *   snapshot count within the window.
 */

import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import {
  computeVolatility,
  classifyMaturity,
  classifyRegime,
} from "@/lib/seo/volatility-service";

const HIGH_THRESHOLD   = 60;
const MEDIUM_THRESHOLD = 30;

const WINDOW_DAYS_MIN = 1;
const WINDOW_DAYS_MAX = 365;

const ALERT_THRESHOLD_DEFAULT = 60;
const ALERT_THRESHOLD_MIN     = 0;
const ALERT_THRESHOLD_MAX     = 100;

/**
 * Parse and validate the optional windowDays query param.
 */
function parseWindowDays(
  searchParams: URLSearchParams
): { windowDays: number | null; error?: never } | { windowDays?: never; error: string } {
  const raw = searchParams.get("windowDays");
  if (raw === null) return { windowDays: null };
  if (!/^\d+$/.test(raw)) return { error: "windowDays must be an integer" };
  const n = parseInt(raw, 10);
  if (n < WINDOW_DAYS_MIN) return { error: `windowDays must be >= ${WINDOW_DAYS_MIN}` };
  if (n > WINDOW_DAYS_MAX) return { error: `windowDays must be <= ${WINDOW_DAYS_MAX}` };
  return { windowDays: n };
}

function parseAlertThreshold(
  searchParams: URLSearchParams
): { alertThreshold: number; error?: never } | { alertThreshold?: never; error: string } {
  const raw = searchParams.get("alertThreshold");
  if (raw === null) return { alertThreshold: ALERT_THRESHOLD_DEFAULT };
  if (!/^-?\d+$/.test(raw)) return { error: "alertThreshold must be an integer" };
  const n = parseInt(raw, 10);
  if (n < ALERT_THRESHOLD_MIN) return { error: `alertThreshold must be >= ${ALERT_THRESHOLD_MIN}` };
  if (n > ALERT_THRESHOLD_MAX) return { error: `alertThreshold must be <= ${ALERT_THRESHOLD_MAX}` };
  return { alertThreshold: n };
}

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const searchParams = new URL(request.url).searchParams;
    const windowResult = parseWindowDays(searchParams);
    if (windowResult.error) return badRequest(windowResult.error);
    const windowDays = windowResult.windowDays ?? null;

    const alertResult = parseAlertThreshold(searchParams);
    if (alertResult.error) return badRequest(alertResult.error);
    const alertThreshold = alertResult.alertThreshold!;

    // Fix requestTime once so the window boundary is stable for this request.
    const requestTime = new Date();
    const windowStart: Date | null = windowDays !== null
      ? new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000)
      : null;

    // ── Load KeywordTargets ─────────────────────────────────────────────────
    const targets = await prisma.keywordTarget.findMany({
      where: { projectId },
      orderBy: [{ createdAt: "asc" }, { id: "asc" }],
      select: { id: true, query: true, locale: true, device: true },
    });

    const keywordCount = targets.length;

    // B2 zero-keyword short-circuit — all new fields initialised to their empty-state values.
    if (keywordCount === 0) {
      return successResponse({
        windowDays,
        alertThreshold,
        alertKeywordCount:              0,
        alertRatio:                     0,
        keywordCount:                   0,
        activeKeywordCount:             0,
        averageVolatility:              0,
        maxVolatility:                  0,
        highVolatilityCount:            0,
        mediumVolatilityCount:          0,
        lowVolatilityCount:             0,
        stableCount:                    0,
        preliminaryCount:               0,
        developingCount:                0,
        stableCountByMaturity:          0,
        // B2 additions
        weightedProjectVolatilityScore: 0,
        volatilityConcentrationRatio:   null,
        top3RiskKeywords:               [],
      });
    }

    // ── Load all snapshots for the project in one query (window-filtered) ───
    const allSnapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        ...(windowStart !== null ? { capturedAt: { gte: windowStart } } : {}),
      },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      select: {
        id: true,
        query: true,
        locale: true,
        device: true,
        capturedAt: true,
        aiOverviewStatus: true,
        rawPayload: true,
      },
    });

    // ── Group snapshots by (query, locale, device) ──────────────────────────
    type SnapRow = {
      id: string;
      capturedAt: Date;
      aiOverviewStatus: string;
      rawPayload: unknown;
    };
    const snapshotMap = new Map<string, SnapRow[]>();

    for (const snap of allSnapshots) {
      const key = `${snap.query}\0${snap.locale}\0${snap.device}`;
      let bucket = snapshotMap.get(key);
      if (!bucket) { bucket = []; snapshotMap.set(key, bucket); }
      bucket.push({
        id: snap.id,
        capturedAt: snap.capturedAt,
        aiOverviewStatus: snap.aiOverviewStatus,
        rawPayload: snap.rawPayload,
      });
    }

    // ── Compute and aggregate ───────────────────────────────────────────────
    let activeKeywordCount     = 0;
    let highVolatilityCount     = 0;
    let mediumVolatilityCount   = 0;
    let lowVolatilityCount      = 0;
    let stableCount             = 0;
    let maxVolatility           = 0;
    let volatilitySum           = 0;
    let preliminaryCount        = 0;
    let developingCount         = 0;
    let stableCountByMaturity   = 0;
    let alertKeywordCount       = 0;

    // B2 accumulators
    let weightedScoreSum  = 0; // SUM(volatilityScore_i * sampleSize_i) — active only
    let weightedSizeSum   = 0; // SUM(sampleSize_i) — active only
    let totalVolatilitySum = 0; // SUM(volatilityScore_i) — active only (for concentration)

    // Collect active keyword records for top3 sort (allocated once, max keywordCount entries)
    interface ActiveRecord {
      keywordTargetId: string;
      query:           string;
      volatilityScore: number;
      sampleSize:      number;
    }
    const activeRecords: ActiveRecord[] = [];

    for (const target of targets) {
      const key = `${target.query}\0${target.locale}\0${target.device}`;
      const snapshots = snapshotMap.get(key) ?? [];
      const profile = computeVolatility(snapshots);

      const score    = profile.volatilityScore;
      const ss       = profile.sampleSize;
      const isActive = ss >= 1;

      if (isActive) {
        activeKeywordCount++;
        // B2: accumulate weighted score and total for active keywords only
        weightedScoreSum   += score * ss;
        weightedSizeSum    += ss;
        totalVolatilitySum += score;
        activeRecords.push({ keywordTargetId: target.id, query: target.query, volatilityScore: score, sampleSize: ss });
      }

      volatilitySum += score;
      if (score > maxVolatility) maxVolatility = score;

      if (score >= HIGH_THRESHOLD)        highVolatilityCount++;
      else if (score >= MEDIUM_THRESHOLD) mediumVolatilityCount++;
      else if (score >= 1)                lowVolatilityCount++;
      else                                stableCount++;

      const maturity = classifyMaturity(ss);
      if (maturity === "stable")          stableCountByMaturity++;
      else if (maturity === "developing") developingCount++;
      else                                preliminaryCount++;

      if (isActive && score >= alertThreshold) alertKeywordCount++;
    }

    const averageVolatility =
      Math.round((volatilitySum / keywordCount) * 100) / 100;

    const alertRatio = keywordCount > 0
      ? Math.round((alertKeywordCount / keywordCount) * 10000) / 10000
      : 0;

    // ── B2: weightedProjectVolatilityScore ───────────────────────────────────
    // 0.00 when no active keywords (SUM(sampleSize) = 0).
    const weightedProjectVolatilityScore =
      weightedSizeSum > 0
        ? Math.round((weightedScoreSum / weightedSizeSum) * 100) / 100
        : 0;

    // ── B2: top3RiskKeywords (deterministic sort, then slice) ────────────────
    // Sort: volatilityScore DESC, query ASC, keywordTargetId ASC
    activeRecords.sort((a, b) => {
      if (b.volatilityScore !== a.volatilityScore) return b.volatilityScore - a.volatilityScore;
      if (a.query !== b.query) return a.query.localeCompare(b.query);
      if (a.keywordTargetId < b.keywordTargetId) return -1;
      if (a.keywordTargetId > b.keywordTargetId) return 1;
      return 0;
    });

    const top3Records = activeRecords.slice(0, 3);

    const top3RiskKeywords = top3Records.map((r) => ({
      keywordTargetId:   r.keywordTargetId,
      query:             r.query,
      volatilityScore:   r.volatilityScore,
      volatilityRegime:  classifyRegime(r.volatilityScore),
      volatilityMaturity: classifyMaturity(r.sampleSize),
      exceedsThreshold:  r.volatilityScore >= alertThreshold,
    }));

    // ── B2: volatilityConcentrationRatio ─────────────────────────────────────
    // null when totalVolatilitySum = 0 (no signal to concentrate).
    let volatilityConcentrationRatio: number | null = null;
    if (totalVolatilitySum > 0) {
      const top3Sum = top3Records.reduce((acc, r) => acc + r.volatilityScore, 0);
      volatilityConcentrationRatio =
        Math.round((top3Sum / totalVolatilitySum) * 10000) / 10000;
    }

    return successResponse({
      windowDays,
      alertThreshold,
      alertKeywordCount,
      alertRatio,
      keywordCount,
      activeKeywordCount,
      averageVolatility,
      maxVolatility,
      highVolatilityCount,
      mediumVolatilityCount,
      lowVolatilityCount,
      stableCount,
      preliminaryCount,
      developingCount,
      stableCountByMaturity,
      // B2 additions
      weightedProjectVolatilityScore,
      volatilityConcentrationRatio,
      top3RiskKeywords,
    });
  } catch (err) {
    console.error("GET /api/seo/volatility-summary error:", err);
    return serverError();
  }
}
