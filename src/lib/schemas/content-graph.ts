import { z } from "zod";

// Content Graph Phase 1 Schemas
// Per docs/specs/CONTENT-GRAPH-DATA-MODEL.md, docs/specs/CONTENT-GRAPH-PHASES.md

export const CG_SURFACE_TYPES = ["website", "wiki", "blog", "x", "youtube"] as const;
export const CG_PUBLISHING_STATES = ["draft", "published", "archived"] as const;
export const CG_PAGE_ROLES = ["primary", "supporting", "reviewed", "compared", "navigation"] as const;
export const CG_LINK_ROLES = ["hub", "support", "navigation"] as const;

// ---------------------------------------------------------------------------
// canonicalIdentifier validation helpers
// ---------------------------------------------------------------------------

// Shared: no whitespace, non-empty (enforced separately from nullable check)
const CANONICAL_ID_BASE = z
  .string()
  .min(1)
  .max(500)
  .regex(/^\S+$/, "canonicalIdentifier must not contain whitespace");

/**
 * Returns a type-specific canonical identifier validator, or the shared base
 * if the type doesn't have stronger rules yet.
 *
 * website / wiki / blog  → normalized host (no scheme, no trailing slash)
 *   e.g. "psymetric.io", "docs.psymetric.io"
 * youtube                → channel ID only (UC + 22 base64url chars)
 *   per VEDA-YOUTUBE-IDENTITY-NORMALIZATION.md; @handle must be resolved before registration
 * x                      → handle without @, lowercase alphanumeric + underscores
 */
function canonicalIdentifierForType(
  type: (typeof CG_SURFACE_TYPES)[number]
): z.ZodString {
  switch (type) {
    case "website":
    case "wiki":
    case "blog":
      // Must look like a hostname: no scheme, no path, no whitespace
      return CANONICAL_ID_BASE.regex(
        /^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$/,
        "canonicalIdentifier for website/wiki/blog must be a normalized hostname (e.g. \"psymetric.io\")"
      );
    case "youtube":
      // Channel ID only (UC + 22 base64url chars, 24 total).
      // Per VEDA-YOUTUBE-IDENTITY-NORMALIZATION.md: @handle and other
      // weaker forms must be resolved to UC... before surface registration.
      // The observatory ownership join requires exact UC... string equality.
      return CANONICAL_ID_BASE.regex(
        /^UC[A-Za-z0-9_-]{22}$/,
        "canonicalIdentifier for youtube must be a channel ID in UC... form (24 characters). Resolve @handles to channel IDs before registration."
      );
    case "x":
      // X handle without @, 1-50 chars, alphanumeric + underscores
      return CANONICAL_ID_BASE.regex(
        /^[A-Za-z0-9_]{1,50}$/,
        "canonicalIdentifier for x must be a handle without @ (e.g. \"psymetric\")"
      );
    default:
      return CANONICAL_ID_BASE;
  }
}

export const CreateCgSurfaceSchema = z
  .object({
    type: z.enum(CG_SURFACE_TYPES),
    // key is canonicalized at write time in the route (trim + lowercase + collapse spaces to hyphens).
    // This schema validates the raw input before canonicalization; the route stores the canonical form.
    key: z
      .string()
      .min(1)
      .max(100)
      .regex(
        /^[a-zA-Z0-9][a-zA-Z0-9 _-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$/,
        "key must start and end with alphanumeric; may contain letters, numbers, spaces, hyphens, underscores"
      ),
    label: z.string().min(1).optional(),
    canonicalIdentifier: z.string().optional(), // per-type validation applied in route after type is known
    canonicalUrl: z.string().url("canonicalUrl must be a valid URL").optional(),
    enabled: z.boolean().optional(),
  })
  .strict()
  .superRefine((data, ctx) => {
    if (data.canonicalIdentifier !== undefined) {
      const result = canonicalIdentifierForType(data.type).safeParse(data.canonicalIdentifier);
      if (!result.success) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["canonicalIdentifier"],
          message: result.error.issues[0]?.message ?? "Invalid canonicalIdentifier for this surface type",
        });
      }
    }
  });

export const CreateCgSiteSchema = z
  .object({
    surfaceId: z.string().uuid(),
    domain: z.string().min(1).max(255),
    framework: z.string().min(1).optional(),
    isCanonical: z.boolean().optional(),
    notes: z.string().optional(),
  })
  .strict();

export const CreateCgPageSchema = z
  .object({
    siteId: z.string().uuid(),
    contentArchetypeId: z.string().uuid().optional(),
    url: z.string().min(1).max(2048),
    title: z.string().min(1),
    canonicalUrl: z.string().optional(),
    publishingState: z.enum(CG_PUBLISHING_STATES).optional(),
    isIndexable: z.boolean().optional(),
  })
  .strict();

export const CreateCgContentArchetypeSchema = z
  .object({
    key: z.string().min(1).max(100),
    label: z.string().min(1),
  })
  .strict();

export const CreateCgTopicSchema = z
  .object({
    key: z.string().min(1).max(100),
    label: z.string().min(1),
  })
  .strict();

export const CreateCgEntitySchema = z
  .object({
    key: z.string().min(1).max(100),
    label: z.string().min(1),
    entityType: z.string().min(1).max(100),
  })
  .strict();

export const CreateCgPageTopicSchema = z
  .object({
    pageId: z.string().uuid(),
    topicId: z.string().uuid(),
    role: z.enum(CG_PAGE_ROLES).optional(),
  })
  .strict();

export const CreateCgPageEntitySchema = z
  .object({
    pageId: z.string().uuid(),
    entityId: z.string().uuid(),
    role: z.enum(CG_PAGE_ROLES).optional(),
  })
  .strict();

export const CreateCgInternalLinkSchema = z
  .object({
    sourcePageId: z.string().uuid(),
    targetPageId: z.string().uuid(),
    anchorText: z.string().optional(),
    linkRole: z.enum(CG_LINK_ROLES).optional(),
  })
  .strict();

export const CreateCgSchemaUsageSchema = z
  .object({
    pageId: z.string().uuid(),
    schemaType: z.string().min(1).max(100),
    isPrimary: z.boolean().optional(),
  })
  .strict();

export type CreateCgSurfaceInput = z.infer<typeof CreateCgSurfaceSchema>;
export { canonicalIdentifierForType };
export type CreateCgSiteInput = z.infer<typeof CreateCgSiteSchema>;
export type CreateCgPageInput = z.infer<typeof CreateCgPageSchema>;
export type CreateCgContentArchetypeInput = z.infer<typeof CreateCgContentArchetypeSchema>;
export type CreateCgTopicInput = z.infer<typeof CreateCgTopicSchema>;
export type CreateCgEntityInput = z.infer<typeof CreateCgEntitySchema>;
export type CreateCgPageTopicInput = z.infer<typeof CreateCgPageTopicSchema>;
export type CreateCgPageEntityInput = z.infer<typeof CreateCgPageEntitySchema>;
export type CreateCgInternalLinkInput = z.infer<typeof CreateCgInternalLinkSchema>;
export type CreateCgSchemaUsageInput = z.infer<typeof CreateCgSchemaUsageSchema>;
