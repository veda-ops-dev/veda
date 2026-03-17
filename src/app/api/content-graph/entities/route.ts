/**
 * GET /api/content-graph/entities — List CG entities for project
 * POST /api/content-graph/entities — Register a CG entity
 *
 * Per docs/specs/CONTENT-GRAPH-DATA-MODEL.md (Phase 1)
 * Note: "CgEntity" is a Content Graph entity (product, technology, concept, org).
 * Not to be confused with editorial Entity models (which are outside VEDA scope).
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  listResponse,
  createdResponse,
  badRequest,
  serverError,
  parsePagination,
} from "@/lib/api-response";
import { resolveProjectId, resolveProjectIdStrict } from "@/lib/project";
import { CreateCgEntitySchema } from "@/lib/schemas/content-graph";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const { page, limit, skip } = parsePagination(request.nextUrl.searchParams);
    const where: { projectId: string; entityType?: string } = { projectId };

    const entityType = request.nextUrl.searchParams.get("entityType");
    if (entityType) where.entityType = entityType;

    const [entities, total] = await Promise.all([
      prisma.cgEntity.findMany({
        where,
        orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.cgEntity.count({ where }),
    ]);

    return listResponse(entities, { page, limit, total });
  } catch (err) {
    console.error("GET /api/content-graph/entities error:", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
    if (error) return badRequest(error);

    let body: unknown;
    try { body = await request.json(); } catch { return badRequest("Invalid JSON body"); }

    const parsed = CreateCgEntitySchema.safeParse(body);
    if (!parsed.success) return badRequest("Validation failed", formatZodErrors(parsed.error));

    const { key, label, entityType } = parsed.data;

    const existing = await prisma.cgEntity.findUnique({
      where: { projectId_key: { projectId, key } },
    });
    if (existing) return badRequest(`Entity key "${key}" already exists for this project`);

    const entity = await prisma.$transaction(async (tx) => {
      const created = await tx.cgEntity.create({
        data: { projectId, key, label, entityType },
      });
      await tx.eventLog.create({
        data: {
          eventType: "CG_ENTITY_CREATED",
          entityType: "cgEntity",
          entityId: created.id,
          actor: "human",
          projectId,
          details: { key, label, entityType },
        },
      });
      return created;
    });

    return createdResponse(entity);
  } catch (err) {
    console.error("POST /api/content-graph/entities error:", err);
    return serverError();
  }
}
