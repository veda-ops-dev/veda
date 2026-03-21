/**
 * POST /api/seo/youtube/search/ingest — Y1 YouTube Search ingest request schema
 *
 * Grounded by:
 * - docs/systems/veda/youtube-observatory/y1-schema-judgment.md (Route Contract section)
 *
 * Strict validation. No extra fields allowed.
 * payload is the full DataForSEO response object — validated structurally by the normalizer.
 */
import { z } from "zod";

export const YtSearchIngestSchema = z
  .object({
    query: z.string().min(1, "query is required"),
    locale: z.string().min(1, "locale is required"),
    device: z.string().min(1, "device is required"),
    locationCode: z.string().min(1, "locationCode is required"),
    payload: z.record(z.string(), z.unknown()),
  })
  .strict();

export type YtSearchIngestInput = z.infer<typeof YtSearchIngestSchema>;

