# Source Provenance and Citation

## Purpose

This document defines how source provenance and citation should work across the V Ecosystem.

It exists to keep factual claims traceable, preserve observatory evidence, and prevent two opposite failure modes:
- citation theater
- evidence-free output

This is a shared architecture document.
It describes the cross-system contract between observatory provenance and output-facing citation behavior.

It should be read together with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/llm-assisted-operations.md`
- `docs/systems/veda/observatory/source-capture-and-inbox.md`
- `docs/architecture/api/api-contract-principles.md`

If this document conflicts with higher-authority truth docs or active bounded-system ownership, those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document defines:
- what provenance means in the ecosystem
- what citation is for
- which system owns which part of the problem
- when citations are required
- when citations are unnecessary noise
- how output surfaces should relate to VEDA source records

---

## What This Doc Is Not

This document is not:
- an academic citation manual
- a publishing workflow state machine
- a VEDA-only observatory spec
- a V Forge editorial playbook
- a claim that every sentence needs a footnote stapled to it like a panicked term paper

It answers a narrower question:

```text
How should the ecosystem preserve source provenance and apply citations in a way that stays truthful, clear, and bounded by system ownership?
```

---

## Ownership

This topic is cross-system, but ownership inside it is split.

### VEDA owns provenance

VEDA owns:
- source capture
- source records
- preserved intake context
- snapshot or reference retention where applicable
- observatory evidence that later workflows may use

That means VEDA is the provenance backbone.
It records what entered the system, where it came from, and why it mattered.

### V Forge owns output citation behavior

V Forge owns:
- how citations appear on produced surfaces
- how references are rendered in output
- output-facing source sections
- production-time citation hygiene for drafts and published artifacts

That means V Forge decides how source-backed claims appear in execution surfaces.
It does not own the canonical provenance layer.

### Project V may reference sources, but does not own the evidence store

Project V may use grounded sources in planning and prioritization.
But it does not become the canonical source registry.

---

## Core Principle

**Citations support claims. Provenance supports trust.**

These are related, but they are not the same thing.

- provenance answers: where did this come from?
- citation answers: what claim on this surface depends on that source?

If a source exists but no visible claim depends on it, it may belong in provenance without becoming a visible citation.
If a visible claim depends on an external fact, it should not float around uncited like a mysterious swamp orb.

---

## Source Provenance Rule

Any external material that may later support reasoning, planning, or production should enter the ecosystem through explicit source capture.

That means the durable evidence floor should be a VEDA intake record such as a `SourceItem` or equivalent governed intake path.

At minimum, provenance should preserve enough context to answer:
- what the source was
- where it came from
- when it entered the system
- why it was captured when that context matters

This keeps later citation and reasoning grounded in actual evidence instead of chat residue and memory soup.

---

## Citation Rule

Visible citations are required when a claim depends on external facts that are:
- specific
- time-sensitive
- disputable
- quoted or paraphrased from a source
- reported as measured, benchmarked, or versioned reality

Visible citations are usually not required for:
- conceptual explanations
- clearly labeled reasoning
- first-principles analysis
- illustrative examples that are explicitly illustrative

The rule is simple:

```text
Cite what would become unreliable, disputable, or outdated without evidence.
Do not cite obvious reasoning just to perform seriousness.
```

---

## Claim Types That Must Be Cited

Citations are required for:
- version-specific product or model claims
- release dates, feature availability, or support status
- capability and limitation claims that can change over time
- quoted or closely paraphrased external claims
- benchmark numbers or reported performance measurements
- historical origin claims when those claims matter to the page

If the reader could reasonably ask, “how do you know that?”, a citation is probably required.

---

## Claim Types That Usually Do Not Need Citation

Citations are usually unnecessary for:
- conceptual definitions explained directly on the page
- mechanism explanations based on explicit reasoning
- design principles stated as house rules or system choices
- hypothetical examples that are clearly labeled as examples

Over-citation makes pages harder to read and signals uncertainty where none is needed.
That is not rigor. That is decorative paperwork.

---

## Source Quality Hierarchy

Preferred source order:

1. primary technical sources
   - official documentation
   - release notes
   - model cards
   - original papers
2. direct artifacts
   - repositories
   - captured snapshots
   - first-party technical posts or changelogs
3. secondary technical sources
   - only when primary sources are unavailable or materially incomplete

Weak commentary, personality-driven summaries, and vague aggregation sludge should not carry critical claims unless there is no better path and the weakness is obvious to the reader.

---

## Time Discipline

Time-sensitive claims should be handled explicitly.

Use:
- dates instead of fuzzy relative phrasing
- qualifiers such as "as of" when appropriate
- refresh discipline when the underlying claim changes

This matters especially for:
- software capabilities
- model constraints
- product availability
- external configuration behavior

Time is one of the main reasons provenance and citation cannot be fake-neat afterthoughts.

---

## Relationship to VEDA Source Records

Where practical, visible citations in output surfaces should trace back to preserved source records in VEDA.

That does not mean every rendered page must expose internal IDs.
It means the system should preserve a defensible path between:
- captured evidence
- grounded use
- output-facing citation or reference behavior

The important rule is:
- VEDA owns the evidence trail
- V Forge owns how that trail is rendered or referenced in outputs

---

## Output Surface Expectations

Output surfaces should:
- cite external facts clearly when those facts matter
- avoid cluttering conceptual writing with unnecessary references
- prefer stable URLs or stored snapshots where possible
- make references readable rather than ornamental

A Sources or References section is usually enough.
Inline markers are acceptable when they make claim-to-source mapping clearer.

The point is clarity, not maximal footnote density.

---

## Anti-Patterns

Reject these patterns:
- citation dumping
- citing obvious definitions for decoration
- using citations to imply status rather than support a claim
- relying on a single weak source for a critical fact when stronger sources are available
- using uncaptured chat memory as if it were provenance
- collapsing VEDA provenance ownership into V Forge output rendering or vice versa

---

## Boundary Check

### Belongs to VEDA
- source capture
- intake provenance
- evidence retention
- source snapshots and intake metadata

### Belongs to V Forge
- how citations appear in drafts and produced outputs
- reference sections on public or production surfaces
- output-specific citation formatting decisions

### Belongs to Project V
- using grounded sources to inform planning
- referencing evidence in roadmap or prioritization contexts without becoming the evidence store

---

## Maintenance Note

Use this document as the active successor for source provenance and citation guidance.

Legacy site-surface citation rules should be treated as historical input once their grounded ideas are preserved here.

Future changes should update this document and the relevant successor docs by full repo-relative path rather than letting old site-architecture notes regain shadow authority.
