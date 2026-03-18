# Phase 4 Ingestion Pipeline Validation — Audit Report

Audited: 2026-03-18
Repo: C:\dev\veda-ops-dev\veda

---

## 1. Phase 4 Roadmap Assumptions (extracted from docs/ROADMAP.md)

### Route shape assumed
- `POST /api/seo/ingest` — DataForSEO SERP ingestion

### Fixture scripts assumed
- `scripts/fixtures/replay-fixture.ts` — single fixture replay
- `scripts/fixtures/replay-all.ts` — batch fixture replay
- `scripts/fixtures/seed-serp-fixture.ts` — fixture seeding
- `scripts/fixtures/export-serp-fixture.ts` — fixture export

### Hammer modules assumed
- `hammer-dataforseo-ingest.ps1` — ingestion contract
- `hammer-realdata-fixtures.ps1` — fixture replay
- `hammer-w5-persistence.ps1` — persistence correctness

### Expected validation flow
1. Run hammer-dataforseo-ingest and confirm ingestion contract
2. Run hammer-realdata-fixtures and confirm fixture replay
3. Verify fixture replay produces SERPSnapshot records consumable by SIL
4. Run hammer-w5-persistence (persistence correctness)
5. If fixture scripts reference legacy paths, update to clean repo paths

### Expected exit criteria
- Ingestion route accepts valid DataForSEO payloads and persists SERPSnapshots
- Ingestion route rejects invalid payloads with correct error shape
- Fixture replay produces queryable snapshot history
- SIL pipeline can compute against replay-seeded data
- Full coordinator: 0 FAIL

---

## 2. Observed Runtime / Implementation Reality

### Actual ingest-related routes present

| Roadmap says | Actual path | Next.js API route |
|---|---|---|
| `POST /api/seo/ingest` | `src/app/api/seo/ingest/run/route.ts` | `POST /api/seo/ingest/run` |
| (not in Phase 4) | `src/app/api/seo/search-performance/ingest/route.ts` | `POST /api/seo/search-performance/ingest` |
| (not in Phase 4) | `src/app/api/test/persist-serp-snapshot/route.ts` | `POST /api/test/persist-serp-snapshot` |

**There is no `route.ts` at `src/app/api/seo/ingest/route.ts`.** The directory exists but only contains the `run/` subdirectory. The actual runtime API path is `/api/seo/ingest/run`, not `/api/seo/ingest`.

### Actual ingest/run route characteristics
- POST handler with Zod .strict() validation
- Body: { keywordTargetIds: UUID[], locale, device, limit?, confirm: boolean }
- Preview mode (confirm=false): returns keyword list + cost estimate, no writes
- Ingest mode (confirm=true): calls DataForSEO API, writes SERPSnapshot + EventLog in $transaction
- Idempotency via P2002 duplicate skip
- Deterministic ordering: query ASC, id ASC
- Project isolation via resolveProjectIdStrict()
- 503 when DATAFORSEO_LOGIN / DATAFORSEO_PASSWORD not set

### Actual fixture scripts present

| Script | Exists | Notes |
|---|---|---|
| `scripts/fixtures/replay-fixture.ts` | YES | Pure library test — calls computeVolatility() against fixture JSON, no DB/API |
| `scripts/fixtures/replay-all.ts` | YES | Discovers all *.json + *.expected.json pairs in serp/, replays each |
| `scripts/fixtures/seed-serp-fixture.ts` | YES | Seeds fixture JSON into DB via Prisma (project + keywordTarget + snapshots) |
| `scripts/fixtures/export-serp-fixture.ts` | YES | Exports SERPSnapshots from DB to fixture JSON |
| `scripts/fixtures/capture.ps1` | YES | Capture orchestrator (not in roadmap but present) |
| `scripts/fixtures/compute-fixture-expectations.ts` | YES | Computes expected.json from fixture |

### Actual fixture data present

`scripts/fixtures/serp/`:
- volatility-case-1.json + .expected.json
- volatility-case-2.json + .expected.json
- volatility-case-3.json + .expected.json
- volatility-case-4.json + .expected.json
- basic-volatility-fixture.json (no .expected.json)

### Actual hammer modules present

| Module | Exists | Target route |
|---|---|---|
| `hammer-dataforseo-ingest.ps1` | YES | `/api/seo/ingest/run` (CORRECT) |
| `hammer-realdata-fixtures.ps1` | YES | Uses seed-serp-fixture.ts + replay-fixture.ts + API endpoints |
| `hammer-w5-persistence.ps1` | YES | `/api/test/persist-serp-snapshot` (test-only route, 404 in production) |

All three modules are sourced by `scripts/api-hammer.ps1` coordinator.

### Actual runtime port / startup behavior
- Default Next.js port 3000 (no custom port in next.config.ts or package.json scripts)
- `api-hammer.ps1` defaults to `http://localhost:3000`
- Dev command: `next dev --turbopack`

### Environment state
- DATABASE_URL: SET
- DIRECT_DATABASE_URL: SET
- DATAFORSEO_LOGIN: NOT SET
- DATAFORSEO_PASSWORD: NOT SET

### Hammer module behavior with missing credentials
- `hammer-dataforseo-ingest.ps1` handles 503 / creds-missing gracefully as SKIP (not FAIL)
- Tests INGEST-A/B (preview mode) work without credentials
- Tests INGEST-C/D (confirm=true) gracefully SKIP when creds missing
- Tests INGEST-E/F/G/H/V (validation, cross-project, determinism, limit) work without credentials

### Library support
- `src/lib/seo/persist-serp-snapshot.ts` — extracted persistence function, used by both test route and potentially reusable
- No ingest-specific lib under `src/lib/seo/` (ingest logic is inline in the route handler)

