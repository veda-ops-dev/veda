/**
 * POST /api/seo/ingest/run — DataForSEO Ingest Bridge (Operator Trigger)
 *
 * Operator-triggered SERP ingestion via DataForSEO Google Organic Live Advanced API.
 * Fetches real-time SERP results and writes SERPSnapshot records.
 *
 * No background jobs. No cron. Manually triggered only.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * MODES
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * confirm=false  →  Preview only. Returns previewCount, estimatedApiCost,
 *                   and keywords list. No writes.
 *
 * confirm=true   →  Perform ingestion. Calls DataForSEO, transforms responses
 *                   into SERPSnapshot records, writes each in a transaction
 *                   with an EventLog entry of type SERP_SNAPSHOT_CAPTURED.
 *                   Returns createdCount, skippedCount, results[].
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * IDEMPOTENCY
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Unique key: (projectId, query, locale, device, capturedAt).
 * If snapshot already exists → skip (P2002 → skippedCount++).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DETERMINISM
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Keywords sorted: query ASC, id ASC before iteration and in response.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DATA MAPPING
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * DataForSEO response → SERPSnapshot:
 *   query            ← KeywordTarget.query (normalizeQuery applied)
 *   locale           ← request body locale
 *   device           ← request body device
 *   capturedAt       ← new Date() at ingest time (per-keyword, fixed once per run)
 *   source           ← "dataforseo"
 *   rawPayload       ← tasks[0].result[0] (full DataForSEO result object)
 *   aiOverviewStatus ← extracted from rawPayload items (present/absent/parse_error)
 *   aiOverviewText   ← markdown text from ai_overview item (if present)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * AI OVERVIEW EXTRACTION
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Scans result.items[] for an item with type === "ai_overview".
 * If found → status "present", text from item.markdown or joined element text.
 * If not found → status "absent".
 * If result/items malformed → status "parse_error".
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DATAFORSEO API
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Endpoint: POST https://api.dataforseo.com/v3/serp/google/organic/live/advanced
 * Auth:     HTTP Basic (DATAFORSEO_LOGIN:DATAFORSEO_PASSWORD base64-encoded)
 * Task:     { keyword, language_code, location_code, device, load_async_ai_overview: true }
 * Locale → language_code + location_code:
 *   locale "en-US" → language_code "en", location_code 2840
 *   Other locales parsed as language_code = locale.split("-")[0],
 *   location_code = LOCALE_LOCATION_CODES[locale] or fallback 2840.
 *
 * Cost estimate: $0.002 per task (Live Advanced) + $0.002 for load_async_ai_overview
 *   = $0.004 per keyword (conservative upper bound). If no AI Overview,
 *   the async charge is refunded by DataForSEO, but we quote the upper bound.
 *
 * Credentials read from: DATAFORSEO_LOGIN, DATAFORSEO_PASSWORD env vars.
 * If missing → 503 with actionable error message.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * INVARIANTS
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * INV-1: All DB queries scoped by projectId.
 * INV-2: All writes inside prisma.$transaction().
 * INV-3: Every mutation emits EventLog (SERP_SNAPSHOT_CAPTURED).
 * INV-7: Zod .strict() on request body schema.
 */

import { z } from "zod";
import { NextRequest } from "next/server";
import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { badRequest, serverError, successResponse } from "@/lib/api-response";
import { resolveProjectIdStrict } from "@/lib/project";
import { normalizeQuery } from "@/lib/validation";

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const DATAFORSEO_BASE = "https://api.dataforseo.com";
const SERP_LIVE_ADVANCED = "/v3/serp/google/organic/live/advanced";

/** Conservative cost per keyword: Live Advanced ($0.002) + async AI Overview ($0.002) */
const COST_PER_KEYWORD_USD = 0.004;

/**
 * Known locale → DataForSEO location_code mappings.
 * Fallback: 2840 (United States).
 */
