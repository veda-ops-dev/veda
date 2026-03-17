/**
 * GET /api/content-graph/pages — List pages for project
 * POST /api/content-graph/pages — Register a page
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
import { CreateCgPageSchema } from "@/lib/schemas/content-graph";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const { page, limit, skip } = parsePagination(request.nextUrl.searchParams);
    const where: { projectId: string; siteId?: string } = { projectId };

    const siteId = request.nextUrl.searchParams.get("siteId");
    if (siteId) where.siteId = siteId;

    const [pages, total] = await Promise.all([
      prisma.cgPage.findMany({
        where,
        orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.cgPage.count({ where }),
    ]);

    return listResponse(pages, { page, limit, total });
  } catch (err) {
    console.error("GET /api/content-graph/pages error:", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
    if (error) return badRequest(error);

    let body: unknown;
    try { body = await request.json(); } catch { return badRequest("Invalid JSON body"); }

    const parsed = CreateCgPageSchema.safeParse(body);
    if (!parsed.success) return badRequest("Validation failed", formatZodErrors(parsed.error));

    const { siteId, contentArchetypeId, url, title, canonicalUrl, publishingState, isIndexable } = parsed.data;

    // Non-disclosure: cross-project siteId returns 404
    const site = await prisma.cgSite.findUnique({
      where: { id: siteId },
      select: { projectId: true },
    });
    if (!site || site.projectId !== projectId) {
      return notFound("Site not found");
    }

    // Non-disclosure: cross-project contentArchetypeId returns 404
    if (contentArchetypeId) {
      const archetype = await prisma.cgContentArchetype.findUnique({
        where: { id: contentArchetypeId },
        select: { projectId: true },
      });
      if (!archetype || archetype.projectId !== projectId) {
        return notFound("ContentArchetype not found");
      }
    }

    const existing = await prisma.cgPage.findUnique({
      where: { projectId_url: { projectId, url } },
    });
    if (existing) return badRequest(`URL "${url}" already registered for this project`);

    const cgPage = await prisma.$transaction(async (tx) => {
      const created = await tx.cgPage.create({
        data: {
          projectId,
          siteId,
          contentArchetypeId: contentArchetypeId ?? null,
          url,
          title,
          canonicalUrl: canonicalUrl ?? null,
          publishingState: publishingState ?? "draft",
          isIndexable: isIndexable ?? true,
        },
      });
      await tx.eventLog.create({
        data: {
          eventType: "CG_PAGE_CREATED",
          entityType: "cgPage",
          entityId: created.id,
          actor: "human",
          projectId,
          details: { url, title, siteId },
        },
      });
      return created;
    });

    return createdResponse(cgPage);
  } catch (err) {
    console.error("POST /api/content-graph/pages error:", err);
    return serverError();
  }
}
