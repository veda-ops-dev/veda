# GA4-OP — Owned-Performance GA4 Observatory: Research Brief

## Document Authority

This brief is grounded against:
- Current clean-repo truth: `C:\dev\veda-ops-dev\veda`
- Authority order: V_ECOSYSTEM.md → SYSTEM-INVARIANTS.md → VEDA_WAVE_2D_CLOSEOUT.md → SCHEMA-REFERENCE.md → search-intelligence-layer.md → hammer-doctrine.md → owned-performance docs
- No live GA4 property has been accessed yet. This brief defines the research that must happen before schema or route design is justified.

---

## 1. Research Brief Framing

### What GA4-OP Is

GA4-OP is the minimum observation floor needed to record project-scoped, page-level post-click performance observations over time, drawn from a declared GA4 property, with explicit time semantics, joinable page identity, and a narrow enough metric posture to remain trustworthy and boring.

Its purpose is to create a repeatable, append-friendly, hammer-testable observation ledger for owned-page GA4 performance — the substrate from which later read surfaces (cross-date performance trends, cross-lane GA4-vs-SERP comparisons, page-cohort engagement analysis) can be derived on read.

GA4-OP is not those read surfaces. It is the floor they require.

GA4-OP fits the existing VEDA pattern:

```
entity + observation + time + interpretation
```

Applied here:
- **entity** = a project-scoped owned page observed through a declared GA4 property
- **observation** = a day-level performance record for that page, capturing traffic volume and engagement signals
- **time** = reportingDate (the GA4 date dimension value) and capturedAt (when VEDA fetched the report)
- **interpretation** = deferred to derived read surfaces; not materialized at GA4-OP v1

### What GA4-OP Is Not

GA4-OP is not:
- a marketing analytics platform
- a conversion optimization system
- a campaign management surface
- a BI dashboard
- a CRO authority
- a merged GA4 + Search Console truth layer
- a real-time performance monitor
- an experimentation platform
- a content planning or publishing surface

GA4-OP is also not the derived read surfaces it enables. Cross-lane comparisons and cohort trend analysis are later derivation layers, not the observation floor itself.

### Why the Observation Floor Must Come First

Without a confirmed observation floor:
- joinability ambiguity gets baked into schema instead of resolved at the boundary
- time semantic confusion (reportingDate vs capturedAt) creates false historical records
- metric selection without property validation leads to fields that don't exist or aren't compatible
- environment mixing produces silently wrong observations
- hammer-testable behavior is impossible to define before the ingest contract is clear
- schema design will be speculative rather than grounded in what the real GA4 property actually delivers

The current VEDA pattern — confirmed across the SEO observatory, DataForSEO ingest bridge, and YouTube research process — is to nail the observation floor first, then build derivation on top of it. GA4-OP must follow the same discipline.

---

## 2. Research Buckets

### Bucket 1: Property Access and Metadata Enumeration

**What must be confirmed:**

1. What GA4 property ID is the source of truth for each VEDA-managed project? Is there one property per site, one shared property across sites, or multiple properties at different scopes?

2. Can the GA4 Data API (`runReport`) be reached with available operator credentials? What service account or OAuth scope is required?

3. Can the GA4 Metadata API (`getMetadata`) be called successfully for the target property? This must return the full list of available dimensions and metrics for that specific property before any field selection is made.

4. Do the planned dimension/metric combinations (likely: `pagePath`, `hostName`, `date`, `sessions`, `engagedSessions`, and candidate breakdown dimensions) pass a compatibility check for this property?

**Why it matters:**

Every downstream design decision depends on knowing what the real property delivers. The Metadata API is the correct verification tool — not documentation, not blog examples, not assumptions from other properties. Properties differ. Compatibility must be confirmed per property.

**What outcome is sufficient to proceed:**

A successful `getMetadata` call against the real target property, with the planned dimension/metric set confirmed as compatible and available. Documented field availability per property.

---

### Bucket 2: Page Identity Reality

**What must be confirmed:**

1. What does `pagePath` actually look like in this property for these specific sites?
   - Are trailing slashes consistent or mixed?
   - Are there locale prefixes (e.g., `/en/about`)?
   - Does `pagePath` include query parameters for any significant portion of pages?
   - Are there query parameters that appear in `pagePath` that should be stripped?

2. What does `hostName` look like? Are there multiple hostnames in the property? Do staging, preview, or other non-production hostnames appear?

