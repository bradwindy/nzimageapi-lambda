// Ports CollectionWeightsTests, FilteredCollectionWeightsTests and WeightedRandomPickTests.

import { describe, expect, it } from "vitest";
import {
	collectionImageCounts,
	collectionWeights,
	filteredCollectionWeights,
	weightedRandomPick,
} from "../src/collections.ts";
import { NoEligibleCollectionsError } from "../src/errors.ts";

const sum = (weights: Map<string, number>) => [...weights.values()].reduce((total, weight) => total + weight, 0);

describe("collectionWeights", () => {
	it("sums to one", () => {
		expect(sum(collectionWeights())).toBeCloseTo(1, 6);
	});

	it("gives every collection a positive weight", () => {
		for (const [name, weight] of collectionWeights()) {
			expect(weight, name).toBeGreaterThan(0);
		}
	});

	it("has the same keys as the counts, in order", () => {
		expect([...collectionWeights().keys()]).toEqual(Object.keys(collectionImageCounts));
	});
});

describe("filteredCollectionWeights", () => {
	const exclude = ["Te Papa Collections Online", "Kura Heritage Collections Online"];

	it("sums to one", () => {
		expect(sum(filteredCollectionWeights(exclude))).toBeCloseTo(1, 6);
	});

	it("drops the excluded collections", () => {
		const weights = filteredCollectionWeights(exclude);
		for (const excluded of exclude) expect(weights.has(excluded)).toBe(false);
	});

	it("keeps every remaining collection with a positive weight", () => {
		const weights = filteredCollectionWeights(["Te Papa Collections Online"]);
		expect(weights.size).toBe(Object.keys(collectionImageCounts).length - 1);
		expect(weights.has("Kura Heritage Collections Online")).toBe(true);
		for (const [name, weight] of weights) expect(weight, name).toBeGreaterThan(0);
	});

	it("redistributes proportionally", () => {
		const removed = "Te Papa Collections Online";
		const unfiltered = collectionWeights();
		const scale = 1 / (1 - unfiltered.get(removed)!);
		for (const [name, weight] of filteredCollectionWeights([removed])) {
			expect(weight).toBeCloseTo(unfiltered.get(name)! * scale, 6);
		}
	});

	it("throws when every collection is excluded", () => {
		expect(() => filteredCollectionWeights(Object.keys(collectionImageCounts))).toThrow(NoEligibleCollectionsError);
	});

	it("matches the unfiltered weights for an empty exclude list", () => {
		const filtered = filteredCollectionWeights([]);
		const unfiltered = collectionWeights();
		expect([...filtered.keys()]).toEqual([...unfiltered.keys()]);
		for (const [name, weight] of filtered) expect(weight).toBeCloseTo(unfiltered.get(name)!, 6);
	});
});

describe("weightedRandomPick", () => {
	it("always returns the only key", () => {
		const weights = new Map([["only", 1]]);
		for (let i = 0; i < 1000; i++) expect(weightedRandomPick(weights)).toBe("only");
	});

	it("always returns the first key when its weight is 1", () => {
		const weights = new Map([
			["a", 1],
			["b", 0],
		]);
		for (let i = 0; i < 1000; i++) expect(weightedRandomPick(weights)).toBe("a");
	});

	it("falls through to the last key when weights sum to less than 1", () => {
		const weights = new Map([
			["a", 0],
			["b", 0],
			["c", 0],
		]);
		for (let i = 0; i < 1000; i++) expect(weightedRandomPick(weights)).toBe("c");
	});

	it("lands a uniform three-key distribution within tolerance", () => {
		const weights = new Map([
			["a", 1 / 3],
			["b", 1 / 3],
			["c", 1 / 3],
		]);
		const counts = new Map([
			["a", 0],
			["b", 0],
			["c", 0],
		]);
		const draws = 12_000;
		for (let i = 0; i < draws; i++) {
			const key = weightedRandomPick(weights);
			counts.set(key, counts.get(key)! + 1);
		}

		const expected = draws / 3;
		for (const [key, count] of counts) {
			expect(Math.abs(count - expected), key).toBeLessThanOrEqual(expected * 0.15);
		}
	});
});
