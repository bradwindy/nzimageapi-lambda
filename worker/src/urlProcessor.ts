// Port of Sources/NZImageApiLambda/Helpers/URLProcessor.swift. Per-collection findings behind
// each strategy are documented there and in Research/highres/.

import type { ApiEnv, RequestContext } from "./context.ts";
import { ApiError } from "./errors.ts";
import { ogImageContent } from "./html.ts";
import type { Http } from "./http.ts";
import { decodeAKLMuseumResponse, type NZImage } from "./models.ts";
import {
	isAlphanumeric,
	isURLHostAllowed,
	lastPathComponent,
	lastPathComponentWithoutExtension,
	pathComponents,
	pathExtension,
	percentEncode,
	slice,
	splitNonEmpty,
	swiftURLString,
	urlHost,
	urlScheme,
} from "./swiftUrl.ts";

/** Returns the URL to serve for `record`, given its current `large_thumbnail_url` (`url`). */
export type URLStrategy = (record: NZImage, url: string, context: RequestContext) => string | Promise<string>;

const NDHA_BASE = "https://ndhadeliver.natlib.govt.nz";
const RECOLLECT_ORIGINAL_DOWNLOAD = /\/item\/[0-9a-f-]+\/files\/[0-9a-f-]+\/download\?variant=original/;
const METS_AMD_SEC = /<mets:amdSec ID="(FL\d+)-amd">([\s\S]*?)<\/mets:amdSec>/g;
const METS_FILE_SIZE = /<key id="fileSizeBytes">(\d+)<\/key>/;
const VERNON_LARGE = "/records/images/large/";
const VERNON_XLARGE = "/records/images/xlarge/";

const encoder = new TextEncoder();

function byCanonicalName<T>(entries: ReadonlyArray<readonly [string, T]>): ReadonlyMap<string, T> {
	return new Map(entries.map(([name, value]) => [name.normalize("NFC"), value]));
}

const recollectDomains = byCanonicalName([
	["Tauranga City Libraries Other Collection", "paekoroki.tauranga.govt.nz"],
	["Hastings Recollect", "hastings.recollect.co.nz"],
	["Lower Hutt MyRecollect", "huttcity.recollect.co.nz"],
	["Hocken Digital Collections", "hocken.recollect.co.nz"],
	["National Army Museum", "nam.recollect.co.nz"],
	["Tāmiro", "massey.recollect.co.nz"],
	["He Purapura Marara Scattered Seeds", "dunedin.recollect.co.nz"],
	["Clutha Heritage", "clutha.recollect.co.nz"],
]);

const flickrSizeRank = new Map<string, number>([
	["o", 100], ["6k", 90], ["5k", 80], ["4k", 70], ["3k", 60], ["k", 50], ["h", 40],
	["b", 30], ["c", 20], ["z", 10], ["w", 6], ["m", 5], ["n", 4], ["q", 3], ["t", 2], ["s", 1],
]);

const flickrObjectURLElse =
	(fallback: URLStrategy): URLStrategy =>
	(record, url, context) =>
		record.object_url ?? fallback(record, url, context);

