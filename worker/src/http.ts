import { ApiError } from "./errors.ts";
import { percentEncode } from "./swiftUrl.ts";

/** Sent on every scrape and probe. Several sources (Recollect vanity domains, Te Papa media) 403 bots. */
export const BROWSER_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36";

/** Sent on the DigitalNZ and Auckland Museum API calls, where Swift sent Alamofire's app User-Agent. */
export const API_USER_AGENT = "nzimages-api";

/**
 * Workers Free plan limit per invocation. Every redirect hop is a subrequest, so redirects are
 * followed here (not by `fetch`) and each hop is counted against this budget.
 */
export const MAX_SUBREQUESTS = 50;

const MAX_REDIRECTS = 20;
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);
const DEFAULT_TIMEOUT_MS = 60_000;
const PROBE_TIMEOUT_MS = 15_000;

export type QueryParameters = Record<string, string | number>;

const isAlamofireQueryAllowed = (character: string) => /^[A-Za-z0-9\-._~/?]$/.test(character);

/** Alamofire `URLEncoding.default`: keys sorted, escaped with `CharacterSet.afURLQueryAllowed`. */
export function alamofireQuery(parameters: QueryParameters): string {
	return Object.keys(parameters)
		.sort()
		.map((key) => {
			const value = String(parameters[key]);
			return `${percentEncode(key, isAlamofireQueryAllowed)}=${percentEncode(value, isAlamofireQueryAllowed)}`;
		})
		.join("&");
}

/** Swift `NetworkRequestManager.validation`: a 2xx status with an `application/json` MIME type. */
export function validateJSONResponse(
	status: number,
	contentType: string | null,
): "non200StatusCode" | "nonJsonResponse" | undefined {
	if (status < 200 || status >= 300) return "non200StatusCode";
	const mimeType = contentType?.split(";")[0]?.trim().toLowerCase();
	return mimeType === "application/json" ? undefined : "nonJsonResponse";
}

export interface ProbeResult {
	status: number;
	contentType: string | null;
}

interface SendOptions {
	method: "GET" | "HEAD";
	headers: Record<string, string>;
	timeoutMs: number;
}

/** All outbound HTTP for one invocation (Swift `NetworkRequestManager`). Create one per request. */
export class Http {
	#subrequests = 0;

	get subrequests(): number {
		return this.#subrequests;
	}

	/** Swift `makeRequest`: a JSON GET that must pass `validateJSONResponse`. */
	async getJSON(endpoint: string, options: { apiKey?: string; parameters?: QueryParameters } = {}): Promise<unknown> {
		const url = options.parameters ? `${endpoint}?${alamofireQuery(options.parameters)}` : endpoint;
		const headers: Record<string, string> = { Accept: "*/*", "User-Agent": API_USER_AGENT };
		if (options.apiKey !== undefined) headers["Authentication-Token"] = options.apiKey;

		const response = await this.#send(url, { method: "GET", headers, timeoutMs: DEFAULT_TIMEOUT_MS });
		const failure = validateJSONResponse(response.status, response.headers.get("content-type"));
		if (failure !== undefined) {
			await response.body?.cancel();
			throw new ApiError(failure, { endpoint, status: String(response.status) });
		}
		return response.json();
	}

	/** Swift `fetchHTML`: any status code is accepted; throws on a network failure or an empty body. */
	async fetchHTML(endpoint: string): Promise<string> {
		const response = await this.#send(endpoint, {
			method: "GET",
			headers: { Accept: "*/*", "User-Agent": BROWSER_USER_AGENT },
			timeoutMs: DEFAULT_TIMEOUT_MS,
		});
		const text = await response.text();
		if (text.length === 0 && response.status !== 204 && response.status !== 205) {
			throw new ApiError("inputDataNilOrZeroLength", { endpoint });
		}
		return text;
	}

	/** Swift `headStatusFollowingRedirects`: the final status of a HEAD, or 0 on failure. */
	async headStatus(endpoint: string): Promise<number> {
		return (await this.#probe(endpoint, "HEAD", {})).status;
	}

	/**
	 * Swift `rangeStatusFollowingRedirects` / `rangeContentType`: a 1-byte ranged GET, for endpoints
	 * that reject HEAD. Returns status 0 on failure.
	 */
	async rangeProbe(endpoint: string): Promise<ProbeResult> {
		return this.#probe(endpoint, "GET", { Range: "bytes=0-0" });
	}

	async #probe(endpoint: string, method: "GET" | "HEAD", headers: Record<string, string>): Promise<ProbeResult> {
		try {
			const response = await this.#send(endpoint, {
				method,
				headers: { Accept: "*/*", "User-Agent": BROWSER_USER_AGENT, ...headers },
				timeoutMs: PROBE_TIMEOUT_MS,
			});
			await response.body?.cancel();
			return { status: response.status, contentType: response.headers.get("content-type") };
		} catch {
			return { status: 0, contentType: null };
		}
	}

	async #send(url: string, { method, headers, timeoutMs }: SendOptions): Promise<Response> {
		const signal = AbortSignal.timeout(timeoutMs);
		let current = url;
		let sendHeaders = headers;
		for (let redirects = 0; ; redirects++) {
			if (this.#subrequests >= MAX_SUBREQUESTS) {
				throw new ApiError("subrequestBudgetExhausted", { url: current });
			}
			this.#subrequests++;
			const response = await fetch(current, { method, headers: sendHeaders, redirect: "manual", signal });
			const location = response.headers.get("location");
			if (!REDIRECT_STATUSES.has(response.status) || location === null) return response;

			await response.body?.cancel();
			if (redirects >= MAX_REDIRECTS) throw new ApiError("tooManyRedirects", { url: current });
			const next = new URL(location, current);
			if (next.origin !== new URL(current).origin) {
				// As fetch's own redirect handling would, keep the DigitalNZ key off other origins.
				const { "Authentication-Token": _apiKey, ...rest } = sendHeaders;
				sendHeaders = rest;
			}
			current = next.href;
		}
	}
}
