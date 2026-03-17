import { z } from "zod";

/**
 * POST /api/seo/serp-snapshot — W5 operator-triggered ingest
 *
 * Distinct from RecordSERPSnapshotSchema (raw ledger write).
 * This schema is the operator-facing ingest contract:
 * - confirm gate: false = dry-run cost estimate, true = write
 * - provider details (rawPayload, source, capturedAt) are server-assigned
 */
export const SERPSnapshotIngestSchema = z
  .object({
    query: z.string().min(1, "query is required"),
    locale: z.string().min(2, "locale is required"),
    device: z.enum(["desktop", "mobile"]),
    confirm: z.boolean(),
  })
  .strict();

export type SERPSnapshotIngestInput = z.infer<typeof SERPSnapshotIngestSchema>;
