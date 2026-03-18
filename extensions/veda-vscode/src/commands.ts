/**
 * commands.ts — VEDA operator surface commands.
 *
 * Commands:
 * - veda.selectEnvironment — Switch active API environment
 * - veda.selectProject — Select active project from the API
 * - veda.showSerpWeather — Project-level SERP weather summary (Phase 1 surface C)
 * - veda.showKeywordVolatility — Focused keyword volatility diagnostic (Phase 1 surface D)
 * - veda.showKeywordOverview — Keyword picker → keyword overview diagnostic (Phase 1 surface E)
 * - veda.showProjectInvestigation — Project-level volatility investigation summary (Phase 1 surface F)
 *
 * All commands are read-only. No mutations. No local business logic.
 */

import * as vscode from "vscode";
import { apiGet } from "./api-client";
import {
  getEnvironments,
  getActiveEnvironment,
  setActiveEnvironment,
  getActiveProject,
  setActiveProject,
  type VedaEnvironment,
  type VedaProject,
} from "./state";

// ── Environment Selection ────────────────────────────────────────────────────

export async function selectEnvironment(): Promise<void> {
  const envs = getEnvironments();
  if (envs.length === 0) {
    vscode.window.showWarningMessage(
      "VEDA: No environments configured. Add environments in Settings → veda.environments."
    );
    return;
  }

  const active = getActiveEnvironment();
  const picked = await vscode.window.showQuickPick(
    envs.map((e) => ({
      label: e.name,
      description: e.baseUrl,
      detail: e.name === active?.name ? "● active" : undefined,
      env: e,
    })),
    { placeHolder: "Select VEDA API environment" }
  );

  if (picked) {
    setActiveEnvironment(picked.env);
    vscode.window.showInformationMessage(`VEDA: Environment set to ${picked.env.name} (${picked.env.baseUrl})`);
  }
}

// ── Project Selection ────────────────────────────────────────────────────────

export async function selectProject(): Promise<void> {
  const env = getActiveEnvironment();
  if (!env) {
    vscode.window.showWarningMessage("VEDA: Select an environment first.");
    return;
  }

  const result = await apiGet<VedaProject[]>("/api/projects");
  if (!result.ok || !result.data) {
    vscode.window.showErrorMessage(`VEDA: Failed to load projects — ${result.error}`);
    return;
  }

  const projects = result.data;
  if (projects.length === 0) {
    vscode.window.showInformationMessage("VEDA: No projects found in this environment.");
    return;
  }

  const active = getActiveProject();
  const picked = await vscode.window.showQuickPick(
    projects.map((p) => ({
      label: p.name,
      description: p.slug,
      detail: p.id === active?.id ? "● active" : undefined,
      project: p,
    })),
    { placeHolder: "Select active VEDA project" }
  );

  if (picked) {
    setActiveProject(picked.project);
    vscode.window.showInformationMessage(`VEDA: Project set to ${picked.project.name}`);
  }
}

// ── SERP Weather (Project-Level Read Surface) ────────────────────────────────

interface SerpWeatherSummary {
  projectId: string;
  windowDays?: number;
  weatherSummary?: {
    condition: string;
    score: number;
    volatilityTrend: string;
    activeFronts: number;
  };
  disturbanceCount?: number;
  alertCount?: number;
  [key: string]: unknown;
}

