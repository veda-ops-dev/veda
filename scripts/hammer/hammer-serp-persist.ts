/**
 * hammer-serp-persist.ts — Deterministic persistence tests for SERP snapshot writes
 *
 * Tests the extracted persistSerpSnapshot() function directly against the real DB.
 * No provider calls. No HTTP layer. Pure persistence + EventLog invariant verification.
 *
 * Usage:
 *   npx tsx scripts/hammer/hammer-serp-persist.ts --projectId <uuid>
 *
 * Flags:
 *   --projectId <uuid>    Required. Project to write test snapshots into.
 *   --cleanup             Delete test snapshots after run (default: true).
 *   --no-cleanup          Keep test snapshots for manual inspection.
 *
 * Exit codes:
 *   0 = all pass
 *   1 = any fail
 *
 * Invariants verified:
 *   - Transaction atomicity: SERPSnapshot + EventLog co-created
 *   - EventLog correctness: eventType, entityType, entityId, projectId, details
 *   - P2002 idempotency: duplicate write returns existing row, no duplicate EventLog
 *   - Field integrity: all input fields round-trip correctly
 *   - Project isolation: persistence function respects projectId boundary
 */

import { PrismaClient, Prisma } from "@prisma/client";
import { persistSerpSnapshot } from "@/lib/seo/persist-serp-snapshot";

const prisma = new PrismaClient();

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
function getArg(name: string): string | undefined {
  const idx = args.indexOf(`--${name}`);
  return idx >= 0 && idx + 1 < args.length ? args[idx + 1] : undefined;
}
const projectId = getArg("projectId");
const cleanup = !args.includes("--no-cleanup");

