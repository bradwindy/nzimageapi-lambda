// Ports URLProcessorPureHelperTests, GetLargerImageTests, URLProcessorMETSParsingTests and
// SignedConverterURLTests.

import { describe, expect, it } from "vitest";
import { ApiError } from "../src/errors.ts";
import {
	ehiveIIIFLargest,
	flickrLargest,
	getLargerImage,
	largestTapuhiJP2PID,
	passthrough,
	recollectDisplayMax,
	recollectDomain,
	recollectDownloadUrlString,
	ripId,
	signedConverterURL,
	stringSwap,
	vamIIIFLargest,
	warArtMasterFLPID,
	weservProxy,
} from "../src/urlProcessor.ts";
import { makeRecord, testContext } from "./helpers.ts";

const record = makeRecord();

describe("flickrLargest", () => {
	it("appends _b when there is no size token", () => {
		expect(flickrLargest(record, "https://live.staticflickr.com/1234/9999_abcde.jpg")).toBe(
			"https://live.staticflickr.com/1234/9999_abcde_b.jpg",
		);
	});

	it("replaces an existing size token with b", () => {
		expect(flickrLargest(record, "https://live.staticflickr.com/1234/9999_abcde_z.jpg")).toBe(
			"https://live.staticflickr.com/1234/9999_abcde_b.jpg",
		);
	});

	it("passes through a non-Flickr host", () => {
		const url = "https://example.com/9999_abcde_z.jpg";
		expect(flickrLargest(record, url)).toBe(url);
	});

	it("passes through a non-jpg extension", () => {
		const url = "https://live.staticflickr.com/1234/9999_abcde.png";
		expect(flickrLargest(record, url)).toBe(url);
	});
});

describe("ehiveIIIFLargest", () => {
	it("builds the master TIFF IIIF URL", () => {
		expect(ehiveIIIFLargest(record, "https://images.ehive.com/accounts/4033/objects/images/ce51j4_1i1a_l.jpg")).toBe(
			"https://iiif.ehive.com/iiif/2/accounts%2f4033%2fobjects%2fimages%2fce51j4_1i1a.tif/full/full/0/default.jpg",
		);
	});

	it("passes through a non-eHive host", () => {
		const url = "https://example.com/accounts/4033/objects/images/ce51j4_1i1a_l.jpg";
		expect(ehiveIIIFLargest(record, url)).toBe(url);
	});

	it("passes through when the stem has no underscore", () => {
		const url = "https://images.ehive.com/accounts/4033/objects/images/abcdefgh.jpg";
		expect(ehiveIIIFLargest(record, url)).toBe(url);
	});
});

describe("vamIIIFLargest", () => {
	it("builds the framemark URL", () => {
		expect(vamIIIFLargest(record, "https://media.vam.ac.uk/media/thira/collection_images/2025PE4780/2025PE4780.jpg")).toBe(
			"https://framemark.vam.ac.uk/collections/2025PE4780/full/max/0/default.jpg",
		);
	});

	it("strips the _jpg_w suffix", () => {
		expect(
			vamIIIFLargest(record, "https://media.vam.ac.uk/media/thira/collection_images/2025PE4780/2025PE4780_jpg_w.jpg"),
		).toBe("https://framemark.vam.ac.uk/collections/2025PE4780/full/max/0/default.jpg");
	});

	it("passes through a non-V&A host", () => {
		const url = "https://example.com/2025PE4780.jpg";
		expect(vamIIIFLargest(record, url)).toBe(url);
	});
});

describe("weservProxy", () => {
	it("builds a percent-encoded proxy URL", () => {
		const url = "https://example.com/some/image.jpg?a=b&c=d";
		const prefix = "https://images.weserv.nl/?url=";
		const result = weservProxy(record, url);

		expect(result.startsWith(prefix)).toBe(true);
		expect(decodeURIComponent(result.slice(prefix.length))).toBe(url);
	});
});

describe("stringSwap", () => {
	const strategy = stringSwap("/records/images/large/", "/records/images/xlarge/");

	it("swaps the token", () => {
		expect(strategy(record, "https://example.com/records/images/large/1/hash.jpg")).toBe(
			"https://example.com/records/images/xlarge/1/hash.jpg",
		);
	});

	it("leaves a non-matching URL unchanged", () => {
		expect(strategy(record, "https://example.com/foo.jpg")).toBe("https://example.com/foo.jpg");
	});
});

