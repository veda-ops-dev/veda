/**
 * GET /api/content-graph/internal-links — List internal links for project
 * POST /api/content-graph/internal-links — Register an internal link
 *
 * Per docs/specs/CONTENT-GRAPH-DATA-MODEL.md (Phase 1)
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  listResponse,
  createdResponse,
  badRequest,
  notFound,
  serverError,
  parsePagination,
} from "@/lib/api-response";
import { resolveProjectId, resolveProjectIdStrict } from "@/lib/project";
import { CreateCgInternalLinkSchema } from "@/lib/schemas/content-graph";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const { page, limit, skip } = parsePagination(request.nextUrl.searchParams);
    const where: { projectId: string; sourcePageId?: string; targetPageId?: string } = { projectId };

    const sourcePageId = request.nextUrl.searchParams.get("sourcePageId");
    if (sourcePageId) where.sourcePageId = sourcePageId;
    const targetPageId = request.nextUrl.searchParams.get("targetPageId");
    if (targetPageId) where.targetPageId = targetPageId;

    const [links, total] = await Promise.all([
      prisma.cgInternalLink.findMany({
        where,
        orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.cgInternalLink.count({ where }),
    ]);

    return listResponse(links, { page, limit, total });
  } catch (err) {
    console.error("GET /api/content-graph/internal-links error:", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
    if (error) return badRequest(error);

    let body: unknown;
    try { body = await request.json(); } catch { return badRequest("Invalid JSON body"); }

    const parsed = CreateCgInternalLinkSchema.safeParse(body);
    if (!parsed.success) return badRequest("Validation failed", formatZodErrors(parsed.error));

    const { sourcePageId, targetPageId, anchorText, linkRole } = parsed.data;

    if (sourcePageId === targetPageId) {
      return badRequest("Source and target page must be different");
    }

    // Non-disclosure: cross-project pageId returns 404
    const [sourcePage, targetPage] = await Promise.all([
      prisma.cgPage.findUnique({ where: { id: sourcePageId }, select: { projectId: true } }),
      prisma.cgPage.findUnique({ where: { id: targetPageId }, select: { projectId: true } }),
    ]);
    if (!sourcePage || sourcePage.projectId !== projectId) return notFound("Source page not found");
    if (!targetPage || targetPage.projectId !== projectId) return notFound("Target page not found");

    const existing = await prisma.cgInternalLink.findUnique({
      where: { sourcePageId_targetPageId: { sourcePageId, targetPageId } },
    });
    if (existing) return badRequest("Internal link already exists between these pages");

    const link = await prisma.$transaction(async (tx) => {
      const created = await tx.cgInternalLink.create({
        data: {
          projectId,
          sourcePageId,
          targetPageId,
          anchorText: anchorText ?? null,
          linkRole: linkRole ?? "support",
        },
      });
      await tx.eventLog.create({
        data: {
          eventType: "CG_INTERNAL_LINK_CREATED",
          entityType: "cgInternalLink",
          entityId: created.id,
          actor: "human",
          projectId,
          details: { sourcePageId, targetPageId, linkRole: linkRole ?? "support" },
        },
      });
      return created;
    });

    return createdResponse(link);
  } catch (err) {
    console.error("POST /api/content-graph/internal-links error:", err);
    return serverError();
  }
}