/** The strategy registry. Collections not listed here fall through to `legacyStrategy`. */
export const strategies: ReadonlyMap<string, URLStrategy> = byCanonicalName<URLStrategy>([
	["Tauranga City Libraries Other Collection", recollectLargest],
	["Hastings Recollect", recollectLargest],
	["Lower Hutt MyRecollect", recollectLargest],
	["Hocken Digital Collections", recollectDisplayMax],
	["He Purapura Marara Scattered Seeds", recollectLargest],
	["Clutha Heritage", recollectLargest],
	["John Kinder Theological Library", recollectOgImageMaster],
	["Tasman Heritage", recollectOgImageMaster],
	["Western Bay Community Archives", recollectOgImageMaster],
	["Far North District Libraries Rediscovery", recollectOgImageMaster],
	["Pakiaka Rotorua Heritage Online", recollectOgImageMaster],
	["Ministry for Culture and Heritage Te Ara Flickr", flickrLandingLargest],
	["Alexander Turnbull Library Flickr", flickrObjectURLElse(flickrLargest)],
	["Dunedin City Council Archives Flickr", flickrObjectURLElse(flickrLargest)],
	["State Library of New South Wales Flickr", flickrLandingLargest],
	["Australian National Maritime Museum Flickr", flickrObjectURLElse(flickrLandingLargest)],
	[
		"Kura Heritage Collections Online",
		(_record, url) =>
			ripId(
				url,
				(id) => `https://kura.aucklandlibraries.govt.nz/iiif/2/photos:${id}/full/max/0/default.jpg`,
				"/image/photos/",
				"/default.jpg",
			),
	],
	["Victoria and Albert Museum", vamIIIFLargest],
	["Mataura Museum NZMuseums", ehiveIIIFLargest],
	["Howick Historical Village NZMuseums", ehiveIIIFLargest],
	["New Zealand Portrait Gallery NZMuseums", ehiveIIIFLargest],
	["Te Hikoi Museum", ehiveIIIFLargest],
	["Te Toi Uku, Crown Lynn and Clayworks Museum", ehiveIIIFLargest],
	["Te Ūaka The Lyttelton Museum", ehiveIIIFLargest],
	["Wyndham & Districts Historical Museum", ehiveIIIFLargest],
	["The University of Waikato Art Collection", ehiveIIIFLargest],
	["Te Ahu Museum", stringSwap(VERNON_LARGE, VERNON_XLARGE)],
	["Ngā Puhipuhi o Te Herenga Waka—Victoria University of Wellington Art Collection", vernonBrowserLargest],
	["Nelson Provincial Museum", stringSwap(VERNON_LARGE, VERNON_XLARGE)],
	["Puke Ariki", stringSwap(VERNON_LARGE, VERNON_XLARGE)],
	["Te Papa Collections Online", tePapaLargest],
	["Auckland Museum Collections", aklMuseumCloudimg],
	["Hawke's Bay Knowledge Bank", knowledgeBankMaster],
	["TAPUHI", tapuhiConverter],
	["Feilding Library", feildingConverter],
	["Kete Horowhenua", keteHorowhenuaOriginal],
	["Manawatū Heritage", manawatuHeritageOriginal],
	["War Art Online", warArtConverter],
]);

/** The Swift `switch` fallback for collections not yet migrated to the registry. */
function legacyStrategy(collection: string): URLStrategy {
	switch (collection) {
		case "Canterbury Museum":
		case "Culture Waitaki":
			return (_record, url) => url.replaceAll("large", "xlarge");
		case "Tāmiro":
			return (_record, url) => recollectDownloadUrlString(url, collection);
		case "Antarctica NZ Digital Asset Manager":
		case "National Publicity Studios black and white file prints":
		case "South Canterbury Museum":
		case "Waimate Museum and Archives PastPerfect":
		case "V.C. Browne & Son NZ Aerial Photograph Collection":
			return passthrough;
		case "Auckland Art Gallery Toi o Tāmaki":
			return (_record, url) => url.replaceAll("medium", "xlarge");
		case "National Army Museum":
			return nationalArmyMuseum;
		default:
			return passthrough;
	}
}

/** Swift `URLProcessor.getLargerImage(for:)`. */
export async function getLargerImage(record: NZImage, context: RequestContext): Promise<NZImage> {
	const collection = record.display_collection;
	if (collection === undefined) throw new ApiError("nilCollection", { id: String(record.id) });

	const name = collection.normalize("NFC");
	const strategy = strategies.get(name) ?? legacyStrategy(name);

	const url = record.large_thumbnail_url;
	if (url === undefined) throw new ApiError("nilUrl", { collection });

	const finalURL = swiftURLString(await strategy(record, url, context));
	if (finalURL === null) throw new ApiError("unableToCreateFinalUrl", { collection });

	return { ...record, large_thumbnail_url: finalURL };
}

