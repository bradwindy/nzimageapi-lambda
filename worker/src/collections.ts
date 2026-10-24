import { NoEligibleCollectionsError } from "./errors.ts";

/**
 * Raw DigitalNZ `category=Images` result counts per collection, fetched 2026-07-06. Pick weights
 * are derived from these, so each collection's odds track its share of the images.
 *
 * Keep these as counts. Hand-set fractions summed to 0.837 in the past, which gave the last
 * entry an extra ~16% pick chance through `weightedRandomPick`'s fallthrough. Refresh with
 * `npm run count-collections` and paste its output over this table.
 */
export const collectionImageCounts: Readonly<Record<string, number>> = {
	"Auckland Museum Collections": 267_710,
	"Te Papa Collections Online": 388_639,
	"Kura Heritage Collections Online": 390_626,
	"Canterbury Museum": 295_981,
	"Antarctica NZ Digital Asset Manager": 59_376,
	"National Publicity Studios black and white file prints": 33_796,
	"Tauranga City Libraries Other Collection": 65_298,
	"Hawke's Bay Knowledge Bank": 29_348,
	"South Canterbury Museum": 22_582,
	"Howick Historical Village NZMuseums": 13_450,
	"National Army Museum": 14_035,
	"TAPUHI": 301_621,
	"Auckland Art Gallery Toi o Tāmaki": 18_204,
	"Waimate Museum and Archives PastPerfect": 8_667,
	"Te Toi Uku, Crown Lynn and Clayworks Museum": 8_106,
	"Culture Waitaki": 10_631,
	"Te Hikoi Museum": 8_714,
	"V.C. Browne & Son NZ Aerial Photograph Collection": 31_506,
	"Tāmiro": 5_636,
	"Alexander Turnbull Library Flickr": 4_307,
	"He Purapura Marara Scattered Seeds": 10_746,
	"Hastings Recollect": 4_015,
	"Lower Hutt MyRecollect": 2_225,
	"Hocken Digital Collections": 56_791,
	"Ministry for Culture and Heritage Te Ara Flickr": 15_714,
	"Dunedin City Council Archives Flickr": 1_768,
	"State Library of New South Wales Flickr": 177,
	"Australian National Maritime Museum Flickr": 126,
	"Mataura Museum NZMuseums": 3_446,
	"New Zealand Portrait Gallery NZMuseums": 136,
	"Te Ūaka The Lyttelton Museum": 18_588,
	"Wyndham & Districts Historical Museum": 3_937,
	"Feilding Library": 3_592,
	"Clutha Heritage": 2_888,
	"John Kinder Theological Library": 2_719,
	"Tasman Heritage": 2_921,
	"Western Bay Community Archives": 2_442,
	"War Art Online": 1_477,
	"Far North District Libraries Rediscovery": 1_435,
	"Pakiaka Rotorua Heritage Online": 1_571,
	"Victoria and Albert Museum": 564,
	"The University of Waikato Art Collection": 540,
	"Te Ahu Museum": 506,
	"Ngā Puhipuhi o Te Herenga Waka—Victoria University of Wellington Art Collection": 488,
	"Nelson Provincial Museum": 198_770,
	"Puke Ariki": 134_911,
	"Kete Horowhenua": 24_375,
	"Manawatū Heritage": 26_055,
};

export function collectionNames(): string[] {
	return Object.keys(collectionImageCounts);
}

function weightsFrom(counts: ReadonlyArray<[string, number]>): Map<string, number> {
	const total = counts.reduce((sum, [, count]) => sum + count, 0);
	return new Map(counts.map(([name, count]) => [name, count / total]));
}

/** Each collection's share of the total image count, in table order. Sums to 1. */
export function collectionWeights(): Map<string, number> {
	return weightsFrom(Object.entries(collectionImageCounts));
}

/**
 * Weights over the table minus `exclude`, re-derived from counts so they still sum to 1.
 * Matching uses canonical equivalence, as Swift `Set<String>` does.
 */
export function filteredCollectionWeights(exclude: Iterable<string>): Map<string, number> {
	const excluded = new Set([...exclude].map((name) => name.normalize("NFC")));
	const remaining = Object.entries(collectionImageCounts).filter(([name]) => !excluded.has(name.normalize("NFC")));
	if (remaining.length === 0) throw new NoEligibleCollectionsError();
	return weightsFrom(remaining);
}

/**
 * Picks a key with probability equal to its weight. Weights should sum to 1; if they sum to
 * less, the shortfall falls through to the last key (the bug the counts table exists to avoid).
 */
export function weightedRandomPick(weights: ReadonlyMap<string, number>): string {
	const threshold = Math.random();
	let cumulative = 0;
	let last: string | undefined;
	for (const [name, weight] of weights) {
		cumulative += weight;
		if (cumulative > threshold) return name;
		last = name;
	}
	if (last === undefined) throw new NoEligibleCollectionsError();
	return last;
}
