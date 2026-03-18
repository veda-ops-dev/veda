# VEDA VS Code Operator Surface

Phase 1 successor surface for the V Ecosystem.

## What This Is

A thin, read-only VS Code extension that connects to VEDA observability APIs.
It is a delivery surface — it does not own data, compute analytics, or mutate system state.

## Surfaces

- **Select Environment** — switch between API environments (local, staging, etc.)
- **Select Project** — pick the active project from the API
- **SERP Weather** — project-level SERP disturbance/weather summary (SIL-16–24 composite)
- **Keyword Volatility** — focused diagnostic for a specific keyword target (SIL-3)

## Invariants

- No direct DB access (no Prisma, no connection strings)
- No local business logic (all computation happens server-side)
- No hidden mutation (all commands are reads)
- Explicit environment and project context (always visible in status bar)
- Thin HTTP client only — calls governed API routes

## Architecture

```
extension.ts          — activation + command registration
commands.ts           — command implementations (4 commands)
api-client.ts         — thin HTTP transport (fetch-based, project headers)
state.ts              — session state (environment + project)
status-bar.ts         — context indicators
```

## Development

```bash
cd extensions/veda-vscode
npm install
npm run compile
```

Then press F5 in VS Code to launch the Extension Development Host.

## Source of Truth

- `docs/systems/operator-surfaces/vscode/phase-1-spec.md`
- `docs/ROADMAP.md` Phase 6
- `docs/architecture/V_ECOSYSTEM.md`
