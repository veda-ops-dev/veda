import { z } from "zod";

/**
 * Allowed data sources for SERPSnapshot ingestion.
 * Validated at the API boundary under the current ingest discipline and
 * Search Intelligence Layer rules.
 */
const VALID_SOURCES = ["dataforseo"] as const;

/**
 * ISO timestamp validation (strict): accepts ISO 8601 datetimes with timezone.
 * Matches: 2025-03-01T12:00:00Z, 2025-03-01T12:00:00.000Z, 2025-03-01T12:00:00+00:00
 */
const ISO_8601_DATETIME_TZ =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/;

const isoTimestampString = z
  .string()
  .regex(ISO_8601_DATETIME_TZ, "Must be a valid ISO 8601 datetime string")
  .refine((val) => !isNaN(new Date(val).getTime()), "Must be a valid ISO 8601 datetime string");

/**
 * POST /api/seo/serp-snapshots - Record SERPSnapshot
 * Grounded by:
 * - `docs/systems/veda/observatory/ingest-discipline.md`
 * - `docs/architecture/veda/search-intelligence-layer.md`
 */
export const RecordSERPSnapshotSchema = z
  .object({
    query: z.string().min(1, "query is required"),
    locale: z.string().min(1, "locale is required"),
    device: z.enum(["desktop", "mobile"]),
    capturedAt: isoTimestampString.optional(),
    validAt: isoTimestampString.optional(),
    rawPayload: z.unknown(),
    payloadSchemaVersion: z.string().optional(),
    aiOverviewStatus: z.enum(["present", "absent", "parse_error"]).optional(),
    aiOverviewText: z.string().optional(),
    source: z.enum(VALID_SOURCES),
    batchRef: z.string().optional(),
  })
  .strict();

