"use strict";
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
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const commands_1 = require("./commands");
const status_bar_1 = require("./status-bar");
function activate(context) {
    // Register commands
    context.subscriptions.push(vscode.commands.registerCommand("veda.selectEnvironment", commands_1.selectEnvironment), vscode.commands.registerCommand("veda.selectProject", commands_1.selectProject), vscode.commands.registerCommand("veda.showSerpWeather", commands_1.showSerpWeather), vscode.commands.registerCommand("veda.showKeywordVolatility", commands_1.showKeywordVolatility), vscode.commands.registerCommand("veda.showKeywordOverview", commands_1.showKeywordOverview), vscode.commands.registerCommand("veda.showProjectInvestigation", commands_1.showProjectInvestigation));
    // Status bar context indicators
    context.subscriptions.push(...(0, status_bar_1.createStatusBarItems)());
}
function deactivate() {
    // Intentionally empty — no background processes, no polling, no cleanup needed
}
//# sourceMappingURL=extension.js.map