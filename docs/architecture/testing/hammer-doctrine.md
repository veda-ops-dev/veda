# hammer doctrine

## purpose

The hammer exists to verify that VEDA operational surfaces preserve system invariants under realistic execution.

Its primary job is to protect:

- database integrity
- API contract integrity
- bounded ownership integrity
- project isolation
- deterministic behavior where required
- read-only guarantees on observational surfaces

For observability routes, the hammer should answer:

> if an operator or system hits this surface, does VEDA behave safely, correctly, deterministically, and without mutating canonical state?

## what the hammer is

The hammer is an integration and invariants test layer.

It is used to verify:

- routes behave correctly against a running system
- request validation rejects invalid input
- successful requests return stable contract shapes
- project-scoped isolation is enforced
- observational routes do not perform hidden writes
- persistence and schema assumptions still hold under real execution

## what the hammer is not

The hammer is not:

- a UI test suite
- a generic code coverage substitute
- a style or refactor enforcement mechanism
- a place to test every helper only because it exists
- a permission slip for speculative feature growth

Code quality may improve as a side effect of hammer work, but that is not its mission.

## doctrine

### 1. invariants first

Hammer coverage should prioritize structural truths over implementation trivia.

Examples:

- no mutation on read-only routes
- correct request rejection on invalid params
- deterministic output ordering
- project isolation
- bounded ownership discipline

### 2. real execution over mock theater

The hammer should exercise live routes and realistic repo state whenever possible.

### 3. exact contract beats vibes

A useful hammer assertion is not just "field exists."
It should prefer:

- exact required fields
- exact absent fields
- exact meta fields
- exact deterministic ordering
- explicit zero-state behavior

### 4. route intent must stay visible

A hammer module should make the route's purpose legible.
If a route is observability-only, the hammer must protect that property directly.

### 5. boring structure wins

Hammer scripts should be broken into focused modules when a single file becomes too large to reason about safely.
A coordinator may compose the modules, but the modules should stay organized by contract concern rather than by random file growth.

## practical categories

### persistence hammer

Verifies:

- schema integrity
- migration integrity
- persistence assumptions
- no unexpected write-side effects

### contract hammer

Verifies:

- request validation
- response structure
- dependency resolution
- deterministic ordering
- zero-state behavior

### mutation-boundary hammer

Verifies:

- read-only routes remain read-only
- observational surfaces do not silently mutate state
- bounded systems do not absorb forbidden ownership

## serp disturbances application

For `src/app/api/seo/serp-disturbances/route.ts`, the hammer should primarily verify:

- the route stays read-only
- invalid params are rejected
- `include` dependency resolution remains stable
- `meta` remains correct and deterministic
- zero-target behavior stays explicit and stable
- project isolation remains enforced

It should not drift into UI concerns or speculative workflow behavior.

## maintenance rule

When a hammer file becomes too large, split it into focused modules and keep a thin coordinator.

Preferred shape:

- shared helpers
- concern-specific modules
- one coordinator entrypoint already referenced by `scripts/api-hammer.ps1`

This keeps the hammer maintainable without changing its mission.
