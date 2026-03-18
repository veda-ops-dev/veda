/**
 * state.ts — Lightweight session state for the VEDA operator surface.
 *
 * Holds only:
 * - active environment (name + base URL)
 * - active project (id + name)
 *
 * This is NOT a local database, offline mirror, or hidden mutation queue.
 * It is continuity infrastructure for the current editor session.
 */

import * as vscode from "vscode";

export interface VedaEnvironment {
  name: string;
  baseUrl: string;
}

export interface VedaProject {
  id: string;
  name: string;
  slug: string;
}

let activeEnvironment: VedaEnvironment | null = null;
let activeProject: VedaProject | null = null;

const stateChangedEmitter = new vscode.EventEmitter<void>();
export const onStateChanged = stateChangedEmitter.event;

// ── Environment ──────────────────────────────────────────────────────────────

export function getEnvironments(): VedaEnvironment[] {
  const config = vscode.workspace.getConfiguration("veda");
  const envs = config.get<VedaEnvironment[]>("environments") ?? [];
  return envs.filter((e) => e.name && e.baseUrl);
}

export function getActiveEnvironment(): VedaEnvironment | null {
  if (activeEnvironment) return activeEnvironment;
  const envs = getEnvironments();
  const activeName = vscode.workspace
    .getConfiguration("veda")
    .get<string>("activeEnvironment");
  return envs.find((e) => e.name === activeName) ?? envs[0] ?? null;
}

export function setActiveEnvironment(env: VedaEnvironment): void {
  activeEnvironment = env;
  activeProject = null; // project context is environment-scoped
  stateChangedEmitter.fire();
}

// ── Project ──────────────────────────────────────────────────────────────────

export function getActiveProject(): VedaProject | null {
  return activeProject;
}

export function setActiveProject(project: VedaProject): void {
  activeProject = project;
  stateChangedEmitter.fire();
}

export function clearProject(): void {
  activeProject = null;
  stateChangedEmitter.fire();
}
