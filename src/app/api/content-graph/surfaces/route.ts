/**
 * GET /api/content-graph/surfaces — List surfaces for project
 * POST /api/content-graph/surfaces — Register a surface
 *
 * Per docs/specs/CONTENT-GRAPH-DATA-MODEL.md (Phase 1)
 *
 * Key canonicalization: keys are stored as lowercase-hyphen form.
 * Input key is trimmed, lowercased, and internal spaces/underscores collapsed to hyphens.
 * The @@unique([projectId, key]) DB constraint then operates on canonical values.
 *
 * Duplicate identity: if canonicalIdentifier is provided, a surface with the same
 * (projectId, type, canonicalIdentifier) is rejected before insert via app-layer check.
 * The DB partial unique index provides the hard backstop.
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
import { CreateCgSurfaceSchema } from "@/lib/schemas/content-graph";
import { formatZodErrors } from "@/lib/zod-helpers";

/**
 * Canonicalize a surface key.
 * Rules: trim whitespace, lowercase, replace spaces/underscores with hyphens,
 * collapse consecutive hyphens, strip leading/trailing hyphens.
 */
function canonicalizeSurfaceKey(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/[\s_]+/g, "-")
    .replace(/-{2,}/g, "-")
    .replace(/^-+|-+$/g, "");
}

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    const { page, limit, skip } = parsePagination(request.nextUrl.searchParams);
    const where = { projectId };

    const [surfaces, total] = await Promise.all([
      prisma.cgSurface.findMany({
        where,
        orderBy: [{ createdAt: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.cgSurface.count({ where }),
    ]);

    return listResponse(surfaces, { page, limit, total });
  } catch (err) {
    console.error("GET /api/content-graph/surfaces error:", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
    if (error) return badRequest(error);

    let body: unknown;
    try { body = await request.json(); } catch { return badRequest("Invalid JSON body"); }

    const parsed = CreateCgSurfaceSchema.safeParse(body);
    if (!parsed.success) return badRequest("Validation failed", formatZodErrors(parsed.error));

    const { type, key: rawKey, label, canonicalIdentifier, canonicalUrl, enabled } = parsed.data;

    // Canonicalize key before uniqueness check and storage
    const key = canonicalizeSurfaceKey(rawKey);
    if (key.length === 0) {
      return badRequest("key is empty after canonicalization");
    }

    // Operator key uniqueness check
    const existingKey = await prisma.cgSurface.findUnique({
      where: { projectId_key: { projectId, key } },
    });
    if (existingKey) return badRequest(`Surface key "${key}" already exists for this project`);

    // Canonical identity uniqueness check (app-layer pre-check; DB partial index is the hard backstop)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    if (canonicalIdentifier !== undefined && canonicalIdentifier !== null) {
      const existingIdentity = await (prisma.cgSurface as any).findFirst({
        where: { projectId, type, canonicalIdentifier },
        select: { id: true, key: true },
      });
      if (existingIdentity) {
        return badRequest(
          `A surface of type "${type}" with canonicalIdentifier "${canonicalIdentifier}" already exists for this project (key: "${existingIdentity.key}")`
        );
      }
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const surface = await prisma.$transaction(async (tx) => {
      const created = await (tx.cgSurface as any).create({
        data: {
          projectId,
          type,
          key,
          label: label ?? null,
          canonicalIdentifier: canonicalIdentifier ?? null,
          canonicalUrl: canonicalUrl ?? null,
          enabled: enabled ?? true,
        },
      });
      await tx.eventLog.create({
        data: {
          eventType: "CG_SURFACE_CREATED",
          entityType: "cgSurface",
          entityId: created.id,
          actor: "human",
          projectId,
          details: {
            key,
            type,
            canonicalIdentifier: canonicalIdentifier ?? null,
          },
        },
      });
      return created;
    });

    return createdResponse(surface);
  } catch (err) {
    console.error("POST /api/content-graph/surfaces error:", err);
    return serverError();
  }
}
