import { z } from "zod";


const ISO_DATE_ONLY_RE = /^\d{4}-\d{2}-\d{2}$/;
const ISO_TIMESTAMP_RE =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z$/;

const isoDateString = z.string().refine(
  (val) => {
    if (!ISO_DATE_ONLY_RE.test(val) && !ISO_TIMESTAMP_RE.test(val))
      return false;
    const parsed = new Date(val);
    if (isNaN(parsed.getTime())) return false;
    if (ISO_DATE_ONLY_RE.test(val)) {
      return parsed.toISOString().slice(0, 10) === val;
    }
    return true;
  },
  "Must be a valid ISO date string (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ssZ)"
);

const SearchPerformanceRowSchema = z
  .object({
    query: z.string().min(1),
    pageUrl: z.string().url(),
    impressions: z.number().int().min(0),
    clicks: z.number().int().min(0),
    ctr: z.number().min(0).max(1),
    avgPosition: z.number().positive(),
    dateStart: isoDateString,
    dateEnd: isoDateString,
  })
  .strict()
  .refine(
    (row) => row.clicks <= row.impressions,
    "clicks cannot exceed impressions"
  );

export const IngestSearchPerformanceSchema = z
  .object({
    rows: z.array(SearchPerformanceRowSchema).min(1),
  })
  .strict();

export type SearchPerformanceRow = z.infer<typeof SearchPerformanceRowSchema>;
