import dotenv from "dotenv";
// Load .env then .env.local (Next.js convention) — "dotenv/config" only loads .env
// which does not exist in this repo; the canonical env file is .env.local.
dotenv.config({ path: ".env" });
dotenv.config({ path: ".env.local", override: true });

/**
 * seed-serp-fixture.ts — Seeds a fixture JSON file into the DB for hammer tests
 *
 * Usage:
 *   npx tsx scripts/fixtures/seed-serp-fixture.ts \
 *     --file scripts/fixtures/serp/<fixture>.json \
 *     [--projectName "Fixture Project"]
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

async function main() {
  const fileIndex = process.argv.indexOf("--file");
  if (fileIndex === -1) throw new Error("--file is required");
  const filePath = process.argv[fileIndex + 1];

  const raw = fs.readFileSync(filePath, "utf-8");
  const parsed: any = JSON.parse(raw);

  const projectSlug = `fixture-${parsed.name || "single"}`;
  const projectId = deterministicUuid(`fixture-project|${projectSlug}`);

  await prisma.project.upsert({
    where: { id: projectId },
    create: { id: projectId, name: `Fixture — ${projectSlug}`, slug: projectSlug },
    update: {},
  });

  console.log(`FIXTURE_PROJECT_ID: ${projectId}`);

  const targets = parsed.keywordTargets || [{
    query: parsed.query,
    locale: parsed.locale,
    device: parsed.device,
    snapshots: parsed.snapshots,
  }];

  for (const kt of targets) {
    const normalizedQuery = normalizeQuery(kt.query);

    const ktId = deterministicUuid(`fixture-kt|${projectId}|${normalizedQuery}|${kt.locale}|${kt.device}`);

    await prisma.keywordTarget.upsert({
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
            rawPayload: snap.rawPayload,
            payloadSchemaVersion: "fixture.v1",
            aiOverviewStatus: snap.aiOverviewStatus,
            aiOverviewText: snap.aiOverviewText ?? null,
            source: "fixture",
            batchRef: parsed.name || "fixture",
          },
        });
      } catch (e) {}
    }

    console.log(`FIXTURE_KT_ID: ${ktId} query="${normalizedQuery}" locale="${kt.locale}" device="${kt.device}"`);
  }

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