---

## 3. Mismatch Map

### M1: Route path — roadmap says `POST /api/seo/ingest`, actual is `POST /api/seo/ingest/run`

**Classification: Roadmap drift (text-level only)**

The roadmap Phase 4 Surfaces/Lanes section says:
> `POST /api/seo/ingest` — DataForSEO SERP ingestion

The actual runtime API path is `POST /api/seo/ingest/run`.

The roadmap's "Already implemented" section says:
> `src/app/api/seo/ingest/` — DataForSEO ingestion

This is technically accurate (the directory exists) but obscures the actual route nesting.

**Impact:** Low. The hammer module (`hammer-dataforseo-ingest.ps1`) already correctly targets `/api/seo/ingest/run`. The mismatch is only in the roadmap text. No runtime or hammer execution is affected.

**Fix:** Update roadmap Phase 4 text from `POST /api/seo/ingest` to `POST /api/seo/ingest/run`.

### M2: DataForSEO credentials not configured

**Classification: Env/config issue (known, handled)**

DATAFORSEO_LOGIN and DATAFORSEO_PASSWORD are not set in .env.local. This means:
- confirm=true (live ingestion) path cannot execute end-to-end
- hammer-dataforseo-ingest.ps1 gracefully SKIPs the write-path tests (INGEST-C, INGEST-D)
- Preview-mode tests (INGEST-A, INGEST-B) and validation tests (INGEST-E, INGEST-F, INGEST-G, INGEST-H, INGEST-V) all work without credentials

**Impact:** Moderate. Phase 4 exit criteria include "Ingestion route accepts valid DataForSEO payloads and persists SERPSnapshots." This cannot be fully validated without credentials. However, the persistence path is independently testable via hammer-w5-persistence.ps1 (which uses the test route and does not need DataForSEO creds).

**Fix:** Operator decision — set DATAFORSEO_LOGIN and DATAFORSEO_PASSWORD when ready to validate the live ingestion path. The code is structurally ready; this is a credential provisioning decision, not a code gap.

### M3: No mismatches in fixture scripts

**Classification: No mismatch**

All four fixture scripts referenced in Phase 4 exist and have correct internal references. No legacy repo paths detected. seed-serp-fixture.ts loads .env.local correctly. replay-fixture.ts imports from relative paths within the clean repo.

### M4: No mismatches in hammer modules

**Classification: No mismatch**

All three hammer modules exist, are sourced by the coordinator, and target correct routes.

### M5: Roadmap "Already implemented" section ambiguity

**Classification: Roadmap drift (minor)**

The "Already implemented" list shows `src/app/api/seo/ingest/` which is technically the directory, but the route is at `src/app/api/seo/ingest/run/route.ts`. This is the same drift as M1 — the directory reference is not wrong but is imprecise relative to the actual API path.

---

## 4. Minimal Correction Path

### Step 1 — Fix roadmap route reference (M1, M5)

Update `docs/ROADMAP.md` Phase 4 Surfaces/Lanes from:
> `POST /api/seo/ingest` — DataForSEO SERP ingestion

To:
> `POST /api/seo/ingest/run` — DataForSEO SERP ingestion (operator-triggered)

Optionally also update "Already implemented" from:
> `src/app/api/seo/ingest/` — DataForSEO ingestion

To:
> `src/app/api/seo/ingest/run/` — DataForSEO ingestion (operator-triggered)

### Step 2 — Provision DataForSEO credentials (M2) — operator decision

When ready, set DATAFORSEO_LOGIN and DATAFORSEO_PASSWORD in .env.local to enable the live ingestion write path. This unblocks INGEST-C and INGEST-D from SKIP to PASS/FAIL.

### Step 3 — Execute Phase 4 as written

With M1 corrected in the roadmap text, the remaining Phase 4 implementation targets are executable:
1. Run hammer-dataforseo-ingest.ps1 — preview-mode and validation tests will PASS; write-path tests will SKIP without creds
2. Run hammer-realdata-fixtures.ps1 — fixture replay validates computeVolatility() and seeded data
3. Run hammer-w5-persistence.ps1 — persistence correctness (independent of DataForSEO creds)
4. Full coordinator run — confirm 0 FAIL

---

## 5. Direct Answers

### Is Phase 4 ready to execute as written?

**Almost.** The only blocker is a text-level route name mismatch in the roadmap (M1). The actual implementation, hammer modules, and fixture scripts are all present and internally consistent.

The hammer modules already target the correct route (`/api/seo/ingest/run`). The fixture scripts exist and reference clean repo paths. The persistence library is extracted and testable independently.

### What exact blocker must be resolved first?

1. **Mandatory (trivial):** Correct the roadmap Phase 4 route reference from `POST /api/seo/ingest` to `POST /api/seo/ingest/run`. This is a one-line text fix. Without it, the roadmap text is misleading to any operator reading it literally.

2. **Conditional (operator decision):** If full end-to-end live ingestion validation is required for Phase 4 exit, DATAFORSEO_LOGIN and DATAFORSEO_PASSWORD must be provisioned. If the exit criteria can be satisfied with the persistence-test path (hammer-w5-persistence) plus preview/validation hammer coverage, credentials are not a blocker.

### What is NOT blocking Phase 4?

- Route implementation: present and complete (`/api/seo/ingest/run`)
- Fixture scripts: all four present and functional
- Hammer modules: all three present and targeting correct routes
- Persistence library: extracted and independently testable
- Coordinator integration: all three modules sourced
- Port/runtime: standard Next.js 3000, hammer defaults match
