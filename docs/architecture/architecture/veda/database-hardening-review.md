# Database Hardening Review

## Purpose

This document records the current database hardening review for VEDA against the active architecture and invariants.

It exists to answer:

```text
Where does the current schema already align with VEDA truth, where are the structural risks, and what has already been hardened?
```

This is a review and planning document.
It is not the authoritative schema reference.
If it conflicts with `prisma/schema.prisma`, the schema is authoritative until a change is intentionally applied.

---

## Review Inputs

This review is grounded against:
- `prisma/schema.prisma`
- `prisma/migrations/20260314000000_veda_baseline/migration.sql`
- `prisma/migrations/20260316000100_cg_project_integrity_completion/migration.sql`
- `prisma/migrations/20260316000200_project_scoped_source_uniqueness/migration.sql`
- `prisma/migrations/20260316000300_semantic_enum_hardening/migration.sql`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/architecture/architecture/veda/observatory-models.md`
- `docs/architecture/architecture/veda/content-graph-model.md`
- `docs/architecture/architecture/platform/vercel-neon-prisma.md`
- `docs/ROADMAP.md`

---

## Review Summary

The schema is now in substantially better shape.

It currently has:
- clear project scoping across the main VEDA domains
- an observatory-only model family
- Prisma datasource split aligned to pooled runtime plus direct migration access
- DB-level project-integrity enforcement across the highest-risk content graph paths
- project-scoped uniqueness for source capture and source feeds
- explicit enums for thin project scoping state and AI overview status

The current risk profile is no longer “major structural mismatch.”
The remaining work is mainly:
- verification coverage
- active-doc anti-drift cleanup
- code-level alignment checks against the rebuilt architecture docs

That is a much healthier place to be.

---

## What Already Aligns Well

### 1. Datasource split is correct

`prisma/schema.prisma` uses:
- `DATABASE_URL`
- `DIRECT_DATABASE_URL`

That aligns with `docs/architecture/architecture/platform/vercel-neon-prisma.md` and remains the correct Neon plus Prisma baseline.

### 2. Core observatory domains are cleanly separated

The schema currently models:
- project scoping
- source and capture
- event logging
- search observation
- system config
- content graph

That matches `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md` and `docs/architecture/architecture/veda/observatory-models.md`.

### 3. Search observation ledger shape is sound

`KeywordTarget`, `SERPSnapshot`, and `SearchPerformance` are scoped and structured in a way that fits the current observation-ledger doctrine.

### 4. Content graph identity surfaces are mostly right

The graph uses stable project-scoped identities such as:
- `CgSurface.projectId + key`
- `CgSite.projectId + domain`
- `CgPage.projectId + url`
- `CgTopic.projectId + key`
- `CgEntity.projectId + key`

That matches the active architecture docs.

### 5. Thin project scoping state is now explicit

`Project.lifecycleState` is now an explicit enum:
- `ProjectLifecycleState`

That is better than a free-text field because it limits the shape while still keeping the concept intentionally thin.

### 6. AI overview status is now explicit

`SERPSnapshot.aiOverviewStatus` is now an explicit enum:
- `AiOverviewStatus`

That is better than application-validated text for a hot-path field with a stable vocabulary.

---

## Hardening Work Completed

### Completed: content graph project-integrity completion

DB-level project consistency is now enforced for:
- `CgPageTopic`
- `CgPageEntity`
- `CgSite` -> `CgSurface`
- `CgPage` -> `CgSite`
- `CgPage` -> optional `CgContentArchetype`
- `CgInternalLink` -> source and target `CgPage`
- `CgSchemaUsage` -> `CgPage`

This closes the highest-risk cross-project contamination paths in the graph.

### Completed: project-scoped source uniqueness

The schema now uses project-scoped uniqueness for:
- `SourceItem` via `@@unique([projectId, url])`
- `SourceFeed` via `@@unique([projectId, feedUrl])`

That aligns uniqueness with actual ownership scope and avoids cross-project coupling through shared URLs.

### Completed: semantic enum hardening

The schema now uses:
- `ProjectLifecycleState` for `Project.lifecycleState`
- `AiOverviewStatus` for `SERPSnapshot.aiOverviewStatus`

That reduces free-text drift on two fields that are important enough to deserve explicit vocabulary.

---

## Current Open Risks

The main open risks are now downstream rather than foundational.

### 1. Hammer coverage gap

The DB has stronger enforcement now, but the system still needs repeatable tests proving that these protections actually fail correctly under violation attempts.

Priority:
- high

### 2. Code-path alignment risk

The active docs and schema are cleaner than before, but implementation paths may still contain assumptions that were written before the current hardening pass.

Priority:
- high

### 3. Active-doc anti-drift language risk

Some newly created active docs still carry a little too much cleanup-era or historical scent.
That is not a schema problem, but it is a real LLM-ingestion problem.

Priority:
- high

---

## Recommended Verification Work

The next verification block should cover:
- attempted cross-project `CgSite` / `CgSurface` linkage
- attempted cross-project `CgPage` / `CgSite` linkage
- attempted cross-project `CgPage` / `CgContentArchetype` linkage
- attempted cross-project `CgInternalLink` creation
- attempted cross-project `CgSchemaUsage` creation
- attempted cross-project `CgPageTopic` creation
- attempted cross-project `CgPageEntity` creation
- duplicate `SourceItem.url` behavior across different projects
- duplicate `SourceFeed.feedUrl` behavior across different projects
- accepted values and rejected values for `ProjectLifecycleState`
- accepted values and rejected values for `AiOverviewStatus`

These should become part of the observatory-only hammer suite described in `docs/ROADMAP.md`.

---

## Recommended Next Actions

### 1. Build hammer coverage for the hardened DB rules
- Owner: `VEDA`
- Why: architectural claims are only trustworthy when violation probes actually fail.

### 2. Do an active-doc anti-drift scrub
- Owner: `cross-system`
- Why: the active docs should teach only current truth to fresh LLM readers.

### 3. Check code-path alignment against the rebuilt architecture spine
- Owner: `cross-system`
- Why: docs and schema are stronger now; implementation should not trail behind with stale assumptions.

---

## Claude Audit Recommendation

The right audit point is approaching, but not quite yet.

### Do Claude audit after:
- the active-doc anti-drift scrub is complete
- the most important hammer coverage exists for the new DB protections

### Why wait until then
Because right now Claude would still spend meaningful audit energy on:
- historical-scent language in active docs
- obvious missing verification gaps

That is useful, but not optimal.

The smarter audit checkpoint is:
- architecture docs rebuilt
- schema hardening applied
- active-doc language cleaned
- first serious hammer coverage in place

At that point Claude can audit for deeper drift instead of just swatting unfinished cleanup flies.

---

## Maintenance Note

This review should be updated when:
- `prisma/schema.prisma` changes materially
- new DB-level integrity constraints are added
- hammer coverage closes the current verification gaps
- the repo reaches the Claude-audit checkpoint

The goal is not to admire the database in a mirror.
The goal is to keep the schema structurally aligned with the active VEDA architecture and hard enough that future drift has nowhere comfortable to hide.
