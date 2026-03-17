/**
 * GET /api/seo/operator-briefing -- Operator Briefing Packet
 *
 * Aggregates SIL-4 (volatility summary), SIL-5 (top alerts), SIL-10
 * (risk attribution), SIL-11 (operator reasoning), and optional SIL-2
 * (SERP deltas) into a single structured briefing packet, including a
 * deterministic promptText string ready for LLM consumption.
 *
 * No writes. No EventLog. No mutations. Read-only surface.
 *
 * Isolation:  resolveProjectId() -- headers only; cross-project -> 400.
 * Determinism: requestTime anchored to current minute boundary so all
 *              window calculations are stable across sequential calls.
 *              promptText contains no wall-clock data.
 *
 * Query params (zod.strict -- unknown params -> 400):
 *   windowDays     int 1-365,  default 60
 *   alertThreshold int 0-100,  default 60
 *   limitAlerts    int 1-200,  default 50
 *   limitDeltas    int 0-200,  default 0 (0 = omit delta section)
 */

import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import {
  computeVolatility,
  classifyMaturity,
  classifyRegime,
  type VolatilityMaturity,
} from "@/lib/seo/volatility-service";
import { extractOrganicResults } from "@/lib/seo/serp-extraction";
import {
  computeOperatorReasoning,
  type KeywordSummary,
  type ProjectVolatilitySummary,
} from "@/lib/seo/reasoning/operator-reasoning";
import {
  buildOperatorBriefingPromptText,
  type BriefingAlertItem,
  type BriefingDeltaItem,
  type BriefingProjectSummary,
  type RiskAttributionSummary,
} from "@/lib/seo/briefing/operator-briefing";

// -----------------------------------------------------------------------------
// Validation schema -- .strict() rejects unknown params before coercion runs
// -----------------------------------------------------------------------------

const QuerySchema = z
  .object({
    windowDays:     z.coerce.number().int().min(1).max(365).default(60),
    alertThreshold: z.coerce.number().int().min(0).max(100).default(60),
    limitAlerts:    z.coerce.number().int().min(1).max(200).default(50),
    limitDeltas:    z.coerce.number().int().min(0).max(200).default(0),
  })
  .strict();

// -----------------------------------------------------------------------------
// Maturity ordering helper
// -----------------------------------------------------------------------------

const MATURITY_RANK: Record<VolatilityMaturity, number> = {
  preliminary: 0,
  developing:  1,
  stable:      2,
};

// -----------------------------------------------------------------------------
// Inline delta computation
//
// Reuses already-loaded snapshot data; computes the last consecutive pair
// for each alerting keyword without additional DB queries.
// extractOrganicResults is the same function used by SIL-2.
// -----------------------------------------------------------------------------

type SnapRow = {
  id:               string;
  capturedAt:       Date;
  aiOverviewStatus: string;
  rawPayload:       unknown;
};

function computeInlineDelta(
  keywordTargetId: string,
  query: string,
  snapshots: SnapRow[]
): BriefingDeltaItem | null {
  // snapshots are pre-sorted capturedAt ASC, id ASC
  if (snapshots.length < 2) return null;

  const from = snapshots[snapshots.length - 2];
  const to   = snapshots[snapshots.length - 1];

  const fromResults = extractOrganicResults(from.rawPayload).results;
  const toResults   = extractOrganicResults(to.rawPayload).results;

  const fromUrls = new Set(fromResults.map((r) => r.url));
  const toUrls   = new Set(toResults.map((r) => r.url));

  // Build rank maps (first-wins for duplicate URLs -- results already sorted rank asc)
  const fromMap = new Map<string, number | null>();
  for (const r of fromResults) { if (!fromMap.has(r.url)) fromMap.set(r.url, r.rank); }
  const toMap = new Map<string, number | null>();
  for (const r of toResults)   { if (!toMap.has(r.url))   toMap.set(r.url, r.rank); }

  let enteredCount = 0;
  let exitedCount  = 0;
  let movedCount   = 0;

  // Entered: in toUrls but not fromUrls
  for (const url of toUrls) { if (!fromUrls.has(url)) enteredCount++; }
  // Exited: in fromUrls but not toUrls
  for (const url of fromUrls) { if (!toUrls.has(url)) exitedCount++; }
  // Moved: in both, both ranks non-null, ranks differ
  for (const [url, fromRank] of fromMap) {
    if (!toMap.has(url)) continue;
    const toRank = toMap.get(url) ?? null;
    if (fromRank !== null && toRank !== null && fromRank !== toRank) movedCount++;
  }

  const aiOverviewFlipped = from.aiOverviewStatus !== to.aiOverviewStatus;

  return {
    keywordTargetId,
    query,
    toSnapshotCapturedAt: to.capturedAt.toISOString(),
    enteredCount,
    exitedCount,
    movedCount,
    aiOverviewFlipped,
  };
}

