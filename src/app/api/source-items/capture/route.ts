/**
 * POST /api/source-items/capture
 * Per docs/operations-planning-api/01-API-ENDPOINTS-AND-VALIDATION-CONTRACTS.md
 *
 * Creates a new SourceItem, or handles recapture if URL already exists.
 * Required: sourceType, url, operatorIntent
 * Optional: platform, notes
 *
 * New capture: status=ingested, generates contentHash, logs SOURCE_CAPTURED → 201
 * Recapture: logs SOURCE_CAPTURED with recapture=true, appends notes → 200
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  createdResponse,
  successResponse,
  badRequest,
  conflict,
  serverError,
} from "@/lib/api-response";
import { generateContentHash } from "@/lib/validation";
import { resolveProjectId } from "@/lib/project";
import { CaptureSourceItemSchema } from "@/lib/schemas/source-item";
import { formatZodErrors } from "@/lib/zod-helpers";

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

    const parsed = CaptureSourceItemSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodErrors(parsed.error));
    }

    const data = parsed.data;

    // --- Check for existing SourceItem with this URL ---
    // NOTE: SourceItem.url is globally unique in the schema. Enforce project isolation explicitly.
    const existing = await prisma.sourceItem.findUnique({
      where: { url: data.url },
    });

    if (existing) {
      // If the URL exists but belongs to another project, do not mutate across projects.
      if (existing.projectId !== projectId) {
        // Preserve global uniqueness invariant without leaking cross-project existence
        return conflict("URL already exists");
      }

      // --- Recapture: URL already exists --- (transactional)
      await prisma.$transaction(async (tx) => {
        if (data.notes) {
          const existingNotes = existing.notes || "";
          const recaptureNote = `\n\n[Recapture ${new Date().toISOString()}]: ${data.notes}`;
          await tx.sourceItem.update({
            where: { id: existing.id },
            data: { notes: existingNotes + recaptureNote },
          });
        }

        await tx.eventLog.create({
          data: {
            eventType: "SOURCE_CAPTURED",
            entityType: "sourceItem",
            entityId: existing.id,
            actor: "human",
            projectId,
            details: {
              recapture: true,
              sourceType: data.sourceType,
              url: data.url,
              operatorIntent: data.operatorIntent,
              ...(data.notes ? { notes: data.notes } : {}),
            },
          },
        });
      });

      return successResponse({
        id: existing.id,
        sourceType: existing.sourceType,
        url: existing.url,
        status: existing.status,
        capturedAt: existing.capturedAt.toISOString(),
        createdAt: existing.createdAt.toISOString(),
      });
    }

    // --- New capture: URL does not exist --- (transactional)
    const contentHash = await generateContentHash(data.url);

    const sourceItem = await prisma.$transaction(async (tx) => {
      const item = await tx.sourceItem.create({
        data: {
          sourceType: data.sourceType,
          platform: data.platform || "other",
          url: data.url,
          capturedBy: "human",
          contentHash,
          operatorIntent: data.operatorIntent,
          notes: data.notes || null,
          status: "ingested",
          projectId,
        },
      });

      await tx.eventLog.create({
        data: {
          eventType: "SOURCE_CAPTURED",
          entityType: "sourceItem",
          entityId: item.id,
          actor: "human",
          projectId,
          details: {
            sourceType: item.sourceType,
            url: item.url,
            operatorIntent: data.operatorIntent,
          },
        },
      });

      return item;
    });

    return createdResponse({
      id: sourceItem.id,
      sourceType: sourceItem.sourceType,
      url: sourceItem.url,
      status: sourceItem.status,
      capturedAt: sourceItem.capturedAt.toISOString(),
      createdAt: sourceItem.createdAt.toISOString(),
    });
  } catch (error) {
    console.error("POST /api/source-items/capture error:", error);
    return serverError();
  }
}
