// Ports NetworkRequestManagerValidationTests, plus the subrequest budget the Worker adds.

import { http, HttpResponse } from "msw";
import { describe, expect, it } from "vitest";
import { Http, MAX_SUBREQUESTS, validateJSONResponse } from "../src/http.ts";
import { network } from "./network.ts";

describe("validateJSONResponse", () => {
	it("accepts 200 with a JSON content type", () => {
		expect(validateJSONResponse(200, "application/json")).toBeUndefined();
	});

	it("accepts the rest of the 2xx range", () => {
		for (const status of [201, 204, 299]) expect(validateJSONResponse(status, "application/json")).toBeUndefined();
	});

	it("fails non-2xx statuses with non200StatusCode", () => {
		for (const status of [400, 404, 500, 199, 300]) {
			expect(validateJSONResponse(status, "application/json")).toBe("non200StatusCode");
		}
	});

	it("fails a 2xx non-JSON MIME type with nonJsonResponse", () => {
		expect(validateJSONResponse(200, "text/html")).toBe("nonJsonResponse");
	});

	it("fails a 2xx with no content type with nonJsonResponse", () => {
		expect(validateJSONResponse(200, null)).toBe("nonJsonResponse");
	});

	it("checks the status before the content type", () => {
		expect(validateJSONResponse(404, "text/html")).toBe("non200StatusCode");
	});
});

describe("Http", () => {
	it("follows redirects itself, counting each hop", async () => {
		network.use(
			http.head("https://a.example/start", () => new Response(null, { status: 302, headers: { location: "/next" } })),
			http.head("https://a.example/next", () => new Response(null, { status: 301, headers: { location: "https://b.example/end" } })),
			http.head("https://b.example/end", () => new Response(null, { status: 200 })),
		);

		const client = new Http();
		expect(await client.headStatus("https://a.example/start")).toBe(200);
		expect(client.subrequests).toBe(3);
	});

	it("never makes more than the Free plan's 50 subrequests in one invocation", async () => {
		let hops = 0;
		network.use(
			http.head("https://loop.example/:n", ({ params }) => {
				hops++;
				return new Response(null, { status: 302, headers: { location: `/${Number(params.n) + 1}` } });
			}),
		);

		const client = new Http();
		const statuses = [];
		for (let i = 0; i < 5; i++) statuses.push(await client.headStatus(`https://loop.example/${i * 100}`));

		expect(statuses).toEqual([0, 0, 0, 0, 0]);
		expect(hops).toBe(MAX_SUBREQUESTS);
		expect(client.subrequests).toBe(MAX_SUBREQUESTS);
	});
});
