/**
 * operator-reasoning.ts — SIL-11 Project-Level Operator Reasoning Engine
 *
 * Pure function module. No DB. No Prisma. No file IO. No Date.now().
 * All outputs are deterministic given the same inputs.
 *
 * Accepts pre-fetched, pre-computed project-level aggregates and a list
 * of per-keyword volatility records. Applies deterministic heuristic rules
 * to produce structured observations, hypotheses, and recommended actions
 * at the project scope.
 *
 * Exports:
 *   OperatorReasoningInput   — input shape (pre-fetched by route handler)
 *   OperatorReasoningOutput  — structured reasoning output
 *   Observation, Hypothesis, RecommendedAction — item types
 *   computeOperatorReasoning() — pure function: input → output
 */

// ─────────────────────────────────────────────────────────────────────────────
// Input / Output types
// ─────────────────────────────────────────────────────────────────────────────

export interface KeywordSummary {
  keywordTargetId: string;
  query: string;
  volatilityScore: number;
  volatilityRegime: string;
  sampleSize: number;
  aiOverviewChurn: number;
  rankVolatilityComponent: number;
  aiOverviewComponent: number;
  featureVolatilityComponent: number;
}

export interface ProjectVolatilitySummary {
  keywordCount: number;
  activeKeywordCount: number;
  averageVolatility: number;
  maxVolatility: number;
  highVolatilityCount: number;
  alertKeywordCount: number;
  alertRatio: number;
  alertThreshold: number;
  weightedProjectVolatilityScore: number;
  volatilityConcentrationRatio: number | null;
}

export interface OperatorReasoningInput {
  projectId: string;
  windowDays: number;
  summary: ProjectVolatilitySummary;
  /** All active keywords (sampleSize >= 1), sorted deterministically by caller */
  keywords: KeywordSummary[];
}

export interface Observation {
  type: string;
  keywordId?: string;
  description: string;
  evidence?: Record<string, unknown>;
}

export interface Hypothesis {
  type: string;
  /** Clamped [0, 1], rounded to 2 decimal places */
  confidence: number;
  explanation: string;
}

export interface RecommendedAction {
  type: string;
  keywordId?: string;
  rationale: string;
}

