/**
 * GET /api/source-items
 * Per docs/operations-planning-api/01-API-ENDPOINTS-AND-VALIDATION-CONTRACTS.md
 *
 * Lists SourceItems with filtering by status, sourceType, platform.
 * Supports pagination: ?page=1&limit=20
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  listResponse,
  badRequest,
  serverError,
  parsePagination,
} from "@/lib/api-response";
import {
  isValidEnum,
  VALID_SOURCE_TYPES,
  VALID_SOURCE_ITEM_STATUSES,
  VALID_PLATFORMS,
} from "@/lib/validation";
import { resolveProjectId } from "@/lib/project";
import type { Prisma } from "@prisma/client";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) {
      return badRequest(error);
    }

    const searchParams = request.nextUrl.searchParams;
    const { page, limit, skip } = parsePagination(searchParams);

    // Always scope by projectId
    const where: Prisma.SourceItemWhereInput = { projectId };

    const status = searchParams.get("status");
    if (status) {
      if (!isValidEnum(status, VALID_SOURCE_ITEM_STATUSES)) {
        return badRequest(`Invalid status: ${status}`);
      }
      where.status = status;
    }

    const sourceType = searchParams.get("sourceType");
    if (sourceType) {
      if (!isValidEnum(sourceType, VALID_SOURCE_TYPES)) {
        return badRequest(`Invalid sourceType: ${sourceType}`);
      }
      where.sourceType = sourceType;
    }

    const platform = searchParams.get("platform");
    if (platform) {
      if (!isValidEnum(platform, VALID_PLATFORMS)) {
        return badRequest(`Invalid platform: ${platform}`);
      }
      where.platform = platform;
    }

    const [items, total] = await Promise.all([
      prisma.sourceItem.findMany({
        where,
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        skip,
        take: limit,
      }),
      prisma.sourceItem.count({ where }),
    ]);

    return listResponse(items, { page, limit, total });
  } catch (error) {
    console.error("GET /api/source-items error:", error);
    return serverError();
  }
}
