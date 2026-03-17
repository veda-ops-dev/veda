/**
 * GET /api/seo/operator-insight — SIL-11 Operator Reasoning Layer
 *
 * Thin route handler. Responsibilities:
 *   1. Validate query params (Zod.strict)
 *   2. Resolve projectId
 *   3. Fetch KeywordTarget + SERPSnapshots (project-isolated)
 *   4. Compute volatility profile and evidence (computeVolatility, extractFeatureSortedArray)
 *   5. Call buildOperatorInsight() from src/lib/seo/operator-insight.ts
 *   6. Return JSON
 *
 * No writes. No EventLog. No mutations. Read-only surface.
 *
 * Isolation:  resolveProjectId() — cross-project access returns 404 (non-disclosure).
 * Determinism: identical snapshot set + params → identical response.
 *              computedAt is wall-clock only; excluded from determinism guarantees.
 */

import { NextRequest } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import {
  badRequest,
  notFound,
  serverError,
  successResponse,
} from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import {
  computeVolatility,
  classifyRegime,
  classifyMaturity,
} from "@/lib/seo/volatility-service";
import { extractFeatureSortedArray } from "@/lib/seo/serp-extraction";
import { buildOperatorInsight, type SpikeRecord } from "@/lib/seo/operator-insight";

// ─────────────────────────────────────────────────────────────────────────────
// Zod schema — strict, no extra params accepted
// ─────────────────────────────────────────────────────────────────────────────

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const QuerySchema = z
  .object({
    keywordTargetId: z
      .string()
      .regex(UUID_PATTERN, "keywordTargetId must be a valid UUID"),
    windowDays: z
      .string()
      .regex(/^\d+$/, "windowDays must be an integer")
      .transform(Number)
      .pipe(z.number().int().min(1).max(365))
      .optional()
      .default(60),
    topSpikes: z
      .string()
      .regex(/^\d+$/, "topSpikes must be an integer")
      .transform(Number)
      .pipe(z.number().int().min(1).max(20))
      .optional()
      .default(5),
  })
  .strict();

// ─────────────────────────────────────────────────────────────────────────────
// GET handler
// ─────────────────────────────────────────────────────────────────────────────

export async function GET(request: NextRequest) {
  try {
    const { projectId, error: projectError } = await resolveProjectId(request);
    if (projectError) return badRequest(projectError);

    // ── Validate query params ────────────────────────────────────────────────
    const sp = new URL(request.url).searchParams;
    const parsed = QuerySchema.safeParse({
      keywordTargetId: sp.get("keywordTargetId") ?? undefined,
      windowDays:      sp.get("windowDays")      ?? undefined,
      topSpikes:       sp.get("topSpikes")        ?? undefined,
    });
    if (!parsed.success) {
      return badRequest(parsed.error.issues[0]?.message ?? "Invalid parameters");
    }

    const { keywordTargetId, windowDays, topSpikes } = parsed.data;

    // Single requestTime anchor — windowStart is stable for this request
    const requestTime = new Date();
    const windowStart = new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000);

    // ── Resolve KeywordTarget (404 non-disclosure on cross-project) ──────────
    const keywordTarget = await prisma.keywordTarget.findUnique({
      where:  { id: keywordTargetId },
      select: { id: true, projectId: true, query: true, locale: true, device: true },
    });

    if (!keywordTarget || keywordTarget.projectId !== projectId) {
      return notFound("KeywordTarget not found");
    }

    const { query, locale, device } = keywordTarget;

    // ── Load snapshots: project-scoped, window-filtered, deterministic order ─
    const snapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        query,
        locale,
        device,
        capturedAt: { gte: windowStart },
      },
      orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
      select: {
        id:               true,
        capturedAt:       true,
        aiOverviewStatus: true,
        rawPayload:       true,
      },
    });

    // ── Volatility profile ───────────────────────────────────────────────────
    const profile  = computeVolatility(snapshots);
    const regime   = classifyRegime(profile.volatilityScore);
    const maturity = classifyMaturity(profile.sampleSize);

    // ── Spikes: top-N pairs by pairVolatilityScore DESC, capturedAt DESC, id DESC ──
    // Reuses computeVolatility([A,B]) — same formula as volatility-spikes endpoint.
    const spikes: SpikeRecord[] = [];
    if (snapshots.length >= 2) {
      interface PairCandidate {
        capturedAt: string;
        capturedAtMs: number;
        toId: string;
        magnitude: number;
      }
      const candidates: PairCandidate[] = [];

      for (let i = 0; i < snapshots.length - 1; i++) {
        const A = snapshots[i];
        const B = snapshots[i + 1];
        const pairProfile = computeVolatility([A, B]);
        candidates.push({
          capturedAt:   B.capturedAt.toISOString(),
          capturedAtMs: B.capturedAt.getTime(),
          toId:         B.id,
          magnitude:    pairProfile.volatilityScore,
        });
      }

      // Sort: magnitude DESC, capturedAt DESC, toId DESC (fully deterministic)
      candidates.sort((a, b) => {
        if (b.magnitude !== a.magnitude) return b.magnitude - a.magnitude;
        if (b.capturedAtMs !== a.capturedAtMs) return b.capturedAtMs - a.capturedAtMs;
        if (b.toId > a.toId) return 1;
        if (b.toId < a.toId) return -1;
        return 0;
      });

      for (const c of candidates.slice(0, topSpikes)) {
        spikes.push({ capturedAt: c.capturedAt, magnitude: c.magnitude });
      }
    }

    // ── Feature transitions: count of consecutive pairs with changed feature set ──
    // Reuses extractFeatureSortedArray — same as feature-transitions endpoint.
    let featureTransitions = 0;
    if (snapshots.length >= 2) {
      for (let i = 0; i < snapshots.length - 1; i++) {
        const fromKey = extractFeatureSortedArray(snapshots[i].rawPayload).join(",");
        const toKey   = extractFeatureSortedArray(snapshots[i + 1].rawPayload).join(",");
        if (fromKey !== toKey) featureTransitions++;
      }
    }

    // ── Call pure library function ───────────────────────────────────────────
    const insight = buildOperatorInsight({
      keywordTargetId,
      query,
      locale,
      device,
      windowDays,

      volatilityScore:            profile.volatilityScore,
      regime,
      maturity,
      sampleSize:                 profile.sampleSize,
      snapshotCount:              snapshots.length,
      rankVolatilityComponent:    profile.rankVolatilityComponent,
      aiOverviewComponent:        profile.aiOverviewComponent,
      featureVolatilityComponent: profile.featureVolatilityComponent,
      aiOverviewChurn:            profile.aiOverviewChurn,

      spikes,
      featureTransitions,
    });

    return successResponse({ ...insight, computedAt: requestTime.toISOString() });
  } catch (err) {
    console.error("GET /api/seo/operator-insight error:", err);
    return serverError();
  }
}
