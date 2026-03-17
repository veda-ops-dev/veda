/**
 * GET /api/seo/search-performance — List search performance records
 *
 * Phase 0-SEO manual read endpoint for GSC data.
 * - Project-scoped queries
 * - Deterministic ordering
 * - Strict validation
 *
 * Multi-project hardened:
 * - Resolves projectId from request
 * - All queries scoped by projectId
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
import type { Prisma } from "@prisma/client";


// Strict ISO 8601 date validation (deterministic across environments)
// Accepts ONLY:
//   - Date-only: YYYY-MM-DD
//   - UTC timestamp: YYYY-MM-DDTHH:mm:ssZ or YYYY-MM-DDTHH:mm:ss.sssZ
// Rejects: locale formats, timezone offsets other than Z, missing Z on timestamps
const ISO_DATE_ONLY_RE = /^\d{4}-\d{2}-\d{2}$/;
const ISO_TIMESTAMP_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z$/;

function isValidIsoDate(value: unknown): value is string {
  if (typeof value !== "string") return false;

  const isDateOnly = ISO_DATE_ONLY_RE.test(value);
  const isTimestamp = ISO_TIMESTAMP_RE.test(value);

  if (!isDateOnly && !isTimestamp) return false;

  const parsed = new Date(value);
  if (isNaN(parsed.getTime())) return false;

  // Round-trip check for date-only to ensure deterministic parsing
  if (isDateOnly) {
    return parsed.toISOString().slice(0, 10) === value;
  }

  // Timestamp with Z: parsing succeeded and format matched
  return true;
}

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) {
      return badRequest(error);
    }

    const searchParams = request.nextUrl.searchParams;
    const { page, limit, skip } = parsePagination(searchParams);

    // Always project-scoped
    const where: Prisma.SearchPerformanceWhereInput = { projectId };

    // query filter (contains, case-insensitive)
    const queryParam = searchParams.get("query");
    if (queryParam) {
      where.query = { contains: queryParam, mode: "insensitive" };
    }

    // pageUrl filter (contains, case-insensitive)
    const pageUrlParam = searchParams.get("pageUrl");
    if (pageUrlParam) {
      where.pageUrl = { contains: pageUrlParam, mode: "insensitive" };
    }

    // dateStart filter (strict ISO validation)
    const dateStartParam = searchParams.get("dateStart");
    let dateStartValue: Date | null = null;
    if (dateStartParam) {
      if (!isValidIsoDate(dateStartParam)) {
        return badRequest("dateStart must be a valid ISO date string (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ssZ)");
      }
      dateStartValue = new Date(dateStartParam);
    }

    // dateEnd filter (strict ISO validation)
    const dateEndParam = searchParams.get("dateEnd");
    let dateEndValue: Date | null = null;
    if (dateEndParam) {
      if (!isValidIsoDate(dateEndParam)) {
        return badRequest("dateEnd must be a valid ISO date string (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ssZ)");
      }
      dateEndValue = new Date(dateEndParam);
    }

    // If both provided, enforce dateStart <= dateEnd
    if (dateStartValue && dateEndValue && dateStartValue > dateEndValue) {
      return badRequest("dateStart must be <= dateEnd");
    }

    // Apply date filters
    if (dateStartValue) {
      where.dateStart = { gte: dateStartValue };
    }
    if (dateEndValue) {
      where.dateEnd = { lte: dateEndValue };
    }

    const [rows, total] = await Promise.all([
      prisma.searchPerformance.findMany({
        where,
        orderBy: [
          { dateStart: "desc" },
          { dateEnd: "desc" },
          { query: "asc" },
          { pageUrl: "asc" },
          { id: "desc" },
        ],
        skip,
        take: limit,
      }),
      prisma.searchPerformance.count({ where }),
    ]);

    return listResponse(rows, { page, limit, total });
  } catch (error) {
    console.error("GET /api/seo/search-performance error:", error);
    return serverError();
  }
}
