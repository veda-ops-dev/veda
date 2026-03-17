import { z } from "zod";
import { normalizeQuery } from "@/lib/validation";

/**
 * POST /api/seo/keyword-research — W4 confirm-gated keyword research wrapper
 *
 * confirm=false → dry-run: cost estimate + normalized keywords, no DB writes
 * confirm=true  → idempotent upsert of KeywordTarget governance records
 *
 * keywords: 1..19 items (20 is rejected — safe batch ceiling)
 * locale: min 2 chars
 * device: "desktop" | "mobile"
 * confirm: boolean strict (string "true" rejected)
 * .strict() — unknown fields rejected
 */

export const KeywordResearchSchema = z
  .object({
    keywords: z
      .array(
        z
          .string()
          .min(1, "each keyword must be non-empty")
          .transform((kw) => normalizeQuery(kw))
          .refine((kw) => kw.length > 0, "each keyword must be non-empty after normalization")
      )
      .min(1, "keywords must have at least 1 item")
      .max(19, "keywords must have at most 19 items"),
    locale: z.string().min(2, "locale is required (min 2 chars)"),
    device: z.enum(["desktop", "mobile"]),
    confirm: z.boolean(),
  })
  .strict();

export type KeywordResearchInput = z.infer<typeof KeywordResearchSchema>;
