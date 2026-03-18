"use strict";
/**
 * status-bar.ts — Status bar items for environment and project context.
 *
 * Per Phase 1 spec: "the operator should never have to guess which environment
 * they are using or which project is active."
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
exports.createStatusBarItems = createStatusBarItems;
const vscode = __importStar(require("vscode"));
const state_1 = require("./state");
let envItem;
let projectItem;
function createStatusBarItems() {
    envItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
    envItem.command = "veda.selectEnvironment";
    envItem.tooltip = "VEDA: Click to switch environment";
    projectItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 99);
    projectItem.command = "veda.selectProject";
    projectItem.tooltip = "VEDA: Click to switch project";
    updateStatusBar();
    const sub = (0, state_1.onStateChanged)(() => updateStatusBar());
    envItem.show();
    projectItem.show();
    return [envItem, projectItem, sub];
}
function updateStatusBar() {
    const env = (0, state_1.getActiveEnvironment)();
    envItem.text = env ? `$(server) ${env.name}` : "$(server) VEDA: No Env";
    const project = (0, state_1.getActiveProject)();
    projectItem.text = project ? `$(project) ${project.name}` : "$(project) No Project";
}
//# sourceMappingURL=status-bar.js.map