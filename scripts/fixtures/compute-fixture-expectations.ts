/**
 * compute-fixture-expectations.ts — Compute expected volatility values from a fixture file.
 *
 * Usage:
 *   npx tsx scripts/fixtures/compute-fixture-expectations.ts \
 *     --file scripts/fixtures/serp/<name>.json
 *
 * Input:  fixture JSON produced by export-serp-fixture.ts
 * Output:
 *   1. Console — human-readable assertion summary (unchanged format)
 *   2. scripts/fixtures/serp/<name>.expected.json — machine-readable expectations
 *      for consumption by hammer-realdata-fixtures.ps1
 *
 * Expected JSON schema:
 *   {
 *     "sampleSize": number,
 *     "snapshotCount": number,
 *     "volatilityScore": number,
 *     "rankVolatilityComponent": number,
 *     "aiOverviewComponent": number,
 *     "featureVolatilityComponent": number,
 *     "volatilityRegime": string,
 *     "aiOverviewChurn": number
 *   }
 *
 * Uses the canonical computeVolatility() and classifyRegime() from
 * src/lib/seo/volatility-service.ts — identical to the live volatility endpoint.
 * Values in expected.json therefore match what the API returns.
 *
 * No DB access. No side effects beyond writing the expected.json file.
 * Exits 0 on success, non-zero on error.
 */

import fs from "node:fs";
import path from "node:path";
import {
  computeVolatility,
  classifyRegime,
  type SnapshotForVolatility,
} from "../../src/lib/seo/volatility-service.js";

// ─────────────────────────────────────────────────────────────────────────────
// Fixture shape (flat — matches export-serp-fixture.ts output)
// ─────────────────────────────────────────────────────────────────────────────

interface FixtureSnapshot {
  capturedAt: string;
  rawPayload: unknown;
  aiOverviewStatus: string;
  aiOverviewText: string | null;
  source?: string;
}

interface FixtureFile {
  query: string;
  locale: string;
  device: string;
  snapshots: FixtureSnapshot[];
}

export interface FixtureExpectations {
  sampleSize: number;
  snapshotCount: number;
  volatilityScore: number;
  rankVolatilityComponent: number;
  aiOverviewComponent: number;
  featureVolatilityComponent: number;
  volatilityRegime: string;
  aiOverviewChurn: number;
}

// ─────────────────────────────────────────────────────────────────────────────
// CLI args
// ─────────────────────────────────────────────────────────────────────────────

type Args = { file: string };

function parseArgs(argv: string[]): Args {
  let file: string | undefined;

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--file") {
      const v = argv[i + 1];
      if (!v || v.startsWith("--")) throw new Error("--file requires a value");
      file = v;
      i++;
    } else {
      throw new Error(`Unknown argument: ${a}`);
    }
  }

  if (!file) throw new Error("--file is required");
  return { file };
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

function main(): void {
  const args = parseArgs(process.argv);

  const absFile = path.resolve(args.file);
  if (!fs.existsSync(absFile)) {
    throw new Error(`Fixture file not found: ${absFile}`);
  }

  let fixture: FixtureFile;
  try {
    fixture = JSON.parse(fs.readFileSync(absFile, "utf-8")) as FixtureFile;
  } catch (e) {
    throw new Error(
      `Failed to parse fixture JSON: ${e instanceof Error ? e.message : e}`
    );
  }

  if (!Array.isArray(fixture.snapshots) || fixture.snapshots.length === 0) {
    throw new Error("Fixture has no snapshots");
  }

  // Build SnapshotForVolatility array — stable synthetic id from index
  // (fixture JSON does not store DB ids)
  const snapshotsForVolatility: SnapshotForVolatility[] = fixture.snapshots.map(
    (s, idx) => ({
      id: `fixture-snap-${idx}`,
      capturedAt: new Date(s.capturedAt),
      aiOverviewStatus: s.aiOverviewStatus,
      rawPayload: s.rawPayload,
    })
  );

  // Enforce deterministic ordering (fixture should already be sorted)
  snapshotsForVolatility.sort((a, b) => {
    const t = a.capturedAt.getTime() - b.capturedAt.getTime();
    if (t !== 0) return t;
    return a.id.localeCompare(b.id);
  });

  const profile = computeVolatility(snapshotsForVolatility);
  const regime = classifyRegime(profile.volatilityScore);
  const snapshotCount = fixture.snapshots.length;

  // ── 1. Console output (unchanged format) ───────────────────────────────────
  console.log("Expected assertions:");
  console.log(
    `sampleSize=${profile.sampleSize}` +
      ` snapshotCount=${snapshotCount}` +
      ` volatilityScore=${profile.volatilityScore}` +
      ` rankComponent=${profile.rankVolatilityComponent}` +
      ` aiComponent=${profile.aiOverviewComponent}` +
      ` featureComponent=${profile.featureVolatilityComponent}` +
      ` regime=${regime}` +
      ` aiOverviewChurn=${profile.aiOverviewChurn}`
  );

  // ── 2. Write expected.json alongside the fixture ────────────────────────────
  const expectations: FixtureExpectations = {
    sampleSize: profile.sampleSize,
    snapshotCount,
    volatilityScore: profile.volatilityScore,
    rankVolatilityComponent: profile.rankVolatilityComponent,
    aiOverviewComponent: profile.aiOverviewComponent,
    featureVolatilityComponent: profile.featureVolatilityComponent,
    volatilityRegime: regime,
    aiOverviewChurn: profile.aiOverviewChurn,
  };

  // Derive expected.json path from fixture path: <name>.json → <name>.expected.json
  const expectedFile = absFile.replace(/\.json$/, ".expected.json");
  fs.writeFileSync(expectedFile, JSON.stringify(expectations, null, 2) + "\n", "utf-8");
  console.log(`Expectations written: ${expectedFile}`);
}

try {
  main();
} catch (err) {
  console.error(
    "compute-fixture-expectations failed:",
    err instanceof Error ? err.message : err
  );
  process.exit(1);
}
