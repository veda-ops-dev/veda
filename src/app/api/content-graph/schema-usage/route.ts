/**
 * GET /api/content-graph/schema-usage — List schema usages for project
 * POST /api/content-graph/schema-usage — Register a schema usage on a page
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
import { CreateCgSchemaUsageSchema } from "@/lib/schemas/content-graph";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const { page, limit, skip } = parsePagination(request.nextUrl.searchParams);
    const where: { projectId: string; pageId?: string; schemaType?: string } = { projectId };

    const pageId = request.nextUrl.searchParams.get("pageId");
    if (pageId) where.pageId = pageId;
    const schemaType = request.nextUrl.searchParams.get("schemaType");
    if (schemaType) where.schemaType = schemaType;

    const [usages, total] = await Promise.all([
      prisma.cgSchemaUsage.findMany({
        where,
        orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.cgSchemaUsage.count({ where }),
    ]);

    return listResponse(usages, { page, limit, total });
  } catch (err) {
    console.error("GET /api/content-graph/schema-usage error:", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
    if (error) return badRequest(error);

    let body: unknown;
    try { body = await request.json(); } catch { return badRequest("Invalid JSON body"); }

    const parsed = CreateCgSchemaUsageSchema.safeParse(body);
    if (!parsed.success) return badRequest("Validation failed", formatZodErrors(parsed.error));

    const { pageId, schemaType, isPrimary } = parsed.data;

    // Non-disclosure: cross-project pageId returns 404
    const page = await prisma.cgPage.findUnique({
      where: { id: pageId },
      select: { projectId: true },
    });
    if (!page || page.projectId !== projectId) return notFound("Page not found");

    const existing = await prisma.cgSchemaUsage.findUnique({
      where: { pageId_schemaType: { pageId, schemaType } },
    });
    if (existing) return badRequest(`Schema type "${schemaType}" already registered for this page`);

    const usage = await prisma.$transaction(async (tx) => {
      const created = await tx.cgSchemaUsage.create({
        data: {
          projectId,
          pageId,
          schemaType,
          isPrimary: isPrimary ?? false,
        },
      });
      await tx.eventLog.create({
        data: {
          eventType: "CG_SCHEMA_USAGE_CREATED",
          entityType: "cgSchemaUsage",
          entityId: created.id,
          actor: "human",
          projectId,
          details: { pageId, schemaType, isPrimary: isPrimary ?? false },
        },
      });
      return created;
    });

    return createdResponse(usage);
  } catch (err) {
    console.error("POST /api/content-graph/schema-usage error:", err);
    return serverError();
  }
}