export async function showSerpWeather(): Promise<void> {
  const project = getActiveProject();
  if (!project) {
    vscode.window.showWarningMessage("VEDA: Select a project first (VEDA: Select Project).");
    return;
  }

  const env = getActiveEnvironment();
  const result = await apiGet<SerpWeatherSummary>(
    "/api/seo/serp-disturbances?include=weather,alerts&windowDays=7"
  );

  if (!result.ok || !result.data) {
    vscode.window.showErrorMessage(`VEDA: SERP weather failed — ${result.error}`);
    return;
  }

  const d = result.data;
  const panel = vscode.window.createWebviewPanel(
    "vedaSerpWeather",
    `SERP Weather — ${project.name}`,
    vscode.ViewColumn.Beside,
    { enableScripts: false }
  );

  const weather = d.weatherSummary;
  panel.webview.html = renderHtml(
    `SERP Weather — ${project.name}`,
    `<p class="context">Environment: ${escHtml(env?.name ?? "unknown")} · Project: ${escHtml(project.name)}</p>` +
    (weather
      ? `<table>
          <tr><th>Condition</th><td>${escHtml(weather.condition)}</td></tr>
          <tr><th>Score</th><td>${weather.score}</td></tr>
          <tr><th>Volatility Trend</th><td>${escHtml(weather.volatilityTrend)}</td></tr>
          <tr><th>Active Fronts</th><td>${weather.activeFronts}</td></tr>
        </table>`
      : "<p>No weather summary available for current window.</p>") +
    `<p>Disturbances: ${d.disturbanceCount ?? "—"} · Alerts: ${d.alertCount ?? "—"}</p>
     <p class="meta">Window: 7 days · Source: GET /api/seo/serp-disturbances</p>`
  );
}

// ── Keyword Volatility (Focused Diagnostic Read Surface) ─────────────────────

interface KeywordVolatility {
  keywordTargetId: string;
  query: string;
  locale: string;
  device: string;
  sampleSize: number;
  snapshotCount: number;
  volatilityScore: number;
  rankVolatilityComponent: number;
  aiOverviewComponent: number;
  featureVolatilityComponent: number;
  aiOverviewChurn: number;
  averageRankShift: number;
  maxRankShift: number;
  volatilityRegime: string;
  maturity: string;
  computedAt: string;
  [key: string]: unknown;
}

export async function showKeywordVolatility(): Promise<void> {
  const project = getActiveProject();
  if (!project) {
    vscode.window.showWarningMessage("VEDA: Select a project first.");
    return;
  }

  // Ask operator for keyword target ID
  const ktId = await vscode.window.showInputBox({
    prompt: "Enter KeywordTarget ID (UUID)",
    placeHolder: "e.g. a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    validateInput: (v) =>
      /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(v)
        ? null
        : "Must be a valid UUID",
  });

  if (!ktId) return;

  const env = getActiveEnvironment();
  const result = await apiGet<KeywordVolatility>(
    `/api/seo/keyword-targets/${ktId}/volatility`
  );

  if (!result.ok || !result.data) {
    if (result.status === 404) {
      vscode.window.showWarningMessage(`VEDA: KeywordTarget ${ktId} not found in this project.`);
    } else {
      vscode.window.showErrorMessage(`VEDA: Volatility fetch failed — ${result.error}`);
    }
    return;
  }

  const d = result.data;
  const panel = vscode.window.createWebviewPanel(
    "vedaKeywordVolatility",
    `Volatility — ${d.query}`,
    vscode.ViewColumn.Beside,
    { enableScripts: false }
  );

  panel.webview.html = renderHtml(
    `Keyword Volatility — ${escHtml(d.query)}`,
    `<p class="context">Environment: ${escHtml(env?.name ?? "unknown")} · Project: ${escHtml(project.name)}</p>
     <table>
       <tr><th>Query</th><td>${escHtml(d.query)}</td></tr>
       <tr><th>Locale / Device</th><td>${escHtml(d.locale)} / ${escHtml(d.device)}</td></tr>
       <tr><th>Volatility Score</th><td>${d.volatilityScore}</td></tr>
       <tr><th>Regime</th><td>${escHtml(d.volatilityRegime)}</td></tr>
       <tr><th>Maturity</th><td>${escHtml(d.maturity)}</td></tr>
       <tr><th>Sample Size</th><td>${d.sampleSize} (from ${d.snapshotCount} snapshots)</td></tr>
       <tr><th>Avg Rank Shift</th><td>${d.averageRankShift}</td></tr>
       <tr><th>Max Rank Shift</th><td>${d.maxRankShift}</td></tr>
       <tr><th>Rank Component</th><td>${d.rankVolatilityComponent}</td></tr>
       <tr><th>AI Overview Component</th><td>${d.aiOverviewComponent}</td></tr>
       <tr><th>Feature Component</th><td>${d.featureVolatilityComponent}</td></tr>
       <tr><th>AI Overview Churn</th><td>${d.aiOverviewChurn}</td></tr>
       <tr><th>Computed At</th><td>${escHtml(d.computedAt)}</td></tr>
     </table>
     <p class="meta">Source: GET /api/seo/keyword-targets/${escHtml(ktId)}/volatility</p>`
  );
}