if (!projectId) {
  console.error("Usage: npx tsx scripts/hammer/hammer-serp-persist.ts --projectId <uuid>");
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------
let passCount = 0;
let failCount = 0;
const createdSnapshotIds: string[] = [];

function pass(name: string, detail?: string) {
  const suffix = detail ? ` (${detail})` : "";
  console.log(`  PASS  ${name}${suffix}`);
  passCount++;
}

function fail(name: string, detail: string) {
  console.log(`  FAIL  ${name} — ${detail}`);
  failCount++;
}

// ---------------------------------------------------------------------------
// Fixture data — minimal valid persistence input
// ---------------------------------------------------------------------------
const runId = Date.now().toString(36);

function makeInput(overrides: Partial<Parameters<typeof persistSerpSnapshot>[0]> = {}) {
  const capturedAt = new Date();
  return {
    projectId: projectId!,
    normalizedQuery: `hammer persist ${runId}`,
    locale: "en-US",
    device: "desktop",
    capturedAt,
    validAt: capturedAt,
    rawPayload: { results: [{ url: "https://example.com", rank: 1 }] } as Prisma.InputJsonValue,
    aiOverviewStatus: "absent",
    aiOverviewText: null,
    organicResultCount: 1,
    aiOverviewPresent: false,
    features: [] as string[],
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
async function runTests() {
  console.log(`\n=== SERP PERSIST DETERMINISTIC TESTS (runId=${runId}) ===\n`);

  // Verify project exists
  const project = await prisma.project.findUnique({ where: { id: projectId! } });
  if (!project) {
    console.error(`Project ${projectId} not found. Provide a valid --projectId.`);
    process.exit(1);
  }

  // ── PERSIST-A: basic write creates snapshot + EventLog ──────────────────
  {
    const testName = "PERSIST-A: basic write creates snapshot + EventLog";
    try {
      const input = makeInput();
      const result = await persistSerpSnapshot(input);
      createdSnapshotIds.push(result.snapshot.id);

      if (!result.created) {
        fail(testName, "expected created=true, got false");
      } else if (result.snapshot.query !== input.normalizedQuery) {
        fail(testName, `query mismatch: ${result.snapshot.query} !== ${input.normalizedQuery}`);
      } else if (result.snapshot.projectId !== projectId) {
        fail(testName, `projectId mismatch`);
      } else {
        // Verify EventLog was written
        const event = await prisma.eventLog.findFirst({
          where: {
            entityId: result.snapshot.id,
            entityType: "serpSnapshot",
            eventType: "SERP_SNAPSHOT_RECORDED",
            projectId: projectId!,
          },
        });
        if (!event) {
          fail(testName, "EventLog entry not found for created snapshot");
        } else {
          pass(testName, `id=${result.snapshot.id}`);
        }
      }
    } catch (err) {
      fail(testName, `exception: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  // ── PERSIST-B: EventLog details contain correct metadata ───────────────
  {
    const testName = "PERSIST-B: EventLog details contain correct metadata";
    try {
      const input = makeInput({
        normalizedQuery: `hammer persist details ${runId}`,
        organicResultCount: 5,
        aiOverviewPresent: true,
        features: ["featured_snippet", "ai_overview"],
      });
      const result = await persistSerpSnapshot(input);
      createdSnapshotIds.push(result.snapshot.id);

      const event = await prisma.eventLog.findFirst({
        where: { entityId: result.snapshot.id, eventType: "SERP_SNAPSHOT_RECORDED" },
      });

      if (!event || !event.details) {
        fail(testName, "EventLog or details missing");
      } else {
        const d = event.details as Record<string, unknown>;
        const checks = [
          d.query === input.normalizedQuery,
          d.locale === "en-US",
          d.device === "desktop",
          d.source === "dataforseo",
          d.organicResultCount === 5,
          d.aiOverviewPresent === true,
          Array.isArray(d.features) && (d.features as string[]).includes("ai_overview"),
        ];
        if (checks.every(Boolean)) {
          pass(testName);
        } else {
          fail(testName, `details mismatch: ${JSON.stringify(d)}`);
        }
      }
    } catch (err) {
      fail(testName, `exception: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  // ── PERSIST-C: P2002 idempotency — duplicate write returns existing ────
  {
    const testName = "PERSIST-C: P2002 idempotency returns existing, no duplicate EventLog";
    try {
      const capturedAt = new Date();
      const input = makeInput({
        normalizedQuery: `hammer persist idem ${runId}`,
        capturedAt,
      });

      // First write
      const r1 = await persistSerpSnapshot(input);
      createdSnapshotIds.push(r1.snapshot.id);

      if (!r1.created) {
        fail(testName, "first write should have created=true");
      } else {
        // Second write with identical key
        const r2 = await persistSerpSnapshot(input);

        if (r2.created) {
          fail(testName, "second write should have created=false (P2002 replay)");
          createdSnapshotIds.push(r2.snapshot.id);
        } else if (r2.snapshot.id !== r1.snapshot.id) {
          fail(testName, `replay returned different id: ${r2.snapshot.id} vs ${r1.snapshot.id}`);
        } else {
          // Verify no duplicate EventLog
          const events = await prisma.eventLog.findMany({
            where: {
              entityId: r1.snapshot.id,
              eventType: "SERP_SNAPSHOT_RECORDED",
            },
          });
          if (events.length !== 1) {
            fail(testName, `expected 1 EventLog, found ${events.length}`);
          } else {
            pass(testName, `id=${r1.snapshot.id}`);
          }
        }
      }
    } catch (err) {
      fail(testName, `exception: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  // ── PERSIST-D: field round-trip integrity ──────────────────────────────
  {
    const testName = "PERSIST-D: all fields round-trip correctly";
    try {
      const capturedAt = new Date("2026-03-01T12:00:00.000Z");
      const validAt = new Date("2026-03-01T11:59:30.000Z");
      const input = makeInput({
        normalizedQuery: `hammer persist fields ${runId}`,
        capturedAt,
        validAt,
        aiOverviewStatus: "present",
        aiOverviewText: "Test AI overview text",
      });
      const result = await persistSerpSnapshot(input);
      createdSnapshotIds.push(result.snapshot.id);

      const s = result.snapshot;
      const checks = [
        ["query", s.query === input.normalizedQuery],
        ["locale", s.locale === "en-US"],
        ["device", s.device === "desktop"],
        ["capturedAt", s.capturedAt.toISOString() === capturedAt.toISOString()],
        ["validAt", s.validAt?.toISOString() === validAt.toISOString()],
        ["aiOverviewStatus", s.aiOverviewStatus === "present"],
        ["source", s.source === "dataforseo"],
        ["batchRef", s.batchRef === null],
      ] as const;

      const failures = checks.filter(([, ok]) => !ok).map(([name]) => name);
      if (failures.length === 0) {
        pass(testName);
      } else {
        fail(testName, `mismatched fields: ${failures.join(", ")}`);
      }
    } catch (err) {
      fail(testName, `exception: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  // ── PERSIST-E: different capturedAt creates distinct snapshots ─────────
  {
    const testName = "PERSIST-E: different capturedAt creates distinct snapshots";
    try {
      const query = `hammer persist distinct ${runId}`;
      const t1 = new Date("2026-04-01T00:00:00.000Z");
      const t2 = new Date("2026-04-01T00:00:01.000Z");

      const r1 = await persistSerpSnapshot(makeInput({ normalizedQuery: query, capturedAt: t1, validAt: t1 }));
      const r2 = await persistSerpSnapshot(makeInput({ normalizedQuery: query, capturedAt: t2, validAt: t2 }));
      createdSnapshotIds.push(r1.snapshot.id, r2.snapshot.id);

      if (!r1.created || !r2.created) {
        fail(testName, `expected both created=true, got ${r1.created}/${r2.created}`);
      } else if (r1.snapshot.id === r2.snapshot.id) {
        fail(testName, "two timestamps produced same snapshot id");
      } else {
        pass(testName);
      }
    } catch (err) {
      fail(testName, `exception: ${err instanceof Error ? err.message : String(err)}`);
    }
  }
}

// ---------------------------------------------------------------------------
// Cleanup + summary
// ---------------------------------------------------------------------------
async function cleanupAndExit() {
  if (cleanup && createdSnapshotIds.length > 0) {
    // Delete EventLog entries first (no FK, but clean up)
    await prisma.eventLog.deleteMany({
      where: { entityId: { in: createdSnapshotIds }, entityType: "serpSnapshot" },
    });
    await prisma.sERPSnapshot.deleteMany({
      where: { id: { in: createdSnapshotIds } },
    });
    console.log(`\nCleaned up ${createdSnapshotIds.length} test snapshots.`);
  }

  console.log(`\n─── SUMMARY: ${passCount} pass, ${failCount} fail ───`);
  await prisma.$disconnect();
  process.exit(failCount > 0 ? 1 : 0);
}

runTests()
  .then(cleanupAndExit)
  .catch(async (err) => {
    console.error("Fatal error:", err);
    await cleanupAndExit();
  });
