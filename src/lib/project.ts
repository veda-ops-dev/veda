/**
 * Project Scoping — Constants and Resolution
 *
 * Every domain query must be project-scoped. This module provides:
 * 1. Default project ID for bootstrap/development
 * 2. Project resolution from request headers/cookies
 * 3. Validation helpers
 *
 * Resolution strategy (Phase 1):
 *   - Check X-Project-Id header
 *   - Check X-Project-Slug header (slug → lookup)
 *   - Check projectId cookie
 *   - Fall back to DEFAULT_PROJECT_ID
 *
 * Future (Phase 2+):
 *   - Path prefix /api/projects/:slug/...
 *   - No fallback — explicit project required
 */

import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { UUID_RE } from "@/lib/constants";

// Deterministic UUID matching the migration seed row
export const DEFAULT_PROJECT_ID = "00000000-0000-4000-a000-000000000001";
export const DEFAULT_PROJECT_SLUG = "veda";


/**
 * Resolve projectId from the request.
 *
 * Priority:
 * 1. X-Project-Id header (UUID)
 * 2. X-Project-Slug header (slug → lookup)
 * 3. projectId cookie
 * 4. DEFAULT_PROJECT_ID
 *
 * Returns { projectId, error? }
 * If error is set, the caller should return badRequest(error).
 *
 * Use for read-only (GET) endpoints where fallback to default project is safe.
 * For mutation endpoints use resolveProjectIdStrict().
 */
export async function resolveProjectId(
  request: NextRequest
): Promise<{ projectId: string; error?: string }> {
  // 1. Check X-Project-Id header
  const headerProjectId = request.headers.get("x-project-id");
  if (headerProjectId) {
    if (!UUID_RE.test(headerProjectId)) {
      return { projectId: "", error: "X-Project-Id must be a valid UUID" };
    }
    const project = await prisma.project.findUnique({
      where: { id: headerProjectId },
      select: { id: true },
    });
    if (!project) {
      return { projectId: "", error: `Project not found: ${headerProjectId}` };
    }
    return { projectId: headerProjectId };
  }

  // 2. Check X-Project-Slug header
  const headerProjectSlug = request.headers.get("x-project-slug");
  if (headerProjectSlug) {
    const project = await prisma.project.findUnique({
      where: { slug: headerProjectSlug },
      select: { id: true },
    });
    if (!project) {
      return { projectId: "", error: `Project not found: ${headerProjectSlug}` };
    }
    return { projectId: project.id };
  }

  // 3. Check cookie
  const cookieProjectId = request.cookies.get("projectId")?.value;
  if (cookieProjectId && UUID_RE.test(cookieProjectId)) {
    const project = await prisma.project.findUnique({
      where: { id: cookieProjectId },
      select: { id: true },
    });
    if (project) {
      return { projectId: cookieProjectId };
    }
    // Cookie has stale/invalid ID — fall through to default
  }

  // 4. Default
  return { projectId: DEFAULT_PROJECT_ID };
}

/**
 * resolveProjectIdStrict — for mutation endpoints.
 *
 * Same resolution priority as resolveProjectId() (header → slug → cookie)
 * but returns an error instead of falling back to DEFAULT_PROJECT_ID when
 * no explicit project context is present.
 *
 * Prevents silent wrong-project mutation when no project context is supplied.
 * Use this for all POST, PUT, DELETE, PATCH endpoints.
 *
 * Returns { projectId, error? }
 * If error is set, the caller should return badRequest(error).
 */
export async function resolveProjectIdStrict(
  request: NextRequest
): Promise<{ projectId: string; error?: string }> {
  // 1. Check X-Project-Id header
  const headerProjectId = request.headers.get("x-project-id");
  if (headerProjectId) {
    if (!UUID_RE.test(headerProjectId)) {
      return { projectId: "", error: "X-Project-Id must be a valid UUID" };
    }
    const project = await prisma.project.findUnique({
      where: { id: headerProjectId },
      select: { id: true },
    });
    if (!project) {
      return { projectId: "", error: `Project not found: ${headerProjectId}` };
    }
    return { projectId: headerProjectId };
  }

  // 2. Check X-Project-Slug header
  const headerProjectSlug = request.headers.get("x-project-slug");
  if (headerProjectSlug) {
    const project = await prisma.project.findUnique({
      where: { slug: headerProjectSlug },
      select: { id: true },
    });
    if (!project) {
      return { projectId: "", error: `Project not found: ${headerProjectSlug}` };
    }
    return { projectId: project.id };
  }

  // 3. Check cookie
  const cookieProjectId = request.cookies.get("projectId")?.value;
  if (cookieProjectId && UUID_RE.test(cookieProjectId)) {
    const project = await prisma.project.findUnique({
      where: { id: cookieProjectId },
      select: { id: true },
    });
    if (project) {
      return { projectId: cookieProjectId };
    }
    // Cookie has stale/invalid ID — fall through to error (no default fallback)
  }

  // No explicit project context supplied — reject the mutation
  return {
    projectId: "",
    error:
      "Project context required for this operation. " +
      "Supply X-Project-Id or X-Project-Slug header.",
  };
}

/**
 * Assert that two entities belong to the same project.
 * Use when creating relationships to enforce project boundaries.
 */
export function assertSameProject(
  projectIdA: string,
  projectIdB: string,
  context: string
): string | null {
  if (projectIdA !== projectIdB) {
    return `Cross-project ${context} not allowed. Entities must belong to the same project.`;
  }
  return null;
}
