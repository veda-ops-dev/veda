/**
 * operator-insight.ts — SIL-11 Operator Reasoning Layer (pure library)
 *
 * Pure function module. No DB access. No Prisma. No file IO. No Date.now().
 * All outputs are deterministic given the same inputs.
 *
 * Exports:
 *   OperatorInsightInput   — input shape (pre-fetched data from route)
 *   OperatorInsightOutput  — structured reasoning output
 *   buildOperatorInsight() — pure function: input → output
 */

// ─────────────────────────────────────────────────────────────────────────────
// Input / Output types
// ─────────────────────────────────────────────────────────────────────────────

export interface SpikeRecord {
  /** ISO timestamp of the later snapshot in the pair */
  capturedAt: string;
  /** pairVolatilityScore for this pair (0–100) */
  magnitude: number;
}

export interface OperatorInsightInput {
  // Keyword target metadata
  keywordTargetId: string;
  query: string;
  locale: string;
  device: string;
  windowDays: number;

  // Volatility profile (already computed by caller via computeVolatility)
  volatilityScore: number;
  regime: string;
  maturity: string;
  sampleSize: number;
  snapshotCount: number;
  rankVolatilityComponent: number;
  aiOverviewComponent: number;
  featureVolatilityComponent: number;
  aiOverviewChurn: number;

  // Pre-computed evidence (caller builds these from snapshot iteration)
  /** Top-N spike pairs (sorted desc by magnitude, already sliced) */
  spikes: SpikeRecord[];
  /** Count of consecutive pairs where the feature set changed */
  featureTransitions: number;
}

export interface Observation {
  type: string;
  message: string;
}

export interface Hypothesis {
  cause: string;
  /** Clamped to [0, 1], rounded to 2 decimal places */
  confidence: number;
}

export interface SuggestedAction {
  action: string;
  /** 1 = highest urgency */
  priority: number;
}

export interface OperatorInsightOutput {
  keywordTargetId: string;
  query: string;
  locale: string;
  device: string;
  windowDays: number;

  volatility: {
    score: number;
    regime: string;
    maturity: string;
    sampleSize: number;
    snapshotCount: number;
  };

  components: {
    rankVolatility: number;
    aiOverview: number;
    featureVolatility: number;
  };

  evidence: {
    aiOverviewChurn: number;
    spikes: SpikeRecord[];
    featureTransitions: number;
  };

