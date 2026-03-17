/**
 * POST /api/seo/keyword-research — W4 confirm-gated keyword research wrapper
 *
 * confirm=false → dry-run: return estimated_cost + normalized_keywords, no DB writes
 * confirm=true  → idempotent upsert of KeywordTarget governance records
 *
 * Constraints:
 * - Project-scoped via resolveProjectId()
 * - No writes without EventLog; no EventLog without writes (prisma.$transaction())
 * - Determinism: response targets sorted by query asc, id asc
 * - Idempotent: existing (projectId, query, locale, device) tuples are skipped
 * - EventType: KEYWORD_TARGET_CREATED per created record only
 * - actor: "human" (operator-triggered)
 * - Does not call DataForSEO
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  successResponse,
  createdResponse,
  badRequest,
  serverError,
} from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { KeywordResearchSchema } from "@/lib/schemas/keyword-research";
import { formatZodErrors } from "@/lib/zod-helpers";

// =============================================================================
// POST /api/seo/keyword-research
// =============================================================================

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) {
      return badRequest(error);
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return badRequest("Invalid JSON body");
    }

    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return badRequest("Request body must be an object");
    }

    const parsed = KeywordResearchSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodErrors(parsed.error));
    }

    const { keywords, locale, device, confirm } = parsed.data;
    // keywords are already normalized by the Zod .transform() in the schema

    // -------------------------------------------------------------------------
    // confirm=false — dry-run, no DB writes
    // -------------------------------------------------------------------------
    if (!confirm) {
      return successResponse({
        confirm_required: true,
        estimated_cost: keywords.length * 0.001,
        normalized_keywords: keywords,
      });
    }

    // -------------------------------------------------------------------------
    // confirm=true — idempotent upsert inside one transaction
    // -------------------------------------------------------------------------
    const result = await prisma.$transaction(async (tx) => {
      // Fetch all existing targets for this (projectId, locale, device) + keyword set
      const existing = await tx.keywordTarget.findMany({
        where: {
          projectId,
          locale,
          device,
          query: { in: keywords },
        },
        select: { query: true },
      });

      const existingQueries = new Set(existing.map((r) => r.query));
      const toCreate = keywords.filter((kw) => !existingQueries.has(kw));

      // Create missing targets and emit one EventLog per created record
      const created: Array<{
        id: string;
        query: string;
        locale: string;
        device: string;
        isPrimary: boolean;
        createdAt: Date;
        updatedAt: Date;
      }> = [];

      for (const query of toCreate) {
        const target = await tx.keywordTarget.create({
          data: {
            projectId,
            query,
            locale,
            device,
            isPrimary: false,
            intent: null,
            notes: null,
          },
        });

        await tx.eventLog.create({
          data: {
            eventType: "KEYWORD_TARGET_CREATED",
            entityType: "keywordTarget",
            entityId: target.id,
            actor: "human",
            projectId,
            details: {
              query,
              locale,
              device,
              isPrimary: false,
            },
          },
        });

        created.push(target);
      }

      // Fetch existing targets that were skipped so we can include them in the response
      const skippedTargets =
        existingQueries.size > 0
          ? await tx.keywordTarget.findMany({
              where: {
                projectId,
                locale,
                device,
                query: { in: [...existingQueries] },
              },
              select: {
                id: true,
                query: true,
                locale: true,
                device: true,
                isPrimary: true,
                createdAt: true,
                updatedAt: true,
              },
            })
          : [];

      return { created, skippedTargets };
    });

    const { created, skippedTargets } = result;

    // Merge created + skipped into a single sorted targets list
    const allTargets = [
      ...created.map((t) => ({
        id: t.id,
        query: t.query,
        locale: t.locale,
        device: t.device,
        isPrimary: t.isPrimary,
        createdAt: t.createdAt.toISOString(),
        updatedAt: t.updatedAt.toISOString(),
      })),
      ...skippedTargets.map((t) => ({
        id: t.id,
        query: t.query,
        locale: t.locale,
        device: t.device,
        isPrimary: t.isPrimary,
        createdAt: t.createdAt.toISOString(),
        updatedAt: t.updatedAt.toISOString(),
      })),
    ];

    // Deterministic ordering: query asc, id asc
    allTargets.sort((a, b) => {
      if (a.query < b.query) return -1;
      if (a.query > b.query) return 1;
      if (a.id < b.id) return -1;
      if (a.id > b.id) return 1;
      return 0;
    });

    return createdResponse({
      created: created.length,
      skipped: skippedTargets.length,
      targets: allTargets,
    });
  } catch (err) {
    console.error("POST /api/seo/keyword-research error:", err);
    return serverError();
  }
}
