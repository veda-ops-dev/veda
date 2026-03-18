/**
 * status-bar.ts — Status bar items for environment and project context.
 *
 * Per Phase 1 spec: "the operator should never have to guess which environment
 * they are using or which project is active."
 */

import * as vscode from "vscode";
import { getActiveEnvironment, getActiveProject, onStateChanged } from "./state";

let envItem: vscode.StatusBarItem;
let projectItem: vscode.StatusBarItem;

export function createStatusBarItems(): vscode.Disposable[] {
  envItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
  envItem.command = "veda.selectEnvironment";
  envItem.tooltip = "VEDA: Click to switch environment";

  projectItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 99);
  projectItem.command = "veda.selectProject";
  projectItem.tooltip = "VEDA: Click to switch project";

  updateStatusBar();

  const sub = onStateChanged(() => updateStatusBar());

  envItem.show();
  projectItem.show();

  return [envItem, projectItem, sub];
}

function updateStatusBar(): void {
  const env = getActiveEnvironment();
  envItem.text = env ? `$(server) ${env.name}` : "$(server) VEDA: No Env";

  const project = getActiveProject();
  projectItem.text = project ? `$(project) ${project.name}` : "$(project) No Project";
}
