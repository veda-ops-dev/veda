/**
 * GET /api/seo/risk-attribution-summary — SIL-10: Temporal Risk Attribution Summary
 *
 * Aggregates SIL-7 volatility attribution components (rankVolatilityComponent,
 * aiOverviewComponent, featureVolatilityComponent) across KeywordTargets and
 * partitions the results into temporal buckets to show how the risk mix shifts
 * over time.
 *
 * No new math. No schema changes. Compute-on-read only. Deterministic.
 * No EventLog (read-only endpoint).
 *
 * Query params:
 *   windowDays   optional int (1–365),  default: 30
 *   bucketDays   optional int (1–30),   default: 7
 *   minMaturity  optional enum ("preliminary" | "developing" | "stable"), default: "preliminary"
 *   limit        optional int (1–500),  default: 200  (KeywordTargets processed)
 *
 * Isolation: resolveProjectId() — headers only.
 * Ordering: keywordTargets [query asc, id asc]; snapshots [capturedAt asc, id asc].
 * Buckets: half-open [start, end) intervals, chronological order (oldest → newest).
 */

import { z } from "zod";
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import {
  computeVolatility,
  classifyMaturity,
  VolatilityMaturity,
} from "@/lib/seo/volatility-service";

// ─────────────────────────────────────────────────────────────────────────────
// Validation schema
// ─────────────────────────────────────────────────────────────────────────────

const MATURITY_VALUES = ["preliminary", "developing", "stable"] as const;

const QuerySchema = z
  .object({
    windowDays:  z.coerce.number().int().min(1).max(365).default(30),
    bucketDays:  z.coerce.number().int().min(1).max(30).default(7),
    minMaturity: z.enum(MATURITY_VALUES).default("preliminary"),
    limit:       z.coerce.number().int().min(1).max(500).default(200),
  })
  .strict();

// ─────────────────────────────────────────────────────────────────────────────
// Maturity ordering for threshold comparison
// ─────────────────────────────────────────────────────────────────────────────

const MATURITY_RANK: Record<VolatilityMaturity, number> = {
  preliminary: 0,
  developing:  1,
  stable:      2,
};

// ─────────────────────────────────────────────────────────────────────────────
// Bucket construction
// ─────────────────────────────────────────────────────────────────────────────

interface TimeBucket {
  start: Date;
  end:   Date;
}

/**
 * Build half-open [start, end) buckets of bucketDays days ending at requestTime.
 * Returned in chronological order (oldest → newest).
 * Example: windowDays=30, bucketDays=7 → 5 buckets where the last ends at requestTime.
 */
