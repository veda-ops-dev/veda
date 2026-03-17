/**
 * GET /api/content-graph/sites — List sites for project
 * POST /api/content-graph/sites — Register a site
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
import { CreateCgSiteSchema } from "@/lib/schemas/content-graph";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const { page, limit, skip } = parsePagination(request.nextUrl.searchParams);
    const where = { projectId };

    const [sites, total] = await Promise.all([
      prisma.cgSite.findMany({
        where,
        orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.cgSite.count({ where }),
    ]);

    return listResponse(sites, { page, limit, total });
  } catch (err) {
    console.error("GET /api/content-graph/sites error:", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
    if (error) return badRequest(error);

    let body: unknown;
    try { body = await request.json(); } catch { return badRequest("Invalid JSON body"); }

    const parsed = CreateCgSiteSchema.safeParse(body);
    if (!parsed.success) return badRequest("Validation failed", formatZodErrors(parsed.error));

    const { surfaceId, domain, framework, isCanonical, notes } = parsed.data;

    // Non-disclosure: cross-project surfaceId returns 404
    // Disabled surface: returns 400 (surface exists but is not accepting new sites)
    const surface = await prisma.cgSurface.findUnique({
      where: { id: surfaceId },
      select: { projectId: true, enabled: true },
    });
    if (!surface || surface.projectId !== projectId) {
      return notFound("Surface not found");
    }
    if (!surface.enabled) {
      return badRequest("Surface is disabled and cannot accept new sites");
    }

    const existing = await prisma.cgSite.findUnique({
      where: { projectId_domain: { projectId, domain } },
    });
    if (existing) return badRequest(`Domain "${domain}" already registered for this project`);

    const site = await prisma.$transaction(async (tx) => {
      const created = await tx.cgSite.create({
        data: {
          projectId,
          surfaceId,
          domain,
          framework: framework ?? null,
          isCanonical: isCanonical ?? true,
          notes: notes ?? null,
        },
      });
      await tx.eventLog.create({
        data: {
          eventType: "CG_SITE_CREATED",
          entityType: "cgSite",
          entityId: created.id,
          actor: "human",
          projectId,
          details: { domain, surfaceId },
        },
      });
      return created;
    });

    return createdResponse(site);
  } catch (err) {
    console.error("POST /api/content-graph/sites error:", err);
    return serverError();
  }
}
