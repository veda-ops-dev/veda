/**
 * extension.ts — VEDA VS Code Operator Surface entry point.
 *
 * This is a Phase 1 successor surface per:
 * - docs/systems/operator-surfaces/vscode/phase-1-spec.md
 * - docs/ROADMAP.md Phase 6
 *
 * Invariants:
 * - Thin client: all data comes from VEDA API, no direct DB access
 * - Read-only: no mutations, no hidden writes
 * - Explicit context: environment and project always visible
 * - No local business logic: the extension renders, it does not compute
 */

import * as vscode from "vscode";
import {
  selectEnvironment,
  selectProject,
  showSerpWeather,
  showKeywordVolatility,
  showKeywordOverview,
  showProjectInvestigation,
} from "./commands";
import { createStatusBarItems } from "./status-bar";

export function activate(context: vscode.ExtensionContext): void {
  // Register commands
  context.subscriptions.push(
    vscode.commands.registerCommand("veda.selectEnvironment", selectEnvironment),
    vscode.commands.registerCommand("veda.selectProject", selectProject),
    vscode.commands.registerCommand("veda.showSerpWeather", showSerpWeather),
    vscode.commands.registerCommand("veda.showKeywordVolatility", showKeywordVolatility),
    vscode.commands.registerCommand("veda.showKeywordOverview", showKeywordOverview),
    vscode.commands.registerCommand("veda.showProjectInvestigation", showProjectInvestigation)
  );

  // Status bar context indicators
  context.subscriptions.push(...createStatusBarItems());
}

export function deactivate(): void {
  // Intentionally empty — no background processes, no polling, no cleanup needed
}