// MARK: Pure platform strategies

export function passthrough(_record: NZImage, url: string): string {
	return url;
}

/** Builds a strategy that replaces every occurrence of `from` with `to`. */
export function stringSwap(from: string, to: string): (record: NZImage, url: string) => string {
	return (_record, url) => url.replaceAll(from, to);
}

export function ripId(url: string, to: (id: string) => string, startString: string, endString: string): string {
	const id = slice(url, startString, endString);
	return id === undefined ? url : to(id);
}

/** Flickr: swap the size suffix for `_b` (1024 px), the largest size sharing the base secret. */
export function flickrLargest(_record: NZImage, url: string): string {
	const lastSlash = url.lastIndexOf("/");
	if (!url.includes("staticflickr.com") || lastSlash < 0) return url;

	const prefix = url.slice(0, lastSlash + 1);
	const file = url.slice(lastSlash + 1);
	if (!file.endsWith(".jpg")) return url;

	const stem = file.slice(0, -".jpg".length);
	const parts = splitNonEmpty(stem, "_");
	const newStem = parts.length >= 3 ? `${parts.slice(0, -1).join("_")}_b` : `${stem}_b`;
	return `${prefix}${newStem}.jpg`;
}

/** eHive: the public IIIF service over the master TIFF serves the full native size. */
export function ehiveIIIFLargest(_record: NZImage, url: string): string {
	const filename = lastPathComponent(url);
	if (!url.includes("images.ehive.com") || !filename.endsWith(".jpg")) return url;

	const stem = filename.slice(0, -".jpg".length);
	const lastUnderscore = stem.lastIndexOf("_");
	if (lastUnderscore < 0) return url;

	const components = pathComponents(url);
	if (components.length === 0) return url;
	components[components.length - 1] = `${stem.slice(0, lastUnderscore)}.tif`;
	const identifier = components.join("/").replaceAll("/", "%2f");

	return `https://iiif.ehive.com/iiif/2/${identifier}/full/full/0/default.jpg`;
}

/** V&A: the IIIF service keyed by the harvested filename stem, up to its 2500 px cap. */
export function vamIIIFLargest(_record: NZImage, url: string): string {
	if (!url.includes("vam.ac.uk") || pathExtension(url).toLowerCase() !== "jpg") return url;

	const stem = lastPathComponentWithoutExtension(url);
	const id = stem.endsWith("_jpg_w") ? stem.slice(0, -"_jpg_w".length) : stem;
	if (id.length === 0) return url;

	return `https://framemark.vam.ac.uk/collections/${id}/full/max/0/default.jpg`;
}

/** Proxy through images.weserv.nl at native resolution (bypasses hotlink protection). */
export function weservProxy(_record: NZImage, url: string): string {
	return `https://images.weserv.nl/?url=${percentEncode(url, isURLHostAllowed)}`;
}

// MARK: Recollect

export function recollectDomain(collection: string): string {
	const domain = recollectDomains.get(collection.normalize("NFC"));
	if (domain === undefined) throw new ApiError("unableToFindRecollectDomain", { collection });
	return domain;
}

export function recollectDownloadUrlString(url: string, collection: string): string {
	const domain = recollectDomain(collection);
	return ripId(url, (id) => `https://${domain}/assets/downloadwiz/${id}`, "display/", "-600");
}

function recollectDomainForRecord(record: NZImage): string | undefined {
	const collection = record.display_collection;
	return collection === undefined ? undefined : recollectDomains.get(collection.normalize("NFC"));
}

/** Recollect where `downloadwiz` masters are disabled: serve the `-max` display derivative. */
export function recollectDisplayMax(record: NZImage, url: string): string {
	const domain = recollectDomainForRecord(record);
	const id = slice(url, "display/", "-");
	if (domain === undefined || id === undefined) return url;
	return `https://${domain}/assets/display/${id}-max`;
}

