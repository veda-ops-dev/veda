# Deployment and Infrastructure Baseline

## Purpose

This document defines the minimum durable infrastructure baseline for the current repo during successor-doc reconstruction.

It exists to keep platform decisions explicit, boring, and replaceable while preserving current architectural truth.

Infrastructure supports the system.
It does not redefine the system.

If this document conflicts with the truth-layer docs or enforced implementation reality, those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document defines the baseline expectations for:
- application hosting
- relational database hosting
- environment separation
- secrets handling
- deployment discipline
- optional versus required platform capabilities

It is a platform architecture document.
It is not a workflow specification for planning, observability, or execution.

---

## What This Doc Is Not

This document is not:
- a vendor shopping guide
- a product roadmap
- a schema reference
- a CMS deployment spec
- a replacement for security docs
- a substitute for bounded-system ownership

It answers the question:

```text
What infrastructure do we minimally need to run the repo safely and predictably?
```

---

## Ownership

This document is cross-system platform guidance.

It supports the implementation surface currently living in this repo, but it does not change ecosystem ownership.

The bounded-system rule remains:
- Project V plans
- VEDA observes
- V Forge executes

Infrastructure exists to host those systems and their APIs.
It must not be used as a backdoor architecture engine.

---

## Core Principle

Infrastructure is replaceable.
System meaning is not.

That means:
- providers may change
- deployment topology may evolve
- operational tooling may improve

But none of that is allowed to redefine:
- bounded ownership
- human-gated control
- project-scoped isolation
- transaction safety
- observability-only VEDA semantics

A hosting vendor is not a philosopher king.
It does not get to rewrite the architecture.

---

## Required Baseline Capabilities

The current repo requires a small, explicit infrastructure baseline.

### 1. Application hosting

The platform must support:
- server-rendered application behavior
- API routes / route handlers
- environment-based configuration
- deployable Node runtime behavior for DB-touching paths

The current recommended implementation path is compatible with Vercel, but the architectural requirement is capability-based rather than brand-worship-based.

### 2. Relational database

The platform must provide a relational database with:
- transactions
- foreign keys and constraints
- stable connection handling
- compatibility with Prisma

The database is not just storage.
It is part of structural enforcement for current invariants, especially around isolation and integrity.

### 3. Authentication capability

The platform must support authenticated operator access to internal surfaces and mutation paths.

This includes the ability to:
- protect internal APIs
- distinguish authenticated actors
- avoid anonymous mutation behavior

Detailed actor and auth rules belong in the security doc set, but the infrastructure baseline must support them.

### 4. Secret management

The platform must support secure environment-managed secrets for:
- database credentials
- auth provider credentials
- deployment tokens
- storage credentials where applicable

Secrets must not live in source control.
That is not bold minimalism. That is sabotage.

---

## Optional but Deferred Capabilities

The following may be useful later, but they are not required to establish the baseline.

### Background jobs / cron

Useful for:
- scheduled ingestion
- maintenance routines
- periodic housekeeping

Not required for the current default, because the current VEDA reconstruction stance prefers explicit and governed behavior over hidden automation assumptions.

### Email / notifications

Useful for:
- operational alerts
- workflow notifications
- future operator messaging

Not required for baseline operation.

### Analytics

Useful for:
- high-level operational visibility
- product usage understanding

Not required to establish canonical system behavior.

### Internal search or retrieval layers

Useful when content and doc volume justify them.
Not required for baseline platform viability.

### Heavy observability stacks

Nice to have later.
Not required for a sane baseline.
Readable logs and deploy visibility are enough to start.

---

## Environment Separation

The baseline assumes at least:
- `development`
- `production`

A `staging` environment may be added when useful, but it is not required to define the baseline.

### Rules

Environment separation should ensure:
- production credentials are distinct from local development credentials
- development experimentation does not silently mutate production systems
- migration workflows are deliberate per environment
- secrets are scoped appropriately to the environment

Where staging exists, it should behave as a verification surface, not a mythology generator.

---

## Deployment Discipline

Deployments should remain explicit and reproducible.

### Baseline expectations

- source-controlled application code
- source-controlled migration files
- non-interactive production deployment flow where possible
- deploy behavior that does not silently rewrite canonical data rules

### Required attitude

A deployment is infrastructure application, not an excuse to improvise data semantics.

That means deployment hooks, build steps, and internal automation must still respect:
- project scoping
- transaction safety
- auth rules
- bounded ownership

Internal code does not get to commit crimes just because it is wearing a deployment badge.

---

## Storage and Asset Handling

Object or asset storage may be needed for:
- screenshots
- generated media
- uploaded reference artifacts
- future published assets

This capability is optional for the narrowest current baseline unless a specific flow depends on it.

Where storage is introduced, it must follow the same boring rules:
- explicit ownership
- explicit access control
- no secret leakage
- no confusion between observatory intake artifacts and owned production assets

That last distinction matters because VEDA capture artifacts and V Forge production artifacts should not blur into one sloppy bucket.

---

## DB-Centric Structural Safety

The database remains a core structural component, not a passive persistence jar.

The infrastructure baseline must support VEDA’s current database direction, including:
- multi-project isolation
- DB-enforced integrity where practical
- transactional multi-write mutation safety
- append-friendly historical observations
- explicit schema design over JSON sludge

This means infrastructure choices that weaken relational integrity or safe migration behavior are a bad fit for the current phase.

---

## Logging and Operational Legibility

The baseline should make failures visible enough to debug without summoning oracle smoke.

Minimum useful visibility includes:
- deploy success or failure
- migration success or failure
- application error visibility
- database connectivity failure visibility

This document does not mandate an elaborate telemetry stack.
It mandates that the system not fail like a mime in a soundproof bunker.

---

## Security Alignment

The infrastructure baseline must support human-gated control.

That means the platform should make it possible to enforce:
- authenticated mutation paths
- actor attribution
- secret isolation
- reviewable operational changes

LLM-assisted workflows do not weaken this rule.
They make it more important.

The operating posture remains:

```text
Propose -> Review -> Apply
```

Infrastructure should support that posture, not sneak around it.

---

## Out of Scope

This document does not define:
- specific auth product choice
- CDN strategy details
- cost optimization strategy
- edge-first deployment policy
- multi-region failover design
- vector database adoption
- GraphRAG stack design
- future V Forge production-hosting details
- future Project V orchestration-hosting details

Those may matter later.
They are not required to define the current baseline.

---

## Invariants

A deployment setup is compliant with this baseline only if:
- infrastructure remains replaceable without redefining system semantics
- relational DB behavior remains available for current invariants
- authenticated operator access is supportable
- secrets remain outside source control
- deployment paths do not silently bypass safety or ownership rules

If one of those fails, the platform baseline has been violated.

---

## Maintenance Note

If future work tries to turn infrastructure planning into:
- architecture inflation
- provider-driven system semantics
- hidden automation authority
- blurred ownership between observability, planning, and execution

that is an architectural warning sign.

The desired result is a deployment baseline that is explicit, durable, and boring enough to trust.
That is exactly what this repo needs right now.
