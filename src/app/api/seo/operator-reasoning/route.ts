/**
 * GET /api/seo/operator-reasoning — SIL-11 Project-Level Operator Reasoning
 *
 * Thin route handler. Responsibilities:
 *   1. Validate query params (Zod.strict)
 *   2. Resolve projectId
 *   3. Load KeywordTargets + SERPSnapshots (project-isolated, O(K×S))
 *   4. Compute per-keyword volatility profiles using computeVolatility()
 *   5. Compute project-level aggregates (mirrors SIL-4 logic inline)
 *   6. Call computeOperatorReasoning() from src/lib/seo/reasoning/operator-reasoning.ts
 *   7. Return JSON
 *
 * No writes. No EventLog. No mutations. Read-only surface.
 *
 * Isolation:  resolveProjectId() — cross-project access returns 404 (non-disclosure).
 * Determinism: identical snapshot set + params → identical response.
 *              No wall-clock fields in the output payload.
 *
 * Query params:
 *   windowDays     optional int (1–365), default 60
 *   alertThreshold optional int (0–100), default 60
 */

import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import {
  computeVolatility,
  classifyRegime,
} from "@/lib/seo/volatility-service";
import {
  computeOperatorReasoning,
  type KeywordSummary,
  type ProjectVolatilitySummary,
} from "@/lib/seo/reasoning/operator-reasoning";

// ─────────────────────────────────────────────────────────────────────────────
// Validation schema
// ─────────────────────────────────────────────────────────────────────────────

const QuerySchema = z
  .object({
    windowDays:     z.coerce.number().int().min(1).max(365).default(60),
    alertThreshold: z.coerce.number().int().min(0).max(100).default(60),
  })
  .strict();

// ─────────────────────────────────────────────────────────────────────────────
// GET handler
// ─────────────────────────────────────────────────────────────────────────────

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    // ── Validate query params ─────────────────────────────────────────────────
    const rawParams = Object.fromEntries(new URL(request.url).searchParams.entries());
    const parsed = QuerySchema.safeParse(rawParams);
    if (!parsed.success) {
      const msgs = parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ");
      return badRequest(`Validation failed: ${msgs}`);
    }
    const { windowDays, alertThreshold } = parsed.data;

    // Fix requestTime once — window boundary is stable for this request.
    const requestTime = new Date();
    const windowStart = new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000);

    // ── Load KeywordTargets (deterministic order) ─────────────────────────────
    const targets = await prisma.keywordTarget.findMany({
      where:   { projectId },
      orderBy: [{ query: "asc" }, { id: "asc" }],
      select:  { id: true, query: true, locale: true, device: true },
    });

    // ── Load all SERPSnapshots for the project in one query ───────────────────
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

    // ── Group snapshots by (query, locale, device) ────────────────────────────
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

    // ── Compute per-keyword profiles ──────────────────────────────────────────
    const keywords: KeywordSummary[] = [];

    // Project-level accumulators (mirrors SIL-4 pattern)
    let activeKeywordCount      = 0;
    let alertKeywordCount       = 0;
    let volatilitySum           = 0;
    let maxVolatility           = 0;
    let weightedScoreSum        = 0;
    let weightedSizeSum         = 0;
    let totalVolatilitySum      = 0;
    let highVolatilityCount     = 0;

    interface ActiveRecord {
      keywordTargetId: string;
      query:           string;
      volatilityScore: number;
      sampleSize:      number;
    }
    const activeRecords: ActiveRecord[] = [];

    for (const target of targets) {
      const key       = `${target.query}\0${target.locale}\0${target.device}`;
      const snapshots = snapshotMap.get(key) ?? [];
      const profile   = computeVolatility(snapshots);

      const score  = profile.volatilityScore;
      const ss     = profile.sampleSize;
      const active = ss >= 1;

      volatilitySum += score;
      if (score > maxVolatility) maxVolatility = score;
      if (score > 70) highVolatilityCount++;

      if (active) {
        activeKeywordCount++;
        weightedScoreSum   += score * ss;
        weightedSizeSum    += ss;
        totalVolatilitySum += score;
        activeRecords.push({ keywordTargetId: target.id, query: target.query, volatilityScore: score, sampleSize: ss });

        if (score >= alertThreshold) alertKeywordCount++;

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
      ? Math.round((alertKeywordCount / keywordCount) * 10000) / 10000
      : 0;
    const weightedProjectVolatilityScore = weightedSizeSum > 0
      ? Math.round((weightedScoreSum / weightedSizeSum) * 100) / 100
      : 0;

    // B2 concentration ratio (same formula as SIL-4)
    activeRecords.sort((a, b) => {
      if (b.volatilityScore !== a.volatilityScore) return b.volatilityScore - a.volatilityScore;
      if (a.query !== b.query) return a.query.localeCompare(b.query);
      return a.keywordTargetId.localeCompare(b.keywordTargetId);
    });
    let volatilityConcentrationRatio: number | null = null;
    if (totalVolatilitySum > 0) {
      const top3Sum = activeRecords.slice(0, 3).reduce((acc, r) => acc + r.volatilityScore, 0);
      volatilityConcentrationRatio = Math.round((top3Sum / totalVolatilitySum) * 10000) / 10000;
    }

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

    // keywords[] is already in query asc, id asc order (target load order).

    // ── Call pure reasoning engine ────────────────────────────────────────────
    const reasoning = computeOperatorReasoning({
      projectId,
      windowDays,
      summary,
      keywords,
    });

    return successResponse({
      projectId,
      windowDays,
      alertThreshold,
      summary: {
        keywordCount,
        activeKeywordCount,
        averageVolatility,
        maxVolatility,
        alertKeywordCount,
        alertRatio,
        weightedProjectVolatilityScore,
        volatilityConcentrationRatio,
      },
      observations:       reasoning.observations,
      hypotheses:         reasoning.hypotheses,
      recommendedActions: reasoning.recommendedActions,
    });
  } catch (err) {
    console.error("GET /api/seo/operator-reasoning error:", err);
    return serverError();
  }
}
