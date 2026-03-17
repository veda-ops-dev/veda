/**
 * POST /api/test/persist-serp-snapshot — Test-only persistence endpoint
 *
 * Exercises persistSerpSnapshot() without any provider dependency.
 * Accepts pre-normalized payload data and writes directly to the database.
 *
 * PRODUCTION GUARD: Returns 404 when NODE_ENV === "production".
 *
 * Purpose:
 *   - Deterministic hammer testing of persistence logic
 *   - EventLog transaction integrity verification
 *   - P2002 idempotency path testing
 *   - Cross-project isolation testing on the write path
 *
 * This route does NOT replace the operator-facing /api/seo/serp-snapshot.
 * It is a test harness for the extracted persistence function.
 */
import { NextRequest } from "next/server";
import { z } from "zod";
import {
  createdResponse,
  successResponse,
  badRequest,
  serverError,
} from "@/lib/api-response";
import { resolveProjectIdStrict } from "@/lib/project";
import { normalizeQuery } from "@/lib/validation";
import { formatZodErrors } from "@/lib/zod-helpers";
import { persistSerpSnapshot } from "@/lib/seo/persist-serp-snapshot";

// ---------------------------------------------------------------------------
// Schema — mirrors PersistSerpSnapshotInput as JSON
// ---------------------------------------------------------------------------

const TestPersistSchema = z
  .object({
    query: z.string().min(1),
    locale: z.string().min(2),
    device: z.enum(["desktop", "mobile"]),
    capturedAt: z.string().datetime().optional(),
    rawPayload: z.unknown().default({}),
    aiOverviewStatus: z.enum(["present", "absent"]).default("absent"),
    aiOverviewText: z.string().nullable().default(null),
    organicResultCount: z.number().int().min(0).default(0),
    aiOverviewPresent: z.boolean().default(false),
    features: z.array(z.string()).default([]),
  })
  .strict();

export async function POST(request: NextRequest) {
  // ── Production guard ──────────────────────────────────────────────────────
  if (process.env.NODE_ENV === "production") {
    return Response.json({ error: "not_found" }, { status: 404 });
  }

  try {
    const { projectId, error } = await resolveProjectIdStrict(request);
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

    const parsed = TestPersistSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodErrors(parsed.error));
    }

    const data = parsed.data;
    const normalizedQuery = normalizeQuery(data.query);
    const capturedAt = data.capturedAt ? new Date(data.capturedAt) : new Date();
    const validAt = capturedAt; // Test route: validAt = capturedAt (no provider datetime)

    const result = await persistSerpSnapshot({
      projectId,
      normalizedQuery,
      locale: data.locale,
      device: data.device,
      capturedAt,
      validAt,
      rawPayload: data.rawPayload as import("@prisma/client").Prisma.InputJsonValue,
      aiOverviewStatus: data.aiOverviewStatus,
      aiOverviewText: data.aiOverviewText,
      organicResultCount: data.organicResultCount,
      aiOverviewPresent: data.aiOverviewPresent,
      features: data.features,
    });

    const { snapshot } = result;
    const responseBody = {
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
      _created: result.created,
    };

    return result.created
      ? createdResponse(responseBody)
      : successResponse(responseBody);
  } catch (err) {
    console.error("POST /api/test/persist-serp-snapshot error:", err);
    return serverError();
  }
}