  observations: Observation[];
  hypotheses: Hypothesis[];
  suggestedActions: SuggestedAction[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

// ─────────────────────────────────────────────────────────────────────────────
// Observations — deterministic rules evaluated in fixed order
// ─────────────────────────────────────────────────────────────────────────────

function buildObservations(input: OperatorInsightInput): Observation[] {
  const obs: Observation[] = [];
  const {
    volatilityScore,
    aiOverviewChurn,
    rankVolatilityComponent,
    featureVolatilityComponent,
    spikes,
    featureTransitions,
    sampleSize,
  } = input;

  const spikeCount = spikes.length;

  // 1. Regime-level (mutually exclusive, highest severity first)
  if (volatilityScore > 75) {
    obs.push({ type: "volatility", message: "SERP is in a chaotic regime — extreme instability detected." });
  } else if (volatilityScore > 60) {
    obs.push({ type: "volatility", message: "SERP shows high volatility." });
  } else if (volatilityScore > 20) {
    obs.push({ type: "volatility", message: "SERP is shifting — moderate volatility detected." });
  } else {
    obs.push({ type: "volatility", message: "SERP is calm — low volatility." });
  }

  // 2. AI Overview churn
  if (aiOverviewChurn >= 5) {
    obs.push({ type: "aiOverview", message: "Frequent AI Overview changes detected — high churn rate." });
  } else if (aiOverviewChurn >= 3) {
    obs.push({ type: "aiOverview", message: "Frequent AI overview changes detected." });
  } else if (aiOverviewChurn >= 1) {
    obs.push({ type: "aiOverview", message: "AI overview churn detected." });
  }

  // 3. Rank instability
  if (rankVolatilityComponent > 40) {
    obs.push({ type: "rankInstability", message: "Primary volatility driver is rank movement." });
  } else if (rankVolatilityComponent > 20) {
    obs.push({ type: "rankInstability", message: "Moderate rank movement detected." });
  }

  // 4. Feature turbulence
  if (featureVolatilityComponent > 15) {
    obs.push({ type: "featureTurbulence", message: "SERP feature composition is changing frequently." });
  } else if (featureVolatilityComponent > 5) {
    obs.push({ type: "featureTurbulence", message: "SERP feature changes observed." });
  }

  // 5. Spike concentration
  if (spikeCount >= 3) {
    obs.push({ type: "spikes", message: "Multiple high-volatility spike events identified in window." });
  } else if (spikeCount >= 1) {
    obs.push({ type: "spikes", message: "Spike event detected in volatility history." });
  }

  // 6. Feature transitions
  if (featureTransitions >= 5) {
    obs.push({ type: "featureTransitions", message: "High volume of SERP feature set changes across window." });
  } else if (featureTransitions >= 2) {
    obs.push({ type: "featureTransitions", message: "SERP feature set transitions observed." });
  }

  // 7. Low evidence warning
  if (sampleSize < 5) {
    obs.push({ type: "lowEvidence", message: "Insufficient snapshot history — insights are preliminary." });
  }

  return obs;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hypotheses — dominant driver + secondary contributors
// ─────────────────────────────────────────────────────────────────────────────

function buildHypotheses(input: OperatorInsightInput): Hypothesis[] {
  const { volatilityScore, rankVolatilityComponent: rank, aiOverviewComponent: ai, featureVolatilityComponent: feat } = input;

  if (volatilityScore === 0) return [];

  const score = volatilityScore;

  // Dominant driver: highest component; tie-break order: rank > ai > feature
  type Driver = { cause: string; component: number };
  const drivers: Driver[] = [
    { cause: "Ranking instability",               component: rank },
    { cause: "AI overview generation variability", component: ai   },
    { cause: "SERP layout experimentation",        component: feat  },
  ];

  // Sort: component DESC (tie-break preserved by stable order above: rank > ai > feat)
  const sorted = drivers.slice().sort((a, b) => b.component - a.component);
  const dominant = sorted[0];

  const hypotheses: Hypothesis[] = [];

  // Primary hypothesis
  if (dominant.component > 0) {
    hypotheses.push({
      cause:      dominant.cause,
      confidence: round2(Math.min(dominant.component / score, 1)),
    });
  }

  // Secondary hypotheses: contributors > 10% of score, excluding dominant
  const SECONDARY_FLOOR = score * 0.10;
  for (const d of sorted.slice(1)) {
    if (d.component > SECONDARY_FLOOR) {
      hypotheses.push({
        cause:      d.cause,
        confidence: round2(Math.min(d.component / score, 1)),
      });
    }
  }

  // Sort: confidence DESC, cause ASC (deterministic)
  hypotheses.sort((a, b) => {
    if (b.confidence !== a.confidence) return b.confidence - a.confidence;
    return a.cause.localeCompare(b.cause);
  });

  return hypotheses;
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggested actions — deterministic trigger set, sorted priority ASC then action ASC
// ─────────────────────────────────────────────────────────────────────────────

function buildSuggestedActions(input: OperatorInsightInput): SuggestedAction[] {
  const { volatilityScore, sampleSize, aiOverviewChurn, spikes, featureTransitions, regime } = input;
  const spikeCount = spikes.length;

  const raw: SuggestedAction[] = [];

  // Capture cadence
  if (regime === "chaotic" || regime === "unstable") {
    raw.push({ action: "Capture additional snapshots daily for 14 days.", priority: 1 });
  } else if (volatilityScore > 0) {
    raw.push({ action: "Capture additional snapshots daily for 14 days.", priority: 2 });
  }

  // Low sample baseline
  if (sampleSize < 5) {
    raw.push({ action: "Increase snapshot collection to build evidence base.", priority: 1 });
  }

  // AI overview churn
  if (aiOverviewChurn >= 3) {
    raw.push({ action: "Review AI overview content strategy for this query.", priority: 2 });
  }
  if (aiOverviewChurn >= 1) {
    raw.push({ action: "Monitor AI overview presence daily.", priority: 3 });
  }

  // Spike investigation
  if (spikeCount >= 3) {
    raw.push({ action: "Investigate competing domains around spike dates.", priority: 2 });
  }

  // Feature churn
  if (featureTransitions >= 3) {
    raw.push({ action: "Segment analysis by SERP feature set.", priority: 3 });
  }

  // High overall volatility
  if (volatilityScore > 50) {
    raw.push({ action: "Review ranking competitors.", priority: 2 });
  }

  // Always: long-term monitoring
  raw.push({ action: "Monitor keyword weekly and compare regime changes.", priority: 4 });

  // Deduplicate: keep lowest priority number per action string
  const seen = new Map<string, SuggestedAction>();
  for (const a of raw) {
    const existing = seen.get(a.action);
    if (!existing || a.priority < existing.priority) {
      seen.set(a.action, a);
    }
  }

  // Sort: priority ASC, action ASC
  return Array.from(seen.values()).sort((a, b) => {
    if (a.priority !== b.priority) return a.priority - b.priority;
    return a.action.localeCompare(b.action);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * buildOperatorInsight — pure function.
 *
 * Accepts pre-fetched, pre-computed data and returns a fully structured
 * operator insight output. No side effects. No I/O. Deterministic.
 */
export function buildOperatorInsight(input: OperatorInsightInput): OperatorInsightOutput {
  return {
    keywordTargetId: input.keywordTargetId,
    query:           input.query,
    locale:          input.locale,
    device:          input.device,
    windowDays:      input.windowDays,

    volatility: {
      score:         input.volatilityScore,
      regime:        input.regime,
      maturity:      input.maturity,
      sampleSize:    input.sampleSize,
      snapshotCount: input.snapshotCount,
    },

    components: {
      rankVolatility:   input.rankVolatilityComponent,
      aiOverview:       input.aiOverviewComponent,
      featureVolatility: input.featureVolatilityComponent,
    },

    evidence: {
      aiOverviewChurn:   input.aiOverviewChurn,
      spikes:            input.spikes,
      featureTransitions: input.featureTransitions,
    },

    observations:    buildObservations(input),
    hypotheses:      buildHypotheses(input),
    suggestedActions: buildSuggestedActions(input),
  };
}
