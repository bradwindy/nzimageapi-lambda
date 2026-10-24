import { collectionWeights, weightedRandomPick } from "./collections.ts";
import type { RequestContext } from "./context.ts";
import { ApiError } from "./errors.ts";
import {
	checkHasTitleAndLargeImage,
	checkResponseNonNull,
	checkSearchNonNull,
	decodeRecordsResponse,
	type NZImage,
} from "./models.ts";
import { getLargerImage } from "./urlProcessor.ts";

const ENDPOINT = "https://api.digitalnz.org/records.json";
const RESULTS_PER_PAGE = 100;
/** DigitalNZ rejects `page` above this regardless of how many results exist. */
const MAX_PAGE = 50_000;

/** Ceiling division, so a collection smaller than one page still has one page. */
export function pageCount(resultCount: number, perPage: number): number {
	if (perPage <= 0 || resultCount <= 0) return 0;
	return Math.floor((resultCount + perPage - 1) / perPage);
}

function randomInt(min: number, max: number): number {
	return min + Math.floor(Math.random() * (max - min + 1));
}

/**
 * Swift `DigitalNZAPIDataSource.newResult`. DigitalNZ has no random sort, so: count the
 * collection's images (`per_page=0`), fetch a random page, pick a random record on it.
 */
export async function newResult(
	context: RequestContext,
	collection: string | undefined,
	weights: ReadonlyMap<string, number> = collectionWeights(),
): Promise<NZImage> {
	const chosenCollection = collection ?? weightedRandomPick(weights);
	const request = (page: number, perPage: number) =>
		context.http.getJSON(ENDPOINT, {
			apiKey: context.env.DIGITALNZ_API_KEY,
			parameters: {
				page,
				per_page: perPage,
				"and[category][]": "Images",
				"and[primary_collection][]": chosenCollection,
			},
		});

	context.log(`Making initial request for collection: ${chosenCollection}`);
	const initial = checkSearchNonNull(checkResponseNonNull(decodeRecordsResponse(await request(1, 0))));
	context.log(`Got initial response, result count ${initial.result_count}`);

	const pages = Math.min(pageCount(initial.result_count, RESULTS_PER_PAGE), MAX_PAGE);
	if (pages <= 0) throw new ApiError("noResults", { collection: chosenCollection, result_count: String(initial.result_count) });

	const page = randomInt(1, pages);
	context.log(`Making second request. pageNumber: ${page}, resultsPerPage: ${RESULTS_PER_PAGE}, collection: ${chosenCollection}`);
	const secondary = decodeRecordsResponse(await request(page, RESULTS_PER_PAGE));
	context.log(`Got second response, result count ${secondary.search?.result_count}`);

	const { results } = checkSearchNonNull(checkResponseNonNull(secondary));
	if (results.length === 0) throw new ApiError("noResults", { collection: chosenCollection, page: String(page) });

	// The last page is usually short, so pick within the page actually returned.
	const chosen = checkHasTitleAndLargeImage(results[randomInt(0, results.length - 1)]!);
	return getLargerImage(chosen, context);
}
