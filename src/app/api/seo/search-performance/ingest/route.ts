/**
 * POST /api/seo/search-performance/ingest — Bulk ingest search performance data
 *
 * Phase 0-SEO manual endpoint for GSC opportunity query ingestion.
 * - Accepts bulk rows (manual upload/paste)
 * - Upserts by composite unique: (projectId, query, pageUrl, dateStart, dateEnd)
 * - Single summary EventLog entry per batch
 *
 * Multi-project hardened:
 * - Resolves projectId from request
 * - All writes scoped by projectId
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { successResponse, badRequest, serverError } from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import type { Prisma } from "@prisma/client";
import {
  IngestSearchPerformanceSchema,
  type SearchPerformanceRow,
} from "@/lib/schemas/search-performance";
import { formatZodErrors } from "@/lib/zod-helpers";

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) {
      return badRequest(error);
    }

    // Parse request body
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return badRequest("Invalid JSON body");
    }

    // Body must be object
    if (typeof body !== "object" || body === null) {
      return badRequest("Request body must be an object");
    }

    const parsed = IngestSearchPerformanceSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodErrors(parsed.error));
    }

    const validatedRows: SearchPerformanceRow[] = parsed.data.rows;

    // Deterministic processing order: sort by (query, pageUrl, dateStart, dateEnd)
    const sortedRows = [...validatedRows].sort((a, b) => {
      const cmp1 = a.query.localeCompare(b.query);
      if (cmp1 !== 0) return cmp1;
      const cmp2 = a.pageUrl.localeCompare(b.pageUrl);
      if (cmp2 !== 0) return cmp2;
      const cmp3 = a.dateStart.localeCompare(b.dateStart);
      if (cmp3 !== 0) return cmp3;
      return a.dateEnd.localeCompare(b.dateEnd);
    });

    // Track date window for summary
    let minDateStart: Date | null = null;
    let maxDateEnd: Date | null = null;

    // Transactional upsert + event log (atomic)
    const rowCount = await prisma.$transaction(async (tx) => {
      let count = 0;

      for (const row of sortedRows) {
        const dateStart = new Date(row.dateStart);
        const dateEnd = new Date(row.dateEnd);

        // Track date window
        if (!minDateStart || dateStart < minDateStart) {
          minDateStart = dateStart;
        }
        if (!maxDateEnd || dateEnd > maxDateEnd) {
          maxDateEnd = dateEnd;
        }

        await tx.searchPerformance.upsert({
          where: {
            projectId_query_pageUrl_dateStart_dateEnd: {
              projectId,
              query: row.query,
              pageUrl: row.pageUrl,
              dateStart,
              dateEnd,
            },
          },
          create: {
            projectId,
            pageUrl: row.pageUrl,
            query: row.query,
            impressions: row.impressions,
            clicks: row.clicks,
            ctr: row.ctr,
            avgPosition: row.avgPosition,
            dateStart,
            dateEnd,
          },
          update: {
            impressions: row.impressions,
            clicks: row.clicks,
            ctr: row.ctr,
            avgPosition: row.avgPosition,
          },
        });

        count++;
      }

      // Emit summary EventLog entry
      const details: Prisma.InputJsonObject = {
        model: "searchPerformance",
        rowCount: count,
        dateWindowStart: minDateStart?.toISOString() ?? null,
        dateWindowEnd: maxDateEnd?.toISOString() ?? null,
      };

      await tx.eventLog.create({
        data: {
          eventType: "SOURCE_CAPTURED",
          entityType: "searchPerformance",
          entityId: projectId,
          actor: "human",
          projectId,
          details,
        },
      });

      return count;
    });

    return successResponse({ ok: true, rowCount });
  } catch (error) {
    console.error("POST /api/seo/search-performance/ingest error:", error);
    return serverError();
  }
}
