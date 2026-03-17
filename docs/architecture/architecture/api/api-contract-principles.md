# API Contract Principles

## Purpose

This document defines the durable API contract principles for the current repo during successor-doc reconstruction.

It exists to keep API behavior explicit, deterministic, reviewable, and aligned with bounded ownership across the V Ecosystem.

This is an API architecture document.
It does not inventory every endpoint.
It defines the rules that endpoint implementations and future endpoint docs must obey.

If this document conflicts with:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/SYSTEM-INVARIANTS.md`
- the current schema
- enforced implementation behavior

those higher-authority sources win and this document must be updated.

---

## What This Doc Is

This document defines the baseline API contract principles for:
- boundary enforcement
- request and response discipline
- mutation safety
- deterministic behavior
- authorization and attribution expectations
- project-scope enforcement
- evented write behavior
- error-shape consistency

---

## What This Doc Is Not

This document is not:
- an endpoint catalog
- a legacy v1 surface map
- a UI contract doc
- a license for endpoint sprawl
- a replacement for validation taxonomy
- a way to smuggle removed VEDA workflow domains back into the repo wearing fake glasses

It answers a simpler question:

```text
What rules should every API surface follow so the system remains safe, legible, and aligned with current architecture?
```

---

## Ownership

This document is cross-system API guidance.

It applies to APIs exposed by the systems of the V Ecosystem, but it does not collapse those systems.

Bounded ownership remains:
- Project V plans
- VEDA observes
- V Forge executes

An API contract must reinforce those boundaries rather than blur them.

---

## Core Principles

### 1. APIs enforce invariants

UI layers, extensions, scripts, and LLM clients may assist operators.
They do not define truth.

APIs are responsible for enforcing:
- ownership boundaries
- project scoping
- authorization rules
- validation rules
- mutation safety
- deterministic contract behavior

If a UI assumes a rule that the API does not enforce, that rule is decorative, not real.

### 2. Every mutation must be explicit

State-changing behavior must happen through explicit mutation endpoints or mutation paths.

Read operations must not quietly mutate canonical state.

No endpoint should perform a meaningful state change as a side effect of an ordinary read.

### 3. Contract behavior must be deterministic

The same valid request against the same state should produce the same contract-level result unless intentional nondeterminism is explicitly documented.

This includes:
- ordering
- validation outcomes
- status-code behavior
- error shape
- duplicate handling

### 4. Human-gated control remains the default

APIs must preserve the governing posture:

```text
Propose -> Review -> Apply
```

This is especially important in AI-assisted and operator-surface workflows.

### 5. Bounded ownership must be visible at the boundary

APIs should make it obvious which system owns a capability.

If an endpoint manages observatory state, it belongs in VEDA.
If it manages planning state, it belongs in Project V.
If it manages drafts or publishing workflow, it belongs in V Forge.

If the ownership is fuzzy, the endpoint design is probably wrong.

---

## Boundary Enforcement

The API boundary is where architectural discipline becomes real.

### Required rule

Every endpoint must enforce the ownership rules of the system exposing it.

Examples:
- VEDA endpoints must not quietly manage production workflow
- Project V endpoints must not become a dump for observatory state
- V Forge endpoints must not impersonate planning truth

### Anti-pattern

Do not preserve a stale mixed-purpose endpoint just because an old doc once listed it.

A fossilized route is still a fossil, even if the JSON was neatly indented.

---

## Project Scope and Isolation

Project-scoped systems must enforce scope at the API boundary.

### Required rules

- reads must enforce project ownership where applicable
- writes must resolve project context explicitly where required
- UUID lookup alone is not sufficient authorization
- cross-project existence leakage is forbidden

If a record belongs to another project, the API should behave as though it does not exist unless an explicitly authorized global surface says otherwise.

This is both an API rule and a structural system invariant.

---

## Read vs Write Discipline

### Read operations

Read operations should:
- be side-effect free by default
- use deterministic ordering for lists
- preserve non-disclosure rules
- avoid hidden event creation for ordinary reads

### Write operations

Write operations should:
- require appropriate authenticated authority
- validate input explicitly
- enforce system ownership and project scope
- use transactions when multiple writes are involved
- emit canonical events where required

If an operation changes durable state, it is a write. Dress it plainly.
Do not hide it behind a convenient GET-shaped trapdoor.

---

## Authentication, Authorization, and Attribution

API contracts should distinguish clearly between:
- authentication
- authorization
- attribution

### Authentication

The API must know who or what is making the request before allowing protected writes.

### Authorization

The API must decide whether that actor is allowed to perform the requested action in the requested scope.

### Attribution

The API should preserve who initiated the change and under what approved authority it occurred.

This should align with:
- `docs/architecture/security/auth-and-actor-model.md`
- VEDA event vocabulary where VEDA mutations are involved

An API that authenticates but fails to attribute meaningfully is only half awake.

---

## Request Shape Principles

API request contracts should be boring and explicit.

### Required rules

- required fields must be truly required
- optional fields must remain genuinely optional
- enum-like fields should be validated explicitly
- unsafe coercion should be avoided
- ambiguous overloaded request bodies should be avoided

### Mutation intent

If a request can trigger a meaningful state transition, the request should make that intent explicit.

### Duplicate and replay behavior

Where duplicate submission or replay is possible, the contract must define what happens.

Examples:
- true conflict
- idempotent replay
- reuse of an existing record
- rejection with stable error semantics

This must not be left to vibes, framework defaults, or the weather.

---

## Response Shape Principles

Response contracts should be stable, machine-usable, and human-legible.

### Success responses

Success responses should:
- return the relevant data payload
- preserve predictable top-level structure
- include pagination metadata for list responses where needed
- avoid leaking internal implementation trivia as public contract

### Error responses

Error responses should:
- use a stable top-level error shape
- provide a machine-usable code
- provide a human-usable message
- include structured details when relevant

The exact envelope may vary by endpoint family, but contract style should remain consistent across the system.

---

## Pagination and List Discipline

List endpoints should behave predictably.

### Required rules

- pagination inputs should be explicit
- default pagination should be documented and sane
- maximum page size should be bounded
- list ordering must be deterministic
- tie-breakers should be explicit where needed

An API list without deterministic ordering is a slot machine pretending to be infrastructure.

---

## Validation at the Boundary

Validation belongs at the API boundary before state is committed.

### Required rules

- reject malformed input clearly
- validate enums explicitly
- validate structural JSON where required
- return deterministic failures
- separate validation failure from authorization failure from state-conflict failure

The detailed error taxonomy belongs in its own doc.
This document establishes the principle that validation is a first-class boundary concern.

---

## Mutation, Events, and Atomicity

Where a mutation requires both state change and audit/event recording, the contract should reflect that those actions are coupled.

### Required rule

If the business behavior requires both:
- persisted state change
- canonical event emission

then the implementation must ensure they succeed or fail together where required.

An API must not claim a state change succeeded if the required canonical event was lost.
And it must not mint events for mutations that never committed.

That kind of mismatch breeds debugging folklore, and folklore is a terrible database.

---

## Idempotency and Safe Retry Behavior

API contracts should define retry-safe behavior for operations where retries are likely.

### Good contract behavior

- safe replay does not create duplicate state accidentally
- retries do not emit misleading duplicate mutation events
- duplicate governance creation is handled explicitly
- clients can distinguish conflict from idempotent success where needed

Not every mutation must be idempotent.
But every important mutation path should have clear duplicate semantics.

---

## Status Code Discipline

HTTP status codes should describe the contract outcome clearly.

### Baseline expectations

- `200` for successful read/update behavior where appropriate
- `201` for successful creation where a new resource is created
- `400` for malformed or validation-failing requests where the contract chooses bad-request semantics
- `401` for unauthenticated access
- `403` where authenticated authority lacks permission, if the surface distinguishes that case
- `404` for missing or non-disclosed resources
- `409` for valid requests that conflict with current state or contract rules
- `429` for rate limiting where applicable
- `500` for unexpected server failure

Exact usage should stay consistent within a surface family.
Do not let status codes become improvisational jazz.

---

## Non-Disclosure and Error Hygiene

APIs must not leak information that violates scope or authorization rules.

### Required rules

- cross-project resources must not leak existence
- error details must not reveal secrets or internal credentials
- validation details should be useful without becoming a data leak
- internal stack trivia should not become public contract

Helpful error messages are good.
Accidental reconnaissance is not.

---

## Operator Surfaces, Extensions, and LLM Clients

Operator-facing clients should consume APIs as clients, not bypass them.

### Required rules

- extensions and internal tools use approved API paths
- API rules are the same regardless of which client called them
- LLM assistance does not weaken boundary enforcement
- internal automation must not bypass auth, validation, or scope rules silently

This matters because “internal tool” is one of the oldest disguises in the software underworld.
A backdoor wearing a badge is still a backdoor.

---

## Versioning and Evolution

API contracts will evolve.
That evolution should be intentional.

### Rules for change

- prefer additive evolution where practical
- document breaking changes explicitly
- do not silently repurpose fields to mean something else later
- retire stale endpoint assumptions rather than keeping zombie compatibility forever

Compatibility discipline matters, but so does architectural cleanliness.
A system should not become a museum of bad decisions.

---

## Out of Scope

This document does not define:
- every endpoint path
- every request and response schema
- validation category details
- UI rendering rules
- transport specifics for every operator surface
- future multi-tenant partner API strategy

Those belong in more specific docs or implementation surfaces.

---

## Invariants

An API surface is compliant with these principles only if:
- it enforces system ownership and scope rules
- it keeps reads and writes behaviorally distinct
- it validates requests explicitly and deterministically
- it preserves attribution and authorization expectations
- it uses stable response and error behavior
- it does not leak cross-project existence or sensitive internal details
- it couples required events and state changes correctly

If one of those fails, the contract is weak even if the endpoint technically returns JSON.

---

## Relationship to Other Docs

This document should be read alongside:
- `docs/architecture/security/auth-and-actor-model.md`
- `docs/architecture/platform/vercel-neon-prisma.md`
- `docs/architecture/platform/deployment-infrastructure-baseline.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/systems/veda/observatory/event-auditability.md`

The next companion doc should define the detailed validation and error taxonomy used to make these principles operational.

---

## Maintenance Note

If future work tries to use the API layer to justify:
- hidden cross-boundary workflows
- stale removed VEDA domains
- silent LLM authority escalation
- inconsistent error behavior
- nondeterministic contract behavior

that is an architectural warning sign.

The API boundary should remain boring, explicit, and strong enough that humans and LLMs can both use it without corrupting system truth.
