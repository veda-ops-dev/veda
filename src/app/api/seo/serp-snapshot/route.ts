/**
 * POST /api/seo/serp-snapshot - W5 operator-triggered SERP ingest
 *
 * Grounded by:
 * - `docs/systems/veda/observatory/observation-ledger.md`
 * - `docs/systems/veda/observatory/ingest-discipline.md`
 * - `docs/architecture/veda/search-intelligence-layer.md`
 *
 * Record rules:
 * - operator-triggered only (no automation)
 * - confirm gate: `confirm=false` returns cost estimate without writing
 * - `confirm=true` calls DataForSEO, normalizes result, writes `SERPSnapshot` + `EventLog`
 * - query normalized at the API boundary (`normalizeQuery`)
 * - `capturedAt` is server-assigned (`now()`)
 * - `validAt` uses provider datetime if present, else `capturedAt`
 * - `rawPayload` stores the full provider response (no truncation)
 * - `source` is fixed to `dataforseo`
 * - locale `en-US` only: other locales return 400 before the provider is called
 * - provider response shape is validated (`tasks[0].result[0].items`) before write
 * - idempotency: `P2002` on `(projectId, query, locale, device, capturedAt)` -> `200`, no `EventLog`
 *
 * Hard constraints:
 * - no schema changes
 * - no list/update/delete
 * - mutation and `EventLog` are co-located in `prisma.$transaction()`
 */
import { NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import {
  createdResponse,
  successResponse,
  badRequest,
  serverError,
} from "@/lib/api-response";
import { resolveProjectIdStrict } from "@/lib/project";
import { normalizeQuery } from "@/lib/validation";
import { SERPSnapshotIngestSchema } from "@/lib/schemas/serp-snapshot-ingest";
import { formatZodErrors } from "@/lib/zod-helpers";
import { Prisma } from "@prisma/client";
import {
  fetchSerpSnapshot,
  DataForSeoError,
} from "@/lib/integrations/dataforseo/client";
import { normalizeDataForSeoSerp } from "@/lib/integrations/dataforseo/normalize-serp";
import { persistSerpSnapshot } from "@/lib/seo/persist-serp-snapshot";

// Fixed cost per ingest task (DataForSEO live/advanced unit price).
const ESTIMATED_COST_USD = 0.0012;

export async function POST(request: NextRequest) {
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

    const parsed = SERPSnapshotIngestSchema.safeParse(body);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodErrors(parsed.error));
    }

    const data = parsed.data;

    // ==========================================================================
    // Dry-run path: confirm=false -- return cost estimate, do NOT write
    // ==========================================================================
    if (!data.confirm) {
      return successResponse({
        confirm_required: true,
        estimated_cost: ESTIMATED_COST_USD,
      });
    }

    // ==========================================================================
    // Confirmed write path: confirm=true
    // ==========================================================================

    const normalizedQuery = normalizeQuery(data.query);

    // capturedAt is server-assigned once and used for idempotency key
    const capturedAt = new Date();

    // -- Recent-window idempotency check (before provider call) --------------
    // If a snapshot for this (projectId, query, locale, device) was captured
    // within the last 60 seconds, return it without re-calling the provider.
    // This handles realistic operator double-submits (replay test, UI retry).
    const recentWindowMs = 60_000;
    const recentCutoff = new Date(capturedAt.getTime() - recentWindowMs);
    const recentSnapshot = await prisma.sERPSnapshot.findFirst({
      where: {
        projectId,
        query: normalizedQuery,
        locale: data.locale,
        device: data.device,
        capturedAt: { gte: recentCutoff },
      },
      orderBy: [{ capturedAt: "desc" }, { id: "desc" }],
    });
    if (recentSnapshot) {
      return successResponse({
        id: recentSnapshot.id,
        query: recentSnapshot.query,
        locale: recentSnapshot.locale,
        device: recentSnapshot.device,
        capturedAt: recentSnapshot.capturedAt.toISOString(),
        validAt: recentSnapshot.validAt?.toISOString() ?? null,
        aiOverviewStatus: recentSnapshot.aiOverviewStatus,
        source: recentSnapshot.source,
        batchRef: recentSnapshot.batchRef,
        createdAt: recentSnapshot.createdAt.toISOString(),
      });
    }

    // -- Call DataForSEO provider --------------------------------------------
    let providerResponse: unknown;
    try {
      providerResponse = await fetchSerpSnapshot({
        query: normalizedQuery,
        locale: data.locale,
        device: data.device,
      });
    } catch (err) {
      if (err instanceof DataForSeoError) {
        // Locale validation failures are client errors (400), not provider errors.
        const isLocaleError = err.message.startsWith("Unsupported locale");
        return Response.json(
          isLocaleError
            ? { error: "invalid_locale", message: err.message }
            : {
                error: "provider_error",
                provider: "dataforseo",
                message: err.providerMessage ?? err.message,
              },
          { status: isLocaleError ? 400 : 502 }
        );
      }
      throw err;
    }

    // -- Validate provider response shape before normalizing or writing -------
    // Avoids writing a broken/empty snapshot when DataForSEO returns an
    // unexpected envelope (e.g. quota exhausted, partial response).
    {
      const r = providerResponse as Record<string, unknown>;
      const tasks = r?.tasks;
      const validShape =
        Array.isArray(tasks) &&
        tasks.length > 0 &&
        Array.isArray((tasks[0] as Record<string, unknown>)?.result) &&
        ((tasks[0] as Record<string, unknown>).result as unknown[]).length > 0 &&
        Array.isArray(
          (((tasks[0] as Record<string, unknown>).result as unknown[])[0] as Record<string, unknown>)?.items
        );

      if (!validShape) {
        return Response.json(
          {
            error: "provider_error",
            provider: "dataforseo",
            message:
              "Provider response missing expected shape: tasks[0].result[0].items",
          },
          { status: 502 }
        );
      }
    }

    // -- Normalize provider response -----------------------------------------
    const normalized = normalizeDataForSeoSerp(providerResponse);

    // validAt: use provider datetime if present, else fall back to capturedAt
    const validAt = normalized.validAt ? new Date(normalized.validAt) : capturedAt;

    const rawPayload = normalized.rawPayload as Prisma.InputJsonValue;

    // -- Write snapshot + event log atomically --------------------------------
    const result = await persistSerpSnapshot({
      projectId,
      normalizedQuery,
      locale: data.locale,
      device: data.device,
      capturedAt,
      validAt,
      rawPayload,
      aiOverviewStatus: normalized.aiOverviewStatus,
      aiOverviewText: normalized.aiOverviewText,
      organicResultCount: normalized.organicResults.length,
      aiOverviewPresent: normalized.aiOverviewPresent,
      features: normalized.features,
    });

    const { snapshot } = result;

    if (result.created) {
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
        organicResultCount: normalized.organicResults.length,
        topDomains: normalized.topDomains,
        aiOverviewPresent: normalized.aiOverviewPresent,
        features: normalized.features,
        createdAt: snapshot.createdAt.toISOString(),
      });
    }

    // P2002 idempotent replay — no EventLog on replay
    return successResponse({
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
    console.error("POST /api/seo/serp-snapshot error:", err);
    return serverError();
  }
}