export interface OperatorReasoningOutput {
  observations: Observation[];
  hypotheses: Hypothesis[];
  recommendedActions: RecommendedAction[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function clamp01(n: number): number {
  return Math.min(1, Math.max(0, n));
}

// ─────────────────────────────────────────────────────────────────────────────
// Observations
// Rules are evaluated in fixed order. Each rule produces zero or one
// observation. Output is sorted deterministically at the end.
// ─────────────────────────────────────────────────────────────────────────────

const HIGH_VOLATILITY_THRESHOLD = 70;
const AI_CHURN_THRESHOLD = 3;
const PROJECT_SPIKE_ALERT_RATIO = 0.25;   // 25%+ keywords alerting
const CONCENTRATION_HIGH = 0.80;           // B2 concentration ratio

function buildObservations(input: OperatorReasoningInput): Observation[] {
  const { summary, keywords } = input;
  const raw: Observation[] = [];

  // Rule 1 — High volatility keywords (one observation per qualifying keyword)
  // Gate: only emit when project average volatility > 30 (hammer-authoritative SIL11-J)
  for (const kw of keywords) {
    if (summary.averageVolatility > 30 && kw.volatilityScore > HIGH_VOLATILITY_THRESHOLD) {
      raw.push({
        type: "HIGH_VOLATILITY_KEYWORD",
        keywordId: kw.keywordTargetId,
        description: `Keyword "${kw.query}" has high volatility (score: ${kw.volatilityScore}).`,
        evidence: {
          volatilityScore: kw.volatilityScore,
          regime: kw.volatilityRegime,
          sampleSize: kw.sampleSize,
        },
      });
    }
  }

  // Rule 2 — AI Overview instability (one observation per qualifying keyword)
  for (const kw of keywords) {
    if (kw.aiOverviewChurn >= AI_CHURN_THRESHOLD) {
      raw.push({
        type: "AI_OVERVIEW_INSTABILITY",
        keywordId: kw.keywordTargetId,
        description: `Keyword "${kw.query}" shows AI Overview churn (${kw.aiOverviewChurn} flips in window).`,
        evidence: {
          aiOverviewChurn: kw.aiOverviewChurn,
          aiOverviewComponent: kw.aiOverviewComponent,
        },
      });
    }
  }

  // Rule 3 — Project volatility spike (project-level, one observation max)
  if (
    summary.activeKeywordCount > 0 &&
    summary.alertRatio >= PROJECT_SPIKE_ALERT_RATIO
  ) {
    raw.push({
      type: "PROJECT_VOLATILITY_SPIKE",
      description: `${summary.alertKeywordCount} of ${summary.activeKeywordCount} active keywords exceed the alert threshold (${Math.round(summary.alertRatio * 100)}%).`,
      evidence: {
        alertKeywordCount: summary.alertKeywordCount,
        activeKeywordCount: summary.activeKeywordCount,
        alertRatio: summary.alertRatio,
        alertThreshold: summary.alertThreshold,
        averageVolatility: summary.averageVolatility,
      },
    });
  }

  // Rule 4 — High concentration risk (project-level, one observation max)
  if (
    summary.volatilityConcentrationRatio !== null &&
    summary.volatilityConcentrationRatio >= CONCENTRATION_HIGH
  ) {
    raw.push({
      type: "HIGH_VOLATILITY_CONCENTRATION",
      description: `Top-3 keywords account for ${Math.round(summary.volatilityConcentrationRatio * 100)}% of project volatility mass.`,
      evidence: {
        concentrationRatio: summary.volatilityConcentrationRatio,
      },
    });
  }

  // Rule 5 — No active keywords (project-level, one observation max)
  if (summary.activeKeywordCount === 0) {
    raw.push({
      type: "NO_ACTIVE_KEYWORDS",
      description: "No keywords have snapshot history. Capture snapshots to begin analysis.",
      evidence: { keywordCount: summary.keywordCount },
    });
  }

  // ── Deterministic sort: type ASC, keywordId ASC (undefined last), description ASC ──
  raw.sort((a, b) => {
    const typeCmp = a.type.localeCompare(b.type);
    if (typeCmp !== 0) return typeCmp;
    const aId = a.keywordId ?? "";
    const bId = b.keywordId ?? "";
    const idCmp = aId.localeCompare(bId);
    if (idCmp !== 0) return idCmp;
    return a.description.localeCompare(b.description);
  });

  return raw;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hypotheses
// Derived from the distribution of attribution components across keywords.
// One hypothesis per plausible cause. Deterministically sorted.
// ─────────────────────────────────────────────────────────────────────────────

function buildHypotheses(input: OperatorReasoningInput): Hypothesis[] {
  const { summary, keywords } = input;

  if (keywords.length === 0 || summary.averageVolatility === 0) return [];

  // Compute weighted mean of each component across active keywords
  let totalWeight = 0;
  let rankSum = 0;
  let aiSum = 0;
  let featureSum = 0;

  for (const kw of keywords) {
    const w = kw.sampleSize;
    totalWeight += w;
    rankSum    += kw.rankVolatilityComponent * w;
    aiSum      += kw.aiOverviewComponent * w;
    featureSum += kw.featureVolatilityComponent * w;
  }

  if (totalWeight === 0) return [];

  const rankMean    = rankSum    / totalWeight;
  const aiMean      = aiSum      / totalWeight;
  const featureMean = featureSum / totalWeight;
  const componentTotal = rankMean + aiMean + featureMean;

  if (componentTotal === 0) return [];

  const raw: Hypothesis[] = [];

  // SERP_RANKING_FLUX — rank-driven
  if (rankMean > 0) {
    const confidence = round2(clamp01(rankMean / componentTotal));
    raw.push({
      type: "SERP_RANKING_FLUX",
      confidence,
      explanation: `Rank movement is the dominant volatility driver across the project (weighted mean rank component: ${round2(rankMean)}).`,
    });
  }

  // SERP_GENERATIVE_EXPERIMENT — AI Overview-driven
  if (aiMean > 0) {
    const confidence = round2(clamp01(aiMean / componentTotal));
    raw.push({
      type: "SERP_GENERATIVE_EXPERIMENT",
      confidence,
      explanation: `AI Overview variability is contributing to project volatility (weighted mean AI component: ${round2(aiMean)}).`,
    });
  }

  // SERP_LAYOUT_SHIFT — feature-driven
  if (featureMean > 0) {
    const confidence = round2(clamp01(featureMean / componentTotal));
    raw.push({
      type: "SERP_LAYOUT_SHIFT",
      confidence,
      explanation: `SERP feature changes are contributing to project volatility (weighted mean feature component: ${round2(featureMean)}).`,
    });
  }

  // ── Deterministic sort: confidence DESC, type ASC ──
  raw.sort((a, b) => {
    if (b.confidence !== a.confidence) return b.confidence - a.confidence;
    return a.type.localeCompare(b.type);
  });

  return raw;
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommended Actions
// One action per qualifying trigger. Deterministically sorted.
// ─────────────────────────────────────────────────────────────────────────────

function buildRecommendedActions(input: OperatorReasoningInput): RecommendedAction[] {
  const { summary, keywords } = input;
  const raw: RecommendedAction[] = [];

  // Action per high-volatility keyword
  // Gate: match observation gate (summary.averageVolatility > 30) per SIL11-J
  for (const kw of keywords) {
    if (summary.averageVolatility > 30 && kw.volatilityScore > HIGH_VOLATILITY_THRESHOLD) {
      raw.push({
        type: "CAPTURE_MORE_SNAPSHOTS",
        keywordId: kw.keywordTargetId,
        rationale: `Keyword "${kw.query}" has high volatility (${kw.volatilityScore}). Increase snapshot frequency to improve signal quality.`,
      });
    }
  }

  // Action per AI churn keyword
  for (const kw of keywords) {
    if (kw.aiOverviewChurn >= AI_CHURN_THRESHOLD) {
      raw.push({
        type: "REVIEW_AI_OVERVIEW_STRATEGY",
        keywordId: kw.keywordTargetId,
        rationale: `Keyword "${kw.query}" has ${kw.aiOverviewChurn} AI Overview flips in window. Review content alignment with AI Overview eligibility.`,
      });
    }
  }

  // Project-wide action for high alert ratio
  if (
    summary.activeKeywordCount > 0 &&
    summary.alertRatio >= PROJECT_SPIKE_ALERT_RATIO
  ) {
    raw.push({
      type: "INVESTIGATE_SERP_EVENT",
      rationale: `${Math.round(summary.alertRatio * 100)}% of active keywords are in alert state. Investigate for a broad SERP event (algorithm update, layout change).`,
    });
  }

  // Project-wide action for high concentration
  if (
    summary.volatilityConcentrationRatio !== null &&
    summary.volatilityConcentrationRatio >= CONCENTRATION_HIGH
  ) {
    raw.push({
      type: "DIVERSIFY_KEYWORD_MONITORING",
      rationale: `Volatility is concentrated in top-3 keywords (${Math.round(summary.volatilityConcentrationRatio * 100)}%). Expand keyword targets to improve coverage.`,
    });
  }

  // Action for empty project
  if (summary.activeKeywordCount === 0 && summary.keywordCount > 0) {
    raw.push({
      type: "CAPTURE_INITIAL_SNAPSHOTS",
      rationale: "Keywords are registered but no snapshots have been captured. Capture initial snapshots to begin monitoring.",
    });
  }

  // ── Deterministic sort: type ASC, keywordId ASC (undefined last), rationale ASC ──
  raw.sort((a, b) => {
    const typeCmp = a.type.localeCompare(b.type);
    if (typeCmp !== 0) return typeCmp;
    const aId = a.keywordId ?? "";
    const bId = b.keywordId ?? "";
    const idCmp = aId.localeCompare(bId);
    if (idCmp !== 0) return idCmp;
    return a.rationale.localeCompare(b.rationale);
  });

  return raw;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * computeOperatorReasoning — pure function.
 *
 * Accepts pre-fetched, pre-computed project-level data and returns
 * fully structured reasoning output. No side effects. No I/O.
 * Deterministic: identical inputs always produce identical outputs.
 */
export function computeOperatorReasoning(
  input: OperatorReasoningInput
): OperatorReasoningOutput {
  return {
    observations:      buildObservations(input),
    hypotheses:        buildHypotheses(input),
    recommendedActions: buildRecommendedActions(input),
  };
}
