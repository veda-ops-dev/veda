/**
 * GET /api/content-graph/page-entities — List page-entity registrations for project
 * POST /api/content-graph/page-entities — Register an entity on a page
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
import { CreateCgPageEntitySchema } from "@/lib/schemas/content-graph";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const { page, limit, skip } = parsePagination(request.nextUrl.searchParams);
    const where: { projectId: string; pageId?: string; entityId?: string } = { projectId };

    const pageId = request.nextUrl.searchParams.get("pageId");
    if (pageId) where.pageId = pageId;
    const entityId = request.nextUrl.searchParams.get("entityId");
    if (entityId) where.entityId = entityId;

    const [pageEntities, total] = await Promise.all([
      prisma.cgPageEntity.findMany({
        where,
        orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.cgPageEntity.count({ where }),
    ]);

    return listResponse(pageEntities, { page, limit, total });
  } catch (err) {
    console.error("GET /api/content-graph/page-entities error:", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
    if (error) return badRequest(error);

    let body: unknown;
    try { body = await request.json(); } catch { return badRequest("Invalid JSON body"); }

    const parsed = CreateCgPageEntitySchema.safeParse(body);
    if (!parsed.success) return badRequest("Validation failed", formatZodErrors(parsed.error));

    const { pageId, entityId, role } = parsed.data;

    // Non-disclosure: cross-project pageId or entityId returns 404
    const [cgPage, cgEntity] = await Promise.all([
      prisma.cgPage.findUnique({ where: { id: pageId }, select: { projectId: true } }),
      prisma.cgEntity.findUnique({ where: { id: entityId }, select: { projectId: true } }),
    ]);
    if (!cgPage || cgPage.projectId !== projectId) return notFound("Page not found");
    if (!cgEntity || cgEntity.projectId !== projectId) return notFound("Entity not found");

    const existing = await prisma.cgPageEntity.findUnique({
      where: { pageId_entityId: { pageId, entityId } },
    });
    if (existing) return badRequest("Entity already registered on this page");

    const pageEntity = await prisma.$transaction(async (tx) => {
      const created = await tx.cgPageEntity.create({
        data: {
          projectId,
          pageId,
          entityId,
          role: role ?? "supporting",
        },
      });
      await tx.eventLog.create({
        data: {
          eventType: "CG_PAGE_ENTITY_CREATED",
          entityType: "cgPageEntity",
          entityId: created.id,
          actor: "human",
          projectId,
          details: { pageId, entityId, role: role ?? "supporting" },
        },
      });
      return created;
    });

    return createdResponse(pageEntity);
  } catch (err) {
    console.error("POST /api/content-graph/page-entities error:", err);
    return serverError();
  }
}