/** The `downloadwiz` master when a HEAD reaches 200, otherwise the `-max` derivative. */
async function recollectMasterOrMax(host: string, id: string, http: Http): Promise<string> {
	const downloadwiz = `https://${host}/assets/downloadwiz/${id}`;
	return (await http.headStatus(downloadwiz)) === 200 ? downloadwiz : `https://${host}/assets/display/${id}-max`;
}

async function recollectLargest(record: NZImage, url: string, { http }: RequestContext): Promise<string> {
	const domain = recollectDomainForRecord(record);
	const id = slice(url, "display/", "-");
	if (domain === undefined || id === undefined) return url;
	return recollectMasterOrMax(domain, id, http);
}

/** Recollect two-asset records: the landing page's `og:image` names the master-bearing asset. */
async function recollectOgImageMaster(record: NZImage, url: string, { http }: RequestContext): Promise<string> {
	const landing = record.landing_url;
	if (landing === undefined) return url;

	let html: string;
	try {
		html = await http.fetchHTML(landing);
	} catch {
		return url;
	}

	const content = ogImageContent(html);
	if (content === undefined) return url;
	const ogURL = swiftURLString(content);
	const host = ogURL === null ? undefined : urlHost(ogURL);
	const id = slice(content, "display/", "-");
	if (host === undefined || id === undefined) return url;

	return recollectMasterOrMax(host, id, http);
}

/** Legacy `switch` case: `og:image` to `downloadwiz`, unprobed. Falls back to the `og:image` URL itself. */
async function nationalArmyMuseum(record: NZImage, url: string, { http }: RequestContext): Promise<string> {
	const landing = record.landing_url;
	if (landing === undefined) return url;

	let html: string;
	try {
		html = await http.fetchHTML(landing);
	} catch {
		return url;
	}

	const content = ogImageContent(html);
	const contentURL = content === undefined ? null : swiftURLString(content);
	const host = contentURL === null ? undefined : urlHost(contentURL);
	if (contentURL === null || host === undefined) return url;

	return ripId(contentURL, (id) => `https://${host}/assets/downloadwiz/${id}`, "display/", "-max");
}

/** The landing page's `/item/<uuid>/files/<fileId>/download?variant=original` link. */
async function recollectOriginalDownloadURL(record: NZImage, hostSuffix: string, http: Http): Promise<string | undefined> {
	const landing = record.landing_url;
	const host = landing === undefined ? undefined : urlHost(landing);
	if (landing === undefined || host === undefined || !host.endsWith(hostSuffix)) return undefined;

	let html: string;
	try {
		html = await http.fetchHTML(landing);
	} catch {
		return undefined;
	}

	const path = RECOLLECT_ORIGINAL_DOWNLOAD.exec(html)?.[0];
	return path === undefined ? undefined : `${urlScheme(landing) ?? "https"}://${host}${path}`;
}

/** Feilding Library: the ~25 MP TIFF original, through the converter. */
async function feildingConverter(record: NZImage, url: string, { http, env }: RequestContext): Promise<string> {
	const downloadURL = await recollectOriginalDownloadURL(record, "feildingheritage.nz", http);
	if (downloadURL === undefined) return url;
	return (await signedConverterURL(downloadURL, env)) ?? url;
}

/** Kete Horowhenua: the original is always JPEG, so serve it directly once a ranged GET confirms it. */
async function keteHorowhenuaOriginal(record: NZImage, url: string, { http }: RequestContext): Promise<string> {
	const downloadURL = await recollectOriginalDownloadURL(record, "kete.net.nz", http);
	if (downloadURL === undefined) return url;
	const { status } = await http.rangeProbe(downloadURL);
	return status === 200 || status === 206 ? downloadURL : url;
}

/** Manawatū Heritage: mixed formats, so JPEG originals are served directly and the rest converted. */
async function manawatuHeritageOriginal(record: NZImage, url: string, { http, env }: RequestContext): Promise<string> {
	const downloadURL = await recollectOriginalDownloadURL(record, "manawatuheritage.pncc.govt.nz", http);
	if (downloadURL === undefined) return url;

	const { status, contentType } = await http.rangeProbe(downloadURL);
	if (status !== 200 && status !== 206) return url;
	if (contentType?.includes("jpeg")) return downloadURL;
	return (await signedConverterURL(downloadURL, env)) ?? url;
}

