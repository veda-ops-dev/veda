/**
 * SIL-3: Keyword Volatility Service
 *
 * Pure computation module — no DB access, no side effects.
 * Accepts pre-fetched snapshots ordered capturedAt ASC, id ASC.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * VOLATILITY FORMULA — RATIONALE
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * volatilityScore (0–100) is a weighted composite of four normalized signals:
 *
 *   W1 = 0.40 × rankShiftScore    (normalized averageRankShift)
 *   W2 = 0.25 × maxShiftScore     (normalized maxRankShift)
 *   W3 = 0.20 × aiChurnScore      (aiOverviewChurn / sampleSize, normalized)
 *   W4 = 0.15 × featureVolScore   (featureVolatility / sampleSize, normalized)
 *
 * Weights justified by operational signal importance:
 *
 *   rankShiftScore (40%): The primary SEO signal. Mean absolute rank movement
 *     across all consecutive deltas captures sustained instability. Highest
 *     weight because average shift is the most actionable intelligence for
 *     content strategy.
 *
 *   maxShiftScore (25%): Captures single-event spikes (algorithm updates,
 *     competitor events). A keyword that is usually stable but occasionally
 *     lurches 30+ places is operationally risky. Second weight because outlier
 *     events matter but shouldn't dominate steady-state scoring.
 *
 *   aiChurnScore (20%): Boolean presence/absence flips of AI Overview. Each
 *     flip represents a discrete intent-model change by Google — high
 *     strategic significance for GEO operators. Weighted lower than rank
 *     because it is a binary signal and can be noisy at low sample counts.
 *
 *   featureVolScore (15%): Count of distinct SERP feature type changes
 *     (featured snippet, PAA, local pack, etc.) per comparison. Lowest weight
 *     because feature presence is less directly actionable in this schema
 *     (rawPayload feature arrays are optional and may be absent in early data).
 *
 * Normalization caps:
 *   rankShiftScore: averageRankShift capped at 20 positions → 0–1
 *   maxShiftScore:  maxRankShift capped at 50 positions → 0–1
 *   aiChurnScore:   ratio of comparisons with AI flip, 0–1
 *   featureVolScore: mean feature changes per comparison, capped at 5 → 0–1
 *
 * Final score rounded to 2 decimal places. Deterministic for any given input.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * SIL-7 ATTRIBUTION COMPONENTS
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Three additive components are derived from the same normalized signals:
 *
 *   rankVolatilityComponent  = (0.40 * rankShiftScore + 0.25 * maxShiftScore) * 100
 *   aiOverviewComponent      = (0.20 * aiChurnScore) * 100
 *   featureVolatilityComponent = (0.15 * featureVolScore) * 100
 *
 * Each rounded to 2 decimal places.
 * Sum: rankVolatilityComponent + aiOverviewComponent + featureVolatilityComponent
 *   ≈ volatilityScore (within ±0.02 due to independent rounding).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * STORAGE STRATEGY — ON-DEMAND COMPUTATION (Option A)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Chosen: compute-on-read, no materialized table.
 *
 * Reasoning:
 *   - Current snapshot volumes per keyword are small (dozens to low hundreds).
 *     O(N) snapshot load + O(N) delta computation is fast at this scale.
 *   - Avoids schema migration and a new materialized table in Phase 1.
 *   - Avoids staleness bugs (materialized scores get out of sync when snapshot
 *     ingestion races with score reads).
 *   - Deterministic: the same snapshot set always produces the same score,
 *     making tests trivially reproducible.
 *   - If query volume grows or snapshot counts exceed ~500 per keyword,
 *     the correct move is to add a SIL-3 materialized table with a
 *     recompute trigger on SERPSnapshot insert. That migration is non-breaking.
 *
 * Rejected: materialized table (Option B)
 *   - Introduces write path into a currently read-only volatility surface.
 *   - Requires new EventType and schema migration.
 *   - Consistency edge cases when snapshot ingestion and score read are concurrent.
 *   - Premature optimization for current data volumes.
 */

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

export interface SnapshotForVolatility {
  id: string;
  capturedAt: Date;
  aiOverviewStatus: string;
  rawPayload: unknown;
}