function buildBuckets(requestTime: Date, windowDays: number, bucketDays: number): TimeBucket[] {
  const windowMs = windowDays * 24 * 60 * 60 * 1000;
  const bucketMs = bucketDays * 24 * 60 * 60 * 1000;
  const windowStart = new Date(requestTime.getTime() - windowMs);

  const buckets: TimeBucket[] = [];
  let current = windowStart.getTime();

  while (current < requestTime.getTime()) {
    const bucketEnd = Math.min(current + bucketMs, requestTime.getTime());
    buckets.push({ start: new Date(current), end: new Date(bucketEnd) });
    current = bucketEnd;
  }

  return buckets;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

// ─────────────────────────────────────────────────────────────────────────────
// Snapshot type (minimal fields for computeVolatility)
// ─────────────────────────────────────────────────────────────────────────────

interface SnapRow {
  id:               string;
  capturedAt:       Date;
  aiOverviewStatus: string;
  rawPayload:       unknown;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET handler
// ─────────────────────────────────────────────────────────────────────────────

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    // ── Parse + validate query params ─────────────────────────────────────────
    const rawParams = Object.fromEntries(new URL(request.url).searchParams.entries());
    const parsed = QuerySchema.safeParse(rawParams);
    if (!parsed.success) {
      const msgs = parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ");
      return badRequest(`Validation failed: ${msgs}`);
    }
    const { windowDays, bucketDays, minMaturity, limit } = parsed.data;

    // Anchor requestTime to the start of the current minute so sequential calls
    // produce identical bucket boundaries (hammer determinism).
    const requestTimeMs = Math.floor(Date.now() / 60_000) * 60_000;
    const requestTime = new Date(requestTimeMs);
    const windowStart = new Date(requestTime.getTime() - windowDays * 24 * 60 * 60 * 1000);

    // ── Load KeywordTargets (deterministic order, capped at limit) ─────────────
    const targets = await prisma.keywordTarget.findMany({
      where: { projectId },
      orderBy: [{ query: "asc" }, { id: "asc" }],
      take: limit,
      select: { id: true, query: true, locale: true, device: true },
    });

    // ── Load all SERPSnapshots for the full window in one query ────────────────
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

    // ── Group snapshots by (query, locale, device) ─────────────────────────────
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

    // ── Build temporal buckets ─────────────────────────────────────────────────
    const buckets = buildBuckets(requestTime, windowDays, bucketDays);

    const minMaturityRank = MATURITY_RANK[minMaturity];

    // ── Compute attribution per bucket ────────────────────────────────────────
    const bucketResults = buckets.map((timeBucket) => {
      let totalWeight     = 0;
      let rankWeighted    = 0;
      let aiWeighted      = 0;
      let featureWeighted = 0;
      let includedKeywordCount = 0;

      for (const target of targets) {
        const key = `${target.query}\0${target.locale}\0${target.device}`;
        const allSnaps = snapshotMap.get(key) ?? [];

        // Filter to snapshots within this bucket [start, end)
        const bucketSnaps = allSnaps.filter(
          (s) => s.capturedAt >= timeBucket.start && s.capturedAt < timeBucket.end
        );

        // Need at least 2 snapshots to form a pair
        if (bucketSnaps.length < 2) continue;

        const profile = computeVolatility(bucketSnaps);
        const maturity = classifyMaturity(profile.sampleSize);
        const maturityRank = MATURITY_RANK[maturity];

        // Skip if below minMaturity threshold
        if (maturityRank < minMaturityRank) continue;

        const weight = profile.sampleSize;
        totalWeight     += weight;
        rankWeighted    += profile.rankVolatilityComponent * weight;
        aiWeighted      += profile.aiOverviewComponent * weight;
        featureWeighted += profile.featureVolatilityComponent * weight;
        includedKeywordCount++;
      }

      if (totalWeight === 0) {
        return {
          start:                timeBucket.start.toISOString(),
          end:                  timeBucket.end.toISOString(),
          includedKeywordCount: 0,
          totalWeight:          0,
          rankShare:            null,
          aiShare:              null,
          featureShare:         null,
          sumCheck:             null,
        };
      }

      const componentTotal = rankWeighted + aiWeighted + featureWeighted;
      if (componentTotal === 0) {
        return {
          start:                timeBucket.start.toISOString(),
          end:                  timeBucket.end.toISOString(),
          includedKeywordCount,
          totalWeight,
          rankShare:            null,
          aiShare:              null,
          featureShare:         null,
          sumCheck:             null,
        };
      }

      // Normalize to percentages that sum to ~100.
      const rankShare    = round2((rankWeighted    / componentTotal) * 100);
      const aiShare      = round2((aiWeighted      / componentTotal) * 100);
      const featureShare = round2((featureWeighted / componentTotal) * 100);
      const sumCheck     = round2(rankShare + aiShare + featureShare);

      return {
        start:                timeBucket.start.toISOString(),
        end:                  timeBucket.end.toISOString(),
        includedKeywordCount,
        totalWeight,
        rankShare,
        aiShare,
        featureShare,
        sumCheck,
      };
    });

    return successResponse({
      windowDays,
      bucketDays,
      minMaturity,
      keywordLimit: limit,
      buckets: bucketResults,
    });
  } catch (err) {
    console.error("GET /api/seo/risk-attribution-summary error:", err);
    return serverError();
  }
}