// MARK: Flickr

/** Flickr with no `object_url`: the larger sizes' secrets are only on the photo page. */
async function flickrLandingLargest(record: NZImage, url: string, { http }: RequestContext): Promise<string> {
	const photoId = splitNonEmpty(lastPathComponent(url), "_")[0];
	const landing = record.landing_url;
	if (!url.includes("staticflickr.com") || photoId === undefined || landing === undefined) {
		return flickrLargest(record, url);
	}

	let html: string;
	let pattern: RegExp;
	try {
		html = await http.fetchHTML(landing);
		pattern = new RegExp(`live\\.staticflickr\\.com/[0-9]+/${photoId}_[0-9a-z]+_([0-9a-z]+)\\.(?:jpg|png|gif)`, "g");
	} catch {
		return flickrLargest(record, url);
	}

	let bestURL: string | undefined;
	let bestRank = -1;
	for (const match of html.replaceAll("\\/", "/").matchAll(pattern)) {
		const rank = flickrSizeRank.get(match[1]!) ?? 0;
		if (rank > bestRank) {
			bestRank = rank;
			bestURL = `https://${match[0]}`;
		}
	}
	return bestURL ?? flickrLargest(record, url);
}

// MARK: Museum APIs and CDNs

/** Te Papa: `/full` when a ranged GET finds it (open-access records), else weserv-proxied `/preview`. */
async function tePapaLargest(record: NZImage, url: string, { http }: RequestContext): Promise<string> {
	if (!url.includes("media.tepapa.govt.nz") || !url.endsWith("/preview")) return weservProxy(record, url);

	const full = `${url.slice(0, -"/preview".length)}/full`;
	const { status } = await http.rangeProbe(full);
	return status === 200 || status === 206 ? full : weservProxy(record, url);
}

/** Auckland Museum: the native master via cloudimg, from the public API's `object_av_link`. */
async function aklMuseumCloudimg(record: NZImage, url: string, { http }: RequestContext): Promise<string> {
	const landingId = record.landing_url === undefined ? undefined : splitNonEmpty(record.landing_url, "/").at(-1);
	if (landingId === undefined) return url;

	let avLink: string | undefined;
	try {
		const response = decodeAKLMuseumResponse(
			await http.getJSON(`https://collection-publicapi.aucklandmuseum.com/api/v3/opacobjects/${landingId}`),
		);
		avLink = response.opacObjectFieldSets?.find((fieldSet) => fieldSet.identifier === "object_av_link")
			?.opacObjectFields?.[0]?.value;
	} catch {
		return url;
	}
	if (avLink === undefined) return url;

	// "J:\Dir\Sub\full\File.jpg|20||Rights..." -> "Dir/Sub/full/File.jpg"
	let path = splitNonEmpty(avLink, "|")[0]?.replaceAll("\\", "/");
	if (path === undefined) return url;
	const characters = Array.from(path);
	if (characters.length >= 2 && characters[1] === ":") path = characters.slice(2).join("");
	while (path.startsWith("/")) path = path.slice(1);
	if (path.length === 0) return url;

	const encoded = percentEncode(path, (character) => isAlphanumeric(character) || "-._~".includes(character));
	return `https://ajrctguoxo.cloudimg.io/v7/_collectionsecure_%2F${encoded}?ci_url_encoded=1&force_format=jpeg&org_if_sml=1`;
}

