/**
 * GET /api/content-graph/topics — List topics for project
 * POST /api/content-graph/topics — Register a topic
 *
 * Per docs/specs/CONTENT-GRAPH-DATA-MODEL.md (Phase 1)
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
import { CreateCgTopicSchema } from "@/lib/schemas/content-graph";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const { page, limit, skip } = parsePagination(request.nextUrl.searchParams);
    const where = { projectId };

    const [topics, total] = await Promise.all([
      prisma.cgTopic.findMany({
        where,
        orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.cgTopic.count({ where }),
    ]);

    return listResponse(topics, { page, limit, total });
  } catch (err) {
    console.error("GET /api/content-graph/topics error:", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
    if (error) return badRequest(error);

    let body: unknown;
    try { body = await request.json(); } catch { return badRequest("Invalid JSON body"); }

    const parsed = CreateCgTopicSchema.safeParse(body);
    if (!parsed.success) return badRequest("Validation failed", formatZodErrors(parsed.error));

    const { key, label } = parsed.data;

    const existing = await prisma.cgTopic.findUnique({
      where: { projectId_key: { projectId, key } },
    });
    if (existing) return badRequest(`Topic key "${key}" already exists for this project`);

    const topic = await prisma.$transaction(async (tx) => {
      const created = await tx.cgTopic.create({
        data: { projectId, key, label },
      });
      await tx.eventLog.create({
        data: {
          eventType: "CG_TOPIC_CREATED",
          entityType: "cgTopic",
          entityId: created.id,
          actor: "human",
          projectId,
          details: { key, label },
        },
      });
      return created;
    });

    return createdResponse(topic);
  } catch (err) {
    console.error("POST /api/content-graph/topics error:", err);
    return serverError();
  }
}
