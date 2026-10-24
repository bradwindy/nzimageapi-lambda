// HTTP routing, auth and response bodies, and the RPC entrypoint.

import { env, exports } from "cloudflare:workers";
import { http, HttpResponse } from "msw";
import { describe, expect, it } from "vitest";
import { collectionNames } from "../src/collections.ts";
import worker, { excludeList } from "../src/index.ts";
import { DIGITALNZ_ENDPOINT, digitalNZ } from "./helpers.ts";
import { network } from "./network.ts";

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

function call(path: string, init: { method?: string; headers?: Record<string, string> } = {}, bindings: Env = env) {
	return worker.fetch(new IncomingRequest(`https://nzimages-api.iolab.nz${path}`, init), bindings);
}

const authorized = { headers: { secret: "AbC123" } };

// Keys out of order, nulls, and a field the API does not return.
const canterburyRecord = {
	display_collection: "Canterbury Museum",
	category: ["Images"],
	id: 123,
	title: "A title",
	description: null,
	thumbnail_url: "https://example.com/t.jpg",
	large_thumbnail_url: "https://example.com/path/large/i.jpg",
	object_url: null,
	landing_url: "https://example.com/item/1",
	creator: ["Someone"],
	date: [],
	subject: null,
};

const canterburyBody =
	'{"id":123,"title":"A title","thumbnail_url":"https://example.com/t.jpg",' +
	'"large_thumbnail_url":"https://example.com/path/xlarge/i.jpg","display_collection":"Canterbury Museum",' +
	'"landing_url":"https://example.com/item/1","creator":["Someone"],"date":[]}';

describe("routing", () => {
	it("returns API Gateway's 404 for other routes, before the secret check", async () => {
		for (const [path, method] of [
			["/", "GET"],
			["/image/", "GET"],
			["/image", "POST"],
			["/collections", "HEAD"],
		] as const) {
			const response = await call(path, { method });
			expect(response.status, `${method} ${path}`).toBe(404);
			if (method !== "HEAD") expect(await response.json()).toEqual({ message: "Not Found" });
		}
	});
});

describe("auth", () => {
	it("returns 500 when API_CLIENT_SECRETS is empty", async () => {
		const response = await call("/image", authorized, { ...env, API_CLIENT_SECRETS: "" });
		expect(response.status).toBe(500);
	});

	it("returns 401 without a secret header", async () => {
		expect((await call("/collections")).status).toBe(401);
	});

	it("returns 401 for a wrong secret", async () => {
		expect((await call("/image", { headers: { secret: "AbC1234" } })).status).toBe(401);
	});
});

describe("GET /collections", () => {
	it("returns the collection names as JSON", async () => {
		const response = await call("/collections", { headers: { secret: "XyZ789" } });
		expect(response.status).toBe(200);
		expect(response.headers.get("content-type")).toBe("application/json");
		expect(await response.json()).toEqual(collectionNames());
	});
});

describe("GET /image", () => {
	it("returns the record as Swift's JSONEncoder would, using collection over exclude", async () => {
		let apiKey: string | null = null;
		const queries: string[] = [];
		network.use(
			http.get(DIGITALNZ_ENDPOINT, ({ request }) => {
				const url = new URL(request.url);
				apiKey = request.headers.get("authentication-token");
				queries.push(url.search);
				const perPage = url.searchParams.get("per_page");
				return HttpResponse.json({ search: { result_count: 1, results: perPage === "0" ? [] : [canterburyRecord] } });
			}),
		);

		const response = await call("/image?collection=Canterbury%20Museum&exclude=Canterbury%20Museum", authorized);

		expect(response.status).toBe(200);
		expect(response.headers.get("content-type")).toBe("application/json");
		expect(await response.text()).toBe(canterburyBody);
		expect(apiKey).toBe("test-digitalnz-key");
		expect(queries).toEqual([
			"?and%5Bcategory%5D%5B%5D=Images&and%5Bprimary_collection%5D%5B%5D=Canterbury%20Museum&page=1&per_page=0",
			"?and%5Bcategory%5D%5B%5D=Images&and%5Bprimary_collection%5D%5B%5D=Canterbury%20Museum&page=1&per_page=100",
		]);
	});

	it("returns 400 with Swift's message when the image cannot be fetched", async () => {
		network.use(http.get(DIGITALNZ_ENDPOINT, () => HttpResponse.json({ error: "down" }, { status: 503 })));

		const response = await call("/image", authorized);

		expect(response.status).toBe(400);
		expect(await response.text()).toBe("Failed to get image for collection: random");
	});
});

describe("ImageApi RPC", () => {
	it("returns the same object GET /image serialises", async () => {
		network.use(digitalNZ(1, [canterburyRecord]));
		expect(await exports.ImageApi.image({ collection: "Canterbury Museum" })).toEqual(JSON.parse(canterburyBody));
	});

	it("returns null where GET /image would return 400", async () => {
		expect(await exports.ImageApi.image({ exclude: collectionNames() })).toBeNull();
	});

	it("lists the collections", async () => {
		expect(await exports.ImageApi.collections()).toEqual(collectionNames());
	});
});

describe("excludeList", () => {
	it("keeps an array's names and drops anything that isn't a string", () => {
		expect(excludeList(["Te Toi Uku, Crown Lynn and Clayworks Museum", 3, "TAPUHI"])).toEqual([
			"Te Toi Uku, Crown Lynn and Clayworks Museum",
			"TAPUHI",
		]);
	});

	it("splits a comma-separated string like the HTTP exclude parameter, dropping empty pieces", () => {
		expect(excludeList("TAPUHI,,Canterbury Museum")).toEqual(["TAPUHI", "Canterbury Museum"]);
		expect(excludeList("")).toEqual([]);
	});

	it("treats anything else as no exclusions", () => {
		expect(excludeList(undefined)).toEqual([]);
		expect(excludeList({ TAPUHI: true })).toEqual([]);
	});
});
