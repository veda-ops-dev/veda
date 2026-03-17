/**
 * seed-serp-fixture.ts — Seeds a fixture JSON file into the DB for hammer tests
 *
 * Usage:
 *   npx tsx scripts/fixtures/seed-serp-fixture.ts \
 *     --file scripts/fixtures/serp/<fixture>.json \
 *     [--projectName "Fixture Project"]
 *
 * Supports TWO fixture shapes:
 *   A) Multi-keyword (legacy):
 *      { name, description?, keywordTargets: [{ query, locale, device, snapshots: [...] }] }
 *   B) Single-keyword (capture export):
 *      { query, locale, device, snapshots: [...] }
 *      In this case, fixture.name is derived from the filename.
 */

import { PrismaClient, Prisma } from "@prisma/client";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const prisma = new PrismaClient();

function normalizeQuery(query: string): string {
  return query.trim().replace(/\s+/g, " ").toLowerCase();
}

function deterministicUuid(label: string): string {
  const h = crypto.createHash("sha256").update(label).digest();
  const bytes = Buffer.from(h.slice(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
}

interface FixtureSnapshot {
  capturedAt: string;
  rawPayload: unknown;
  aiOverviewStatus: string;
  aiOverviewText: string | null;
}

interface FixtureKeywordTarget {
  query: string;
  locale: string;
  device: string;
  snapshots: FixtureSnapshot[];
}

interface FixtureFileMulti {
  name: string;
  description?: string;
  keywordTargets: FixtureKeywordTarget[];
}

interface FixtureFileSingle {
  query: string;
  locale: string;
  device: string;
  snapshots: FixtureSnapshot[];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isMultiFixture(x: unknown): x is FixtureFileMulti {
  return (
    isRecord(x) &&
    typeof x.name === "string" &&
    Array.isArray(x.keywordTargets)
  );
}

function isSingleFixture(x: unknown): x is FixtureFileSingle {
  return (
    isRecord(x) &&
    typeof x.query === "string" &&
    typeof x.locale === "string" &&
    typeof x.device === "string" &&
    Array.isArray(x.snapshots)
  );
}

async function main() {
  const fileIndex = process.argv.indexOf("--file");
  if (fileIndex === -1) throw new Error("--file is required");
  const filePath = process.argv[fileIndex + 1];

  const raw = fs.readFileSync(filePath, "utf-8");
  const parsed: unknown = JSON.parse(raw);

  let fixture: FixtureFileMulti;

  if (isMultiFixture(parsed)) {
    fixture = parsed;
  } else if (isSingleFixture(parsed)) {
    const derivedName = path.basename(filePath, path.extname(filePath));
    fixture = {
      name: derivedName,
      description: `Derived from capture export: ${derivedName}`,
      keywordTargets: [
        {
          query: parsed.query,
          locale: parsed.locale,
          device: parsed.device,
          snapshots: parsed.snapshots,
        },
      ],
    };
  } else {
    throw new Error("Unsupported fixture format");
  }

  const projectSlug = `fixture-${fixture.name}`;
  const projectId = deterministicUuid(`fixture-project|${projectSlug}`);

  await prisma.project.upsert({
    where: { id: projectId },
    create: { id: projectId, name: `Fixture — ${fixture.name}`, slug: projectSlug },
    update: {},
  });

  console.log(`FIXTURE_PROJECT_ID: ${projectId}`);

  for (const kt of fixture.keywordTargets) {
    const normalizedQuery = normalizeQuery(kt.query);

    const ktId = deterministicUuid(`fixture-kt|${projectId}|${normalizedQuery}|${kt.locale}|${kt.device}`);

    const record = await prisma.keywordTarget.upsert({
      where: {
        projectId_query_locale_device: {
          projectId,
          query: normalizedQuery,
          locale: kt.locale,
          device: kt.device,
        },
      },
      create: {
        id: ktId,
        projectId,
        query: normalizedQuery,
        locale: kt.locale,
        device: kt.device,
        isPrimary: false,
      },
      update: {},
    });

    for (const snap of kt.snapshots) {
      try {
        await prisma.sERPSnapshot.create({
          data: {
            projectId,
            query: normalizedQuery,
            locale: kt.locale,
            device: kt.device,
            capturedAt: new Date(snap.capturedAt),
            validAt: new Date(snap.capturedAt),
            rawPayload: snap.rawPayload as Prisma.InputJsonValue,
            payloadSchemaVersion: "fixture.v1",
            aiOverviewStatus: snap.aiOverviewStatus,
            aiOverviewText: snap.aiOverviewText ?? null,
            source: "fixture",
            batchRef: fixture.name,
          },
        });
      } catch (e) {
        if (!(e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002")) {
          throw e;
        }
      }
    }

    console.log(`FIXTURE_KT_ID: ${record.id} query="${normalizedQuery}" locale="${kt.locale}" device="${kt.device}"`);
  }

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
