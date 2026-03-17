/**
 * GET /api/content-graph/page-topics — List page-topic registrations for project
 * POST /api/content-graph/page-topics — Register a topic on a page
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
import { CreateCgPageTopicSchema } from "@/lib/schemas/content-graph";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const { page, limit, skip } = parsePagination(request.nextUrl.searchParams);
    const where: { projectId: string; pageId?: string; topicId?: string } = { projectId };

    const pageId = request.nextUrl.searchParams.get("pageId");
    if (pageId) where.pageId = pageId;
    const topicId = request.nextUrl.searchParams.get("topicId");
    if (topicId) where.topicId = topicId;

    const [pageTopics, total] = await Promise.all([
      prisma.cgPageTopic.findMany({
        where,
        orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.cgPageTopic.count({ where }),
    ]);

    return listResponse(pageTopics, { page, limit, total });
  } catch (err) {
    console.error("GET /api/content-graph/page-topics error:", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
    if (error) return badRequest(error);

    let body: unknown;
    try { body = await request.json(); } catch { return badRequest("Invalid JSON body"); }

    const parsed = CreateCgPageTopicSchema.safeParse(body);
    if (!parsed.success) return badRequest("Validation failed", formatZodErrors(parsed.error));

    const { pageId, topicId, role } = parsed.data;

    // Non-disclosure: cross-project pageId or topicId returns 404
    const [cgPage, cgTopic] = await Promise.all([
      prisma.cgPage.findUnique({ where: { id: pageId }, select: { projectId: true } }),
      prisma.cgTopic.findUnique({ where: { id: topicId }, select: { projectId: true } }),
    ]);
    if (!cgPage || cgPage.projectId !== projectId) return notFound("Page not found");
    if (!cgTopic || cgTopic.projectId !== projectId) return notFound("Topic not found");

    const existing = await prisma.cgPageTopic.findUnique({
      where: { pageId_topicId: { pageId, topicId } },
    });
    if (existing) return badRequest("Topic already registered on this page");

    const pageTopic = await prisma.$transaction(async (tx) => {
      const created = await tx.cgPageTopic.create({
        data: {
          projectId,
          pageId,
          topicId,
          role: role ?? "supporting",
        },
      });
      await tx.eventLog.create({
        data: {
          eventType: "CG_PAGE_TOPIC_CREATED",
          entityType: "cgPageTopic",
          entityId: created.id,
          actor: "human",
          projectId,
          details: { pageId, topicId, role: role ?? "supporting" },
        },
      });
      return created;
    });

    return createdResponse(pageTopic);
  } catch (err) {
    console.error("POST /api/content-graph/page-topics error:", err);
    return serverError();
  }
}