export interface VolatilityProfile {
  sampleSize: number;                  // Number of consecutive pairs evaluated
  averageRankShift: number;            // Mean absolute rank movement across all pairs
  maxRankShift: number;                // Maximum single rank movement observed
  featureVolatility: number;           // Total distinct SERP feature changes across pairs
  aiOverviewChurn: number;             // Count of AI Overview status flips across pairs
  volatilityScore: number;             // 0–100 normalized composite
  // SIL-7 attribution components (0–100 each, sum ≈ volatilityScore within ±0.02)
  rankVolatilityComponent: number;     // Rank-driven portion: (W1+W2) * 100
  aiOverviewComponent: number;         // AI Overview portion: W3 * 100
  featureVolatilityComponent: number;  // Feature volatility portion: W4 * 100
}

// ─────────────────────────────────────────────────────────────────────────────
// Payload extraction (inline — avoids circular dep with serp-deltas route)
// Only extracts what volatility needs: ranked URLs and feature arrays.
// ─────────────────────────────────────────────────────────────────────────────

interface MinimalResult {
  url: string;
  rank: number | null;
}

function extractResults(rawPayload: unknown): MinimalResult[] {
  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return [];
  }
  const p = rawPayload as Record<string, unknown>;

  // DataForSEO items array (primary)
  if (Array.isArray(p.items)) {
    return p.items
      .filter(
        (item): item is Record<string, unknown> =>
          item !== null &&
          typeof item === "object" &&
          !Array.isArray(item) &&
          (item as Record<string, unknown>).type === "organic" &&
          typeof (item as Record<string, unknown>).url === "string"
      )
      .map((item) => ({
        url: item.url as string,
        rank:
          typeof item.rank_absolute === "number"
            ? item.rank_absolute
            : typeof item.position === "number"
            ? item.position
            : null,
      }))
      .sort((a, b) => {
        if (a.rank === null && b.rank === null) return a.url.localeCompare(b.url);
        if (a.rank === null) return 1;
        if (b.rank === null) return -1;
        return a.rank - b.rank;
      });
  }

  // Simple results array (test payloads)
  if (Array.isArray(p.results)) {
    return p.results
      .filter(
        (item): item is Record<string, unknown> =>
          item !== null &&
          typeof item === "object" &&
          !Array.isArray(item) &&
          typeof (item as Record<string, unknown>).url === "string"
      )
      .map((item) => ({
        url: item.url as string,
        rank:
          typeof item.rank === "number"
            ? item.rank
            : typeof item.position === "number"
            ? item.position
            : null,
      }))
      .sort((a, b) => {
        if (a.rank === null && b.rank === null) return a.url.localeCompare(b.url);
        if (a.rank === null) return 1;
        if (b.rank === null) return -1;
        return a.rank - b.rank;
      });
  }

  return [];
}

/**
 * Extract SERP feature type strings from rawPayload.
 * DataForSEO returns items with type !== "organic" for features (featured_snippet,
 * people_also_ask, local_pack, knowledge_graph, etc.).
 * For simple/test payloads, reads top-level features array.
 */
function extractFeatureTypes(rawPayload: unknown): Set<string> {
  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return new Set();
  }
  const p = rawPayload as Record<string, unknown>;
  const types = new Set<string>();

  if (Array.isArray(p.items)) {
    for (const item of p.items) {
      if (
        item !== null &&
        typeof item === "object" &&
        !Array.isArray(item) &&
        typeof (item as Record<string, unknown>).type === "string" &&
        (item as Record<string, unknown>).type !== "organic"
      ) {
        types.add((item as Record<string, unknown>).type as string);
      }
    }
    return types;
  }

  if (Array.isArray(p.features)) {
    for (const f of p.features) {
      if (typeof f === "string" && f.length > 0) types.add(f);
      else if (
        f !== null &&
        typeof f === "object" &&
        !Array.isArray(f) &&
        typeof (f as Record<string, unknown>).type === "string"
      ) {
        types.add((f as Record<string, unknown>).type as string);
      }
    }
  }

  return types;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pairwise delta computation (single pair)
// ─────────────────────────────────────────────────────────────────────────────

