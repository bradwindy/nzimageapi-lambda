import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
	plugins: [
		cloudflareTest({
			wrangler: { configPath: "./wrangler.jsonc" },
			miniflare: {
				bindings: {
					DIGITALNZ_API_KEY: "test-digitalnz-key",
					API_CLIENT_SECRETS: "site:AbC123,mobile:XyZ789",
					CONVERTER_SIGNING_KEY: "test-signing-key-for-unit-tests",
					JP2_CONVERTER_URL: "https://converter.example.com",
				},
			},
		}),
	],
	test: {
		setupFiles: ["test/setup.ts"],
	},
});
