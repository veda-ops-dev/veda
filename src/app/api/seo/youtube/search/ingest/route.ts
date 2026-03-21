/**
 * POST /api/seo/youtube/search/ingest — Y1 YouTube Search Observatory ingest
 *
 * Grounded by:
 * - docs/systems/veda/youtube-observatory/y1-schema-judgment.md
 * - docs/systems/veda/youtube-observatory/ingest-discipline.md
 * - docs/systems/veda/youtube-observatory/validation-doctrine.md
 *
 * Behavior:
 * 1. Resolve projectId strictly (no fallback)
 * 2. Validate request body with Zod .strict()
 * 3. Find-or-create YtSearchTarget; emit YT_SEARCH_TARGET_CREATED if created
 * 4. 60-second recent-window idempotency gate → 409 on duplicate
 * 5. Run pure normalizer on payload
 * 6. Single transaction: snapshot + elements + EventLog
 * 7. Return 201 with snapshotId and elementCount
 *
 * Error responses: 400 / 404 / 409 / 500
 *
 * Hard constraints:
 * - No read routes in this pass
 * - No enrichment
 * - Mutation and EventLog co-located in prisma.$transaction()
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  createdResponse,
  badRequest,
  conflict,
  notFound,
  serverError,
} from "@/lib/api-response";
import { resolveProjectIdStrict } from "@/lib/project";
import { YtSearchIngestSchema } from "@/lib/schemas/yt-search-ingest";
import { formatZodErrors } from "@/lib/zod-helpers";
import { normalizeYtSearchPayload } from "@/lib/seo/youtube/normalize-yt-search";
import { Prisma } from "@prisma/client";

const RECENT_WINDOW_MS = 60_000;

export async function POST(request: NextRequest) {
  try {
    // 1. Resolve project strictly
    const { projectId, error: projectError } = await resolveProjectIdStrict(request);
    if (projectError) {
      // Non-disclosure: if project not found, return 404 not 400
      if (projectError.includes("not found")) {
        return notFound("Not found");
      }
      return badRequest(projectError);
    }

    // 2. Parse and validate request body
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return badRequest("Invalid JSON body");
    }

    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return badRequest("Request body must be an object");
    }

    const parsed = YtSearchIngestSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodErrors(parsed.error));
    }

    const data = parsed.data;

    // 3. Normalize payload via pure normalizer
    let normalized;
    try {
      normalized = normalizeYtSearchPayload(data.payload);
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Payload normalization failed";
      return badRequest(msg);
    }

    // Validate: every element must have a valid rankAbsolute (normalizer already filters,
    // but check for duplicate rankAbsolute within the payload — atomic rejection per T9-01)
    const rankSet = new Set<number>();
    for (const el of normalized.elements) {
      if (rankSet.has(el.rankAbsolute)) {
        return badRequest(
          `Duplicate rank_absolute ${el.rankAbsolute} in payload items`
        );
      }
      rankSet.add(el.rankAbsolute);
    }

    const capturedAt = new Date();

    // 4. Find-or-create target
    let target = await prisma.ytSearchTarget.findUnique({
      where: {
        projectId_query_locale_device_locationCode: {
          projectId,
          query: data.query,
          locale: data.locale,
          device: data.device,
          locationCode: data.locationCode,
        },
      },
    });

    let targetCreated = false;
    if (!target) {
      // Create target + EventLog atomically
      target = await prisma.$transaction(async (tx) => {
        const created = await tx.ytSearchTarget.create({
          data: {
            projectId,
            query: data.query,
            locale: data.locale,
            device: data.device,
            locationCode: data.locationCode,
          },
        });

        await tx.eventLog.create({
          data: {
            eventType: "YT_SEARCH_TARGET_CREATED",
            entityType: "ytSearchTarget",
            entityId: created.id,
            actor: "system",
            projectId,
            details: {
              query: data.query,
              locale: data.locale,
              device: data.device,
              locationCode: data.locationCode,
            },
          },
        });

        return created;
      });
      targetCreated = true;
    }

    // 5. Idempotency: 60-second recent-window gate
    const recentCutoff = new Date(capturedAt.getTime() - RECENT_WINDOW_MS);
    const recentSnapshot = await prisma.ytSearchSnapshot.findFirst({
      where: {
        projectId,
        ytSearchTargetId: target.id,
        capturedAt: { gte: recentCutoff },
      },
      orderBy: [{ capturedAt: "desc" }, { id: "desc" }],
    });

    if (recentSnapshot) {
      return conflict("Duplicate snapshot within 60-second window");
    }

    // 6. Atomic write: snapshot + elements + EventLog
    const validAt = normalized.snapshot.validAt
      ? new Date(normalized.snapshot.validAt)
      : null;

    const result = await prisma.$transaction(async (tx) => {
      const snapshot = await tx.ytSearchSnapshot.create({
        data: {
          projectId,
          ytSearchTargetId: target!.id,
          capturedAt,
          validAt,
          checkUrl: normalized.snapshot.checkUrl,
          itemsCount: normalized.snapshot.itemsCount,
          itemTypes: normalized.snapshot.itemTypes,
          rawPayload: normalized.snapshot.resultEnvelope as Prisma.InputJsonValue,
          source: "dataforseo-youtube-organic",
        },
      });

      // Create element rows
      if (normalized.elements.length > 0) {
        await tx.ytSearchElement.createMany({
          data: normalized.elements.map((el) => ({
            snapshotId: snapshot.id,
            projectId,
            elementType: el.elementType,
            rankAbsolute: el.rankAbsolute,
            rankGroup: el.rankGroup,
            blockRank: el.blockRank,
            blockName: el.blockName,
            channelId: el.channelId,
            videoId: el.videoId,
            isShort: el.isShort,
            isLive: el.isLive,
            isMovie: el.isMovie,
            isVerified: el.isVerified,
            observedPublishedAt: el.observedPublishedAt
              ? new Date(el.observedPublishedAt)
              : null,
            rawPayload: el.rawPayload as Prisma.InputJsonValue,
          })),
        });
      }

      // EventLog for snapshot
      await tx.eventLog.create({
        data: {
          eventType: "YT_SEARCH_SNAPSHOT_RECORDED",
          entityType: "ytSearchSnapshot",
          entityId: snapshot.id,
          actor: "system",
          projectId,
          details: {
            targetId: target!.id,
            query: data.query,
            locale: data.locale,
            device: data.device,
            locationCode: data.locationCode,
            itemsCount: normalized.snapshot.itemsCount,
            elementCount: normalized.elements.length,
            itemTypes: normalized.snapshot.itemTypes,
            source: "dataforseo-youtube-organic",
            targetCreated,
          },
        },
      });

      return snapshot;
    });

    // 7. Return 201
    return createdResponse({
      snapshotId: result.id,
      elementCount: normalized.elements.length,
      targetId: target.id,
      targetCreated,
      capturedAt: result.capturedAt.toISOString(),
      itemsCount: result.itemsCount,
    });
  } catch (err) {
    console.error("POST /api/seo/youtube/search/ingest error:", err);
    return serverError();
  }
}