/** Hawke's Bay Knowledge Bank: the honest-native `/master/` original listed on the landing page. */
async function knowledgeBankMaster(record: NZImage, url: string, { http }: RequestContext): Promise<string> {
	const parts = pathComponents(url);
	const landing = record.landing_url;
	if (
		!url.includes("cdn.knowledgebank.org.nz") ||
		parts.length < 4 ||
		parts[0] !== "node" ||
		parts[2] !== "images" ||
		landing === undefined
	) {
		return url;
	}
	const nodeId = parts[1]!;
	const filename = lastPathComponent(url);

	const stem = filename.replace(/\.jpe?g$/i, "");
	if (stem === filename) return url;
	const base = stem.replace(/-\d+x\d+(-\d+)?$/i, "");
	const baseVariant = base.replace(/-\d+$/, "");
	const wanted = new Set([base.toLowerCase(), baseVariant.toLowerCase()]);

	let html: string;
	let pattern: RegExp;
	try {
		html = await http.fetchHTML(
			landing.replaceAll("https://knowledgebank.org.nz", "https://www.knowledgebank.org.nz"),
		);
		pattern = new RegExp(
			`https://cdn\\.knowledgebank\\.org\\.nz/node/${nodeId}/master/([^"' <>]+?)\\.(?:jpg|jpeg|png)`,
			"gi",
		);
	} catch {
		return url;
	}

	const masters = new Map<string, string>();
	for (const match of html.matchAll(pattern)) {
		if (!masters.has(match[0])) masters.set(match[0], match[1]!.toLowerCase());
	}

	if (masters.size === 1) return masters.keys().next().value!;
	for (const [master, masterStem] of masters) {
		if (wanted.has(masterStem)) return master;
	}
	return url;
}

/** Vernon Browser sites where some records lack an `xlarge`: HEAD-probe it first. */
async function vernonBrowserLargest(_record: NZImage, url: string, { http }: RequestContext): Promise<string> {
	if (!url.includes(VERNON_LARGE)) return url;
	const xlarge = url.replaceAll(VERNON_LARGE, VERNON_XLARGE);
	return (await http.headStatus(xlarge)) === 200 ? xlarge : url;
}

// MARK: Converter (JP2/TIFF masters)

/**
 * `<JP2_CONVERTER_URL>/?url=<encoded sourceURL>&sig=<hex HMAC-SHA256(CONVERTER_SIGNING_KEY, sourceURL)>`,
 * or null when either binding is unset, so callers fall back to the harvested URL.
 */
export async function signedConverterURL(sourceURL: string, env: ApiEnv): Promise<string | null> {
	const base = env.JP2_CONVERTER_URL;
	const key = env.CONVERTER_SIGNING_KEY;
	if (!base || !key) return null;

	const hmacKey = await crypto.subtle.importKey("raw", encoder.encode(key), { name: "HMAC", hash: "SHA-256" }, false, [
		"sign",
	]);
	const mac = new Uint8Array(await crypto.subtle.sign("HMAC", hmacKey, encoder.encode(sourceURL)));
	const sig = Array.from(mac, (byte) => byte.toString(16).padStart(2, "0")).join("");

	const trimmed = base.endsWith("/") ? base.slice(0, -1) : base;
	return `${trimmed}/?url=${percentEncode(sourceURL, isAlphanumeric)}&sig=${sig}`;
}

/** TAPUHI (NDHA/Rosetta): the largest JP2 master from the METS, through the converter. */
async function tapuhiConverter(_record: NZImage, url: string, { http, env }: RequestContext): Promise<string> {
	let flStreamURL: string;
	try {
		flStreamURL = await resolveTapuhiFLStreamURL(url, http);
	} catch {
		return url;
	}
	return (await signedConverterURL(flStreamURL, env)) ?? url;
}

async function resolveTapuhiFLStreamURL(url: string, http: Http): Promise<string> {
	const dpsMatch = /dps_pid=IE(\d+)/.exec(url);
	const iePID = dpsMatch ? `IE${dpsMatch[1]}` : /IE\d+/.exec(url)?.[0];
	if (iePID === undefined) throw new ApiError("unableToExtractIEPID", { url });

	const mets = await http.fetchHTML(`${NDHA_BASE}/delivery/DeliveryManagerServlet?dps_pid=${iePID}&dps_func=mets`);
	const flPID = largestTapuhiJP2PID(mets, 100 * 1024 * 1024);
	if (flPID === undefined) throw new ApiError("noFilesFound", { url, iePID });

	return `${NDHA_BASE}/delivery/DeliveryManagerServlet?dps_pid=${flPID}&dps_func=stream`;
}