describe("ripId", () => {
	it("slices the id and applies the transform", () => {
		const url = "https://kura.aucklandlibraries.govt.nz/image/photos/ABC123/default.jpg";
		expect(ripId(url, (id) => `id-was-${id}`, "/image/photos/", "/default.jpg")).toBe("id-was-ABC123");
	});

	it("returns the original URL when a marker is absent", () => {
		const url = "https://example.com/other/path.jpg";
		expect(ripId(url, (id) => `id-was-${id}`, "/image/photos/", "/default.jpg")).toBe(url);
	});
});

describe("Recollect helpers", () => {
	it("returns the domain for a known collection", () => {
		expect(recollectDomain("Hastings Recollect")).toBe("hastings.recollect.co.nz");
		expect(recollectDomain("Hocken Digital Collections")).toBe("hocken.recollect.co.nz");
	});

	it("throws unableToFindRecollectDomain for an unknown collection", () => {
		expect(() => recollectDomain("Not A Recollect Collection")).toThrow(
			expect.objectContaining({ kind: "unableToFindRecollectDomain" }),
		);
	});

	it("builds the downloadwiz path", () => {
		expect(recollectDownloadUrlString("https://hastings.recollect.co.nz/assets/display/12345-600", "Hastings Recollect")).toBe(
			"https://hastings.recollect.co.nz/assets/downloadwiz/12345",
		);
	});

	it("throws building a download URL for an unknown collection", () => {
		expect(() => recollectDownloadUrlString("https://example.com/assets/display/12345-600", "Unknown")).toThrow(ApiError);
	});

	it("builds the -max display path", () => {
		const hocken = makeRecord({ display_collection: "Hocken Digital Collections" });
		expect(recollectDisplayMax(hocken, "https://hocken.recollect.co.nz/assets/display/98765-600")).toBe(
			"https://hocken.recollect.co.nz/assets/display/98765-max",
		);
	});

	it("falls back to the URL for an unknown collection", () => {
		const unknown = makeRecord({ display_collection: "Unknown Collection" });
		const url = "https://example.com/assets/display/98765-600";
		expect(recollectDisplayMax(unknown, url)).toBe(url);
	});
});

describe("passthrough", () => {
	it("returns the current URL unchanged", () => {
		expect(passthrough(record, "https://example.com/img.jpg")).toBe("https://example.com/img.jpg");
	});
});

