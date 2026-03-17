/**
 * POST /api/seo/serp-snapshots - Record a SERPSnapshot
 * GET  /api/seo/serp-snapshots - List SERPSnapshots
 *
 * Grounded by:
 * - `docs/systems/veda/observatory/observation-ledger.md`
 * - `docs/systems/veda/observatory/ingest-discipline.md`
 * - `docs/architecture/veda/search-intelligence-layer.md`
 *
 * Record rules:
 * - immutable observation records (append-only)
 * - unique on `(projectId, query, locale, device, capturedAt)`
 * - query normalized at the API boundary
 * - `200` idempotent replay on duplicate (observation, not governance)
 * - `EventLog` emitted in the same transaction (POST only)
 *
 * GET constraints:
 * - project-scoped (`resolveProjectId`)
 * - deterministic ordering: `capturedAt desc, id desc`
 * - strict query param validation
 * - `includePayload` controls `rawPayload` via Prisma `select`
 * - no write behavior
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  createdResponse,
  successResponse,
  listResponse,
  badRequest,
  serverError,
  parsePagination,
} from "@/lib/api-response";
import { resolveProjectId } from "@/lib/project";
import { normalizeQuery } from "@/lib/validation";
import { RecordSERPSnapshotSchema } from "@/lib/schemas/serp-snapshot";
import { formatZodErrors } from "@/lib/zod-helpers";
import { Prisma } from "@prisma/client";

// Allowed device values - enforced at API boundary
const ALLOWED_DEVICES = ["desktop", "mobile"] as const;
type Device = (typeof ALLOWED_DEVICES)[number];

// ISO 8601 datetime with timezone (matches serp-snapshot schema validator)
const ISO_8601_DATETIME_TZ =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/;

function isValidIsoTimestamp(value: string): boolean {
  if (!ISO_8601_DATETIME_TZ.test(value)) return false;
  return !isNaN(new Date(value).getTime());
}

// =============================================================================
// GET /api/seo/serp-snapshots
// =============================================================================

export async function GET(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) {
      return badRequest(error);
    }

    const searchParams = request.nextUrl.searchParams;
    const { page, limit, skip } = parsePagination(searchParams);

    // Always project-scoped
    const where: Prisma.SERPSnapshotWhereInput = { projectId };

    // query filter (optional - normalize if present)
    const queryParam = searchParams.get("query");
    if (queryParam !== null) {
      if (queryParam.trim() === "") {
        return badRequest("query must not be empty");
      }
      where.query = normalizeQuery(queryParam);
    }

    // locale filter (optional, string)
    const localeParam = searchParams.get("locale");
    if (localeParam !== null) {
      if (localeParam.trim() === "") {
        return badRequest("locale must not be empty");
      }
      where.locale = localeParam;
    }

    // device filter (optional, enum-restricted)
    const deviceParam = searchParams.get("device");
    if (deviceParam !== null) {
      if (!(ALLOWED_DEVICES as readonly string[]).includes(deviceParam)) {
        return badRequest(`device must be one of: ${ALLOWED_DEVICES.join(", ")}`);
      }
      where.device = deviceParam as Device;
    }

    // from filter - capturedAt >= from
    const fromParam = searchParams.get("from");
    if (fromParam !== null) {
      if (!isValidIsoTimestamp(fromParam)) {
        return badRequest(
          'from must be a valid ISO 8601 datetime with timezone (e.g. 2025-01-01T00:00:00Z)'
        );
      }
      where.capturedAt = {
        ...(where.capturedAt as Prisma.DateTimeFilter ?? {}),
        gte: new Date(fromParam),
      };
    }

    // to filter - capturedAt <= to
    const toParam = searchParams.get("to");
    if (toParam !== null) {
      if (!isValidIsoTimestamp(toParam)) {
        return badRequest(
          'to must be a valid ISO 8601 datetime with timezone (e.g. 2025-12-31T23:59:59Z)'
        );
      }
      where.capturedAt = {
        ...(where.capturedAt as Prisma.DateTimeFilter ?? {}),
        lte: new Date(toParam),
      };
    }

    // includePayload filter (optional, strict true/false)
    const includePayloadParam = searchParams.get("includePayload");
    let includePayload = false;
    if (includePayloadParam !== null) {
      if (
        includePayloadParam !== "true" &&
        includePayloadParam !== "false"
      ) {
        return badRequest('includePayload must be "true" or "false"');
      }
      includePayload = includePayloadParam === "true";
    }

    // Base select - always returned fields
    const baseSelect = {
      id: true,
      query: true,
      locale: true,
      device: true,
      capturedAt: true,
      validAt: true,
      aiOverviewStatus: true,
      aiOverviewText: true,
      payloadSchemaVersion: true,
      source: true,
      batchRef: true,
      createdAt: true,
    };

    // Conditionally include rawPayload to avoid always returning JSONB blobs
    const select = includePayload
      ? { ...baseSelect, rawPayload: true }
      : baseSelect;

    const [rows, total] = await Promise.all([
      prisma.sERPSnapshot.findMany({
        where,
        orderBy: [{ capturedAt: "desc" }, { id: "desc" }],
        skip,
        take: limit,
        select,
      }),
      prisma.sERPSnapshot.count({ where }),
    ]);

    const items = rows.map((r) => ({
      ...r,
      capturedAt: r.capturedAt.toISOString(),
      validAt: r.validAt?.toISOString() ?? null,
      createdAt: r.createdAt.toISOString(),
    }));

    return listResponse(items, { page, limit, total });
  } catch (err) {
    console.error("GET /api/seo/serp-snapshots error:", err);
    return serverError();
  }
}

// =============================================================================
// POST /api/seo/serp-snapshots
// =============================================================================

export async function POST(request: NextRequest) {
  try {
    const { projectId, error } = await resolveProjectId(request);
    if (error) {
      return badRequest(error);
    }

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
            aiOverviewStatus: data.aiOverviewStatus ?? "unknown",
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

      return createdResponse({
        id: snapshot.id,
        query: snapshot.query,
        locale: snapshot.locale,
        device: snapshot.device,
        capturedAt: snapshot.capturedAt.toISOString(),
        validAt: snapshot.validAt?.toISOString() ?? null,
        aiOverviewStatus: snapshot.aiOverviewStatus,
        source: snapshot.source,
        batchRef: snapshot.batchRef,
        createdAt: snapshot.createdAt.toISOString(),
      });
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
          return successResponse({
            id: existing.id,
            query: existing.query,
            locale: existing.locale,
            device: existing.device,
            capturedAt: existing.capturedAt.toISOString(),
            validAt: existing.validAt?.toISOString() ?? null,
            aiOverviewStatus: existing.aiOverviewStatus,
            source: existing.source,
            batchRef: existing.batchRef,
            createdAt: existing.createdAt.toISOString(),
          });
        }

        return serverError();
      }
      throw err;
    }
  } catch (error) {
    console.error("POST /api/seo/serp-snapshots error:", error);
    return serverError();
  }
}
