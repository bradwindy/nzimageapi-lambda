// Calls /image for every collection and checks the response and image URL the way
// Sources/Testing/CollectionTester did. Prints a pass/fail table; exits 1 if any collection fails.
//
//   NZIMAGE_API_SECRET=... npm run check-collections -- [--base-url URL] [--collection NAME]...
//                                                       [--compare-url URL]
//
// --compare-url also fetches each collection from a second deployment (e.g. the old Lambda, with
// NZIMAGE_COMPARE_SECRET if its secret differs) and reports whether both returned the same URL
// shape. Records are random, so this compares hosts and path patterns, not exact URLs.

import { parseArgs } from "node:util";
import { BROWSER_USER_AGENT } from "../src/http.ts";

const USAGE = `Usage: npm run check-collections -- [--base-url URL] [--collection NAME]... [--compare-url URL]

  --base-url URL      Worker to test (default http://127.0.0.1:8787)
  --collection NAME   Collection to test; repeat for several (default: every collection from /collections)
  --compare-url URL   Second deployment to compare URL shapes against

Environment:
  NZIMAGE_API_SECRET       secret header for --base-url (required)
  NZIMAGE_COMPARE_SECRET   secret header for --compare-url (default NZIMAGE_API_SECRET)`;

const CONCURRENCY = 4;

const { values: options } = parseArgs({
	options: {
		"base-url": { type: "string", default: "http://127.0.0.1:8787" },
		collection: { type: "string", multiple: true },
		"compare-url": { type: "string" },
		help: { type: "boolean", short: "h" },
	},
});

if (options.help) {
	console.log(USAGE);
	process.exit(0);
}

const secret = process.env.NZIMAGE_API_SECRET;
if (!secret) {
	console.error(`NZIMAGE_API_SECRET is not set\n\n${USAGE}`);
	process.exit(2);
}
const compareSecret = process.env.NZIMAGE_COMPARE_SECRET ?? secret;
const baseURL = options["base-url"].replace(/\/+$/, "");
const compareURL = options["compare-url"]?.replace(/\/+$/, "");

interface ImageResult {
	error?: string;
	imageURL?: string;
}

interface Row {
	collection: string;
	pass: boolean;
	api: string;
	image: string;
	contentType: string;
	fileType: string;
	imageURL?: string;
	error?: string;
	shape?: string;
	compareShape?: string;
}

async function getImage(base: string, apiSecret: string, collection: string): Promise<ImageResult> {
	try {
		const response = await fetch(`${base}/image?collection=${encodeURIComponent(collection)}`, {
			headers: { secret: apiSecret },
			signal: AbortSignal.timeout(120_000),
		});
		const body = await response.text();
		if (response.status !== 200) return { error: `HTTP ${response.status}: ${body.slice(0, 200)}` };

		let json: unknown;
		try {
			json = JSON.parse(body);
		} catch {
			return { error: "response is not JSON" };
		}
		const imageURL = (json as { large_thumbnail_url?: unknown }).large_thumbnail_url;
		return typeof imageURL === "string" ? { imageURL } : { error: "no large_thumbnail_url in response" };
	} catch (error) {
		return { error: `request failed: ${(error as Error).message}` };
	}
}

function detectFileType(bytes: Uint8Array): string {
	if (bytes.length < 2) return "unknown";
	if (bytes[0] === 0xff && bytes[1] === 0xd8) return "JPEG image";
	if (bytes.length >= 4 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) return "PNG image";
	if (bytes.length >= 3 && bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) return "GIF image";
	const ascii = new TextDecoder().decode(bytes.slice(0, 12));
	if (ascii.startsWith("RIFF") && ascii.slice(8, 12) === "WEBP") return "WebP image";
	return "unknown binary data";
}

interface ImageCheck {
	ok: boolean;
	status: string;
	contentType: string;
	fileType: string;
}

async function probe(
	url: string,
	init: { method?: string; headers?: Record<string, string> },
): Promise<{ status: number; contentType: string }> {
	try {
		const response = await fetch(url, {
			...init,
			headers: { "User-Agent": BROWSER_USER_AGENT, ...init.headers },
			signal: AbortSignal.timeout(10_000),
		});
		await response.body?.cancel();
		return { status: response.status, contentType: response.headers.get("content-type") ?? "unknown" };
	} catch {
		return { status: 0, contentType: "unknown" };
	}
}

/**
 * CollectionTester's check (a 200 HEAD, then the first 20 bytes for the file type), with two
 * changes: the Worker's browser User-Agent, because Flickr now refuses CollectionTester's bare
 * "Mozilla/5.0", and a 1-byte ranged GET when HEAD fails, because Te Papa `/full` and presigned
 * S3 originals reject HEAD.
 */
async function validateImageURL(url: string): Promise<ImageCheck> {
	let { status, contentType } = await probe(url, { method: "HEAD" });
	let label = status === 0 ? "error" : String(status);
	if (status !== 200) {
		const ranged = await probe(url, { headers: { Range: "bytes=0-0" } });
		if (ranged.status === 200 || ranged.status === 206) {
			status = 200;
			contentType = ranged.contentType;
			label = `${ranged.status} GET`;
		}
	}
	if (status !== 200) return { ok: false, status: label, contentType, fileType: "-" };

	let fileType = "unknown";
	try {
		const response = await fetch(url, {
			headers: { "User-Agent": BROWSER_USER_AGENT, Range: "bytes=0-19" },
			signal: AbortSignal.timeout(60_000),
		});
		fileType = detectFileType(new Uint8Array(await response.arrayBuffer()).slice(0, 20));
	} catch {
		fileType = "error";
	}
	return { ok: true, status: label, contentType, fileType };
}