// -----------------------------------------------------------------------------
// GET handler
// -----------------------------------------------------------------------------

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    // Validate params -- unknown params produce 400 via .strict()
    const rawParams = Object.fromEntries(new URL(request.url).searchParams.entries());
    const parsed = QuerySchema.safeParse(rawParams);
    if (!parsed.success) {
      const msgs = parsed.error.issues
        .map((i) => `${i.path.join(".")}: ${i.message}`)
        .join("; ");
      return badRequest(`Validation failed: ${msgs}`);
    }
    const { windowDays, alertThreshold, limitAlerts, limitDeltas } = parsed.data;

    // Single requestTime anchor -- floor to current minute for hammer determinism.
    // All window boundaries derive from this single value; no second Date.now() call.
    const requestTimeMs = Math.floor(Date.now() / 60_000) * 60_000;
    const requestTime   = new Date(requestTimeMs);
    const windowStart   = new Date(requestTimeMs - windowDays * 24 * 60 * 60 * 1000);

    // -------------------------------------------------------------------------
    // DB: load KeywordTargets + SERPSnapshots in two queries (O(K*S) pattern)
    // -------------------------------------------------------------------------

    const targets = await prisma.keywordTarget.findMany({
      where:   { projectId },
      orderBy: [{ query: "asc" }, { id: "asc" }],
      select:  { id: true, query: true, locale: true, device: true },
    });

    const allSnapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        capturedAt: { gte: windowStart },
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

    // Group snapshots by natural key (query + locale + device)
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

    // -------------------------------------------------------------------------
    // Compute per-keyword profiles + project-level aggregates
    // -------------------------------------------------------------------------

    // keywords[] will be passed to computeOperatorReasoning; explicitly sorted below.
    const keywords: KeywordSummary[] = [];

    // Alert candidates (all keywords exceeding threshold with sampleSize >= 1)
    interface AlertCandidate {
      keywordTargetId: string;
      query:           string;
      locale:          string;
      device:          string;
      volatilityScore: number;
      volatilityRegime: string;
      maturity:        VolatilityMaturity;
      sampleSize:      number;
      rankVolatilityComponent: number;
      aiOverviewComponent: number;
      featureVolatilityComponent: number;
    }
    const alertCandidates: AlertCandidate[] = [];

    // Concentration computation accumulators
    interface ActiveRecord {
      keywordTargetId: string;
      query:           string;
      volatilityScore: number;
      sampleSize:      number;
    }
    const activeRecords: ActiveRecord[] = [];

    let activeKeywordCount  = 0;
    let alertKeywordCount   = 0;
    let volatilitySum       = 0;
    let maxVolatility       = 0;
    let weightedScoreSum    = 0;
    let weightedSizeSum     = 0;
    let totalVolatilitySum  = 0;
    let highVolatilityCount = 0;

    for (const target of targets) {
      const key       = `${target.query}\0${target.locale}\0${target.device}`;
      const snapshots = snapshotMap.get(key) ?? [];
      const profile   = computeVolatility(snapshots);

      const score    = profile.volatilityScore;
      const ss       = profile.sampleSize;
      const isActive = ss >= 1;

      volatilitySum += score;
      if (score > maxVolatility) maxVolatility = score;
      if (score > 70) highVolatilityCount++;

      if (isActive) {
        activeKeywordCount++;
        weightedScoreSum   += score * ss;
        weightedSizeSum    += ss;
        totalVolatilitySum += score;
        activeRecords.push({
          keywordTargetId: target.id,
          query:           target.query,
          volatilityScore: score,
          sampleSize:      ss,
        });

        if (score >= alertThreshold) {
          alertKeywordCount++;
          alertCandidates.push({
            keywordTargetId:            target.id,
            query:                      target.query,
            locale:                     target.locale,
            device:                     target.device,
            volatilityScore:            score,
            volatilityRegime:           classifyRegime(score),
            maturity:                   classifyMaturity(ss),
            sampleSize:                 ss,
            rankVolatilityComponent:    profile.rankVolatilityComponent,
            aiOverviewComponent:        profile.aiOverviewComponent,
            featureVolatilityComponent: profile.featureVolatilityComponent,
          });
        }

        keywords.push({
          keywordTargetId:            target.id,
          query:                      target.query,
          volatilityScore:            score,
          volatilityRegime:           classifyRegime(score),
          sampleSize:                 ss,
          aiOverviewChurn:            profile.aiOverviewChurn,
          rankVolatilityComponent:    profile.rankVolatilityComponent,
          aiOverviewComponent:        profile.aiOverviewComponent,
          featureVolatilityComponent: profile.featureVolatilityComponent,
        });
      }
    }

    const keywordCount      = targets.length;
    const averageVolatility = keywordCount > 0
      ? Math.round((volatilitySum / keywordCount) * 100) / 100
      : 0;
    const alertRatio = keywordCount > 0
      ? Math.round((alertKeywordCount / keywordCount) * 10_000) / 10_000
      : 0;
    const weightedProjectVolatilityScore = weightedSizeSum > 0
      ? Math.round((weightedScoreSum / weightedSizeSum) * 100) / 100
      : 0;

    // Concentration ratio (B2 formula -- same as SIL-4)
    activeRecords.sort((a, b) => {
      if (b.volatilityScore !== a.volatilityScore) return b.volatilityScore - a.volatilityScore;
      if (a.query !== b.query) return a.query.localeCompare(b.query);
      return a.keywordTargetId.localeCompare(b.keywordTargetId);
    });
    let volatilityConcentrationRatio: number | null = null;
    if (totalVolatilitySum > 0) {
      const top3Sum = activeRecords
        .slice(0, 3)
        .reduce((acc, r) => acc + r.volatilityScore, 0);
      volatilityConcentrationRatio =
        Math.round((top3Sum / totalVolatilitySum) * 10_000) / 10_000;
    }

    // -------------------------------------------------------------------------
    // topAlerts -- deterministic 3-key sort, capped to limitAlerts
    // -------------------------------------------------------------------------

    alertCandidates.sort((a, b) => {
      if (b.volatilityScore !== a.volatilityScore) return b.volatilityScore - a.volatilityScore;
      const qCmp = a.query.localeCompare(b.query);
      if (qCmp !== 0) return qCmp;
      return a.keywordTargetId.localeCompare(b.keywordTargetId);
    });

    const topAlerts: BriefingAlertItem[] = alertCandidates
      .slice(0, limitAlerts)
      .map((c) => ({
        keywordTargetId:            c.keywordTargetId,
        query:                      c.query,
        locale:                     c.locale,
        device:                     c.device,
        volatilityScore:            c.volatilityScore,
        volatilityRegime:           c.volatilityRegime,
        sampleSize:                 c.sampleSize,
        rankVolatilityComponent:    c.rankVolatilityComponent,
        aiOverviewComponent:        c.aiOverviewComponent,
        featureVolatilityComponent: c.featureVolatilityComponent,
      }));

    // -------------------------------------------------------------------------
    // Risk attribution summary -- weighted mean of SIL-7 components
    // Mirrors SIL-10 logic; uses the same snapshot data already in memory.
    // Single bucket covering the full window (no temporal bucketing here).
    // -------------------------------------------------------------------------

    let riskAttributionSummary: RiskAttributionSummary | null = null;
    {
      let totalWeight  = 0;
      let rankWeighted = 0;
      let aiWeighted   = 0;
      let featWeighted = 0;

      for (const kw of keywords) {
        const w = kw.sampleSize;
        totalWeight  += w;
        rankWeighted += kw.rankVolatilityComponent * w;
        aiWeighted   += kw.aiOverviewComponent * w;
        featWeighted += kw.featureVolatilityComponent * w;
      }

      if (totalWeight > 0) {
        const componentTotal = rankWeighted + aiWeighted + featWeighted;
        if (componentTotal > 0) {
          const round2 = (n: number) => Math.round(n * 100) / 100;
          const rankShare    = round2((rankWeighted / componentTotal) * 100);
          const aiShare      = round2((aiWeighted   / componentTotal) * 100);
          const featureShare = round2((featWeighted / componentTotal) * 100);
          riskAttributionSummary = { rankPercent: rankShare, aiPercent: aiShare, featurePercent: featureShare };
        } else {
          riskAttributionSummary = { rankPercent: null, aiPercent: null, featurePercent: null };
        }
      }
    }

    // -------------------------------------------------------------------------
    // Operator reasoning (SIL-11) -- keywords must be explicitly sorted
    // -------------------------------------------------------------------------

    // Explicit sort: query ASC, keywordTargetId ASC -- do not rely on load order
    keywords.sort((a, b) => {
      const qCmp = a.query.localeCompare(b.query);
      if (qCmp !== 0) return qCmp;
      return a.keywordTargetId.localeCompare(b.keywordTargetId);
    });

    const summary: ProjectVolatilitySummary = {
      keywordCount,
      activeKeywordCount,
      averageVolatility,
      maxVolatility,
      highVolatilityCount,
      alertKeywordCount,
      alertRatio,
      alertThreshold,
      weightedProjectVolatilityScore,
      volatilityConcentrationRatio,
    };

    const operatorReasoning = computeOperatorReasoning({
      projectId,
      windowDays,
      summary,
      keywords,
    });

    // -------------------------------------------------------------------------
    // Optional deltas -- inline computation from snapshot data already in memory.
    // Only computed for the top-N alerting keywords (by the already-sorted
    // alertCandidates list) to cap work at O(limitDeltas * S).
    // -------------------------------------------------------------------------

    const deltas: BriefingDeltaItem[] = [];
    if (limitDeltas > 0) {
      const deltaTargets = alertCandidates.slice(0, limitDeltas);
      for (const candidate of deltaTargets) {
        const key       = `${candidate.query}\0${candidate.locale}\0${candidate.device}`;
        const snapshots = snapshotMap.get(key) ?? [];
        const delta     = computeInlineDelta(candidate.keywordTargetId, candidate.query, snapshots);
        if (delta !== null) deltas.push(delta);
      }
      // deltas inherit the alert sort order (volatility DESC, query ASC, id ASC) -- deterministic
    }

    // -------------------------------------------------------------------------
    // Build briefing summary shape (no highVolatilityCount in external summary)
    // -------------------------------------------------------------------------

    const briefingSummary: BriefingProjectSummary = {
      keywordCount,
      activeKeywordCount,
      averageVolatility,
      maxVolatility,
      alertKeywordCount,
      alertRatio,
      alertThreshold,
      weightedProjectVolatilityScore,
      volatilityConcentrationRatio,
    };

    // -------------------------------------------------------------------------
    // Build promptText -- pure function, no wall-clock data
    // -------------------------------------------------------------------------

    const promptText = buildOperatorBriefingPromptText({
      projectId,
      windowDays,
      alertThreshold,
      summary: briefingSummary,
      topAlerts,
      riskAttributionSummary,
      operatorReasoning,
      deltas,
    });

    // -------------------------------------------------------------------------
    // Response
    // -------------------------------------------------------------------------

    return successResponse({
      projectId,
      windowDays,
      alertThreshold,
      summary: briefingSummary,
      topAlerts,
      riskAttributionSummary,
      operatorReasoning,
      deltas,
      promptText,
    });
  } catch (err) {
    console.error("GET /api/seo/operator-briefing error:", err);
    return serverError();
  }
}
