"use strict";
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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onStateChanged = void 0;
exports.getEnvironments = getEnvironments;
exports.getActiveEnvironment = getActiveEnvironment;
exports.setActiveEnvironment = setActiveEnvironment;
exports.getActiveProject = getActiveProject;
exports.setActiveProject = setActiveProject;
exports.clearProject = clearProject;
const vscode = __importStar(require("vscode"));
let activeEnvironment = null;
let activeProject = null;
const stateChangedEmitter = new vscode.EventEmitter();
exports.onStateChanged = stateChangedEmitter.event;
// ── Environment ──────────────────────────────────────────────────────────────
function getEnvironments() {
    const config = vscode.workspace.getConfiguration("veda");
    const envs = config.get("environments") ?? [];
    return envs.filter((e) => e.name && e.baseUrl);
}
function getActiveEnvironment() {
    if (activeEnvironment)
        return activeEnvironment;
    const envs = getEnvironments();
    const activeName = vscode.workspace
        .getConfiguration("veda")
        .get("activeEnvironment");
    return envs.find((e) => e.name === activeName) ?? envs[0] ?? null;
}
function setActiveEnvironment(env) {
    activeEnvironment = env;
    activeProject = null; // project context is environment-scoped
    stateChangedEmitter.fire();
}
// ── Project ──────────────────────────────────────────────────────────────────
function getActiveProject() {
    return activeProject;
}
function setActiveProject(project) {
    activeProject = project;
    stateChangedEmitter.fire();
}
function clearProject() {
    activeProject = null;
    stateChangedEmitter.fire();
}
//# sourceMappingURL=state.js.map