3. Are there any significant URL rewrite or redirect patterns that would make the GA4-reported `pagePath` differ from the canonical page path VEDA knows?

4. What is the practical null or empty rate for `pagePath` in this property?

**Why it matters:**

The join-key design depends entirely on knowing the real shape of `pagePath` and `hostName` in the target property. Normalization rules cannot be ratified before this is known. Designing normalization from assumptions will produce a join key that silently fragments or silently merges pages depending on the actual URL patterns.

The single highest-risk question here: does this property contain mixed production/staging traffic via multiple hostnames? If yes, environment separation must be resolved before any ingest is designed.

**Likely risk areas:**

- Trailing slash inconsistency is common. If `/about` and `/about/` both appear as distinct `pagePath` values, normalization that strips trailing slashes will merge them. If only one form appears, normalization is safe. Must be confirmed per property.
- Query parameters in `pagePath` vary by site. Sites with search or filter UIs may have significant query-parameter noise. Sites with simple static routes may have none.
- Locale-prefixed routes may need to remain distinct (observing `/en/about` separately from `/fr/about`) or may need to be normalized to the base path (`/about`). This is a modeling decision that cannot be made without knowing whether the sites have localized route structures.

**What outcome is sufficient to proceed:**

A sample of the top 50–100 `pagePath` values by session volume from a date range covering at least 30 days, with `hostName` dimension included. This sample should reveal: trailing slash patterns, query parameter presence, locale prefix presence, and whether multiple hostnames appear.

---

### Bucket 3: Environment Separation

**What must be confirmed:**

1. Is production traffic already separated from staging, preview, development, or test traffic in this GA4 property?

2. If multiple hostnames appear in the property, which ones are production and which are not?

3. Is internal traffic (operator browsing, dev/test visits) filtered out or tagged separately?

4. Is there legacy data noise from prior measurement setups that cannot be separated cleanly?

**Why it matters:**

This is a gate condition. If production and staging traffic are mixed in the property, the first observation slice is untrustworthy. Ingest must not proceed until environment separation is confirmed or the filter scope for a trustworthy first slice is defined.

VEDA should not ingest noisy property truth just because the API is available.

**Likely risk areas:**

- Properties that receive traffic from both `www.example.com` and `staging.example.com` without filtering will silently mix production and test signals. Without `hostName`-level filtering, observations will include staging traffic.
- Internal team visits may inflate engagement signals on low-traffic pages.

**What outcome is sufficient to proceed:**

A confirmed hostname inventory from the property showing that production traffic is either already isolated or that a `hostName` filter can be applied at report time to scope observations to production only. If environment mixing is material, it must be resolved before ingest is built.

---

### Bucket 4: Attribution Model Confirmation

**What must be confirmed:**

1. Which attribution scope is available in this property for source/medium analysis?
   - Session-scoped: `sessionSource`, `sessionMedium` — what brought this session
   - First-user: `firstUserSource`, `firstUserMedium` — how the user originally acquired
   - Last-user: `lastUserSource`, `lastUserMedium` — most recent channel before this session

2. Is session-scoped source/medium the right default for this lane's observation goal?

3. What is the practical volume of `(direct) / (none)` in the session source data? Is direct traffic volume high enough that source/medium breakdown adds meaningful observatory signal, or does it collapse into mostly-direct noise?

4. Are session-scoped source/medium dimensions confirmed as compatible with `pagePath`, `hostName`, and `date` in a single report for this property?

**Why it matters:**

GA4 exposes multiple attribution scopes that produce different numbers for the same property over the same date range. The lane must declare which scope it commits to before any source/medium fields are included in schema. Using the wrong scope silently produces misleading source attribution.

Source/medium may also not belong as a main-row field in the primary observation table. If it becomes a breakdown row or a separate entity, that affects schema design. The choice cannot be made before the volume and compatibility reality is confirmed.

**What outcome is sufficient to proceed:**

A compatibility check confirming that the planned attribution dimension(s) are valid for this property. A spot-check report showing source/medium volume distribution (particularly the (direct) fraction) across a sample date range. A documented decision on which attribution scope GA4-OP commits to.

---

### Bucket 5: Data History and Latency

**What must be confirmed:**

1. How far back does clean, usable data go in this property? Is there a date where the measurement setup changed significantly (property migration, instrumentation change, domain change) that would make older data unreliable as a baseline?