// ── Keyword Picker → Overview (Phase 1 Surface E) ────────────────────────────
//
// Replaces manual UUID entry for the main keyword diagnostic flow.
// 1. Fetches keyword targets from GET /api/seo/keyword-targets
// 2. Shows QuickPick for selection
// 3. Fetches GET /api/seo/keyword-targets/{id}/overview
// 4. Renders bounded read-only overview panel
//
// Manual UUID entry (showKeywordVolatility) is retained as fallback.

interface KeywordTargetListItem {
  id: string;
  query: string;
  locale: string;
  device: string;
  isPrimary: boolean;
  intent: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

interface KeywordOverview {
  keywordTargetId: string;
  query: string;
  locale: string;
  device: string;
  snapshotCount: number;
  latestSnapshot: {
    id: string;
    capturedAt: string;
    rank: number | null;
    aiOverviewPresent: boolean;
    featureFamilies: string[];
  } | null;
  volatility: {
    score: number;
    regime: string;
    maturity: string;
    sampleSize: number;
    components: {
      rank: number;
      aiOverview: number;
      feature: number;
    };
  };
  classification: {
    changeType: string;
    confidence: number;
    reasoning: string;
  };
  intentDrift: {
    driftDetected: boolean;
    transitionCount: number;
  };
  featureVolatility: {
    familyCount: number;
    transitionCount: number;
  };
  domainDominance: {
    topDomains: Array<{ domain: string; count: number }>;
  };
  serpSimilarity: {
    averageSimilarity: number;
  };
  [key: string]: unknown;
}

export async function showKeywordOverview(): Promise<void> {
  const project = getActiveProject();
  if (!project) {
    vscode.window.showWarningMessage("VEDA: Select a project first (VEDA: Select Project).");
    return;
  }

  const env = getActiveEnvironment();

  // Step 1: Fetch keyword targets for this project
  const listResult = await apiGet<KeywordTargetListItem[]>(
    "/api/seo/keyword-targets?limit=200"
  );

  if (!listResult.ok || !listResult.data) {
    vscode.window.showErrorMessage(`VEDA: Failed to load keyword targets — ${listResult.error}`);
    return;
  }

  const targets = listResult.data;
  if (targets.length === 0) {
    vscode.window.showInformationMessage("VEDA: No keyword targets found for this project.");
    return;
  }

  // Step 2: QuickPick
  const picked = await vscode.window.showQuickPick(
    targets.map((t) => ({
      label: t.query,
      description: `${t.locale} / ${t.device}${t.isPrimary ? " ★" : ""}`,
      detail: t.intent ? `Intent: ${t.intent}` : undefined,
      target: t,
    })),
    { placeHolder: "Select a keyword target to view overview" }
  );

  if (!picked) return;

  // Step 3: Fetch overview
  const overviewResult = await apiGet<KeywordOverview>(
    `/api/seo/keyword-targets/${picked.target.id}/overview`
  );

  if (!overviewResult.ok || !overviewResult.data) {
    if (overviewResult.status === 404) {
      vscode.window.showWarningMessage("VEDA: Keyword target not found — may have been removed.");
    } else {
      vscode.window.showErrorMessage(`VEDA: Overview fetch failed — ${overviewResult.error}`);
    }
    return;
  }

  // Step 4: Render overview panel
  const d = overviewResult.data;
  const panel = vscode.window.createWebviewPanel(
    "vedaKeywordOverview",
    `Overview — ${d.query}`,
    vscode.ViewColumn.Beside,
    { enableScripts: false }
  );

  const latest = d.latestSnapshot;
  const vol = d.volatility;

  panel.webview.html = renderHtml(
    `Keyword Overview — ${escHtml(d.query)}`,
    `<p class="context">Environment: ${escHtml(env?.name ?? "unknown")} · Project: ${escHtml(project.name)}</p>

     <h2>Identity</h2>
     <table>
       <tr><th>Query</th><td>${escHtml(d.query)}</td></tr>
       <tr><th>Locale / Device</th><td>${escHtml(d.locale)} / ${escHtml(d.device)}</td></tr>
       <tr><th>Snapshots</th><td>${d.snapshotCount}</td></tr>
     </table>

     <h2>Volatility</h2>
     <table>
       <tr><th>Score</th><td>${vol.score}</td></tr>
       <tr><th>Regime</th><td>${escHtml(vol.regime)}</td></tr>
       <tr><th>Maturity</th><td>${escHtml(vol.maturity)}</td></tr>
       <tr><th>Sample Size</th><td>${vol.sampleSize}</td></tr>
       <tr><th>Rank Component</th><td>${vol.components.rank}</td></tr>
       <tr><th>AI Overview Component</th><td>${vol.components.aiOverview}</td></tr>
       <tr><th>Feature Component</th><td>${vol.components.feature}</td></tr>
     </table>

     <h2>Classification</h2>
     <table>
       <tr><th>Change Type</th><td>${escHtml(d.classification?.changeType ?? "—")}</td></tr>
       <tr><th>Confidence</th><td>${d.classification?.confidence ?? "—"}</td></tr>
       <tr><th>Reasoning</th><td>${escHtml(d.classification?.reasoning ?? "—")}</td></tr>
     </table>

     <h2>Signals</h2>
     <table>
       <tr><th>Intent Drift</th><td>${d.intentDrift?.driftDetected ? "Detected" : "None"} (${d.intentDrift?.transitionCount ?? 0} transitions)</td></tr>
       <tr><th>Feature Volatility</th><td>${d.featureVolatility?.familyCount ?? 0} families, ${d.featureVolatility?.transitionCount ?? 0} transitions</td></tr>
       <tr><th>SERP Similarity (avg)</th><td>${d.serpSimilarity?.averageSimilarity ?? "—"}</td></tr>
     </table>` +

    (latest
      ? `<h2>Latest Snapshot</h2>
         <table>
           <tr><th>Captured</th><td>${escHtml(latest.capturedAt)}</td></tr>
           <tr><th>Rank</th><td>${latest.rank ?? "—"}</td></tr>
           <tr><th>AI Overview</th><td>${latest.aiOverviewPresent ? "Present" : "Absent"}</td></tr>
           <tr><th>Feature Families</th><td>${latest.featureFamilies?.length ? escHtml(latest.featureFamilies.join(", ")) : "—"}</td></tr>
         </table>`
      : "<p>No snapshots available.</p>") +

    `<p class="meta">Source: GET /api/seo/keyword-targets/${escHtml(picked.target.id)}/overview</p>`
  );
}

// ── Project Investigation Summary (Phase 1 Surface F) ────────────────────────
//
// Calls GET /api/seo/volatility-summary?windowDays=7
// Renders bounded read-only project-level investigation summary.
// No client-side recomputation. No sidebar. No panel framework.

interface VolatilitySummary {
  windowDays: number | null;
  alertThreshold: number;
  alertKeywordCount: number;
  alertRatio: number;
  keywordCount: number;
  activeKeywordCount: number;
  averageVolatility: number;
  maxVolatility: number;
  highVolatilityCount: number;
  mediumVolatilityCount: number;
  lowVolatilityCount: number;
  stableCount: number;
  preliminaryCount: number;
  developingCount: number;
  stableCountByMaturity: number;
  weightedProjectVolatilityScore: number;
  volatilityConcentrationRatio: number | null;
  top3RiskKeywords: Array<{
    keywordTargetId: string;
    query: string;
    volatilityScore: number;
    volatilityRegime: string;
    volatilityMaturity: string;
    exceedsThreshold: boolean;
  }>;
}

export async function showProjectInvestigation(): Promise<void> {
  const project = getActiveProject();
  if (!project) {
    vscode.window.showWarningMessage("VEDA: Select a project first (VEDA: Select Project).");
    return;
  }

  const env = getActiveEnvironment();
  const result = await apiGet<VolatilitySummary>(
    "/api/seo/volatility-summary?windowDays=7"
  );

  if (!result.ok || !result.data) {
    vscode.window.showErrorMessage(`VEDA: Project investigation failed — ${result.error}`);
    return;
  }

  const d = result.data;
  const panel = vscode.window.createWebviewPanel(
    "vedaProjectInvestigation",
    `Investigation — ${project.name}`,
    vscode.ViewColumn.Beside,
    { enableScripts: false }
  );

  const top3Html = d.top3RiskKeywords.length > 0
    ? `<table>
        <tr><th>Query</th><th>Score</th><th>Regime</th><th>Maturity</th><th>Alert</th></tr>
        ${d.top3RiskKeywords.map((k) =>
          `<tr>
            <td>${escHtml(k.query)}</td>
            <td>${k.volatilityScore}</td>
            <td>${escHtml(k.volatilityRegime)}</td>
            <td>${escHtml(k.volatilityMaturity)}</td>
            <td>${k.exceedsThreshold ? "⚠" : "—"}</td>
          </tr>`
        ).join("")}
       </table>`
    : "<p>No active risk keywords.</p>";

  panel.webview.html = renderHtml(
    `Project Investigation — ${escHtml(project.name)}`,
    `<p class="context">Environment: ${escHtml(env?.name ?? "unknown")} · Project: ${escHtml(project.name)}</p>

     <h2>Project Summary</h2>
     <table>
       <tr><th>Window</th><td>${d.windowDays ?? "all time"} days</td></tr>
       <tr><th>Keywords (total)</th><td>${d.keywordCount}</td></tr>
       <tr><th>Keywords (active)</th><td>${d.activeKeywordCount}</td></tr>
       <tr><th>Average Volatility</th><td>${d.averageVolatility}</td></tr>
       <tr><th>Max Volatility</th><td>${d.maxVolatility}</td></tr>
       <tr><th>Weighted Score</th><td>${d.weightedProjectVolatilityScore}</td></tr>
     </table>

     <h2>Volatility Distribution</h2>
     <table>
       <tr><th>High (≥60)</th><td>${d.highVolatilityCount}</td></tr>
       <tr><th>Medium (≥30)</th><td>${d.mediumVolatilityCount}</td></tr>
       <tr><th>Low (≥1)</th><td>${d.lowVolatilityCount}</td></tr>
       <tr><th>Stable (0)</th><td>${d.stableCount}</td></tr>
     </table>

     <h2>Maturity Distribution</h2>
     <table>
       <tr><th>Preliminary</th><td>${d.preliminaryCount}</td></tr>
       <tr><th>Developing</th><td>${d.developingCount}</td></tr>
       <tr><th>Stable</th><td>${d.stableCountByMaturity}</td></tr>
     </table>

     <h2>Alerts</h2>
     <table>
       <tr><th>Alert Threshold</th><td>${d.alertThreshold}</td></tr>
       <tr><th>Alert Keywords</th><td>${d.alertKeywordCount}</td></tr>
       <tr><th>Alert Ratio</th><td>${d.alertRatio}</td></tr>
       <tr><th>Concentration Ratio</th><td>${d.volatilityConcentrationRatio ?? "—"}</td></tr>
     </table>

     <h2>Top 3 Risk Keywords</h2>
     ${top3Html}

     <p class="meta">Source: GET /api/seo/volatility-summary?windowDays=7</p>`
  );
}

// ── HTML Helpers ──────────────────────────────────────────────────────────────

function escHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function renderHtml(title: string, body: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${escHtml(title)}</title>
  <style>
    body { font-family: var(--vscode-font-family, sans-serif); padding: 16px; color: var(--vscode-foreground); background: var(--vscode-editor-background); }
    h1 { font-size: 1.3em; margin: 0 0 12px 0; }
    h2 { font-size: 1.1em; margin: 20px 0 8px 0; opacity: 0.9; }
    table { border-collapse: collapse; width: 100%; margin: 12px 0; }
    th, td { text-align: left; padding: 6px 12px; border-bottom: 1px solid var(--vscode-panel-border, #333); }
    th { width: 180px; opacity: 0.8; }
    .context { font-size: 0.85em; opacity: 0.7; margin-bottom: 8px; }
    .meta { font-size: 0.8em; opacity: 0.5; margin-top: 16px; }
  </style>
</head>
<body>
  <h1>${title}</h1>
  ${body}
</body>
</html>`;
}
