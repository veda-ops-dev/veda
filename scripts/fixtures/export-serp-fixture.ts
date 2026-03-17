/**
 * export-serp-fixture.ts — Pull SERPSnapshots from DB into a deterministic fixture JSON.
 *
 * Usage:
 *   npx tsx scripts/fixtures/export-serp-fixture.ts \
 *     --keywordTargetId <uuid> \
 *     --name <fixture-name> \
 *     [--windowDays <n>]   (optional; default: no window — all snapshots)
 *
 * Output: scripts/fixtures/serp/<name>.json
 *
 * Fixture shape:
 *   {
 *     "query": "...",
 *     "locale": "...",
 *     "device": "...",
 *     "snapshots": [
 *       {
 *         "capturedAt": "2026-02-01T00:00:00.000Z",
 *         "rawPayload": { ... },
 *         "aiOverviewStatus": "absent",
 *         "aiOverviewText": null,
 *         "source": "operator"
 *       }
 *     ]
 *   }
 *
 * Rules:
 *   - Read-only. No DB writes.
 *   - Ordering: capturedAt ASC, id ASC (deterministic).
 *   - Max 25 snapshots.
 *   - rawPayload preserved exactly as stored.
 *   - Timestamps serialized as ISO strings.
 *   - Exits 0 on success, non-zero on error.
 */

import { PrismaClient } from "@prisma/client";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const prisma = new PrismaClient();

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const MAX_SNAPSHOTS = 25;

type Args = {
  keywordTargetId: string;
  name: string;
  windowDays: number | null;
};

function parseArgs(argv: string[]): Args {
  const args: Partial<Args> = { windowDays: null };

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    const next = (): string => {
      const v = argv[i + 1];
      if (v === undefined || v.startsWith("--")) {
        throw new Error(`Missing value for ${a}`);
      }
      i++;
      return v;
    };

    switch (a) {
      case "--keywordTargetId":
        args.keywordTargetId = next();
        break;
      case "--name":
        args.name = next();
        break;
      case "--windowDays": {
        const n = parseInt(next(), 10);
        if (!Number.isFinite(n) || n < 1 || n > 365) {
          throw new Error("--windowDays must be an integer 1–365");
        }
        args.windowDays = n;
        break;
      }
      default:
        throw new Error(`Unknown argument: ${a}`);
    }
  }

  if (!args.keywordTargetId) {
    throw new Error("--keywordTargetId is required");
  }
  if (!UUID_RE.test(args.keywordTargetId)) {
    throw new Error("--keywordTargetId must be a valid UUID");
  }
  if (!args.name) {
    throw new Error("--name is required");
  }
  if (!/^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$/.test(args.name)) {
    throw new Error(
      "--name must be lowercase alphanumeric with hyphens (e.g. volatility-case-1)"
    );
  }

  return args as Args;
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv);

  const target = await prisma.keywordTarget.findUnique({
    where: { id: args.keywordTargetId },
    select: { id: true, query: true, locale: true, device: true, projectId: true },
  });

  if (!target) {
    throw new Error(`KeywordTarget not found: ${args.keywordTargetId}`);
  }

  const windowFilter =
    args.windowDays !== null
      ? { capturedAt: { gte: new Date(Date.now() - args.windowDays * 24 * 60 * 60 * 1000) } }
      : {};

  const snapshots = await prisma.sERPSnapshot.findMany({
    where: {
      projectId: target.projectId,
      query: target.query,
      locale: target.locale,
      device: target.device,
      ...windowFilter,
    },
    orderBy: [{ capturedAt: "asc" }, { id: "asc" }],
    take: MAX_SNAPSHOTS,
    select: {
      capturedAt: true,
      rawPayload: true,
      aiOverviewStatus: true,
      aiOverviewText: true,
      source: true,
    },
  });

  if (snapshots.length === 0) {
    throw new Error(
      `No SERPSnapshots found for KeywordTarget ${args.keywordTargetId}` +
        (args.windowDays !== null ? ` within windowDays=${args.windowDays}` : "")
    );
  }

  const fixture = {
    query: target.query,
    locale: target.locale,
    device: target.device,
    snapshots: snapshots.map((s) => ({
      capturedAt: s.capturedAt.toISOString(),
      rawPayload: s.rawPayload,
      aiOverviewStatus: s.aiOverviewStatus,
      aiOverviewText: s.aiOverviewText ?? null,
      source: "operator",
    })),
  };

  const thisDir = path.dirname(fileURLToPath(import.meta.url));
  const outDir = path.join(thisDir, "serp");
  const outFile = path.join(outDir, `${args.name}.json`);

  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(outFile, JSON.stringify(fixture, null, 2) + "\n", "utf-8");

  console.log(`Fixture written: scripts/fixtures/serp/${args.name}.json`);
  console.log(`Snapshot count: ${snapshots.length}`);
  console.log(`Query:  ${target.query}`);
  console.log(`Locale: ${target.locale}  Device: ${target.device}`);
}

main()
  .catch((err) => {
    console.error(
      "export-serp-fixture failed:",
      err instanceof Error ? err.message : err
    );
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
