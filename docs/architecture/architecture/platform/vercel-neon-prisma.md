# Vercel, Neon, and Prisma

## Purpose

This document defines the boring, durable integration baseline for running the current VEDA repo on Vercel with Neon Postgres and Prisma.

It exists to keep deployment and database access predictable while the repo remains in post-Wave-2D successor-doc reconstruction.

This is a platform architecture document.
It does not redefine bounded-system ownership.
It does not grant infrastructure any authority over planning, observability, or execution semantics.

If this document conflicts with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- the current Prisma schema

those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document defines the platform baseline for:
- application runtime placement
- database connection strategy
- Prisma usage rules
- migration discipline
- environment variable expectations
- operational guardrails for serverless deployment

---

## What This Doc Is Not

This document is not:
- a product roadmap
- a vendor lock declaration
- a schema design document
- a VEDA feature spec
- a Project V planning document
- a V Forge execution workflow document

It explains how the current repo should be deployed safely, not what the system means.

---

## Ownership

This document is cross-system platform guidance.

It supports the current VEDA repo implementation, but it does not change system ownership.

Bounded ownership remains:
- Project V plans
- VEDA observes
- V Forge executes

Infrastructure exists to host those systems cleanly.
It does not decide their domain boundaries.

---

## Recommended Baseline

The current recommended baseline is:

- Vercel for application hosting
- Neon Postgres for the relational database
- Prisma for schema management and application data access
- Node runtime for all database-touching application paths by default

This baseline is recommended because it is simple, supported by the current repo shape, and compatible with transaction-safe relational behavior.

---

## Core Platform Rules

### 1. Database access runs in Node by default

Any route, server action, or server-side path that touches the database should run in the Node runtime by default.

This keeps database connectivity straightforward and avoids edge-runtime driver footguns.

### 2. Runtime traffic uses pooled connections

Application runtime traffic should use a pooled connection string.

This reduces connection exhaustion risk in serverless environments where multiple instances may be created concurrently.

### 3. Migrations use a direct connection

Schema management and migration workflows should use a direct database connection rather than the pooled runtime connection.

This avoids transaction-pooling problems during migration execution.

### 4. Prisma client must be reused

The application must not create a brand-new Prisma client for every request.

Prisma client should be instantiated once per server instance and reused.

In development, reuse should survive hot reload through a stable global pattern.

### 5. Platform choices must not bypass invariants

No hosting or database convenience path is allowed to bypass:
- project-scoped isolation
- transaction safety
- deterministic validation expectations
- atomic state-plus-event behavior where required

Platform convenience is not a permission slip for architectural slop.

---

## Runtime Strategy

### Default runtime model

Use the Node runtime for:
- Next.js route handlers that access Prisma
- server actions that read or mutate DB state
- server-rendered code paths that query relational state
- migration and administrative flows

This is the safe baseline.

### Edge runtime stance

Edge runtime is not the default for database-touching paths.

If an edge path is introduced later, it must be intentional and justified by a real requirement.
It must also use a driver and access pattern compatible with that environment.

Even then, the edge path must still preserve the same invariants around isolation, validation, and mutation safety.

For current reconstruction work, the right default is still:

```text
DB access -> Node runtime
```

---

## Environment Variables

The baseline expects two database connection variables:

- `DATABASE_URL`
- `DIRECT_DATABASE_URL`

### `DATABASE_URL`

This should be the pooled runtime connection string used by application code.

### `DIRECT_DATABASE_URL`

This should be the direct connection string used for:
- Prisma migrations
- schema administration
- direct maintenance workflows where pooling is inappropriate

The rule is simple:
- runtime app traffic uses pooled connection
- migrations and direct schema operations use direct connection

---

## Prisma Datasource Discipline

Prisma datasource configuration should reflect the split between runtime access and migration access.

The intended pattern is:
- datasource `url` -> `DATABASE_URL`
- datasource `directUrl` -> `DIRECT_DATABASE_URL`