const LOCALE_LOCATION_CODES: Record<string, number> = {
  "en-US": 2840,
  "en-GB": 2826,
  "en-CA": 2124,
  "en-AU": 2036,
  "en-IN": 2356,
  "de-DE": 2276,
  "fr-FR": 2250,
  "es-ES": 2724,
  "es-MX": 2484,
  "it-IT": 2380,
  "pt-BR": 2076,
  "pt-PT": 2620,
  "nl-NL": 2528,
  "pl-PL": 2616,
  "sv-SE": 2752,
  "da-DK": 2208,
  "nb-NO": 2578,
  "fi-FI": 2246,
  "ja-JP": 2392,
  "ko-KR": 2410,
  "zh-CN": 2156,
  "zh-TW": 2158,
};

// ─────────────────────────────────────────────────────────────────────────────
// Request body schema
// ─────────────────────────────────────────────────────────────────────────────

const RunIngestSchema = z
  .object({
    keywordTargetIds: z
      .array(z.string().uuid("Each keywordTargetId must be a valid UUID"))
      .min(1, "At least one keywordTargetId is required")
      .max(50, "Maximum 50 keywordTargetIds per run"),
    locale: z.string().min(1, "locale is required").default("en-US"),
    device: z.enum(["desktop", "mobile"]),
    limit: z.number().int().min(1).max(50).default(50),
    confirm: z.boolean(),
  })
  .strict();

// ─────────────────────────────────────────────────────────────────────────────
// Locale parsing helpers
// ─────────────────────────────────────────────────────────────────────────────

function localeToLanguageCode(locale: string): string {
  // "en-US" → "en", "de-DE" → "de"
  const parts = locale.split("-");
  return parts[0].toLowerCase();
}

function localeToLocationCode(locale: string): number {
  return LOCALE_LOCATION_CODES[locale] ?? 2840;
}

// ─────────────────────────────────────────────────────────────────────────────
// DataForSEO API client
// ─────────────────────────────────────────────────────────────────────────────

interface DataForSEOTaskRequest {
  keyword: string;
  language_code: string;
  location_code: number;
  device: "desktop" | "mobile";
  load_async_ai_overview: boolean;
}

interface DataForSEOResultItem {
  type: string;
  rank_group?: number;
  rank_absolute?: number;
  markdown?: string | null;
  items?: Array<{ type: string; title?: string; text?: string }>;
  [key: string]: unknown;
}

interface DataForSEOResult {
  keyword?: string;
  items?: DataForSEOResultItem[];
  item_types?: string[];
  [key: string]: unknown;
}

interface DataForSEOTask {
  id?: string;
  status_code: number;
  status_message: string;
  result?: DataForSEOResult[] | null;
}

interface DataForSEOResponse {
  status_code: number;
  status_message: string;
  tasks: DataForSEOTask[];
}

async function callDataForSEO(
  tasks: DataForSEOTaskRequest[],
  login: string,
  password: string
): Promise<DataForSEOResponse> {
  const credentials = Buffer.from(`${login}:${password}`).toString("base64");

  const httpResponse = await fetch(`${DATAFORSEO_BASE}${SERP_LIVE_ADVANCED}`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${credentials}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(tasks),
  });

  if (!httpResponse.ok) {
    throw new Error(
      `DataForSEO HTTP error: ${httpResponse.status} ${httpResponse.statusText}`
    );
  }

  return httpResponse.json() as Promise<DataForSEOResponse>;
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Overview extraction from a DataForSEO result object
// ─────────────────────────────────────────────────────────────────────────────

interface AiOverviewExtraction {
  status: "present" | "absent" | "parse_error";
  text: string | null;
}

