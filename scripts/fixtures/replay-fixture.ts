/**
 * replay-fixture.ts — Validate computeVolatility() against a captured fixture.
 *
 * Usage:
 *   tsx scripts/fixtures/replay-fixture.ts --name volatility-case-1
 *   tsx scripts/fixtures/replay-fixture.ts --file scripts/fixtures/serp/volatility-case-1.json
 *
 * Output:  exactly one line — "PASS" or "FAIL" — then exits 0 or 1.
 * No other output is printed (hammer integration contract).
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  computeVolatility,
  classifyRegime,
  type SnapshotForVolatility,
} from "../../src/lib/seo/volatility-service.js";

// ─────────────────────────────────────────────────────────────────────────────
// Types
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

interface FixtureExpectations {
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
// CLI
// ─────────────────────────────────────────────────────────────────────────────

const SERP_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "serp"
);

function resolveFiles(argv: string[]): { fixtureFile: string; expectedFile: string } {
  let name: string | undefined;
  let file: string | undefined;

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--name") {
      const v = argv[i + 1];
      if (!v || v.startsWith("--")) fail("--name requires a value");
      name = v;
      i++;
    } else if (a === "--file") {
      const v = argv[i + 1];
      if (!v || v.startsWith("--")) fail("--file requires a value");
      file = v;
      i++;
    } else {
      fail(`Unknown argument: ${a}`);
    }
  }

  if (!name && !file) fail("--name or --file is required");

  let fixtureFile: string;
  let expectedFile: string;

  if (name) {
    fixtureFile  = path.join(SERP_DIR, `${name}.json`);
    expectedFile = path.join(SERP_DIR, `${name}.expected.json`);
  } else {
    const abs    = path.resolve(file!);
    fixtureFile  = abs;
    expectedFile = abs.replace(/\.json$/, ".expected.json");
  }

  return { fixtureFile, expectedFile };
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function fail(reason?: string): never {
  if (reason) process.stderr.write(reason + "\n");
  process.stdout.write("FAIL\n");
  process.exit(1);
}

function withinTolerance(got: number, want: number, tol: number): boolean {
  return Math.abs(got - want) <= tol;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

function main(): void {
  const { fixtureFile, expectedFile } = resolveFiles(process.argv);

  // ── Load fixture ──────────────────────────────────────────────────────────
  if (!fs.existsSync(fixtureFile)) {
    fail(`fixture file not found: ${fixtureFile}`);
  }
  if (!fs.existsSync(expectedFile)) {
    fail(`expected.json not found: ${expectedFile}`);
  }

  let fixture: FixtureFile;
  try {
    fixture = JSON.parse(fs.readFileSync(fixtureFile, "utf-8")) as FixtureFile;
  } catch (e) {
    fail(`failed to parse fixture JSON: ${e instanceof Error ? e.message : e}`);
  }

  let expected: FixtureExpectations;
  try {
    expected = JSON.parse(fs.readFileSync(expectedFile, "utf-8")) as FixtureExpectations;
  } catch (e) {
    fail(`failed to parse expected JSON: ${e instanceof Error ? e.message : e}`);
  }

  // ── Validate expected fields present ─────────────────────────────────────
  const requiredFields: (keyof FixtureExpectations)[] = [
    "sampleSize", "snapshotCount", "volatilityScore",
    "rankVolatilityComponent", "aiOverviewComponent",
    "featureVolatilityComponent", "volatilityRegime", "aiOverviewChurn",
  ];
  for (const f of requiredFields) {
    if (expected[f] === undefined || expected[f] === null) {
      fail(`expected.json missing field: ${f}`);
    }
  }

  if (!Array.isArray(fixture.snapshots) || fixture.snapshots.length === 0) {
    fail("fixture has no snapshots");
  }

  // ── Build SnapshotForVolatility[] ────────────────────────────────────────
  const snapshotsForVolatility: SnapshotForVolatility[] = fixture.snapshots.map(
    (s, idx) => ({
      id: `fixture-snap-${idx}`,
      capturedAt: new Date(s.capturedAt),
      aiOverviewStatus: s.aiOverviewStatus,
      rawPayload: s.rawPayload,
    })
  );

  // Deterministic order: capturedAt ASC, id ASC
  snapshotsForVolatility.sort((a, b) => {
    const t = a.capturedAt.getTime() - b.capturedAt.getTime();
    if (t !== 0) return t;
    return a.id.localeCompare(b.id);
  });

  // ── Compute ───────────────────────────────────────────────────────────────
  const profile      = computeVolatility(snapshotsForVolatility);
  const regime       = classifyRegime(profile.volatilityScore);
  const snapshotCount = fixture.snapshots.length;

  // ── Compare ───────────────────────────────────────────────────────────────
  const failures: string[] = [];

  // Exact: sampleSize
  if (profile.sampleSize !== expected.sampleSize) {
    failures.push(`sampleSize: got ${profile.sampleSize} want ${expected.sampleSize}`);
  }

  // Exact: snapshotCount
  if (snapshotCount !== expected.snapshotCount) {
    failures.push(`snapshotCount: got ${snapshotCount} want ${expected.snapshotCount}`);
  }

  // Exact: aiOverviewChurn
  if (profile.aiOverviewChurn !== expected.aiOverviewChurn) {
    failures.push(`aiOverviewChurn: got ${profile.aiOverviewChurn} want ${expected.aiOverviewChurn}`);
  }

  // Exact: volatilityRegime
  if (regime !== expected.volatilityRegime) {
    failures.push(`volatilityRegime: got ${regime} want ${expected.volatilityRegime}`);
  }

  // Tolerance ±0.05: volatilityScore
  if (!withinTolerance(profile.volatilityScore, expected.volatilityScore, 0.05)) {
    failures.push(
      `volatilityScore: got ${profile.volatilityScore} want ${expected.volatilityScore} ` +
      `diff ${Math.abs(profile.volatilityScore - expected.volatilityScore).toFixed(4)}`
    );
  }

  // Tolerance ±0.05: rankVolatilityComponent
  if (!withinTolerance(profile.rankVolatilityComponent, expected.rankVolatilityComponent, 0.05)) {
    failures.push(
      `rankVolatilityComponent: got ${profile.rankVolatilityComponent} want ${expected.rankVolatilityComponent} ` +
      `diff ${Math.abs(profile.rankVolatilityComponent - expected.rankVolatilityComponent).toFixed(4)}`
    );
  }

  // Tolerance ±0.05: aiOverviewComponent
  if (!withinTolerance(profile.aiOverviewComponent, expected.aiOverviewComponent, 0.05)) {
    failures.push(
      `aiOverviewComponent: got ${profile.aiOverviewComponent} want ${expected.aiOverviewComponent} ` +
      `diff ${Math.abs(profile.aiOverviewComponent - expected.aiOverviewComponent).toFixed(4)}`
    );
  }

  // featureVolatilityComponent: exact if expected=0, else ±0.05
  const featTol = expected.featureVolatilityComponent === 0 ? 0 : 0.05;
  if (!withinTolerance(profile.featureVolatilityComponent, expected.featureVolatilityComponent, featTol)) {
    failures.push(
      `featureVolatilityComponent: got ${profile.featureVolatilityComponent} want ${expected.featureVolatilityComponent} ` +
      `diff ${Math.abs(profile.featureVolatilityComponent - expected.featureVolatilityComponent).toFixed(4)}`
    );
  }

  // Component sum ≈ volatilityScore ±0.10
  const compSum = profile.rankVolatilityComponent + profile.aiOverviewComponent + profile.featureVolatilityComponent;
  if (!withinTolerance(compSum, profile.volatilityScore, 0.10)) {
    failures.push(
      `component sum: ${compSum.toFixed(4)} vs volatilityScore ${profile.volatilityScore} ` +
      `diff ${Math.abs(compSum - profile.volatilityScore).toFixed(4)} > 0.10`
    );
  }

  // ── Result ────────────────────────────────────────────────────────────────
  if (failures.length > 0) {
    for (const f of failures) process.stderr.write(f + "\n");
    process.stdout.write("FAIL\n");
    process.exit(1);
  }

  process.stdout.write("PASS\n");
  process.exit(0);
}

main();
