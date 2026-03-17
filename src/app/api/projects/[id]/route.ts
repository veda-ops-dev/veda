/**
 * GET /api/projects/:id — Get project by ID
 *
 * Returns a single project record.
 * Non-disclosure: returns 404 for non-existent projects.
 * No project-scoping header required — this is a project container lookup.
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { successResponse, badRequest, notFound, serverError } from "@/lib/api-response";
import { UUID_RE } from "@/lib/constants";

interface RouteContext {
  params: Promise<{ id: string }>;
}

export async function GET(request: NextRequest, context: RouteContext) {
  try {
    const { id } = await context.params;

    if (!UUID_RE.test(id)) {
      return badRequest("Project ID must be a valid UUID");
    }

    const project = await prisma.project.findUnique({
      where: { id },
    });

    if (!project) {
      return notFound("Not found");
    }

    return successResponse(project);
  } catch (error) {
    console.error("GET /api/projects/:id error:", error);
    return serverError();
  }
}