function extractAiOverview(result: DataForSEOResult): AiOverviewExtraction {
  if (!result || typeof result !== "object") {
    return { status: "parse_error", text: null };
  }

  if (!Array.isArray(result.items)) {
    // No items array — treat as absent unless item_types says otherwise
    if (Array.isArray(result.item_types) && result.item_types.includes("ai_overview")) {
      return { status: "parse_error", text: null };
    }
    return { status: "absent", text: null };
  }

  const aiItem = result.items.find((item) => item.type === "ai_overview");

  if (!aiItem) {
    return { status: "absent", text: null };
  }

  // Extract text: prefer markdown, then join ai_overview_element text fields
  let text: string | null = null;

  if (typeof aiItem.markdown === "string" && aiItem.markdown.trim().length > 0) {
    text = aiItem.markdown;
  } else if (Array.isArray(aiItem.items)) {
    const parts = aiItem.items
      .filter(
        (el): el is { type: string; title?: string; text?: string } =>
          el !== null && typeof el === "object"
      )
      .map((el) => [el.title, el.text].filter(Boolean).join(" "))
      .filter((s) => s.length > 0);
    text = parts.length > 0 ? parts.join("\n") : null;
  }

  return { status: "present", text };
}

// ─────────────────────────────────────────────────────────────────────────────
// POST handler
// ─────────────────────────────────────────────────────────────────────────────