interface PairwiseDelta {
  /** Mean absolute rank shift for URLs present in both snapshots. */
  averageRankShift: number;
  /** Maximum absolute rank shift observed in this pair. */
  maxRankShift: number;
  /** Number of SERP feature types that changed (appeared or disappeared). */
  featureChangeCount: number;
  /** Whether AI Overview status flipped. */
  aiOverviewFlipped: boolean;
}

function buildRankMap(results: MinimalResult[]): Map<string, number | null> {
  const map = new Map<string, number | null>();
  for (const r of results) {
    if (!map.has(r.url)) map.set(r.url, r.rank); // first-wins: results pre-sorted by rank asc
  }
  return map;
}

function computePairDelta(
  from: SnapshotForVolatility,
  to: SnapshotForVolatility
): PairwiseDelta {
  const fromResults = extractResults(from.rawPayload);
  const toResults   = extractResults(to.rawPayload);

  // Build rank maps keyed by URL (first-wins on duplicates)
  const fromMap = buildRankMap(fromResults);
  const toMap   = buildRankMap(toResults);

  // Rank shift: only for URLs present in both snapshots with non-null ranks
  const shifts: number[] = [];
  for (const [url, fromRank] of fromMap) {
    if (!toMap.has(url)) continue;
    const toRank = toMap.get(url)!;
    if (fromRank !== null && toRank !== null) {
      shifts.push(Math.abs(fromRank - toRank));
    }
  }

  const averageRankShift =
    shifts.length > 0
      ? shifts.reduce((s, v) => s + v, 0) / shifts.length
      : 0;

  const maxRankShift =
    shifts.length > 0 ? Math.max(...shifts) : 0;

  // Feature volatility: symmetric difference of feature type sets
  const fromFeatures = extractFeatureTypes(from.rawPayload);
  const toFeatures   = extractFeatureTypes(to.rawPayload);
  let featureChangeCount = 0;
  for (const f of fromFeatures) { if (!toFeatures.has(f)) featureChangeCount++; }
  for (const f of toFeatures)   { if (!fromFeatures.has(f)) featureChangeCount++; }

  // AI Overview churn: boolean flip
  const aiOverviewFlipped = from.aiOverviewStatus !== to.aiOverviewStatus;

  return { averageRankShift, maxRankShift, featureChangeCount, aiOverviewFlipped };
}

// ─────────────────────────────────────────────────────────────────────────────
// Score normalization helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Clamp value to [0, cap], return 0–1 ratio. */
function normalizeToOne(value: number, cap: number): number {
  if (cap === 0) return 0;
  return Math.min(value, cap) / cap;
}