2. What is the observed data latency for this property? Typical GA4 latency is 24–48 hours, but some properties may differ.

3. Is there a meaningful amount of data already available for the likely page set, or is the property too new to provide a useful observation floor?

**Why it matters:**

If the property only has a few days of history, the first slice will not produce meaningful time-series observations. If the history has a significant measurement change in the middle of it, early data may not be comparable to recent data.

A property that is instrumented but empty, or that has a significant history gap, needs to be noted before schema is designed to receive that data.

**What outcome is sufficient to proceed:**

A spot-check confirming at least 30 days of usable data with consistent page identity patterns. Documentation of any known history gaps or instrumentation changes within the available date range.

---

### Bucket 6: Soft-Navigation and App Router Tracking

**What must be confirmed:**

1. For Next.js App Router sites: are client-side route transitions generating `page_view` events in GA4, or are they being silently dropped?

2. Is `@next/third-parties` `<GoogleAnalytics>` in place, or is a legacy `gtag.js` script pattern being used?

3. What is the practical `pageviews` vs `sessions` ratio for pages that should be receiving multiple client-side navigation events? A ratio close to 1:1 suggests client-side route transitions are not being tracked.

4. Are there any pages with significantly lower `pagePath` appearance in GA4 than expected based on content structure?

**Why it matters:**

For App Router Next.js sites, client-side route transitions are not automatically tracked by a standard `gtag.js` tag. If instrumentation is not handling this correctly, a significant fraction of page-level observations will be missing silently. The observatory will have a systematic gap that is not visible from the API — it just looks like those pages receive no visits.

This is the highest technical risk for this lane on Next.js sites. It is not visible from the API surface without cross-checking against expected page visit patterns.

**Likely risk areas:**

- A single-page-app-style Next.js site where navigation is entirely client-side will have near-zero page-level data if instrumentation is wrong.
- A mostly static site with few client-side transitions will have lower exposure to this risk.

**What outcome is sufficient to proceed:**

Confirmation that either (a) `@next/third-parties` `<GoogleAnalytics>` is in place and client-side transitions are verified as tracked via a spot-check in the GA4 DebugView, or (b) the site structure is confirmed to be static/SSR-only and client-side transition tracking is not a material concern. If soft-navigation tracking is broken, it must be fixed before ingest is built.

---

## 3. Priority Ranking

Research buckets ranked by importance for unblocking GA4-OP:

**1. Bucket 3 — Environment Separation (gate condition)**
If production and staging traffic are mixed, the observatory is untrustworthy from the start. This must be confirmed before any other research produces meaningful results.

**2. Bucket 1 — Property Access and Metadata Enumeration (highest schema-blocking priority)**
Nothing else can be designed without confirmed API access and validated dimension/metric availability for the real property. This bucket unblocks field selection, compatibility confirmation, and schema design.

**3. Bucket 2 — Page Identity Reality**
The join-key design and normalization rules cannot be ratified without knowing what `pagePath` and `hostName` actually look like. Must be confirmed before schema design.

**4. Bucket 6 — Soft-Navigation / App Router Tracking**
The highest silent-failure risk. If App Router client-side transitions are not being tracked, the observation floor has a systematic gap that is not visible from the API alone. Must be confirmed before ingest is built, not after.

**5. Bucket 4 — Attribution Model Confirmation**
Required before source/medium fields are included in schema. Can be done in parallel with Bucket 2 once API access is confirmed.

**6. Bucket 5 — Data History and Latency (lowest gate priority)**
Important for knowing what historical slice is usable, but does not block the fundamental design work. Can be confirmed alongside Bucket 1 and 2 work.

---

## 4. Failure Modes

**1. Designing schema before confirming page identity shape**
If schema is designed assuming `pagePath` values are clean (no query params, consistent trailing slash, single hostname), and real property data reveals mixed `pagePath` shapes, the join-key normalization logic will be wrong. Downstream read surfaces that depend on stable page identity will produce wrong results silently. The fix requires a schema migration.

**2. Treating instrumentation presence as observatory readiness**
If a GA4 tag is installed but App Router soft-navigation is not being tracked, the observatory floor has a systematic page-level gap. Installing a tag is not the same as confirming that the site generates trustworthy page observations. Skipping Bucket 6 produces a silently incomplete observatory.