describe("getLargerImage", () => {
	async function finalURL(display_collection: string, large_thumbnail_url: string, object_url?: string) {
		const result = await getLargerImage(
			makeRecord({ display_collection, large_thumbnail_url, ...(object_url ? { object_url } : {}) }),
			testContext(),
		);
		return result.large_thumbnail_url;
	}

	it("throws nilCollection when the collection is missing", async () => {
		const { display_collection: _, ...noCollection } = makeRecord({ large_thumbnail_url: "https://example.com/x.jpg" });
		await expect(getLargerImage(noCollection, testContext())).rejects.toMatchObject({ kind: "nilCollection" });
	});

	it("throws nilUrl when large_thumbnail_url is missing", async () => {
		const noURL = makeRecord({ display_collection: "Some Unrecognised Collection" });
		await expect(getLargerImage(noURL, testContext())).rejects.toMatchObject({ kind: "nilUrl" });
	});

	it("Kura Heritage: CONTENTdm IIIF", async () => {
		expect(
			await finalURL(
				"Kura Heritage Collections Online",
				"https://kura.aucklandlibraries.govt.nz/image/photos/ABC123/default.jpg",
			),
		).toBe("https://kura.aucklandlibraries.govt.nz/iiif/2/photos:ABC123/full/max/0/default.jpg");
	});

	it("Victoria and Albert Museum: IIIF", async () => {
		expect(
			await finalURL(
				"Victoria and Albert Museum",
				"https://media.vam.ac.uk/media/thira/collection_images/2025PE4780/2025PE4780.jpg",
			),
		).toBe("https://framemark.vam.ac.uk/collections/2025PE4780/full/max/0/default.jpg");
	});

	it("Mataura Museum: eHive IIIF", async () => {
		expect(
			await finalURL("Mataura Museum NZMuseums", "https://images.ehive.com/accounts/4033/objects/images/ce51j4_1i1a_l.jpg"),
		).toBe("https://iiif.ehive.com/iiif/2/accounts%2f4033%2fobjects%2fimages%2fce51j4_1i1a.tif/full/full/0/default.jpg");
	});

	it("Te Ahu Museum: Vernon string swap", async () => {
		expect(await finalURL("Te Ahu Museum", "https://cdn.example.com/records/images/large/01/hash.jpg")).toBe(
			"https://cdn.example.com/records/images/xlarge/01/hash.jpg",
		);
	});

	it("Hocken: Recollect -max", async () => {
		expect(await finalURL("Hocken Digital Collections", "https://hocken.recollect.co.nz/assets/display/98765-600")).toBe(
			"https://hocken.recollect.co.nz/assets/display/98765-max",
		);
	});

	it("Alexander Turnbull Library Flickr prefers object_url", async () => {
		expect(
			await finalURL(
				"Alexander Turnbull Library Flickr",
				"https://live.staticflickr.com/1234/9999_abcde.jpg",
				"https://example.com/original.jpg",
			),
		).toBe("https://example.com/original.jpg");
	});

	it("Canterbury Museum: large to xlarge", async () => {
		expect(await finalURL("Canterbury Museum", "https://example.com/path/large/image.jpg")).toBe(
			"https://example.com/path/xlarge/image.jpg",
		);
	});

	it("Culture Waitaki: large to xlarge", async () => {
		expect(await finalURL("Culture Waitaki", "https://example.com/path/large/image.jpg")).toBe(
			"https://example.com/path/xlarge/image.jpg",
		);
	});

	it("Auckland Art Gallery: medium to xlarge", async () => {
		expect(await finalURL("Auckland Art Gallery Toi o Tāmaki", "https://example.com/path/medium/image.jpg")).toBe(
			"https://example.com/path/xlarge/image.jpg",
		);
	});

	it("Tāmiro: Recollect downloadwiz", async () => {
		expect(await finalURL("Tāmiro", "https://massey.recollect.co.nz/assets/display/55555-600")).toBe(
			"https://massey.recollect.co.nz/assets/downloadwiz/55555",
		);
	});

	it("South Canterbury Museum: passthrough", async () => {
		const url = "https://example.com/path/original/image.jpg";
		expect(await finalURL("South Canterbury Museum", url)).toBe(url);
	});

	it("an unknown collection defaults to passthrough", async () => {
		const url = "https://example.com/path/original/image.jpg";
		expect(await finalURL("Some Totally Unrecognised Collection", url)).toBe(url);
	});
});

