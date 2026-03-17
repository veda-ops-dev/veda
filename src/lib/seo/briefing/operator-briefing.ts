/**
 * operator-briefing.ts -- Operator Briefing Packet (pure library)
 *
 * Pure function module. No DB. No Prisma. No Date.now(). No random. No I/O.
 * All outputs are deterministic given the same inputs.
 *
 * Exports:
 *   BriefingAlertItem        -- shape of one top-alert entry
 *   BriefingDeltaItem        -- shape of one delta entry (optional section)
 *   RiskAttributionSummary   -- project-level attribution percentages
 *   BriefingInput            -- full input to buildOperatorBriefingPromptText()
 *   buildOperatorBriefingPromptText() -- pure function -> stable promptText string
 *
 * promptText contract:
 *   - Stable for identical inputs (no wall-clock data, no computedAt).
 *   - Contains sections: SYSTEM RULES, PROJECT SUMMARY, TOP ALERTS,
 *     OPERATOR REASONING (SIL-11), TASK FOR CLAUDE.
 *   - Instructs LLM to return proposal JSON only; states no changes applied.
 */

import type {
  Observation,
  Hypothesis,
  RecommendedAction,
} from "@/lib/seo/reasoning/operator-reasoning";

// -----------------------------------------------------------------------------
// Exported types
// -----------------------------------------------------------------------------

export interface BriefingProjectSummary {
  keywordCount: number;
  activeKeywordCount: number;
  averageVolatility: number;
  maxVolatility: number;
  alertKeywordCount: number;
  alertRatio: number;
  alertThreshold: number;
  weightedProjectVolatilityScore: number;
  volatilityConcentrationRatio: number | null;
}

export interface BriefingAlertItem {
  keywordTargetId: string;
  query: string;
  locale: string;
  device: string;
  volatilityScore: number;
  volatilityRegime: string;
  sampleSize: number;
  rankVolatilityComponent: number;
  aiOverviewComponent: number;
  featureVolatilityComponent: number;
}

export interface BriefingDeltaItem {
  keywordTargetId: string;
  query: string;
  /** ISO timestamp of the newer snapshot -- for traceability, not wall-clock */
  toSnapshotCapturedAt: string;
  enteredCount: number;
  exitedCount: number;
  movedCount: number;
  aiOverviewFlipped: boolean;
}

export interface RiskAttributionSummary {
  rankPercent: number | null;
  aiPercent: number | null;
  featurePercent: number | null;
}

export interface BriefingOperatorReasoning {
  observations: Observation[];
  hypotheses: Hypothesis[];
  recommendedActions: RecommendedAction[];
}

export interface BriefingInput {
  projectId: string;
  windowDays: number;
  alertThreshold: number;
  summary: BriefingProjectSummary;
  topAlerts: BriefingAlertItem[];
  riskAttributionSummary: RiskAttributionSummary | null;
  operatorReasoning: BriefingOperatorReasoning;
  /** Empty array when limitDeltas=0 */
  deltas: BriefingDeltaItem[];
}

// -----------------------------------------------------------------------------
// Internal rendering helpers
// -----------------------------------------------------------------------------

function pct(ratio: number | null): string {
  if (ratio === null) return "N/A";
  return `${(ratio * 100).toFixed(1)}%`;
}

function renderSummarySection(
  s: BriefingProjectSummary,
  windowDays: number,
  alertThreshold: number
): string {
  const concRatio =
    s.volatilityConcentrationRatio !== null
      ? `${(s.volatilityConcentrationRatio * 100).toFixed(1)}%`
      : "N/A";

  return [
    `## PROJECT SUMMARY`,
    `Window: ${windowDays} days | Alert threshold: ${alertThreshold}`,
    `Keywords total: ${s.keywordCount} | Active (with data): ${s.activeKeywordCount}`,
    `Average volatility: ${s.averageVolatility} | Max volatility: ${s.maxVolatility}`,
    `Weighted project score: ${s.weightedProjectVolatilityScore}`,
    `Alert keywords: ${s.alertKeywordCount} of ${s.activeKeywordCount} active (${pct(s.alertRatio)})`,
    `Volatility concentration (top-3 share): ${concRatio}`,
  ].join("\n");
}

function renderAlertsSection(alerts: BriefingAlertItem[]): string {
  if (alerts.length === 0) {
    return `## TOP ALERTS\nNo keywords currently exceed the alert threshold.`;
  }

  const rows = alerts.map((a, i) =>
    [
      `  ${i + 1}. "${a.query}" [${a.locale}/${a.device}]`,
      `     Score: ${a.volatilityScore} | Regime: ${a.volatilityRegime} | Samples: ${a.sampleSize}`,
      `     Components -- Rank: ${a.rankVolatilityComponent} | AI: ${a.aiOverviewComponent} | Feature: ${a.featureVolatilityComponent}`,
      `     ID: ${a.keywordTargetId}`,
    ].join("\n")
  );

  return [`## TOP ALERTS (${alerts.length})`, ...rows].join("\n");
}