That separation should remain explicit.
It prevents migration workflows from accidentally depending on the same connection behavior as ordinary runtime traffic.

---

## Prisma Client Reuse

Prisma client must be treated as a shared server-side resource, not a disposable per-request toy.

### Required rule

- instantiate once per server instance
- reuse across requests
- prevent hot-reload duplication in development

### Why this matters

Without reuse:
- connection counts inflate
- serverless behavior becomes noisier
- debugging gets worse
- Neon connection pressure rises for no good reason

That is needless chaos cosplay and should be avoided.

---

## Migration Discipline

Migrations must stay explicit, reviewable, and boring.

### Local workflow

The baseline workflow is:
1. update schema intentionally
2. run migration locally
3. verify behavior
4. commit migration files

### Production workflow

Production deployments should use non-interactive migration execution.

### Rules

- do not run interactive migration commands in production
- do not treat `db push` as a casual substitute for disciplined migrations in stable environments
- keep migration history understandable
- where rollback is non-trivial, document the rollback or recovery plan

This is especially important after Wave 2D, where schema clarity and bounded ownership are part of the cleanup contract.

---

## Serverless Connection Guardrails

Serverless deployment can multiply application instances quickly.

That creates boring but real database risks.

### Required guardrails

- use pooled runtime connections
- keep transactions short
- avoid holding connections longer than needed
- avoid unnecessary chatty DB patterns inside a single request
- keep DB work inside well-bounded server-side paths

### Why this matters

The goal is not magical scale theater.
The goal is to avoid self-inflicted connection exhaustion while preserving transaction-safe relational behavior.

---

## Observability and Operational Signals

This platform baseline only requires minimal operational visibility.

At minimum, the system should make it easy to notice:
- connection failures
- Prisma query or transaction errors
- migration failures
- obvious connection exhaustion symptoms

Useful practices include:
- logging request-correlated server errors
- distinguishing DB connectivity failures from validation failures
- keeping migration logs reviewable

This document does not require a giant observability vendor stack.
Boring logs that make failure modes legible are enough for the baseline.

---

## Security and Secret Handling

Secrets and provider credentials must remain outside source control.

Typical examples include:
- database connection strings
- auth provider credentials
- storage credentials
- deployment tokens

The platform baseline assumes environment-managed secrets.

Infrastructure setup must not create backdoor mutation paths that bypass authenticated application behavior.
That matters because this repo is LLM-assisted and operator-driven, which makes explicit guarded paths more important, not less.

---

## Relationship to VEDA Database Direction

This platform baseline should support the current VEDA database direction rather than distort it.

That means the deployment shape should remain compatible with:
- strong multi-project isolation
- explicit schema over JSON sludge
- DB-enforced integrity where structurally important
- append-friendly observation history
- transaction-safe evented mutations
- future compatibility with additional retrieval approaches without premature vector-everything complexity

In other words: keep the floor solid first.
Do not build a sci-fi mezzanine before the concrete cures.

---

## Out of Scope

This document does not define:
- vendor pricing
- autoscaling strategy details
- multi-region architecture
- edge-first database strategy
- GraphRAG architecture
- vector indexing policy
- execution workflow hosting for future V Forge surfaces
- Project V orchestration runtime design

Those may matter later.
They are not the baseline defined here.

---

## Invariants

The following platform invariants define compliance with this baseline:

- DB-touching runtime code uses Node by default
- runtime app traffic uses pooled DB connectivity
- migrations use direct DB connectivity
- Prisma client is reused rather than recreated per request
- platform setup does not weaken current system invariants

If an implementation breaks those rules, it is not compliant with this baseline.

---

## Maintenance Note

If future work tries to use infrastructure choices to justify:
- silent mutation shortcuts
- weaker transaction behavior
- blurred project boundaries
- edge-runtime database cleverness without need
- schema shortcuts that undermine current truth

that is an architectural warning sign.

The desired outcome is boring, legible deployment.
That is a feature, not a lack of imagination.