**3. Using multiple attribution scopes without declaring a commitment**
If the schema includes both session-scoped and first-user source/medium fields without an explicit declaration of which is primary, read surfaces built above the data will produce inconsistent attribution narratives. The commitment must be explicit and made before schema design.

**4. Proceeding with mixed production/staging traffic**
If environment separation is assumed rather than confirmed, observation rows will contain staging and test traffic mixed with real user activity. This is not recoverable from the data after the fact. Bucket 3 must clear before ingest is built.

**5. Treating reportingDate and capturedAt as interchangeable**
If implementation stores only one time value (typically capturedAt), time-series analysis becomes impossible because the data appears as a pile of fetch events rather than a historical performance record. Both values must be explicit and separated from the start.

**6. Designing hammer tests assuming determinism that does not exist at the provider surface**
GA4 reporting data can vary across re-fetches of the same date range (minor adjustments as data finalizes). If the hammer assumes that the same report API call always returns identical numbers, tests will fail intermittently without indicating a real implementation bug. The hammer must test local invariants (row existence, ordering, time semantics, project isolation) rather than GA4 numeric exactness.

---

## 5. Recommended Research Sequence

The exact bounded research sequence to run before GA4-OP schema/route judgment:

**Step 1: Environment check (Bucket 3)**

Before anything else:
- Confirm production hostname(s) for the target property
- Check whether staging or non-production hostnames are present
- Determine whether internal traffic filtering is in place
- Decision: is production traffic clean enough to proceed, or does environment separation need to be resolved first?

If environment is mixed: stop until it is clean. No further research produces trustworthy results on a mixed property.

**Step 2: API access and metadata confirmation (Bucket 1)**

Once environment is clean:
- Confirm GA4 Data API access with available credentials
- Call `getMetadata` against the real target property
- Verify that `pagePath`, `hostName`, `date`, `sessions`, `engagedSessions` are available and mutually compatible
- Verify that candidate breakdown dimensions (sessionSource, sessionMedium, deviceCategory) are also available and compatible with the primary dimensions
- Document the actual available dimension/metric set

**Step 3: Page identity inventory (Bucket 2 + part of Bucket 4)**

Using confirmed API access:
- Pull a report for the top 50–100 pages by session volume over 30 days with `pagePath` and `hostName` dimensions
- Document the actual trailing slash pattern, query param presence, locale prefix presence
- Decide on normalization rules based on actual data (not assumptions)
- Confirm that `pagePath` + `hostName` produces a stable and trustworthy compound page identity

**Step 4: Attribution scope decision (Bucket 4)**

Using the same report window:
- Pull a spot-check with session-scoped source/medium dimensions
- Document (direct) volume fraction
- Decide: does session-scoped source/medium belong as a main-row field, a breakdown row, or defer to v2?

**Step 5: Soft-navigation confirmation (Bucket 6)**

For Next.js App Router sites:
- Confirm whether `@next/third-parties` `<GoogleAnalytics>` is in place or a legacy pattern is used
- Spot-check pageviews vs sessions ratio for pages that should receive multiple client-side navigations
- If possible, run a DebugView spot-check to confirm route transitions fire `page_view` events
- Decision: is client-side navigation tracking confirmed, or does instrumentation need repair?

**Step 6: History check (Bucket 5)**

- Confirm usable data start date
- Note any known measurement discontinuities
- Document available date range for first observatory slice

**Step 7: Schema and route judgment**

Only after Steps 1–6 are complete: design the GA4-OP observation schema (property configuration table, page performance observation table) and the ingest route contract.

The schema must follow the existing VEDA SERP pattern:
- thin route handler
- pure normalizer library
- atomic write with EventLog
- idempotency on a declared uniqueness key
- `rawPayload` preserved
- hot fields promoted explicitly

Write the hammer spec before writing the route.
The hammer spec is the proof that the design is testable.

---

## Document Notes

- This brief was produced against current clean-repo truth in `C:\dev\veda-ops-dev\veda`.
- No GA4 property has been accessed yet. The brief defines what must be confirmed before schema/route design is justified.
- No schema tables, route contracts, or implementation decisions are made in this document.
- The brief should be re-evaluated after Step 1 (environment check) and Step 2 (API access + metadata confirmation) are complete.
- `https://www.vedaops.dev/` may serve as a bounded proving surface for instrumentation sanity, joinability checks, and small-scope readiness confirmation before applying the same approach to larger project properties.
