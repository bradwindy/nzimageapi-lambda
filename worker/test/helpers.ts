import { http, HttpResponse } from "msw";
import { type ApiEnv, createContext, type RequestContext } from "../src/context.ts";
import type { NZImage } from "../src/models.ts";

export const TEST_ENV: ApiEnv = {
	DIGITALNZ_API_KEY: "test-digitalnz-key",
	API_CLIENT_SECRETS: "site:AbC123,mobile:XyZ789",
	CONVERTER_SIGNING_KEY: "test-signing-key-for-unit-tests",
	JP2_CONVERTER_URL: "https://converter.example.com",
};

export function makeRecord(fields: Partial<NZImage> = {}): NZImage {
	return { id: 1, title: "Title", description: "Description", display_collection: "Some Collection", ...fields };
}

export interface TestContext extends RequestContext {
	messages: string[];
}

export function testContext(env: ApiEnv = TEST_ENV): TestContext {
	const messages: string[] = [];
	return { ...createContext(env, (message) => messages.push(message)), messages };
}

export const DIGITALNZ_ENDPOINT = "https://api.digitalnz.org/records.json";

/**
 * Answers both DigitalNZ requests: the `per_page=0` count request with `resultCount` and no
 * results, the page request with `results`.
 */
export function digitalNZ(resultCount: number, results: unknown[]) {
	return http.get(DIGITALNZ_ENDPOINT, ({ request }) => {
		const perPage = Number(new URL(request.url).searchParams.get("per_page"));
		return HttpResponse.json({
			search: { result_count: resultCount, results: perPage === 0 ? [] : results },
		});
	});
}
