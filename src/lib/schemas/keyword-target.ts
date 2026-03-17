import { z } from "zod";

/**
 * POST /api/seo/keyword-targets - Create KeywordTarget
 * Grounded by:
 * - `docs/systems/veda/observatory/ingest-discipline.md`
 * - `docs/architecture/veda/search-intelligence-layer.md`
 */
export const CreateKeywordTargetSchema = z
  .object({
    query: z.string().min(1, "query is required"),
    locale: z.string().min(1, "locale is required"),
    device: z.enum(["desktop", "mobile"]),
    isPrimary: z.boolean().optional(),
    intent: z.string().optional(),
    notes: z.string().optional(),
  })
  .strict();
