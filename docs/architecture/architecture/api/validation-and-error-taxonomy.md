# Validation and Error Taxonomy

## Purpose

This document defines the durable validation and error taxonomy principles for the current repo during successor-doc reconstruction.

It exists to keep validation explicit, deterministic, explainable, and usable by humans, operator surfaces, and LLM assistance without reintroducing stale workflow assumptions from removed VEDA domains.

This is an API and governance document.
It does not define every system-specific validation rule forever.
It defines how validation and failure reporting should behave so the system remains boring enough to trust.

If this document conflicts with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/architecture/architecture/api/api-contract-principles.md`
- current schema or enforced implementation behavior

those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document defines the baseline rules for:
- when validation should run
- what validation is responsible for
- how failures are categorized
- how blocking and warning behavior should differ
- how error codes should be structured and stabilized
- how validation results should be communicated at the API boundary
- how validation interacts with auditability and LLM assistance

---

## What This Doc Is Not

This document is not:
- a stale content-model rulebook from the mixed VEDA era
- a publish-workflow spec for removed editorial domains
- a replacement for schema constraints
- a permission model
- a general telemetry taxonomy
- a quality oracle that pretends readiness and excellence are the same thing

It answers a narrower question:

```text
How should the system validate requests and report failures so operators and tools can act on them predictably?
```

---

## Ownership

This document is cross-system API and governance guidance.

It applies wherever bounded systems expose validated mutation paths, but it does not collapse system ownership.

The bounded-system rule remains:
- Project V plans
- VEDA observes
- V Forge executes

Each system will have some system-specific rules.
This document defines the shared doctrine for how those rules should behave at the boundary.

---

## Core Principles

### 1. Validation protects state quality at the boundary

Validation exists to stop malformed, unauthorized, structurally unsafe, or contract-breaking state changes before they commit.

Validation is not punishment.
It is a guardrail.

### 2. Validation must be deterministic

Given the same request and the same state, validation should produce the same outcome.

No endpoint should return one error on Monday and a different philosophical mood on Tuesday for the same input.

### 3. Validation must be explainable

Failures should be understandable to a human operator and structured enough for tools and LLM assistance to respond to them safely.

### 4. Blocking and warning concerns must stay distinct

Some failures must prevent mutation.
Others should inform an operator without stopping forward progress.

If the system mixes those casually, operator trust dissolves.

### 5. Validation does not silently mutate truth

Validation may analyze, reject, or describe.
It should not quietly rewrite canonical state as a hidden side effect.

### 6. Stable error codes matter

Error codes are part of the contract.
Humans may read messages, but systems, UI surfaces, and LLM assistance often need stable identifiers.

---

## Validation Layers

Validation can exist in more than one layer.
Those layers should cooperate rather than contradict each other.

### 1. Schema and database constraints

These protect structural truth where hard guarantees are required.

Examples:
- uniqueness constraints
- foreign keys
- DB-level integrity checks
- required columns and valid relations

These are authoritative for structural safety.

### 2. API boundary validation

This validates request shape, enum values, state-transition legality, scope rules, and contract expectations before state is committed.

This is where the user-facing validation doctrine is most visible.

### 3. Domain validation

This validates system-specific business rules inside the owning bounded system.

Examples:
- observatory-specific ingest rules in VEDA
- planning-state transition rules in Project V
- execution workflow rules in V Forge

### 4. Derived or advisory validation

This includes warnings, readiness indicators, and other guidance that may help an operator but should not necessarily block the mutation.

The system should be honest about which layer produced the result.

---

## When Validation Runs

Validation may run at several times depending on the operation.

### Required cases

Validation should run:
- before any meaningful mutation is committed
- before any state transition that has explicit preconditions
- before any operation that would violate scope, ownership, or contract rules
- before any action that requires structural safety guarantees

### Optional or advisory cases

Validation may also run:
- on explicit operator request
- as a dry-run or preview path
- to produce readiness or warning feedback before a later action

### Rule

If validation is advisory rather than blocking, the contract should say so plainly.
Do not make operators guess whether a red box is fatal or merely dramatic.

---

## Validation Result Model

Validation results should be structured, predictable, and machine-usable.

A useful validation result generally includes:
- overall status
- per-category or per-check outcome where relevant
- list of structured issues
- stable error codes
- human-readable messages
- severity level
- field or path context where applicable

### Recommended result pattern

At minimum, a validation result should make it possible to answer:
- did this pass?
- if not, what failed?
- is the failure blocking?
- where is the problem?
- what class of rule was violated?

---

## Severity Levels

Validation issues should distinguish severity clearly.

### `blocking`

A blocking issue prevents the requested operation from succeeding.

Typical examples:
- malformed required input
- invalid enum value
- forbidden state transition
- missing required project context
- cross-project reference violation
- DB-backed uniqueness conflict where the operation cannot continue

### `warning`

A warning highlights a concern without preventing the requested operation.

Typical examples:
- advisory metadata issue
- weak optional field quality
- incomplete but non-fatal enrichment
- readiness concerns for a later step that is not being executed now

### Rule

Warnings must not masquerade as blockers.
Blockers must not be hidden as mild suggestions.

---

## Error Taxonomy Families

The exact codes will vary by endpoint family, but error taxonomy should be grouped into durable categories.

### 1. Request shape errors

The request is malformed or incomplete at the transport or body-contract level.

Examples:
- required field missing
- invalid JSON structure
- unsupported field shape
- bad scalar format

### 2. Validation errors

The request is structurally valid, but fails explicit boundary or domain validation.

Examples:
- invalid enum value
- illegal state transition
- rule-specific field conflict
- domain precondition failure

### 3. Authorization and scope errors

The actor is missing, unauthorized, or attempting access outside the allowed scope.

Examples:
- unauthenticated request
- forbidden mutation
- missing project context for write
- cross-project non-disclosed access attempt

### 4. Conflict errors

The request is valid in principle, but current state prevents it from succeeding cleanly.

Examples:
- duplicate governed target creation
- uniqueness conflict
- stale version conflict if optimistic concurrency is used
- incompatible current status for the requested transition

### 5. Not-found or non-disclosed errors

The requested resource is missing or intentionally undisclosed due to scope protection.

### 6. Internal errors

The server failed unexpectedly.

These should remain rare, clearly separated from validation failures, and not used as a lazy bucket for known contract problems.

---

## Error Code Design Rules

Error codes should be treated as stable contract identifiers.

### Required rules

- codes should be uppercase with underscore separation
- codes should name the rule family and failure condition clearly
- codes should remain stable once published in an active contract
- messages may evolve for clarity, but codes should not drift casually
- one code should describe one meaningful failure condition

### Good examples

- `REQUIRED_FIELD_MISSING`
- `INVALID_ENUM_VALUE`
- `PROJECT_CONTEXT_REQUIRED`
- `STATE_TRANSITION_FORBIDDEN`
- `CROSS_PROJECT_ACCESS_DENIED`
- `UNIQUE_CONSTRAINT_CONFLICT`

### Bad examples

- `BAD_REQUEST_2`
- `THING_FAILED`
- `UNKNOWN_ERROR` for known validation behavior
- endpoint-specific nonsense that cannot generalize beyond one route

A good error code should be boring, specific, and durable.
Like a wrench, not a poem.

---

## Message Design Rules

Human-readable messages should help a real operator recover.

### Required rules

- messages should be plain and specific
- messages should explain what is wrong without leaking sensitive internals
- messages should avoid vague blame language
- messages should align with the actual code and severity

### Example

Prefer:

```text
Keyword target already exists for this project, query, locale, and device.
```

Over:

```text
Unable to complete request due to invalid keyword circumstances.
```

The latter is pure bureaucratic fog juice.

---

## Field and Path Context

Where practical, validation issues should identify the field or path involved.

Examples:
- `field: "query"`
- `field: "device"`
- `path: "payload.items[0].url"`

This helps:
- UI feedback
- tool-assisted repair
- LLM explanation without guessing

Not every error needs a field pointer, but many should have one.

---

## Determinism and Ordering

Validation result ordering should be deterministic where multiple issues are returned.

### Recommended rule

Return issues in a stable order, such as:
1. request-shape failures
2. authorization/scope failures
3. domain validation failures
4. warnings

Within a category, use stable field or rule ordering where practical.

This reduces UI churn and makes debugging more reproducible.

---

## Relationship to Status Codes

Error taxonomy and HTTP status codes are related but not identical.

### Typical mapping

- malformed request -> `400`
- unauthenticated -> `401`
- unauthorized -> `403` where distinguished
- missing or non-disclosed resource -> `404`
- state conflict or uniqueness conflict -> `409`
- unexpected server failure -> `500`

### Rule

Do not overload `500` for known validation failures.
If the system knew what went wrong, the contract should say so honestly.

---

## Validation and State Mutation

Validation should not secretly mutate canonical state.

### Allowed behavior

- reject mutation
- describe issues
- return structured results
- optionally emit a canonical failure event where the owning system requires that behavior

### Disallowed behavior

- silently fixing input and pretending validation passed
- auto-applying content or planning changes without explicit contract behavior
- mutating state during a read-only validation preview

If a repair path exists, it should be explicit and attributable.

---

## Validation and Event Logging

Event logging for validation outcomes must respect system ownership.

### Rule

Not every validation failure needs a canonical event.
When failure events are recorded, that behavior should be intentional and fit the owning system’s audit model.

For VEDA-specific mutation flows, failure events should remain consistent with observatory-scoped event vocabulary and event-auditability rules.

### Important constraint

Do not resurrect removed editorial or production event vocabularies just because old docs once had them.
That architecture is dead. Let it rest.

---

## LLM Assistance and Validation

LLMs may assist with validation-oriented work, but they must remain inside governed paths.

### LLMs may

- explain failures in plain language
- suggest likely fixes
- summarize groups of validation issues
- help draft corrected request payloads for operator review

### LLMs may not

- bypass validation
- silently downgrade blockers to warnings
- auto-apply corrections to canonical state without an approved path
- invent nonexistent validation rules

The rule remains:

```text
Propose -> Review -> Apply
```

LLM assistance is interpretation support, not magical exemption from the contract.

---

## Operator-Surface Use

Validation output should be useful across:
- dashboard interfaces
- VS Code and browser operator surfaces
- scripts and internal clients
- LLM-assisted tooling

That means the contract should produce results that are:
- stable enough for machines
- readable enough for humans
- structured enough for assistive tooling

If the validation output only makes sense to the original author after three coffees and a reunion tour of old docs, it is not good enough.

---

## Out of Scope

This document does not define:
- every system-specific validation rule
- all future readiness criteria for Project V or V Forge
- UI presentation details
- telemetry dashboards
- schema migration failure handling beyond general contract principles

Those belong in narrower docs or implementation.

---

## Invariants

A validation and error contract is compliant with this doctrine only if:
- validation is explicit and deterministic
- blocking and warning issues are clearly distinguished
- error codes remain stable and machine-usable
- messages remain human-usable
- validation does not silently mutate canonical state
- status-code behavior aligns with contract reality
- scope and authorization failures are kept distinct from ordinary validation where practical
- internal failures are not used as a dumping ground for known contract errors

If one of those fails, the taxonomy is weak even if the API technically returns an error blob.

---

## Relationship to Other Docs

This document should be read alongside:
- `docs/architecture/architecture/api/api-contract-principles.md`
- `docs/architecture/architecture/security/auth-and-actor-model.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/systems/veda/observatory/event-auditability.md`

System-specific docs may define narrower validation rules later, but they should inherit the contract doctrine defined here.

---

## Maintenance Note

If future work tries to turn validation into:
- a hidden mutation engine
- a grab bag of unstable error strings
- a vague readiness oracle with no explicit rules
- a way to sneak stale removed workflow assumptions back into active truth

that is an architectural warning sign.

The desired result is simple:
- explicit rules
- deterministic outcomes
- stable codes
- useful messages
- no silent mutation

That is how validation becomes a trustworthy boundary instead of a haunted carnival booth.
