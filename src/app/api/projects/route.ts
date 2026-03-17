/**
 * GET  /api/projects — List all projects
 * POST /api/projects — Create a new project container
 *
 * GET: Read-only, deterministic ordering, standard pagination.
 * POST: Creates project + EventLog in a single transaction.
 *       Lifecycle state starts at "created".
 *
 * Invariants:
 * - Deterministic ordering: slug asc, id asc
 * - POST uses Zod.strict() validation
 * - POST writes inside prisma.$transaction()
 * - POST emits EventLog (PROJECT_CREATED)
 * - Slug uniqueness enforced at DB level
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  listResponse,
  createdResponse,
  badRequest,
  conflict,
  serverError,
  parsePagination,
} from "@/lib/api-response";
import { CreateProjectSchema, deriveSlug } from "@/lib/schemas/project";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const { page, limit, skip } = parsePagination(searchParams);

    const [projects, total] = await Promise.all([
      prisma.project.findMany({
        orderBy: [{ slug: "asc" }, { id: "asc" }],
        skip,
        take: limit,
      }),
      prisma.project.count(),
    ]);

    return listResponse(projects, { page, limit, total });
  } catch (error) {
    console.error("GET /api/projects error:", error);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return badRequest("Request body must be valid JSON");
    }

    const parsed = CreateProjectSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodErrors(parsed.error));
    }

    const { name, description } = parsed.data;
    const slug = parsed.data.slug ?? deriveSlug(name);

    if (!slug || slug.length < 2) {
      return badRequest("Could not derive a valid slug from the project name. Provide a slug explicitly.");
    }

    // Advisory uniqueness check (DB constraint is authoritative)
    const existing = await prisma.project.findUnique({
      where: { slug },
      select: { id: true },
    });
    if (existing) {
      return conflict(`A project with slug "${slug}" already exists.`);
    }

    // Atomic: create project + EventLog
    const project = await prisma.$transaction(async (tx) => {
      const p = await tx.project.create({
        data: {
          name,
          slug,
          description: description ?? null,
          lifecycleState: "created",
        },
      });

      await tx.eventLog.create({
        data: {
          eventType: "PROJECT_CREATED",
          entityType: "vedaProject",
          entityId: p.id,
          actor: "human",
          projectId: p.id,
          details: { name, slug },
        },
      });

      return p;
    });

    return createdResponse(project);
  } catch (error) {
    if (
      error instanceof Error &&
      error.message.includes("Unique constraint")
    ) {
      return conflict("A project with this slug already exists.");
    }
    console.error("POST /api/projects error:", error);
    return serverError();
  }
}
