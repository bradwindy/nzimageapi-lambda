// Ports DigitalNZAPIDataSourcePageMathTests, with DigitalNZ mocked at the HTTP layer.

import { describe, expect, it } from "vitest";
import { newResult, pageCount } from "../src/digitalnz.ts";
import type { NZImage } from "../src/models.ts";
import { digitalNZ, testContext } from "./helpers.ts";
import { network } from "./network.ts";

describe("pageCount", () => {
	it("uses ceiling division", () => {
		expect(pageCount(50, 100)).toBe(1);
		expect(pageCount(1, 100)).toBe(1);
		expect(pageCount(100, 100)).toBe(1);
		expect(pageCount(101, 100)).toBe(2);
		expect(pageCount(250, 100)).toBe(3);
	});

	it("is zero for empty or invalid input", () => {
		expect(pageCount(0, 100)).toBe(0);
		expect(pageCount(50, 0)).toBe(0);
	});
});

describe("newResult", () => {
	it("resolves a collection smaller than one page without going out of bounds", async () => {
		const results: NZImage[] = Array.from({ length: 5 }, (_, i) => ({
			id: i,
			title: `title ${i}`,
			description: `description ${i}`,
			thumbnail_url: `https://example.com/${i}-thumb.jpg`,
			large_thumbnail_url: `https://example.com/${i}-large.jpg`,
			object_url: `https://example.com/${i}-object.jpg`,
			display_collection: "Test Collection XYZ",
			landing_url: `https://example.com/${i}`,
		}));
		network.use(digitalNZ(5, results));

		for (let i = 0; i < 30; i++) {
			const result = await newResult(testContext(), "Test Collection XYZ");
			expect(result.id).toBeGreaterThanOrEqual(0);
			expect(result.id).toBeLessThan(5);
		}
	});

	it("throws noResults when the count is zero", async () => {
		network.use(digitalNZ(0, []));
		await expect(newResult(testContext(), "Any Collection")).rejects.toMatchObject({ kind: "noResults" });
	});

	it("throws noResults when the page comes back empty", async () => {
		network.use(digitalNZ(5, []));
		await expect(newResult(testContext(), "Any Collection")).rejects.toMatchObject({ kind: "noResults" });
	});

	it("picks from the injected weights when no collection is given", async () => {
		network.use(
			digitalNZ(1, [
				{
					id: 99,
					title: "t",
					description: "d",
					large_thumbnail_url: "https://example.com/large.jpg",
					display_collection: "Weighted Collection",
				},
			]),
		);
		const context = testContext();

		const result = await newResult(context, undefined, new Map([["Weighted Collection", 1]]));

		expect(result.id).toBe(99);
		expect(context.messages.some((message) => message.includes("Weighted Collection"))).toBe(true);
	});

	it("applies the V&A strategy to the chosen record", async () => {
		network.use(
			digitalNZ(1, [
				{
					id: 7,
					title: "t",
					description: "d",
					large_thumbnail_url: "https://media.vam.ac.uk/media/thira/collection_images/2025PE4780/2025PE4780.jpg",
					display_collection: "Victoria and Albert Museum",
				},
			]),
		);

		const result = await newResult(testContext(), "Victoria and Albert Museum");

		expect(result.large_thumbnail_url).toBe("https://framemark.vam.ac.uk/collections/2025PE4780/full/max/0/default.jpg");
	});
});
