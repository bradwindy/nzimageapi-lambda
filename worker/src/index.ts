import { WorkerEntrypoint } from "cloudflare:workers";
import { authorizedConsumer, requestImage } from "./api.ts";
import { collectionNames } from "./collections.ts";
import type { NZImage } from "./models.ts";
import { splitNonEmpty } from "./swiftUrl.ts";

export type { NZImage } from "./models.ts";

const JSON_HEADERS = { "content-type": "application/json" };
const ROUTES = new Set(["/image", "/collections"]);

/** API Gateway joined repeated query parameters with commas; keep that. */
function queryParameter(url: URL, name: string): string | undefined {
	return url.searchParams.has(name) ? url.searchParams.getAll(name).join(",") : undefined;
}

export default {
	async fetch(request, env): Promise<Response> {
		const url = new URL(request.url);

		// API Gateway only routed GET /image and GET /collections to the Lambda and answered
		// everything else itself, before the secret check.
		if (request.method !== "GET" || !ROUTES.has(url.pathname)) {
			return Response.json({ message: "Not Found" }, { status: 404 });
		}

		const clients = env.API_CLIENT_SECRETS;
		if (!clients) {
			console.log("API_CLIENT_SECRETS not configured; refusing request");
			return new Response(null, { status: 500 });
		}

		const presented = request.headers.get("secret");
		const consumer = presented === null ? null : await authorizedConsumer(presented, clients);
		if (consumer === null) return new Response(null, { status: 401 });
		console.log(`Authorized consumer: ${consumer}`);

		if (url.pathname === "/collections") {
			return new Response(JSON.stringify(collectionNames()), { headers: JSON_HEADERS });
		}

		const collection = queryParameter(url, "collection");
		const exclude = splitNonEmpty(queryParameter(url, "exclude") ?? "", ",");
		const image = await requestImage(env, collection, exclude);
		if (image === null) {
			return new Response(`Failed to get image for collection: ${collection ?? "random"}`, { status: 400 });
		}
		return new Response(JSON.stringify(image), { headers: JSON_HEADERS });
	},
} satisfies ExportedHandler<Env>;

/** The binding is untyped at runtime, so a caller could pass the HTTP-style comma string. */
export function excludeList(value: unknown): string[] {
	if (Array.isArray(value)) return value.filter((name): name is string => typeof name === "string");
	return typeof value === "string" ? value.split(",").filter((name) => name !== "") : [];
}

/**
 * RPC entrypoint for Workers on the same account, through a service binding. No secret check:
 * only Workers the account owner binds can call it.
 */
export class ImageApi extends WorkerEntrypoint<Env> {
	/** Exactly the object `GET /image` would serialise, or null where `/image` would return 400. */
	async image(options?: { collection?: string; exclude?: string[] } | null): Promise<NZImage | null> {
		console.log("Authorized consumer: service binding");
		return requestImage(this.env, options?.collection, excludeList(options?.exclude));
	}

	async collections(): Promise<string[]> {
		return collectionNames();
	}
}