/** War Art Online (NDHA/Rosetta): the TIFF master through the converter, unless the baseline is already full size. */
async function warArtConverter(_record: NZImage, url: string, { http, env }: RequestContext): Promise<string> {
	let flStreamURL: string;
	try {
		flStreamURL = await resolveWarArtFLStreamURL(url, http);
	} catch {
		return url;
	}
	return (await signedConverterURL(flStreamURL, env)) ?? url;
}

async function resolveWarArtFLStreamURL(url: string, http: Http): Promise<string> {
	const iePID = /IE\d+/.exec(url)?.[0];
	if (iePID === undefined) throw new ApiError("unableToExtractIEPID", { url });

	const mets = await http.fetchHTML(`${NDHA_BASE}/delivery/DeliveryManagerServlet?dps_pid=${iePID}&dps_func=mets`);
	// 110 MB matches the converter's own download cap.
	const flPID = warArtMasterFLPID(mets, 110 * 1024 * 1024, 700 * 1024);
	if (flPID === undefined) throw new ApiError("noFilesFound", { url, iePID });

	return `${NDHA_BASE}/delivery/DeliveryManagerServlet?dps_pid=${flPID}&dps_func=stream`;
}

interface METSFile {
	pid: string;
	body: string;
	size: number | undefined;
}

function* metsFiles(mets: string): Generator<METSFile> {
	for (const match of mets.matchAll(METS_AMD_SEC)) {
		const body = match[2]!;
		const digits = METS_FILE_SIZE.exec(body)?.[1];
		yield { pid: match[1]!, body, size: digits === undefined ? undefined : Number(digits) };
	}
}

const hasMIMEType = (body: string, mimeType: string) => body.includes(`<key id="fileMIMEType">${mimeType}</key>`);

/** The FL PID of the largest `image/jp2` file no larger than `maxBytes`. */
export function largestTapuhiJP2PID(mets: string, maxBytes: number): string | undefined {
	let bestPID: string | undefined;
	let bestSize = -1;
	for (const { pid, body, size } of metsFiles(mets)) {
		if (!hasMIMEType(body, "image/jp2") || size === undefined) continue;
		if (size <= maxBytes && size > bestSize) {
			bestSize = size;
			bestPID = pid;
		}
	}
	return bestPID;
}

/**
 * The FL PID of the TIFF master to convert, or undefined to serve the harvested baseline: when no
 * TIFF fits under `maxBytes`, or (with no PDF compilation present) when the largest access JPEG is
 * at least `accessPassthroughThreshold` bytes, meaning it is already full resolution.
 */
export function warArtMasterFLPID(mets: string, maxBytes: number, accessPassthroughThreshold: number): string | undefined {
	let bestTIFFPID: string | undefined;
	let bestTIFFSize = -1;
	let largestAccessJPEG = -1;
	let hasPDF = false;

	for (const { pid, body, size = -1 } of metsFiles(mets)) {
		if (hasMIMEType(body, "image/tiff")) {
			if (size <= maxBytes && size > bestTIFFSize) {
				bestTIFFSize = size;
				bestTIFFPID = pid;
			}
		} else if (hasMIMEType(body, "image/jpeg")) {
			largestAccessJPEG = Math.max(largestAccessJPEG, size);
		} else if (hasMIMEType(body, "application/pdf")) {
			hasPDF = true;
		}
	}

	if (bestTIFFPID === undefined) return undefined;
	if (hasPDF) return bestTIFFPID;
	if (largestAccessJPEG >= accessPassthroughThreshold) return undefined;
	return bestTIFFPID;
}
