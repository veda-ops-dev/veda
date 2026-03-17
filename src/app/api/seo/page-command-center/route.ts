/**
 * GET /api/seo/page-command-center — Page Command Center Lite
 *
 * Read-only compute-on-read observatory surface. Returns a structured
 * page-oriented packet synthesizing editor/page context with existing
 * observatory data (keyword targets, volatility signals, route-text overlaps).
 *
 * No writes. No EventLog. No mutations. No Content Graph. No materialized tables.
 *
 * Isolation:  resolveProjectId() — headers only; cross-project → 400.
 * Determinism: all arrays explicitly sorted with tie-breakers on id.
 *
 * Query params (zod.strict — unknown params → 400):
 *   routeHint      string, optional  — route path hint (e.g. "/news/[slug]")
 *   fileName       string, optional  — file name (e.g. "page.tsx")
 *   fileType       string, optional  — file type hint (e.g. "page")
 *   limitKeywords  int 1-20, default 3  — max top risk keywords
 *   limitOverlaps  int 1-50, default 5  — max route-text overlap matches
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
} from "@/lib/seo/volatility-service";
import {
  tokenizeRouteHint,
  tokenizeFileName,
  computeRouteTextOverlaps,
  isPageRelevant,
  type KeywordOverlapCandidate,
} from "@/lib/seo/page-command-center";
import { computeSerpObservatory } from "@/lib/seo/serp-observatory";

// -----------------------------------------------------------------------------
// Query param validation — .strict() rejects unknown params
// -----------------------------------------------------------------------------

const QuerySchema = z
  .object({
    routeHint:     z.string().max(500).optional(),
    fileName:      z.string().max(200).optional(),
    fileType:      z.string().max(50).optional(),
    limitKeywords: z.coerce.number().int().min(1).max(20).default(3),
    limitOverlaps: z.coerce.number().int().min(1).max(50).default(5),
  })
  .strict();

// -----------------------------------------------------------------------------
// Available actions — static UI contract metadata (no mutation actions)
// -----------------------------------------------------------------------------

const AVAILABLE_ACTIONS = [
  { action: "project_investigation", label: "Run Project Investigation" },
  { action: "keyword_diagnostic", label: "Run Keyword Diagnostic" },
  { action: "page_keyword_diagnostic", label: "Choose Project Keyword Diagnostic" },
] as const;

// -----------------------------------------------------------------------------
// GET handler
// -----------------------------------------------------------------------------

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    // ── Validate query params ─────────────────────────────────────────────
    const rawParams = Object.fromEntries(
      new URL(request.url).searchParams.entries()
    );
    const parsed = QuerySchema.safeParse(rawParams);
    if (!parsed.success) {
      const msgs = parsed.error.issues
        .map((i) => `${i.path.join(".")}: ${i.message}`)
        .join("; ");
      return badRequest(`Validation failed: ${msgs}`);
    }

    const {
      routeHint = null,
      fileName = null,
      fileType = null,
      limitKeywords,
      limitOverlaps,
    } = parsed.data;

    // ── Load project metadata ─────────────────────────────────────────────
    const project = await prisma.project.findUnique({
      where: { id: projectId },
      select: { id: true, name: true, slug: true, description: true },
    });

    if (!project) {
      // 404 non-disclosure — project not found
      return badRequest("Project not found");
    }

    // ── Load keyword targets ──────────────────────────────────────────────
    const targets = await prisma.keywordTarget.findMany({
      where: { projectId },
      orderBy: [{ query: "asc" }, { id: "asc" }],
      select: { id: true, query: true, locale: true, device: true },
    });

    // ── Short-circuit if no keyword targets ───────────────────────────────
    if (targets.length === 0) {
      return successResponse({
        pageContext: {
          routeHint,
          fileName,
          fileType,
          isPageRelevant: isPageRelevant(routeHint, fileName, fileType),
        },
        projectContext: {
          projectId: project.id,
          projectName: project.name,
          projectSlug: project.slug,
        },
        observatorySummary: {
          hasRiskSignals: false,
          topRiskKeywordCount: 0,
          routeTextOverlapCount: 0,
        },
        serpObservatory: {
          volatilityLevel: "stable",
          recentRankTurbulence: false,
          aiOverviewActivity: "none",
          dominantSerpFeatures: [],
          recentEvents: [],
        },
        topRiskKeywords: [],
        routeTextKeywordMatches: [],
        availableActions: [...AVAILABLE_ACTIONS],
        notes: [
          "No keyword targets configured for this project.",
          "No page analysis has been performed.",
        ],
      });
    }

    // ── Load snapshots for volatility computation ─────────────────────────
    // Default 60-day window (same as operator-briefing default)
    const WINDOW_DAYS = 60;
    const requestTimeMs = Date.now();
    const windowStart = new Date(
      requestTimeMs - WINDOW_DAYS * 24 * 60 * 60 * 1000
    );

    const allSnapshots = await prisma.sERPSnapshot.findMany({
      where: {
        projectId,
        capturedAt: { gte: windowStart },
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

    // Group snapshots by natural key
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
      if (!bucket) {
        bucket = [];
        snapshotMap.set(key, bucket);
      }
      bucket.push({
        id: snap.id,
        capturedAt: snap.capturedAt,
        aiOverviewStatus: snap.aiOverviewStatus,
        rawPayload: snap.rawPayload,
      });
    }

    // ── Compute per-keyword volatility ────────────────────────────────────
    interface KeywordProfile {
      keywordTargetId: string;
      query: string;
      volatilityScore: number;
      sampleSize: number;
    }
    const profiles: KeywordProfile[] = [];

    for (const target of targets) {
      const key = `${target.query}\0${target.locale}\0${target.device}`;
      const snapshots = snapshotMap.get(key) ?? [];
      const profile = computeVolatility(snapshots);

      profiles.push({
        keywordTargetId: target.id,
        query: target.query,
        volatilityScore: profile.volatilityScore,
        sampleSize: profile.sampleSize,
      });
    }

    // ── Top risk keywords ─────────────────────────────────────────────────
    // Same sort as volatility-summary B2: volatilityScore DESC, query ASC, id ASC
    // Only active keywords (sampleSize >= 1)
    const activeProfiles = profiles.filter((p) => p.sampleSize >= 1);

    activeProfiles.sort((a, b) => {
      if (b.volatilityScore !== a.volatilityScore)
        return b.volatilityScore - a.volatilityScore;
      const qCmp = a.query.localeCompare(b.query);
      if (qCmp !== 0) return qCmp;
      return a.keywordTargetId.localeCompare(b.keywordTargetId);
    });

    const topRiskKeywords = activeProfiles.slice(0, limitKeywords).map((p) => ({
      keywordTargetId: p.keywordTargetId,
      query: p.query,
      volatilityScore: p.volatilityScore,
      regime: classifyRegime(p.volatilityScore),
      maturity: classifyMaturity(p.sampleSize),
    }));

    // ── Route-text keyword overlaps ───────────────────────────────────────
    // Build page tokens from routeHint + fileName
    const pageTokens: string[] = [];
    if (routeHint) {
      pageTokens.push(...tokenizeRouteHint(routeHint));
    }
    if (fileName) {
      pageTokens.push(...tokenizeFileName(fileName));
    }
    // Deduplicate page tokens (preserve order)
    const seenPageTokens = new Set<string>();
    const dedupedPageTokens: string[] = [];
    for (const t of pageTokens) {
      if (!seenPageTokens.has(t)) {
        seenPageTokens.add(t);
        dedupedPageTokens.push(t);
      }
    }

    const overlapCandidates: KeywordOverlapCandidate[] = targets.map((t) => ({
      keywordTargetId: t.id,
      query: t.query,
    }));

    const routeTextKeywordMatches = computeRouteTextOverlaps(
      dedupedPageTokens,
      overlapCandidates,
      limitOverlaps
    );

    // ── SERP Observatory ─────────────────────────────────────────────────
    const serpObservatory = computeSerpObservatory(snapshotMap);

    // ── Assemble response ─────────────────────────────────────────────────
    const hasRiskSignals =
      topRiskKeywords.length > 0 &&
      topRiskKeywords.some((k) => k.volatilityScore > 0);

    const notes: string[] = [
      "Heuristic route-text overlaps only.",
      "No page analysis has been performed.",
    ];

    if (dedupedPageTokens.length === 0 && (routeHint || fileName)) {
      notes.push(
        "No matchable tokens extracted from route/file context."
      );
    }

    return successResponse({
      pageContext: {
        routeHint,
        fileName,
        fileType,
        isPageRelevant: isPageRelevant(routeHint, fileName, fileType),
      },
      projectContext: {
        projectId: project.id,
        projectName: project.name,
        projectSlug: project.slug,
      },
      observatorySummary: {
        hasRiskSignals,
        topRiskKeywordCount: topRiskKeywords.length,
        routeTextOverlapCount: routeTextKeywordMatches.length,
      },
      serpObservatory,
      topRiskKeywords,
      routeTextKeywordMatches,
      availableActions: [...AVAILABLE_ACTIONS],
      notes,
    });
  } catch (err) {
    console.error("GET /api/seo/page-command-center error:", err);
    return serverError();
  }
}
