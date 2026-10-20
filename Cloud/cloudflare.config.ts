import { bindings, defineConfig, exports } from "cf/config";

export default defineConfig((ctx) => ({
	worker: {
		name: "sakura-cloud",
		compatibilityDate: "2026-08-22",
		entrypoint: "src/index.ts",
		observability: {
			enabled: true,
		},
		exports: {
			Device: exports.durableObject({ storage: "sqlite" }),
		},
		env: {
			APPLE_TEAM_ID: bindings.text("YYM4Z6MU8F"),
			APP_BUNDLE_ID: bindings.text("com.tsubuzaki.SakuraRSS"),
			APP_ATTEST_ENVIRONMENT: bindings.text(ctx.mode === "development" ? "development" : "production"),
			TOKENS_PER_MINUTE: bindings.text("20000"),
			AI: bindings.ai(),
			DEVICE: bindings.durableObject({
				worker: "sakura-cloud",
				exportName: "Device",
			}),
		},
	},
}));