function renderRiskAttributionSection(r: RiskAttributionSummary | null): string {
  if (r === null) {
    return `## RISK ATTRIBUTION\nInsufficient data to compute attribution for this window.`;
  }
  return [
    `## RISK ATTRIBUTION`,
    `Rank-driven: ${r.rankPercent !== null ? `${r.rankPercent}%` : "N/A"}`,
    `AI Overview-driven: ${r.aiPercent !== null ? `${r.aiPercent}%` : "N/A"}`,
    `Feature-driven: ${r.featurePercent !== null ? `${r.featurePercent}%` : "N/A"}`,
  ].join("\n");
}

function renderDeltasSection(deltas: BriefingDeltaItem[]): string {
  if (deltas.length === 0) return "";

  const rows = deltas.map((d, i) =>
    [
      `  ${i + 1}. "${d.query}" -- snapshot at ${d.toSnapshotCapturedAt}`,
      `     Entered: ${d.enteredCount} | Exited: ${d.exitedCount} | Moved: ${d.movedCount} | AI flip: ${d.aiOverviewFlipped ? "YES" : "no"}`,
      `     ID: ${d.keywordTargetId}`,
    ].join("\n")
  );

  return [`## RECENT SERP DELTAS (${deltas.length})`, ...rows].join("\n");
}

function renderObservations(obs: Observation[]): string {
  if (obs.length === 0) return "  (none)";
  return obs
    .map((o, i) => {
      const kw = o.keywordId ? ` [kw:${o.keywordId}]` : "";
      return `  ${i + 1}. [${o.type}]${kw} ${o.description}`;
    })
    .join("\n");
}

function renderHypotheses(hyp: Hypothesis[]): string {
  if (hyp.length === 0) return "  (none)";
  return hyp
    .map(
      (h, i) =>
        `  ${i + 1}. [${h.type}] confidence=${h.confidence} -- ${h.explanation}`
    )
    .join("\n");
}

function renderActions(actions: RecommendedAction[]): string {
  if (actions.length === 0) return "  (none)";
  return actions
    .map((a, i) => {
      const kw = a.keywordId ? ` [kw:${a.keywordId}]` : "";
      return `  ${i + 1}. [${a.type}]${kw} ${a.rationale}`;
    })
    .join("\n");
}

function renderReasoningSection(r: BriefingOperatorReasoning): string {
  return [
    `## OPERATOR REASONING (SIL-11)`,
    ``,
    `### Observations`,
    renderObservations(r.observations),
    ``,
    `### Hypotheses`,
    renderHypotheses(r.hypotheses),
    ``,
    `### Recommended Actions`,
    renderActions(r.recommendedActions),
  ].join("\n");
}

// -----------------------------------------------------------------------------
// Public entry point
// -----------------------------------------------------------------------------

/**
 * buildOperatorBriefingPromptText -- pure function.
 *
 * Renders a stable, deterministic prompt string from pre-computed briefing data.
 * No timestamps. No wall-clock data. No computedAt. Identical inputs -> identical output.
 *
 * The prompt instructs the LLM to:
 *   - Return a JSON proposal only (observations / hypotheses / recommendedActions).
 *   - Make no changes and apply no mutations.
 *   - Treat all content as read-only diagnostic context.
 */
export function buildOperatorBriefingPromptText(input: BriefingInput): string {
  const deltasSection = renderDeltasSection(input.deltas);

  const sections: string[] = [
    `## SYSTEM RULES (NO MUTATIONS)`,
    `You are a read-only SEO intelligence assistant operating on the VEDA observability platform.`,
    `CONSTRAINTS (follow without exception):`,
    `  - You MUST NOT apply any changes, write any data, or modify any state.`,
    `  - You MUST NOT call any write endpoints or suggest state mutations.`,
    `  - All analysis is diagnostic only. No changes are applied.`,
    `  - Your output MUST be a JSON object only. No prose. No markdown outside the JSON.`,
    ``,
    renderSummarySection(input.summary, input.windowDays, input.alertThreshold),
    ``,
    renderAlertsSection(input.topAlerts),
    ``,
    renderRiskAttributionSection(input.riskAttributionSummary),
  ];

  if (deltasSection) {
    sections.push(``, deltasSection);
  }

  sections.push(
    ``,
    renderReasoningSection(input.operatorReasoning),
    ``,
    `## TASK FOR CLAUDE`,
    `Based on the diagnostic data above, return a JSON proposal object with this exact schema:`,
    ``,
    `{`,
    `  "observations": [`,
    `    { "type": string, "keywordId": string | null, "description": string }`,
    `  ],`,
    `  "hypotheses": [`,
    `    { "type": string, "confidence": number, "explanation": string }`,
    `  ],`,
    `  "recommendedActions": [`,
    `    { "type": string, "keywordId": string | null, "rationale": string }`,
    `  ]`,
    `}`,
    ``,
    `Rules for your response:`,
    `  - Output valid JSON only. No prose before or after.`,
    `  - No changes are applied. This is a proposal only.`,
    `  - Do not invent data not present in the briefing above.`,
    `  - Confidence values must be numbers in [0, 1].`,
    `  - If no actionable signal exists, return empty arrays.`,
    `  - projectId: ${input.projectId}`
  );

  return sections.join("\n");
}
