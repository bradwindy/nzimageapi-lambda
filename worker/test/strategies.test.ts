// Network-backed strategies, which the Swift suite left untested. These cover the parts the
// port replaced: SwiftSoup (og:image), Alamofire probes, and Foundation percent-encoding.

import { http, HttpResponse } from "msw";
import { describe, expect, it } from "vitest";
import { BROWSER_USER_AGENT } from "../src/http.ts";
import { getLargerImage } from "../src/urlProcessor.ts";
import { makeRecord, testContext } from "./helpers.ts";
import { network } from "./network.ts";

async function finalURL(fields: Parameters<typeof makeRecord>[0]) {
	return (await getLargerImage(makeRecord(fields), testContext())).large_thumbnail_url;
}

describe("Recollect og:image master", () => {
	const landing = "https://tasman.recollect.co.nz/nodes/view/1";
	const html = `<html><head>
		<!-- <meta property="og:image" content="https://decoy.example/assets/display/1-max"> -->
		<meta content="https://heritage.tasmanlibraries.govt.nz/assets/display/4242-max?w=1&amp;h=2" property="og:image">
	</head></html>`;
	const record = {
		display_collection: "Tasman Heritage",
		landing_url: landing,
		large_thumbnail_url: "https://tasman.recollect.co.nz/assets/display/9-600",
	};

	it("serves the og:image asset's master when its HEAD reaches 200", async () => {
		network.use(
			http.get(landing, () => HttpResponse.html(html)),
			http.head("https://heritage.tasmanlibraries.govt.nz/assets/downloadwiz/4242", () => new Response(null, { status: 200 })),
		);
		expect(await finalURL(record)).toBe("https://heritage.tasmanlibraries.govt.nz/assets/downloadwiz/4242");
	});

	it("serves -max when the master redirects to an error page", async () => {
		network.use(
			http.get(landing, () => HttpResponse.html(html)),
			http.head(
				"https://heritage.tasmanlibraries.govt.nz/assets/downloadwiz/4242",
				() => new Response(null, { status: 302, headers: { location: "/error404" } }),
			),
			http.head("https://heritage.tasmanlibraries.govt.nz/error404", () => new Response(null, { status: 404 })),
		);
		expect(await finalURL(record)).toBe("https://heritage.tasmanlibraries.govt.nz/assets/display/4242-max");
	});
});

describe("Te Papa", () => {
	const preview = "https://media.tepapa.govt.nz/collection/123/preview";
	const record = { display_collection: "Te Papa Collections Online", large_thumbnail_url: preview };

	it("serves /full when a 1-byte ranged GET with a browser UA finds it", async () => {
		network.use(
			http.get("https://media.tepapa.govt.nz/collection/123/full", ({ request }) =>
				request.headers.get("range") === "bytes=0-0" && request.headers.get("user-agent") === BROWSER_USER_AGENT
					? new Response("x", { status: 206 })
					: new Response(null, { status: 400 }),
			),
		);
		expect(await finalURL(record)).toBe("https://media.tepapa.govt.nz/collection/123/full");
	});

	it("falls back to weserv-proxied /preview when /full errors", async () => {
		network.use(http.get("https://media.tepapa.govt.nz/collection/123/full", () => new Response(null, { status: 500 })));
		expect(await finalURL(record)).toBe(
			"https://images.weserv.nl/?url=https:%2F%2Fmedia.tepapa.govt.nz%2Fcollection%2F123%2Fpreview",
		);
	});
});

describe("Manawatū Heritage", () => {
	const landing = "https://manawatuheritage.pncc.govt.nz/item/abc";
	const download = "https://manawatuheritage.pncc.govt.nz/item/0a1b-2c/files/3d4e-5f/download?variant=original";
	const record = {
		display_collection: "Manawatū Heritage",
		landing_url: landing,
		large_thumbnail_url: "https://cache.example/iiif/full/!880,1024/0/default.jpg",
	};

	function serve(contentType: string) {
		network.use(
			http.get(landing, () => HttpResponse.html(`<a href="/item/0a1b-2c/files/3d4e-5f/download?variant=original">Download</a>`)),
			http.get(download, () => new Response(null, { status: 302, headers: { location: "https://s3.example/original" } })),
			http.get("https://s3.example/original", () => new Response("x", { status: 206, headers: { "content-type": contentType } })),
		);
	}

	it("serves a JPEG original directly", async () => {
		serve("image/jpeg");
		expect(await finalURL(record)).toBe(download);
	});

	it("routes any other original through the signed converter", async () => {
		serve("image/tiff");
		expect(await finalURL(record)).toMatch(
			/^https:\/\/converter\.example\.com\/\?url=https%3A%2F%2Fmanawatuheritage%2Epncc%2Egovt%2Enz%2Fitem%2F0a1b%2D2c%2Ffiles%2F3d4e%2D5f%2Fdownload%3Fvariant%3Doriginal&sig=[0-9a-f]{64}$/,
		);
	});
});

describe("Auckland Museum", () => {
	it("builds the cloudimg master URL from object_av_link", async () => {
		network.use(
			http.get("https://collection-publicapi.aucklandmuseum.com/api/v3/opacobjects/am_humanhistory-object-12", () =>
				HttpResponse.json({
					opacObjectFieldSets: [
						{ identifier: "other", opacObjectFields: [{ value: "x" }] },
						{
							identifier: "object_av_link",
							opacObjectFields: [{ value: "J:\\DocumentaryHeritage\\Sub Dir\\full\\Māori File.jpg|20||Rights" }],
						},
					],
				}),
			),
		);

		expect(
			await finalURL({
				display_collection: "Auckland Museum Collections",
				landing_url: "https://www.aucklandmuseum.com/collection/object/am_humanhistory-object-12",
				large_thumbnail_url: "https://collection-api.aucklandmuseum.com/records/images/medium/x.jpg",
			}),
		).toBe(
			"https://ajrctguoxo.cloudimg.io/v7/_collectionsecure_%2FDocumentaryHeritage%2FSub%20Dir%2Ffull%2FM%C4%81ori%20File.jpg?ci_url_encoded=1&force_format=jpeg&org_if_sml=1",
		);
	});
});