describe("METS parsing", () => {
	const amdSec = (pid: string, mime: string, sizeBytes: number) => `<mets:amdSec ID="${pid}-amd">
    <key id="fileMIMEType">${mime}</key>
    <key id="fileSizeBytes">${sizeBytes}</key>
</mets:amdSec>`;
	const mets = (blocks: string[]) => `<mets:mets>${blocks.join("")}</mets:mets>`;

	describe("largestTapuhiJP2PID", () => {
		it("picks the largest JP2 under the cap", () => {
			const xml = mets([amdSec("FL1", "image/jp2", 1000), amdSec("FL2", "image/jp2", 5000)]);
			expect(largestTapuhiJP2PID(xml, 10000)).toBe("FL2");
		});

		it("skips TIFF and JPEG blocks", () => {
			const xml = mets([
				amdSec("FL1", "image/tiff", 999_999),
				amdSec("FL2", "image/jpeg", 500_000),
				amdSec("FL3", "image/jp2", 2000),
			]);
			expect(largestTapuhiJP2PID(xml, 10000)).toBe("FL3");
		});

		it("excludes JP2s over the cap", () => {
			const xml = mets([amdSec("FL1", "image/jp2", 50000), amdSec("FL2", "image/jp2", 3000)]);
			expect(largestTapuhiJP2PID(xml, 10000)).toBe("FL2");
		});

		it("returns undefined when no JP2 is present", () => {
			const xml = mets([amdSec("FL1", "image/tiff", 999_999), amdSec("FL2", "image/jpeg", 500_000)]);
			expect(largestTapuhiJP2PID(xml, 10000)).toBeUndefined();
		});

		it("returns undefined for malformed XML", () => {
			expect(largestTapuhiJP2PID("not xml at all, no amdSec blocks here", 10000)).toBeUndefined();
		});
	});

	describe("warArtMasterFLPID", () => {
		it("returns undefined when no TIFF is under the cap", () => {
			const xml = mets([amdSec("FL1", "image/jpeg", 500_000)]);
			expect(warArtMasterFLPID(xml, 10000, 700_000)).toBeUndefined();
		});

		it("returns the TIFF when a PDF is present, regardless of a large JPEG", () => {
			const xml = mets([
				amdSec("FL1", "image/tiff", 5000),
				amdSec("FL2", "application/pdf", 100),
				amdSec("FL3", "image/jpeg", 900_000),
			]);
			expect(warArtMasterFLPID(xml, 10000, 700_000)).toBe("FL1");
		});

		it("returns undefined when the access JPEG is at or above the threshold", () => {
			const xml = mets([amdSec("FL1", "image/tiff", 5000), amdSec("FL2", "image/jpeg", 900_000)]);
			expect(warArtMasterFLPID(xml, 10000, 700_000)).toBeUndefined();
		});

		it("returns the TIFF for a thumbnail-tier access JPEG", () => {
			const xml = mets([amdSec("FL1", "image/tiff", 5000), amdSec("FL2", "image/jpeg", 500_000)]);
			expect(warArtMasterFLPID(xml, 10000, 700_000)).toBe("FL1");
		});

		it("picks the largest TIFF under the cap", () => {
			const xml = mets([
				amdSec("FL1", "image/tiff", 2000),
				amdSec("FL2", "image/tiff", 50000),
				amdSec("FL3", "image/tiff", 8000),
				amdSec("FL4", "image/jpeg", 500_000),
			]);
			expect(warArtMasterFLPID(xml, 10000, 700_000)).toBe("FL3");
		});
	});
});

describe("signedConverterURL", () => {
	const sourceURL = "https://ndhadeliver.natlib.govt.nz/delivery/DeliveryManagerServlet?dps_pid=FL12345&dps_func=stream";

	it("matches the Python HMAC reference vector", async () => {
		const signed = await signedConverterURL(sourceURL, {
			JP2_CONVERTER_URL: "https://converter.example.com",
			CONVERTER_SIGNING_KEY: "test-signing-key-for-unit-tests",
		});
		expect(signed).toMatch(/&sig=ad32460761cd4e437111196c73a7b36aae697c3fd1217fa3dcf975307232e00f$/);
	});

	// Expected encoding checked against Foundation: "a/Tāmiro_x-y.z".addingPercentEncoding(
	// withAllowedCharacters: .alphanumerics) == "a%2FT%C4%81miro%5Fx%2Dy%2Ez".
	it("encodes everything but ASCII alphanumerics, as addingPercentEncoding(.alphanumerics) does", async () => {
		const signed = await signedConverterURL(`${sourceURL}&name=Tāmiro`, {
			JP2_CONVERTER_URL: "https://converter.example.com/",
			CONVERTER_SIGNING_KEY: "test-signing-key-for-unit-tests",
		});
		expect(signed).toMatch(
			/^https:\/\/converter\.example\.com\/\?url=https%3A%2F%2Fndhadeliver%2Enatlib%2Egovt%2Enz%2Fdelivery%2FDeliveryManagerServlet%3Fdps%5Fpid%3DFL12345%26dps%5Ffunc%3Dstream%26name%3DT%C4%81miro&sig=[0-9a-f]{64}$/,
		);
	});

	it("returns null when the signing key is unset", async () => {
		expect(await signedConverterURL("https://example.com/master.tif", { JP2_CONVERTER_URL: "https://converter.example.com" })).toBeNull();
	});

	it("returns null when the converter URL is unset", async () => {
		expect(await signedConverterURL("https://example.com/master.tif", { CONVERTER_SIGNING_KEY: "some-key" })).toBeNull();
	});
});