export async function POST(request: NextRequest) {
  try {
    const { projectId, error: projectError } = await resolveProjectIdStrict(request);
    if (projectError) return badRequest(projectError);

    // ── Parse body ─────────────────────────────────────────────────────────────
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return badRequest("Invalid JSON body");
    }

    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return badRequest("Request body must be an object");
    }

    const parsed = RunIngestSchema.safeParse(body);
    if (!parsed.success) {
      const msgs = parsed.error.issues
        .map((i) => `${i.path.join(".") || "body"}: ${i.message}`)
        .join("; ");
      return badRequest(`Validation failed: ${msgs}`);
    }

    const { keywordTargetIds, locale, device, limit, confirm } = parsed.data;

    // ── Load + validate KeywordTargets belong to this project ──────────────────
    // Load all requested IDs in a single query, then cross-check.
    const targets = await prisma.keywordTarget.findMany({
      where: {
        id: { in: keywordTargetIds },
        projectId,
      },
      orderBy: [{ query: "asc" }, { id: "asc" }],
      select: { id: true, query: true, locale: true, device: true },
    });

    // Any IDs not returned belong to another project or don't exist → 404
    if (targets.length !== keywordTargetIds.length) {
      const foundIds = new Set(targets.map((t) => t.id));
      const missing = keywordTargetIds.filter((id) => !foundIds.has(id));
      return badRequest(
        `One or more keywordTargetIds not found in this project: ${missing.join(", ")}`,
        [{ code: "NOT_FOUND", message: "Cross-project access or missing KeywordTargets" }]
      ) as ReturnType<typeof badRequest>;
    }

    // Apply limit (deterministic: already ordered query ASC, id ASC)
    const selectedTargets = targets.slice(0, limit);

    // ── Preview mode ────────────────────────────────────────────────────────────
    if (!confirm) {
      const estimatedApiCost =
        Math.round(selectedTargets.length * COST_PER_KEYWORD_USD * 10000) / 10000;

      return successResponse({
        mode: "preview",
        previewCount: selectedTargets.length,
        estimatedApiCost,
        keywords: selectedTargets.map((t) => ({
          keywordTargetId: t.id,
          query: t.query,
          locale,
          device,
        })),
      });
    }

    // ── Ingest mode ─────────────────────────────────────────────────────────────

    // Read DataForSEO credentials from env
    const dfsLogin = process.env.DATAFORSEO_LOGIN;
    const dfsPassword = process.env.DATAFORSEO_PASSWORD;

    if (!dfsLogin || !dfsPassword) {
      return (
        successResponse(
          {
            error:
              "DataForSEO credentials not configured. Set DATAFORSEO_LOGIN and DATAFORSEO_PASSWORD environment variables.",
          },
          503
        ) as ReturnType<typeof successResponse>
      );
    }

    const languageCode = localeToLanguageCode(locale);
    const locationCode = localeToLocationCode(locale);

    // Fix capturedAt once for the entire run (deterministic per run)
    const capturedAt = new Date();

    // Build DataForSEO task list (one task per keyword; Live endpoint = 1 task/call)
    // We call sequentially to stay within operator control and avoid batching complexity.
    // For up to 50 keywords, sequential live calls are acceptable for an operator-triggered flow.
    const results: Array<{
      keywordTargetId: string;
      query: string;
      status: "created" | "skipped" | "error";
      snapshotId?: string;
      errorMessage?: string;
    }> = [];

    let createdCount = 0;
    let skippedCount = 0;

    for (const target of selectedTargets) {
      const normalizedQuery = normalizeQuery(target.query);

      const taskRequest: DataForSEOTaskRequest = {
        keyword: normalizedQuery,
        language_code: languageCode,
        location_code: locationCode,
        device: device === "desktop" ? "desktop" : "mobile",
        load_async_ai_overview: true,
      };

      let rawResult: DataForSEOResult | null = null;
      let aiOverviewStatus: "present" | "absent" | "parse_error" = "absent";
      let aiOverviewText: string | null = null;

      try {
        const dfsResponse = await callDataForSEO([taskRequest], dfsLogin, dfsPassword);

        if (
          dfsResponse.status_code === 20000 &&
          Array.isArray(dfsResponse.tasks) &&
          dfsResponse.tasks.length > 0
        ) {
          const task = dfsResponse.tasks[0];
          if (
            task.status_code === 20000 &&
            Array.isArray(task.result) &&
            task.result.length > 0
          ) {
            rawResult = task.result[0];
            const aiExtracted = extractAiOverview(rawResult);
            aiOverviewStatus = aiExtracted.status;
            aiOverviewText = aiExtracted.text;
          } else {
            // Task-level error — store partial payload, mark parse_error
            rawResult = { keyword: normalizedQuery, _taskError: task.status_message } as unknown as DataForSEOResult;
            aiOverviewStatus = "parse_error";
          }
        } else {
          rawResult = { keyword: normalizedQuery, _apiError: dfsResponse.status_message } as unknown as DataForSEOResult;
          aiOverviewStatus = "parse_error";
        }
      } catch (fetchErr) {
        // DataForSEO network/parse error — record as error, do not write snapshot
        results.push({
          keywordTargetId: target.id,
          query: target.query,
          status: "error",
          errorMessage:
            fetchErr instanceof Error ? fetchErr.message : "DataForSEO fetch failed",
        });
        continue;
      }

      // ── Write snapshot in transaction ──────────────────────────────────────
      try {
        const snapshot = await prisma.$transaction(async (tx) => {
          const created = await tx.sERPSnapshot.create({
            data: {
              projectId,
              query: normalizedQuery,
              locale,
              device,
              capturedAt,
              validAt: capturedAt,
              rawPayload: rawResult as Prisma.InputJsonValue,
              payloadSchemaVersion: "dataforseo.serp.organic.live.advanced.v1",
              aiOverviewStatus,
              aiOverviewText: aiOverviewText ?? null,
              source: "dataforseo",
              batchRef: null,
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
                keywordTargetId: target.id,
                query: normalizedQuery,
                locale,
                device,
                source: "dataforseo",
                aiOverviewStatus,
              },
            },
          });

          return created;
        });

        createdCount++;
        results.push({
          keywordTargetId: target.id,
          query: target.query,
          status: "created",
          snapshotId: snapshot.id,
        });
      } catch (writeErr) {
        if (
          writeErr instanceof Prisma.PrismaClientKnownRequestError &&
          writeErr.code === "P2002"
        ) {
          // Duplicate snapshot — idempotency skip
          skippedCount++;
          results.push({
            keywordTargetId: target.id,
            query: target.query,
            status: "skipped",
          });
        } else {
          results.push({
            keywordTargetId: target.id,
            query: target.query,
            status: "error",
            errorMessage:
              writeErr instanceof Error ? writeErr.message : "Write failed",
          });
        }
      }
    }

    return successResponse({
      mode: "ingest",
      createdCount,
      skippedCount,
      errorCount: results.filter((r) => r.status === "error").length,
      results,
    });
  } catch (err) {
    console.error("POST /api/seo/ingest/run error:", err);
    return serverError();
  }
}
