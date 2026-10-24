import { ApiError, DecodingError } from "./errors.ts";
import { swiftURLString } from "./swiftUrl.ts";

/**
 * One DigitalNZ record, in exactly the shape `GET /image` returns it (Swift `NZRecordsResult`).
 * Absent fields are omitted, as Swift's synthesised `Encodable` omits nil optionals.
 */
export interface NZImage {
	id?: number;
	title?: string;
	description?: string;
	thumbnail_url?: string;
	large_thumbnail_url?: string;
	object_url?: string;
	display_collection?: string;
	landing_url?: string;
	origin_url?: string;
	source_url?: string;
	creator?: string[];
	date?: string[];
	subject?: string[];
}

export interface RecordsSearch<Result = NZImage> {
	result_count?: number;
	results?: Result[];
}

export interface RecordsResponse<Result = NZImage> {
	search?: RecordsSearch<Result>;
}

export interface OpacObjectField {
	value?: string;
}

export interface OpacObjectFieldSet {
	identifier?: string;
	opacObjectFields?: OpacObjectField[];
}

export interface AKLMuseumResponse {
	opacObjectFieldSets?: OpacObjectFieldSet[];
}

// Decoding mirrors Swift's JSONDecoder with all-optional properties: a missing or null key is
// absent, but a present value of the wrong type fails the whole document (for a page of records,
// see decodeRecordsPage).

type JSONObject = Record<string, unknown>;
type Decoder<T> = (value: unknown, path: string) => T;

function decodeObject(value: unknown, path: string): JSONObject {
	if (typeof value !== "object" || value === null || Array.isArray(value)) {
		throw new DecodingError(`Expected an object at ${path}`);
	}
	return value as JSONObject;
}

const decodeString: Decoder<string> = (value, path) => {
	if (typeof value !== "string") throw new DecodingError(`Expected a string at ${path}`);
	return value;
};

const decodeInt: Decoder<number> = (value, path) => {
	if (typeof value !== "number" || !Number.isSafeInteger(value)) {
		throw new DecodingError(`Expected an integer at ${path}`);
	}
	return value;
};

const decodeURLString: Decoder<string> = (value, path) => {
	const url = swiftURLString(decodeString(value, path));
	if (url === null) throw new DecodingError(`Invalid URL string at ${path}`);
	return url;
};

function decodeArray<T>(decodeElement: Decoder<T>): Decoder<T[]> {
	return (value, path) => {
		if (!Array.isArray(value)) throw new DecodingError(`Expected an array at ${path}`);
		return value.map((element, index) => decodeElement(element, `${path}[${index}]`));
	};
}

function decodeFields<T>(value: unknown, path: string, fields: ReadonlyArray<readonly [string, Decoder<unknown>]>): T {
	const object = decodeObject(value, path);
	const decoded: JSONObject = {};
	for (const [key, decode] of fields) {
		const field = object[key];
		if (field !== undefined && field !== null) decoded[key] = decode(field, `${path}.${key}`);
	}
	return decoded as T;
}

// Swift `NZRecordsResult.CodingKeys` order, which is also the order the fields are serialised in.
const RECORD_FIELDS: ReadonlyArray<readonly [string, Decoder<unknown>]> = [
	["id", decodeInt],
	["title", decodeString],
	["description", decodeString],
	["thumbnail_url", decodeURLString],
	["large_thumbnail_url", decodeURLString],
	["object_url", decodeURLString],
	["display_collection", decodeString],
	["landing_url", decodeURLString],
	["origin_url", decodeURLString],
	["source_url", decodeURLString],
	["creator", decodeArray(decodeString)],
	["date", decodeArray(decodeString)],
	["subject", decodeArray(decodeString)],
];

export function decodeRecord(value: unknown, path = "$"): NZImage {
	return decodeFields(value, path, RECORD_FIELDS);
}

const decodeSearch: Decoder<RecordsSearch> = (value, path) =>
	decodeFields(value, path, [
		["result_count", decodeInt],
		["results", decodeArray(decodeRecord)],
	]);

export function decodeRecordsResponse(value: unknown): RecordsResponse {
	return decodeFields(value, "$", [["search", decodeSearch]]);
}

const decodeUndecodedArray: Decoder<unknown[]> = (value, path) => {
	if (!Array.isArray(value)) throw new DecodingError(`Expected an array at ${path}`);
	return value;
};

const decodeUndecodedSearch: Decoder<RecordsSearch<unknown>> = (value, path) =>
	decodeFields(value, path, [
		["result_count", decodeInt],
		["results", decodeUndecodedArray],
	]);

/**
 * A page of records with the records left undecoded, so only the one picked is decoded with
 * `decodeRecord`. Decoding all 100 (URL re-encoding included) was most of a request's CPU on the
 * Free plan's 10 ms budget, and it let one malformed record elsewhere on the page fail the request.
 */
export function decodeRecordsPage(value: unknown): RecordsResponse<unknown> {
	return decodeFields(value, "$", [["search", decodeUndecodedSearch]]);
}

const decodeOpacObjectField: Decoder<OpacObjectField> = (value, path) =>
	decodeFields(value, path, [["value", decodeString]]);

const decodeOpacObjectFieldSet: Decoder<OpacObjectFieldSet> = (value, path) =>
	decodeFields(value, path, [
		["identifier", decodeString],
		["opacObjectFields", decodeArray(decodeOpacObjectField)],
	]);

export function decodeAKLMuseumResponse(value: unknown): AKLMuseumResponse {
	return decodeFields(value, "$", [["opacObjectFieldSets", decodeArray(decodeOpacObjectFieldSet)]]);
}

/** Swift `NZRecordsResponse.checkNonNull()`. */
export function checkResponseNonNull<Result>(response: RecordsResponse<Result>): RecordsSearch<Result> {
	if (response.search === undefined) throw new ApiError("nullResponseContent");
	return response.search;
}

/** Swift `NZRecordsSearch.checkNonNull()`. */
export function checkSearchNonNull<Result>(search: RecordsSearch<Result>): { result_count: number; results: Result[] } {
	if (search.result_count === undefined || search.results === undefined) {
		throw new ApiError("nullSearchContent", { result_count: String(search.result_count) });
	}
	return { result_count: search.result_count, results: search.results };
}

/** Swift `NZRecordsResult.checkHasTitleAndLargeImage()`: the minimum needed to return a record. */
export function checkHasTitleAndLargeImage(record: NZImage): NZImage {
	if (record.id === undefined || record.title === undefined || record.large_thumbnail_url === undefined) {
		throw new ApiError("nullImageOrTitle", { id: String(record.id) });
	}
	return record;
}
