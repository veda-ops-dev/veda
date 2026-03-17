import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",

    // VEDA repo ignores:
    // MCP tools are maintained as a separate subsystem and are not held
    // to the core app's no-`any` lint invariants.
    "mcp/**",
  ]),
]);

export default eslintConfig;