/** Round to N decimal places. */
function round(value: number, decimals: number): number {
  const factor = Math.pow(10, decimals);
  return Math.round(value * factor) / factor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Compute a VolatilityProfile from ordered SERPSnapshots.
 *
 * Input snapshots MUST be ordered capturedAt ASC, id ASC (deterministic).
 * Returns sampleSize=0 and all-zero metrics if fewer than 2 snapshots.
 */
export function computeVolatility(
  snapshots: SnapshotForVolatility[]
): VolatilityProfile {
  const ZERO: VolatilityProfile = {
    sampleSize: 0,
    averageRankShift: 0,
    maxRankShift: 0,
    featureVolatility: 0,
    aiOverviewChurn: 0,
    volatilityScore: 0,
    rankVolatilityComponent: 0,
    aiOverviewComponent: 0,
    featureVolatilityComponent: 0,
  };

  if (snapshots.length < 2) return ZERO;

  // Compute N-1 consecutive pairwise deltas
  const deltas: PairwiseDelta[] = [];
  for (let i = 0; i < snapshots.length - 1; i++) {
    deltas.push(computePairDelta(snapshots[i], snapshots[i + 1]));
  }

  const sampleSize = deltas.length;

  // Aggregate raw metrics
  const allAvgShifts    = deltas.map((d) => d.averageRankShift);
  const allMaxShifts    = deltas.map((d) => d.maxRankShift);
  const allFeatureCounts = deltas.map((d) => d.featureChangeCount);
  const aiFlips         = deltas.filter((d) => d.aiOverviewFlipped).length;

  const averageRankShift = round(
    allAvgShifts.reduce((s, v) => s + v, 0) / sampleSize,
    4
  );
  const maxRankShift = Math.max(...allMaxShifts);
  const featureVolatility = allFeatureCounts.reduce((s, v) => s + v, 0);
  const aiOverviewChurn = aiFlips;

  // ── Composite score (0–100) ─────────────────────────────────────────────────
  // Cap constants — calibrated to realistic SERP data ranges.
  const RANK_SHIFT_CAP    = 20;   // avg positions
  const MAX_SHIFT_CAP     = 50;   // max positions
  const FEATURE_COUNT_CAP = 5;    // avg feature changes per comparison
  // AI churn normalized as ratio of flipped comparisons to total

  const rankShiftScore  = normalizeToOne(averageRankShift, RANK_SHIFT_CAP);
  const maxShiftScore   = normalizeToOne(maxRankShift, MAX_SHIFT_CAP);
  const aiChurnScore    = normalizeToOne(aiFlips, sampleSize);           // ratio 0–1
  const featureVolScore = normalizeToOne(                                // mean per comparison
    featureVolatility / sampleSize,
    FEATURE_COUNT_CAP
  );

  const rawScore =
    0.40 * rankShiftScore +
    0.25 * maxShiftScore  +
    0.20 * aiChurnScore   +
    0.15 * featureVolScore;

  const volatilityScore = round(rawScore * 100, 2);

  // ── SIL-7 Attribution Components ───────────────────────────────────────────
  // Derived from the same normalized scores — no new math.
  const rankVolatilityComponent    = round((0.40 * rankShiftScore + 0.25 * maxShiftScore) * 100, 2);
  const aiOverviewComponent        = round((0.20 * aiChurnScore) * 100, 2);
  const featureVolatilityComponent = round((0.15 * featureVolScore) * 100, 2);

  return {
    sampleSize,
    averageRankShift,
    maxRankShift,
    featureVolatility,
    aiOverviewChurn,
    volatilityScore,
    rankVolatilityComponent,
    aiOverviewComponent,
    featureVolatilityComponent,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Maturity classification
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Maturity tiers for a volatility score derived from a given sampleSize.
 *
 * Maturity answers: "how much should we trust this score?"
 * It is orthogonal to volatilityScore, which answers: "how chaotic is this keyword?"
 *
 * A score of 80 from 2 pairs is an alarm with low confidence.
 * A score of 80 from 50 pairs is an operational finding that warrants action.
 * A score of 5 from 2 pairs means nothing.
 * A score of 5 from 50 pairs means the keyword is genuinely stable.
 *
 * Thresholds:
 *   preliminary  sampleSize 0–4    Too few pairs to draw conclusions.
 *   developing   sampleSize 5–19   Emerging signal; treat as directional.
 *   stable       sampleSize ≥ 20   Sufficient history for operational confidence.
 *
 * The threshold of 20 is chosen because the volatility formula averages across
 * all pairs: with fewer than 5 pairs, a single outlier pair dominates the
 * average; with 5–19, the average is meaningful but a cluster of outliers can
 * still distort it; at 20+, central-limit effects begin to stabilize the mean.
 */
export type VolatilityMaturity = "preliminary" | "developing" | "stable";

// ─────────────────────────────────────────────────────────────────────────────
// Regime classification (SIL-8 B1)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Volatility regime — operator-facing label derived from the rounded
 * volatilityScore (2 decimal places, as produced by computeVolatility).
 *
 * Boundary mapping (exact — from SIL-8 spec):
 *   calm:     0.00 <= score <= 20.00
 *   shifting: 20.00 < score <= 50.00
 *   unstable: 50.00 < score <= 75.00
 *   chaotic:  score > 75.00
 *
 * Input MUST already be rounded to 2 decimal places.
 * No additional rounding is performed here.
 */
export type VolatilityRegime = "calm" | "shifting" | "unstable" | "chaotic";

export function classifyRegime(volatilityScore: number): VolatilityRegime {
  if (volatilityScore <= 20.00) return "calm";
  if (volatilityScore <= 50.00) return "shifting";
  if (volatilityScore <= 75.00) return "unstable";
  return "chaotic";
}

export function classifyMaturity(sampleSize: number): VolatilityMaturity {
  if (sampleSize >= 20) return "stable";
  if (sampleSize >= 5)  return "developing";
  return "preliminary";
}
