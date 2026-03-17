import { z } from "zod";

export const CaptureSourceItemSchema = z
  .object({
    sourceType: z.enum(["rss", "webpage", "comment", "reply", "video", "other"]),
    url: z.string().url(),
    operatorIntent: z.string().min(1),
    platform: z
      .enum([
        "website",
        "x",
        "youtube",
        "github",
        "reddit",
        "hackernews",
        "substack",
        "linkedin",
        "discord",
        "other",
      ])
      .optional(),
    notes: z.string().optional(),
  })
  .strict();
