/**
 * Project validation schemas
 *
 * Per VEDA-CREATE-PROJECT-WORKFLOW.md
 * All write schemas use .strict() per invariant rules.
 */
import { z } from "zod";

// ── Slug generation helper ──────────────────────────────────────────────────

const SLUG_RE = /^[a-z0-9][a-z0-9-]*[a-z0-9]$/;

/**
 * Derive a URL-safe slug from a project name.
 * Rules: lowercase, alphanumeric + hyphens, no leading/trailing hyphens.
 */
export function deriveSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

// ── Create Project ──────────────────────────────────────────────────────────

export const CreateProjectSchema = z
  .object({
    name: z.string().min(1).max(200),
    slug: z
      .string()
      .min(2)
      .max(100)
      .regex(SLUG_RE, "Slug must be lowercase alphanumeric with hyphens, no leading/trailing hyphens")
      .optional(),
    description: z.string().max(2000).optional(),
  })
  .strict();


