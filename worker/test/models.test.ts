// Ports ModelCodingTests (the decode and validation paths the API uses).

import { describe, expect, it } from "vitest";
import { DecodingError } from "../src/errors.ts";
import {
	checkHasTitleAndLargeImage,
	checkResponseNonNull,
	checkSearchNonNull,
	decodeAKLMuseumResponse,
	decodeRecord,
	decodeRecordsResponse,
} from "../src/models.ts";

const fullResult = {
	id: 42,
	title: "A Photograph",
	description: "A description",
	thumbnail_url: "https://example.com/thumb.jpg",
	large_thumbnail_url: "https://example.com/large.jpg",
	object_url: "https://example.com/object.jpg",
	display_collection: "Test Collection",
	landing_url: "https://example.com/item/1",
	origin_url: "https://example.com/origin.jpg",
	source_url: "https://example.com/source.jpg",
};

describe("NZImage decoding", () => {
	it("decodes the snake_case keys", () => {
		expect(decodeRecord(fullResult)).toEqual(fullResult);
	});

	it("round-trips through JSON", () => {
		const original = decodeRecord(fullResult);
		expect(decodeRecord(JSON.parse(JSON.stringify(original)))).toEqual(original);
	});

	it("rejects the whole record when a field has the wrong type, as JSONDecoder does", () => {
		expect(() => decodeRecord({ ...fullResult, id: "42" })).toThrow(DecodingError);
	});
});

describe("checkHasTitleAndLargeImage", () => {
	it("passes with an id, title and large thumbnail", () => {
		expect(() => checkHasTitleAndLargeImage({ id: 1, title: "T", large_thumbnail_url: "https://example.com/l.jpg" })).not.toThrow();
	});

	it("throws nullImageOrTitle when the large thumbnail is missing", () => {
		expect(() =>
			checkHasTitleAndLargeImage({ id: 1, title: "T", description: "d", display_collection: "c" }),
		).toThrow(expect.objectContaining({ kind: "nullImageOrTitle" }));
	});

	it("throws nullImageOrTitle when the title is missing", () => {
		expect(() => checkHasTitleAndLargeImage({ id: 1, large_thumbnail_url: "https://example.com/l.jpg" })).toThrow(
			expect.objectContaining({ kind: "nullImageOrTitle" }),
		);
	});
});

describe("records response", () => {
	it("decodes result_count and nested results", () => {
		const response = decodeRecordsResponse({ search: { result_count: 2, results: [fullResult, fullResult] } });
		expect(response.search?.result_count).toBe(2);
		expect(response.search?.results).toHaveLength(2);
		expect(() => checkSearchNonNull(checkResponseNonNull(response))).not.toThrow();
	});

	it("throws when search is missing", () => {
		expect(() => checkResponseNonNull({})).toThrow(expect.objectContaining({ kind: "nullResponseContent" }));
	});

	it("throws when result_count is missing", () => {
		expect(() => checkSearchNonNull({ results: [] })).toThrow(expect.objectContaining({ kind: "nullSearchContent" }));
	});

	it("throws when results is missing", () => {
		expect(() => checkSearchNonNull({ result_count: 0 })).toThrow(expect.objectContaining({ kind: "nullSearchContent" }));
	});

	it("passes with an empty results array", () => {
		expect(() => checkSearchNonNull({ result_count: 0, results: [] })).not.toThrow();
	});
});

describe("Auckland Museum response", () => {
	it("decodes the field sets", () => {
		const response = decodeAKLMuseumResponse({
			opacObjectFieldSets: [
				{ identifier: "object_av_link", opacObjectFields: [{ value: "J:\\Dir\\Sub\\full\\File.jpg|20||Rights" }] },
			],
		});

		const fieldSet = response.opacObjectFieldSets?.[0];
		expect(fieldSet?.identifier).toBe("object_av_link");
		expect(fieldSet?.opacObjectFields?.[0]?.value).toBe("J:\\Dir\\Sub\\full\\File.jpg|20||Rights");
	});
});
