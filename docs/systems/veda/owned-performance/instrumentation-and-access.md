# Instrumentation and Access

## Purpose

This document defines the instrumentation and access posture for a future GA4-owned-performance lane inside current VEDA.

It exists to answer:

```text
What must be true before GA4 data is trustworthy enough to enter VEDA as an observatory surface?
```

This is a successor doctrine and readiness document.
It is not a code implementation guide.
It is not a schema file.
It is not a route contract.

If this document conflicts with current higher-order truth, the higher-order truth wins and this document must be updated.

---

## Authority

Read this doc under:
- `docs/architecture/V_ECOSYSTEM.md`
- `docs/SYSTEM-INVARIANTS.md`
- `docs/VEDA_WAVE_2D_CLOSEOUT.md`
- `docs/architecture/architecture/veda/SCHEMA-REFERENCE.md`
- `docs/architecture/testing/hammer-doctrine.md`
- `docs/systems/veda/owned-performance/overview.md`
- `docs/systems/veda/owned-performance/ga4-observatory.md`
- `docs/systems/veda/owned-performance/observatory-model.md`

Official external references for this lane should prefer:
- Google Analytics Data API official documentation
- official Next.js documentation only where instrumentation behavior is relevant

The structured research sequence that formalizes these readiness questions is in:
- `docs/systems/veda/owned-performance/ga4-research-brief.md`

---

## Core Principle

If site instrumentation is wrong, the observatory lies.
If property access is wrong, the observatory lies differently.

This lane is only trustworthy when both are boringly correct.

That means a future GA4 lane must validate:
- site-side measurement reality
- property and API access reality
- metadata and compatibility reality
- environment separation reality

before schema and route ambition outrun source truth.

---

## Site-Side Instrumentation Discipline

### What matters

For VEDA, instrumentation matters only insofar as it makes owned-performance observation trustworthy.

The important question is not:

```text
Did we install Google Analytics somehow?
```

The important question is:

```text
Is the site generating page and route observations in a way that can later be trusted and joined cleanly?
```

### Minimum requirements

A future owned-performance lane should confirm:
- the correct GA4 property is receiving data
- production traffic is not silently mixed with staging or test traffic
- page and route identity is measured consistently
- soft-navigation behavior for App Router or SPA-like flows is not silently dropping page views
- hostname and environment signals are clear enough to prevent false joins

### On Next.js instrumentation and GA4

This distinction matters and must not be assumed wrong at implementation time:

**`instrumentation.ts` in Next.js is not the GA4 integration path.**

The `instrumentation.ts` file (available in Next.js 14+) is a server-side hook for OpenTelemetry and tracing integrations. It does not inject client-side analytics tags. It has no connection to GA4 event collection.

**The officially supported GA4 integration path for Next.js App Router sites** is `@next/third-parties`, specifically the `<GoogleAnalytics gaId="..." />` component. This component handles App Router compatibility concerns that a plain `<Script>` tag with `gtag.js` may not handle correctly for client-side route transitions.

A future owned-performance lane should prefer the officially supported integration path rather than hand-rolled gtag script patterns or folklore from legacy Pages Router setups.

### App Router soft-navigation risk

For Next.js App Router sites, client-side route transitions are not automatically tracked as `page_view` events by the standard Google Site Tag (`gtag.js`).

This is a known gap and the practical null-rate for page-level observations depends on whether instrumentation handles this correctly.

If `@next/third-parties` `<GoogleAnalytics>` is in place, partial App Router navigation coverage is handled.
The exact behavior for complex layouts with partial rendering must still be confirmed against real property data during the readiness pass.

The research brief (Bucket 6) covers this specifically.

### What this doc does not require

This document does not require a single universal site-instrumentation pattern.

But if Next.js sites are the intended owned surface, the instrumentation path should prefer official supported integration behavior rather than hand-rolled script folklore.

---

## API Access Discipline

A future GA4 lane requires explicit API access, not just site-side tags.

### Questions that must be answered before implementation
- what property ID is the source of truth per VEDA project?
- what service or operator credentials can read it?
- what scope or permission level is required?
- can metadata be discovered cleanly via the GA4 Metadata API (`getMetadata`)?
- can dimension/metric compatibility be checked before report design?

