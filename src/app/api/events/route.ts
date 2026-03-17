/**
 * GET /api/events — List EventLog entries with filtering
 *
 * Multi-project hardened:
 * - Resolves projectId from request
 * - Scopes all reads and counts by projectId
 */

import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  listResponse,
  badRequest,
  serverError,
  parsePagination,
} from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { EventType, EntityType, ActorType } from "@prisma/client";
import type { Prisma } from "@prisma/client";
import { UUID_RE } from "@/lib/constants";


function isEnumValue<T extends Record<string, string>>(
  enumObj: T,
  value: unknown
): value is T[keyof T] {
  return typeof value === "string" && Object.values(enumObj).includes(value);
}

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) {
      return badRequest(error);
    }

    const searchParams = request.nextUrl.searchParams;
    const { page, limit, skip } = parsePagination(searchParams);

    // 🔒 Always project-scoped
    const where: Prisma.EventLogWhereInput = { projectId };

    const eventType = searchParams.get("eventType");
    if (eventType) {
      if (!isEnumValue(EventType, eventType)) {
        return badRequest(
          `eventType must be one of: ${Object.values(EventType).join(", ")}`
        );
      }
      where.eventType = eventType;
    }

    const entityType = searchParams.get("entityType");
    if (entityType) {
      if (!isEnumValue(EntityType, entityType)) {
        return badRequest(
          `entityType must be one of: ${Object.values(EntityType).join(", ")}`
        );
      }
      where.entityType = entityType;
    }

    const entityId = searchParams.get("entityId");
    if (entityId) {
      if (!UUID_RE.test(entityId)) {
        return badRequest("entityId must be a valid UUID");
      }
      where.entityId = entityId;
    }

    const actor = searchParams.get("actor");
    if (actor) {
      if (!isEnumValue(ActorType, actor)) {
        return badRequest(
          `actor must be one of: ${Object.values(ActorType).join(", ")}`
        );
      }
      where.actor = actor;
    }

    const timestampFilter: Prisma.DateTimeFilter = {};

    const after = searchParams.get("after");
    if (after) {
      const afterDate = new Date(after);
      if (isNaN(afterDate.getTime())) {
        return badRequest("after must be a valid ISO date string");
      }
      timestampFilter.gte = afterDate;
    }

    const before = searchParams.get("before");
    if (before) {
      const beforeDate = new Date(before);
      if (isNaN(beforeDate.getTime())) {
        return badRequest("before must be a valid ISO date string");
      }
      timestampFilter.lte = beforeDate;
    }

    if (timestampFilter.gte || timestampFilter.lte) {
      where.timestamp = timestampFilter;
    }

    const [events, total] = await Promise.all([
      prisma.eventLog.findMany({
        where,
        orderBy: [{ timestamp: "desc" }, { id: "desc" }],
        skip,
        take: limit,
      }),
      prisma.eventLog.count({ where }),
    ]);

    return listResponse(events, { page, limit, total });
  } catch (error) {
    console.error("GET /api/events error:", error);
    return serverError();
  }
}