function generaliseSegment(segment: string, isLast: boolean): string {
	if (isLast && segment.includes(".")) return `*${segment.slice(segment.lastIndexOf(".")).toLowerCase()}`;
	const [head = "", ...rest] = segment.split(/%2f/i);
	const general = head.replace(/[A-Za-z0-9]+/g, (token) => (/\d/.test(token) || /^[0-9a-f]{8,}$/i.test(token) ? "#" : token));
	return rest.length > 0 ? `${general}%2F…` : general;
}

/** Host, generalised path and query keys: what a strategy produces, minus record-specific ids. */
function urlShape(value: string): string {
	let url: URL;
	try {
		url = new URL(value);
	} catch {
		return "invalid URL";
	}
	const segments = url.pathname.split("/").slice(1);
	const path = segments
		.slice(0, 4)
		.map((segment, index) => generaliseSegment(segment, index === segments.length - 1))
		.join("/");
	const query = [...url.searchParams]
		.map(([key, parameter]) => (/^https?:\/\//.test(parameter) ? `${key}=<${urlShape(parameter)}>` : key))
		.sort()
		.join("&");
	return `${url.host}/${path}${segments.length > 4 ? "/…" : ""}${query ? `?${query}` : ""}`;
}

async function check(collection: string): Promise<Row> {
	const row: Row = { collection, pass: false, api: "fail", image: "-", contentType: "-", fileType: "-" };
	const [result, compared] = await Promise.all([
		getImage(baseURL, secret!, collection),
		compareURL ? getImage(compareURL, compareSecret, collection) : Promise.resolve(undefined),
	]);

	if (compared) row.compareShape = compared.imageURL ? urlShape(compared.imageURL) : `error (${compared.error})`;
	if (result.imageURL === undefined) {
		row.error = result.error;
		return row;
	}

	row.api = "ok";
	row.imageURL = result.imageURL;
	row.shape = urlShape(result.imageURL);
	const image = await validateImageURL(result.imageURL);
	row.image = image.status;
	row.contentType = image.contentType;
	row.fileType = image.fileType;
	row.pass = image.ok;
	if (!row.pass) row.error = `image URL returned ${row.image}`;
	return row;
}

async function mapWithConcurrency<T, R>(items: T[], limit: number, map: (item: T) => Promise<R>): Promise<R[]> {
	const results: R[] = new Array(items.length);
	let next = 0;
	const worker = async () => {
		while (next < items.length) {
			const index = next++;
			results[index] = await map(items[index]!);
		}
	};
	await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
	return results;
}

async function listCollections(): Promise<string[]> {
	const response = await fetch(`${baseURL}/collections`, { headers: { secret: secret! }, signal: AbortSignal.timeout(30_000) });
	if (!response.ok) throw new Error(`GET ${baseURL}/collections returned ${response.status}`);
	return (await response.json()) as string[];
}

function printTable(rows: Row[]) {
	const columns: Array<[string, (row: Row) => string]> = [
		["Collection", (row) => row.collection],
		["Result", (row) => (row.pass ? "PASS" : "FAIL")],
		["API", (row) => row.api],
		["Image", (row) => row.image],
		["Content-Type", (row) => row.contentType],
		["File type", (row) => row.fileType],
	];
	if (compareURL) {
		columns.push(["Shape vs compare", (row) => (row.shape === undefined ? "-" : row.shape === row.compareShape ? "same" : "differs")]);
	}

	const widths = columns.map(([title, value]) => Math.max(title.length, ...rows.map((row) => value(row).length)));
	const line = (cells: string[]) => cells.map((cell, index) => cell.padEnd(widths[index]!)).join("  ");
	console.log(line(columns.map(([title]) => title)));
	console.log(line(widths.map((width) => "-".repeat(width))));
	for (const row of rows) console.log(line(columns.map(([, value]) => value(row))));

	const failures = rows.filter((row) => !row.pass);
	if (failures.length > 0) {
		console.log("\nFailures:");
		for (const row of failures) console.log(`  ${row.collection}: ${row.error}${row.imageURL ? `\n    ${row.imageURL}` : ""}`);
	}

	const differences = rows.filter((row) => compareURL && row.shape !== undefined && row.shape !== row.compareShape);
	if (differences.length > 0) {
		console.log("\nShape differences (random records can legitimately differ, e.g. master vs fallback):");
		for (const row of differences) console.log(`  ${row.collection}\n    this:    ${row.shape}\n    compare: ${row.compareShape}`);
	}

	console.log(`\n${rows.length - failures.length}/${rows.length} passed`);
}

const collections = options.collection ?? (await listCollections());
const rows = await mapWithConcurrency(collections, CONCURRENCY, check);
printTable(rows);
process.exit(rows.every((row) => row.pass) ? 0 : 1);
