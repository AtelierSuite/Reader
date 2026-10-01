import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      main: "./src/index.ts",
      miniflare: {
        compatibilityDate: "2026-08-22",
        durableObjects: { DEVICE: { className: "Device", useSQLite: true } },
        bindings: {
          APPLE_TEAM_ID: "TEAMTEAM99",
          APP_BUNDLE_ID: "com.tsubuzaki.SakuraRSS",
          APP_ATTEST_ENVIRONMENT: "development",
          TOKENS_PER_MINUTE: "2000",
          CHALLENGE_SECRET: "test-secret",
          JEV_API_KEY: "jev-test",
        },
      },
    }),
  ],
});
