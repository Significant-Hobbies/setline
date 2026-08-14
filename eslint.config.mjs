import { defineConfig, globalIgnores } from "eslint/config";

const eslintConfig = defineConfig([
  globalIgnores([
    "dist/**",
    "node_modules/**",
    "worker-configuration.d.ts",
    "worker/agent-edge.d.mts",
  ]),
]);

export default eslintConfig;
