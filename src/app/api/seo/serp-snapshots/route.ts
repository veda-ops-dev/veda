/**
 * POST /api/seo/serp-snapshots - Record a SERPSnapshot
 * GET  /api/seo/serp-snapshots - List SERPSnapshots
 *
 * Hardened: extracted query + response layers, strict contract enforcement
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  createdResponse,
  successResponse,
  listResponse,
  badRequest,
  serverError,
} from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { normalizeQuery } from "@/lib/validation";
import { RecordSERPSnapshotSchema } from "@/lib/schemas/serp-snapshot";
import { formatZodErrors } from "@/lib/zod-helpers";
import { Prisma } from "@prisma/client";
import { parseSerpSnapshotQuery } from "@/lib/seo/serp-snapshot-query";
import {
  buildSerpSnapshotSelect,
  serializeSerpSnapshotRow,
  serializeSerpSnapshots,
} from "@/lib/seo/serp-snapshot-response";

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    let parsed;
    try {
      parsed = parseSerpSnapshotQuery({
        searchParams: request.nextUrl.searchParams,
        projectId,
      });
    } catch (e) {
      return badRequest(e instanceof Error ? e.message : "Invalid query");
    }

    const select = buildSerpSnapshotSelect(parsed.includePayload);

    const [rows, total] = await Promise.all([
      prisma.sERPSnapshot.findMany({
        where: parsed.where,
        orderBy: [{ capturedAt: "desc" }, { id: "desc" }],
        skip: parsed.skip,
        take: parsed.limit,
        select,
      }),
      prisma.sERPSnapshot.count({ where: parsed.where }),
    ]);

    const items = serializeSerpSnapshots(rows);

    return listResponse(items, {
      page: parsed.page,
      limit: parsed.limit,
      total,
    });
  } catch (err) {
    console.error("GET serp-snapshots error", err);
    return serverError();
  }
}

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) return badRequest(error);

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return badRequest("Invalid JSON body");
    }

    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return badRequest("Request body must be an object");
    }

    const parsed = RecordSERPSnapshotSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodErrors(parsed.error));
    }

    const data = parsed.data;
    const normalizedQueryStr = normalizeQuery(data.query);

    const capturedAt = data.capturedAt ? new Date(data.capturedAt) : new Date();
    const validAt = data.validAt ? new Date(data.validAt) : capturedAt;

    try {
      const snapshot = await prisma.$transaction(async (tx) => {
        const created = await tx.sERPSnapshot.create({
          data: {
            projectId,
            query: normalizedQueryStr,
            locale: data.locale,
            device: data.device,
            capturedAt,
            validAt,
            rawPayload: data.rawPayload as Prisma.InputJsonValue,
            payloadSchemaVersion: data.payloadSchemaVersion ?? null,
            aiOverviewStatus: data.aiOverviewStatus ?? "parse_error",
            aiOverviewText: data.aiOverviewText ?? null,
            source: data.source,
            batchRef: data.batchRef ?? null,
          },
        });

        await tx.eventLog.create({
          data: {
            eventType: "SERP_SNAPSHOT_RECORDED",
            entityType: "serpSnapshot",
            entityId: created.id,
            actor: "human",
            projectId,
            details: {
              query: normalizedQueryStr,
              locale: data.locale,
              device: data.device,
              source: data.source,
              ...(data.batchRef ? { batchRef: data.batchRef } : {}),
            },
          },
        });

        return created;
      });

      return createdResponse(serializeSerpSnapshotRow(snapshot));
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === "P2002"
      ) {
        const existing = await prisma.sERPSnapshot.findUnique({
          where: {
            projectId_query_locale_device_capturedAt: {
              projectId,
              query: normalizedQueryStr,
              locale: data.locale,
              device: data.device,
              capturedAt,
            },
          },
        });

        if (existing) {
          return successResponse(serializeSerpSnapshotRow(existing));
        }

        return serverError();
      }
      throw err;
    }
  } catch (error) {
    console.error("POST serp-snapshots error", error);
    return serverError();
  }
}