### The Metadata API is the right readiness tool

The GA4 Data API exposes a `getMetadata` method that returns all dimensions and metrics available for a specific property, including which combinations are compatible.

This is the correct tool for the "confirm metadata and compatibility before implementation" step.

The right pattern is:
- call `getMetadata` against the real property
- verify that the planned dimension/metric combinations are valid
- confirm that planned hot fields are available as stable real fields in that property

Do not rely on blog examples or assumed field availability. Properties differ.

### Why this matters

A property that is tagged but not queryable through the Data API is not an observatory source yet.

VEDA should treat access and queryability as first-class readiness concerns.

---

## Metadata and Compatibility Discipline

The future lane must confirm the actual property surface before collecting data.

That means a future implementation should verify:
- available dimensions
- available metrics
- compatibility of intended dimension/metric combinations
- any property-specific limitations that would make a planned observatory slice brittle

The goal is simple:
- do not document or build around combinations that fail in practice
- do not guess the property shape from memory or blog examples

---

## Joinability Discipline

Joinability matters more than metric volume.

A future owned-performance lane must be able to answer:
- what stable page or route key exists?
- does that key match the owned surface model elsewhere in VEDA?
- are trailing slash, hostname, locale, or query-string variations going to split identity incorrectly?
- can Next.js route changes or rewrites make the reported page identity drift from what VEDA thinks the owned surface is?

The join-key posture is defined at doctrine level in `observatory-model.md`.
The final normalization rules and join-key design are not pre-approved here; they require real property data to confirm.

---

## Environment Separation

This is easy to get wrong and worth saying plainly.

A future GA4 lane should not proceed casually if:
- production and staging traffic are mixed
- multiple hostnames are pooled without explicit rule
- internal or test traffic is not understood
- the property contains legacy noise that cannot be separated cleanly enough for a trustworthy first slice

VEDA should not ingest noisy property truth just because the API is available.

---

## Future Proving Surface

`https://www.vedaops.dev/` may serve as a useful small-scale proving surface for:
- confirming instrumentation is in place and working
- performing joinability checks against a known-simple owned surface
- verifying environment separation before applying the same approach to more complex properties
- validating that the research brief readiness questions have been answered in practice

This is bounded to proving surface use only.
It is not a substitute for confirming the full property readiness across all targeted VEDA projects.

---

## Recommended Readiness Questions

Before schema/route judgment, the following readiness questions should be answered.

These map directly to the research buckets in `ga4-research-brief.md`:

1. Is the correct property instrumented, accessible, and queryable via the Data API?
2. Can the Metadata API enumerate available dimensions and metrics for that property?
3. Can intended dimension/metric combinations be compatibility-checked?
4. Can page or route identity be joined cleanly to owned surfaces?
5. Is environment separation good enough to make the first slice trustworthy?
6. Are App Router client-side route transitions generating `page_view` events or being silently dropped?

If any of those fail, the right next step is more research or instrumentation cleanup, not schema ambition.

---

## What This Doc Rejects

This document explicitly rejects the following anti-patterns:
- assuming a site tag is equivalent to observatory readiness
- assuming WordPress-plugin-era setup knowledge is enough for Next.js observability
- assuming `instrumentation.ts` handles GA4 event collection
- building a GA4 lane before confirming property metadata and compatibility
- ingesting broad analytics noise because the source is available
- pretending environment mixing is acceptable for a first observatory slice

---

## Out of Scope

This document does not define:
- exact implementation code
- tag-manager architecture
- schema tables
- route contracts
- metric allowlists
- campaign instrumentation
- experimentation workflows

Those are separate concerns and should not be smuggled into readiness doctrine.

---

## Maintenance Note

If this lane grows, instrumentation and access doctrine should stay boring.

Do not let:
- tag-manager complexity
- implementation folklore
- cross-environment sloppiness
- access assumptions
- confusion between server-side tracing hooks and client-side analytics tags

turn owned-performance observation into a source of false certainty.

For VEDA, trustworthy small truth beats noisy broad truth.
