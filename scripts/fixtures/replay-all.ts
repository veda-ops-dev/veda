/**
 * replay-all.ts — Run replay-fixture against every fixture in scripts/fixtures/serp/
 *
 * Discovers all *.json files that have a paired *.expected.json and replays each.
 * Aggregates results and prints exactly one line: "PASS" or "FAIL".
 * Failures are reported to stderr with the fixture name.
 *
 * Usage:
 *   tsx scripts/fixtures/replay-all.ts
 *
 * Exit codes:
 *   0 — all fixtures passed
 *   1 — one or more fixtures failed, or no fixtures found
 */

import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const HERE          = path.dirname(fileURLToPath(import.meta.url));
const SERP_DIR      = path.resolve(HERE, "serp");
const REPLAY_SCRIPT = path.resolve(HERE, "replay-fixture.ts");
const REPO_ROOT     = path.resolve(HERE, "..", "..");

// Windows gotcha: node cannot reliably exec a .cmd directly via execFileSync.
// Use cmd.exe /c for .cmd, then pwsh for .ps1, then npx tsx.
const TSX_CMD = path.join(REPO_ROOT, "node_modules", ".bin", "tsx.cmd");
const TSX_PS1 = path.join(REPO_ROOT, "node_modules", ".bin", "tsx.ps1");

type Runner = { command: string; prefixArgs: string[] };

function resolveTsxRunner(): Runner {
  if (fs.existsSync(TSX_CMD)) {
    return { command: "cmd.exe", prefixArgs: ["/c", TSX_CMD] };
  }
  if (fs.existsSync(TSX_PS1)) {
    return {
      command: "pwsh",
      prefixArgs: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", TSX_PS1],
    };
  }
  return { command: "npx", prefixArgs: ["tsx"] };
}

function discoverFixtures(): string[] {
  if (!fs.existsSync(SERP_DIR)) return [];

  return fs
    .readdirSync(SERP_DIR)
    .filter((f) => f.endsWith(".json") && !f.endsWith(".expected.json"))
    .filter((f) => fs.existsSync(path.join(SERP_DIR, f.replace(/\.json$/, ".expected.json"))))
    .map((f) => f.replace(/\.json$/, ""))
    .sort((a, b) => a.localeCompare(b));
}

function main(): void {
  const fixtures = discoverFixtures();

  if (fixtures.length === 0) {
    process.stderr.write("no fixtures with paired expected.json found in " + SERP_DIR + "\n");
    process.stdout.write("FAIL\n");
    process.exit(1);
  }

  const runner = resolveTsxRunner();
  const failures: string[] = [];

  for (const name of fixtures) {
    try {
      const args = [...runner.prefixArgs, REPLAY_SCRIPT, "--name", name];
      execFileSync(runner.command, args, {
        encoding: "utf-8",
        stdio: ["ignore", "pipe", "pipe"],
      });
    } catch (err: unknown) {
      const e = err as { stdout?: string; stderr?: string; status?: number };
      const detail = (e.stderr ?? "").trim();
      failures.push(name + (detail ? ` (${detail})` : ""));
    }
  }

  if (failures.length > 0) {
    for (const f of failures) process.stderr.write("FAIL: " + f + "\n");
    process.stdout.write("FAIL\n");
    process.exit(1);
  }

  process.stdout.write("PASS\n");
  process.exit(0);
}

main();
