// Prints live DigitalNZ `category=Images` counts for every collection in the counts table, as a
// TypeScript literal to paste over `collectionImageCounts` in src/collections.ts.
// Replaces Sources/Testing/CollectionLister.
//
//   DIGITALNZ_API_KEY=... npm run count-collections

import { collectionImageCounts } from "../src/collections.ts";

const ENDPOINT = "https://api.digitalnz.org/records.json";

const apiKey = process.env.DIGITALNZ_API_KEY;
if (!apiKey) {
	console.error("DIGITALNZ_API_KEY is not set");
	process.exit(1);
}

interface SearchResponse {
	search?: { result_count?: number; facets?: { primary_collection?: Record<string, number> } };
}

async function search(parameters: Record<string, string>): Promise<SearchResponse> {
	const url = `${ENDPOINT}?${new URLSearchParams({ per_page: "0", "and[category][]": "Images", ...parameters })}`;
	const response = await fetch(url, {
		headers: { "Authentication-Token": apiKey! },
		signal: AbortSignal.timeout(60_000),
	});
	const text = await response.text();
	if (!response.ok) {
		console.error(`DigitalNZ returned ${response.status}: ${text.slice(0, 200)}`);
		process.exit(1);
	}
	return JSON.parse(text) as SearchResponse;
}

// One facet query covers every collection (DigitalNZ caps facets at 350 per page).
const facets = (await search({ facets: "primary_collection", facets_per_page: "350" })).search?.facets?.primary_collection ?? {};

const lines: string[] = [];
for (const name of Object.keys(collectionImageCounts)) {
	let count = facets[name];
	if (count === undefined) {
		console.error(`${name}: not in the facet list, counting it on its own`);
		count = (await search({ "and[primary_collection][]": name })).search?.result_count ?? 0;
	}
	if (count === 0) console.error(`${name}: 0 images. A zero count gives it no chance of being picked.`);
	lines.push(`\t${JSON.stringify(name)}: ${count.toLocaleString("en-US").replaceAll(",", "_")},`);
}

console.log(["export const collectionImageCounts: Readonly<Record<string, number>> = {", ...lines, "};"].join("\n"));
console.error(`Fetched ${new Date().toISOString().slice(0, 10)}. Update the date in the comment above the table.`);
