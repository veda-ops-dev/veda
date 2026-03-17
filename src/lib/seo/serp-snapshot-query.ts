import { Prisma } from "@prisma/client";
import { z } from "zod";
import { normalizeQuery } from "@/lib/validation";

const ALLOWED_DEVICES = ["desktop", "mobile"] as const;
const ALLOWED_INCLUDE_PAYLOAD = ["true", "false"] as const;
const ISO_8601_DATETIME_TZ =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/;

function isValidIsoTimestamp(value: string): boolean {
  if (!ISO_8601_DATETIME_TZ.test(value)) return false;
  return !isNaN(new Date(value).getTime());
}

const positiveIntString = (field: string) =>
  z
    .string()
    .regex(/^\d+$/, `${field} must be a positive integer`)
    .transform((value) => Number.parseInt(value, 10));

const isoTimestampString = z
  .string()
  .refine(
    isValidIsoTimestamp,
    "Must be a valid ISO 8601 datetime with timezone"
  );

export const SerpSnapshotQuerySchema = z
  .object({
    query: z.string().optional(),
    locale: z.string().optional(),
    device: z.enum(ALLOWED_DEVICES).optional(),
    from: isoTimestampString.optional(),
    to: isoTimestampString.optional(),
    includePayload: z.enum(ALLOWED_INCLUDE_PAYLOAD).optional(),
    page: positiveIntString("page").optional(),
    limit: positiveIntString("limit")
      .refine((value) => value <= 100, "limit must be less than or equal to 100")
      .optional(),
  })
  .strict();

export type SerpSnapshotQueryFilters = {
  query: string | null;
  locale: string | null;
  device: (typeof ALLOWED_DEVICES)[number] | null;
  from: string | null;
  to: string | null;
};

export type ParsedSerpSnapshotQuery = {
  page: number;
  limit: number;
  skip: number;
  where: Prisma.SERPSnapshotWhereInput;
  includePayload: boolean;
  filters: SerpSnapshotQueryFilters;
};

function formatIssues(error: z.ZodError): string {
  return error.issues
    .map((issue) => {
      const path = issue.path.length > 0 ? `${issue.path.join(".")}: ` : "";
      return `${path}${issue.message}`;
    })
    .join("; ");
}

export function parseSerpSnapshotQuery(args: {
  searchParams: URLSearchParams;
  projectId: string;
}): ParsedSerpSnapshotQuery {
  const rawQueryParam = args.searchParams.get("query");
  if (rawQueryParam !== null && rawQueryParam.trim().length === 0) {
    throw new Error("query must not be empty");
  }

  const rawLocaleParam = args.searchParams.get("locale");
  if (rawLocaleParam !== null && rawLocaleParam.trim().length === 0) {
    throw new Error("locale must not be empty");
  }

  const rawParams = Object.fromEntries(args.searchParams.entries());
  const parsed = SerpSnapshotQuerySchema.safeParse(rawParams);
  if (!parsed.success) {
    throw new Error(`Validation failed: ${formatIssues(parsed.error)}`);
  }

  const query = parsed.data.query?.trim();
  const locale = parsed.data.locale?.trim();

  const fromDate = parsed.data.from ? new Date(parsed.data.from) : null;
  const toDate = parsed.data.to ? new Date(parsed.data.to) : null;
  if (fromDate && toDate && fromDate.getTime() > toDate.getTime()) {
    throw new Error("from must be less than or equal to to");
  }

  const page = parsed.data.page ?? 1;
  const limit = parsed.data.limit ?? 20;
  const skip = (page - 1) * limit;

  const where: Prisma.SERPSnapshotWhereInput = { projectId: args.projectId };
  if (query) {
    where.query = normalizeQuery(query);
  }
  if (locale) {
    where.locale = locale;
  }
  if (parsed.data.device) {
    where.device = parsed.data.device;
  }
  if (fromDate || toDate) {
    where.capturedAt = {
      ...(fromDate ? { gte: fromDate } : {}),
      ...(toDate ? { lte: toDate } : {}),
    };
  }

  return {
    page,
    limit,
    skip,
    where,
    includePayload: parsed.data.includePayload === "true",
    filters: {
      query: query ? normalizeQuery(query) : null,
      locale: locale ?? null,
      device: parsed.data.device ?? null,
      from: parsed.data.from ?? null,
      to: parsed.data.to ?? null,
    },
  };
}
