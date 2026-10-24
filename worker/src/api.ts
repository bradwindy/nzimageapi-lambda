import { filteredCollectionWeights } from "./collections.ts";
import { type ApiEnv, createContext, type Logger, type RequestContext } from "./context.ts";
import { newResult } from "./digitalnz.ts";
import { ApiError, NoEligibleCollectionsError } from "./errors.ts";
import type { NZImage } from "./models.ts";
import { splitNonEmpty } from "./swiftUrl.ts";

const encoder = new TextEncoder();

async function sha256(value: string): Promise<ArrayBuffer> {
	return crypto.subtle.digest("SHA-256", encoder.encode(value));
}

/**
 * Returns the name of the consumer whose secret matches `presented`, or null. `allowed` is
 * `API_CLIENT_SECRETS` (`name:secret,name:secret`). Every entry is compared, with no early
 * exit, and both sides are hashed first so the comparison is fixed-length and constant-time.
 */
export async function authorizedConsumer(presented: string, allowed: string): Promise<string | null> {
	const presentedDigest = await sha256(presented);
	let matched: string | null = null;
	for (const entry of splitNonEmpty(allowed, ",")) {
		const separator = entry.indexOf(":");
		if (separator < 0) continue;
		const secretDigest = await sha256(entry.slice(separator + 1));
		if (crypto.subtle.timingSafeEqual(presentedDigest, secretDigest)) matched = entry.slice(0, separator);
	}
	return matched;
}

/** Swift `NZImageApi.image`: null where `/image` returns 400. */
export async function image(
	context: RequestContext,
	collection: string | undefined,
	exclude: ReadonlySet<string>,
): Promise<NZImage | null> {
	try {
		const weights = collection === undefined && exclude.size > 0 ? filteredCollectionWeights(exclude) : undefined;
		return await newResult(context, collection, weights);
	} catch (error) {
		if (error instanceof NoEligibleCollectionsError) {
			context.log("No eligible collections remain after applying the exclude filter");
		} else if (error instanceof ApiError) {
			context.log(`A rich error occurred. Kind: ${error.kind}, Data: ${JSON.stringify(error.data)}`);
		} else {
			context.log(`An unexpected error occurred: ${error instanceof Error ? error.message : String(error)}`);
		}
		return null;
	}
}

/**
 * The shared entry for `GET /image` and the RPC method. An explicit `collection` wins and
 * `exclude` is ignored; `exclude` only filters the random pick.
 */
export async function requestImage(
	env: ApiEnv,
	collection: string | undefined,
	exclude: Iterable<string>,
	log: Logger = console.log,
): Promise<NZImage | null> {
	const excluded = collection === undefined ? new Set(exclude) : new Set<string>();
	const requested = collection ?? "random";

	log(`Requested collection: ${requested}`);
	log(`Excluded collections: ${excluded.size === 0 ? "none" : [...excluded].sort().join(", ")}`);

	const result = await image(createContext(env, log), collection, excluded);
	if (result === null) log(`Failed to get image for collection: ${requested}`);
	return result;
}
