//
//  File.swift
//
//
//  Created by Bradley Windybank on 30/06/23.
//

import Foundation
import RichError
import SwiftSoup

final class URLProcessor: Sendable {
    // MARK: Internal

    struct URLProcessorError: RichError {
        typealias ErrorKind = URLProcessorErrorKind

        enum URLProcessorErrorKind: String {
            case nilCollection
            case unknownCollectionName
            case nilUrl
            case unableToEscapeUrl
            case unableToCreateFinalUrl
            case unableToFindRecollectDomain
            case unableToExtractIEPID
            case unableToExtractDVS
            case noFilesFound
        }

        var kind: URLProcessorErrorKind
        var data: [String: String]
    }

    /// A reusable, per-collection URL-rewriting strategy. Receives the full `result`
    /// (so platform functions can read `collection`/`landingUrl`/`objectUrl`) plus the
    /// current `large_thumbnail_url`, and returns the final URL string.
    typealias URLStrategy = @Sendable (_ result: NZRecordsResult, _ url: URL) async throws -> String

    /// Per-collection strategy registry. Migrated incrementally during the high-res
    /// sweep: when a collection is (re)processed it gains an entry here and loses its
    /// legacy `switch` case in the same commit. Empty until the first migration; the
    /// `switch` below is the fallback during migration and becomes a bare
    /// `default: passthrough` once every collection has moved across.
    static let strategies: [String: URLStrategy] = [
        "Tauranga City Libraries Other Collection": { result, url in
            await recollectLargest(result, url)
        },
        "Hastings Recollect": { result, url in
            await recollectLargest(result, url)
        },
        "Lower Hutt MyRecollect": { result, url in
            await recollectLargest(result, url)
        },
        "Hocken Digital Collections": { result, url in
            recollectDisplayMax(result, url)
        },
        "He Purapura Marara Scattered Seeds": { result, url in
            await recollectLargest(result, url)
        },
        "Clutha Heritage": { result, url in
            // Healthy Recollect (Recollect Ltd / NZMS) — clutha.recollect.co.nz redirects to the
            // council vanity domain heritage.cluthadc.govt.nz. The harvested `-600`
            // display tier is ~1000 px-capped; the `downloadwiz` master is present for
            // ~99.5% of records (up to ~26 MP, 1.3×–36× the display area). The rare
            // pending-master records (and the small-original records whose `-600` is
            // upscaled-fake) fall back to / serve the honest `-max` native.
            await recollectLargest(result, url)
        },
        "John Kinder Theological Library": { result, url in
            // Recollect "two-asset" (cf. National Army Museum): the harvested large_thumbnail id is
            // a master-less display derivative — its `downloadwiz` 404s ("goDownload failed") and
            // `display/<id>-max` is capped ~1000 px — while the node page's `og:image` points to a
            // DIFFERENT primary asset whose `downloadwiz` master IS retained (80/80 sampled, up to
            // 31.5 MP). `recollectLargest` (which rips the harvested id) would regress every record
            // to ~1000 px, so we scrape the node `og:image` → master. 22/32 pixel-win (median 3.8×,
            // up to 43×), 8/32 equal (small ≤1000 px native), 2/32 honest-smaller (the upscaled-fake
            // `-600` vs the honest 800 px native — honest-native-always, cf. Clutha/Hocken/Kura).
            await recollectOgImageMaster(result, url)
        },
        "Tasman Heritage": { result, url in
            // Same Recollect two-asset shape as John Kinder (the harvested large_thumbnail id is a
            // master-less display derivative; the node og:image points to a DIFFERENT primary asset
            // whose downloadwiz master IS present — 80/80 sampled, up to 9803 px). Plus a Clutha-style
            // vanity redirect: tasman.recollect.co.nz → heritage.tasmanlibraries.govt.nz, which the og
            // image carries, so recollectOgImageMaster (which uses the og:image's own host) targets the
            // vanity domain automatically. 26/32 pixel-win (median 3.14×, max 15×/10 MP), 3 equal (small
            // ≤1000 px native), 3 honest-smaller (upscaled-fake -600 → honest native).
            await recollectOgImageMaster(result, url)
        },
        "Western Bay Community Archives": { result, url in
            // Same Recollect two-asset shape as John Kinder / Tasman, on a newer Recollect
            // generation (westernbay.recollect.co.nz; footer "Recollect Limited"). The harvested
            // large_thumbnail id is a master-less display derivative (its `downloadwiz` 404s,
            // `display/<id>-max` == `-600` ~1000 px), while the node `og:image` points to a
            // DIFFERENT primary asset whose `downloadwiz` master IS present (29/29 live nodes
            // sampled, up to ~25 MP). No vanity redirect (stays on westernbay.recollect.co.nz).
            // 24/24 pixel-win (median 11.7×, max 34.6×). ~3% of harvested records were renumbered
            // by a site migration and now 404 (node → error404 page with no og:image) → graceful
            // fallback to the harvested `url`; additive (Group B), so not a regression.
            await recollectOgImageMaster(result, url)
        },
        "Far North District Libraries Rediscovery": { result, url in
            // Same Recollect two-asset shape as John Kinder / Tasman / Western Bay
            // (fndclibraries.recollect.co.nz, Far North District Libraries). The harvested
            // large_thumbnail id is a master-less display derivative (its `downloadwiz` 404s for ~70%
            // of records, `display/<id>-600` == `-max` ~1000 px), while the node `og:image` points to
            // the master-bearing primary asset (sometimes the same id, usually a different one) whose
            // `downloadwiz` master IS present — 59/60 sampled (98%). No vanity redirect (stays on
            // fndclibraries.recollect.co.nz). 58/60 pixel-win (median 23.4×, max 57.6× / ~38 MP), 1
            // equal, 0 honest-smaller. ~1.7% of nodes are stale (no real `og:image` — the page returns
            // the site logo) → graceful fallback to the harvested `-600`; additive (Group B), so not a
            // regression. (The site UA-gates its assets — 403 without a browser UA — but `fetchHTML`
            // and `headStatusFollowingRedirects` both send one.)
            await recollectOgImageMaster(result, url)
        },
        "Pakiaka Rotorua Heritage Online": { result, url in
            // Same Recollect two-asset shape as Far North / Western Bay / Tasman / John Kinder
            // (rotorua.recollect.co.nz, Rotorua Library — Te Aka Mauri), PLUS a Clutha/Tasman-style
            // vanity redirect rotorua.recollect.co.nz -> pakiaka.rotorualibrary.govt.nz. The harvested
            // `large_thumbnail_url` is the small `-280` thumbnail; the node `og:image` points to the
            // master-bearing primary asset on the vanity host (og id differs from thumb id for ~78%;
            // its `downloadwiz` master is present for 64/64 sampled = 100%). recollectOgImageMaster
            // builds the master URL from the og:image's OWN host, so it targets the vanity domain
            // directly (no cross-host redirect during the probe) — important here because the assets
            // are UA-gated (403 without a browser UA) and the rotorua.recollect.co.nz -> vanity redirect
            // is cross-host. 63/64 pixel-win (median 11.7×, max 144× / 6000×4000 ≈ 24 MP), 1 equal
            // (a genuinely tiny 380×300 native), 0 honest-smaller, 0 stale/dead. The `downloadwiz`
            // master is ≥ `-max` for every record (a true larger master for ~40%, == `-max` for ~60%).
            await recollectOgImageMaster(result, url)
        },
        "Ministry for Culture and Heritage Te Ara Flickr": { result, url in
            // object_url is null; a subset of the pool has `_h`/`_k`/`_o` originals (up to ~13 MP)
            // reachable only via the photo page's alternate secrets. Scrape for the largest;
            // `flickrLandingLargest` falls back to `_b` (1024) when nothing larger is present.
            await flickrLandingLargest(result, url)
        },
        "Alexander Turnbull Library Flickr": { result, url in
            // National Library NZ Commons publishes the full original at `object_url`
            // (`_o`, ~100% of records) — that is the Flickr ceiling. Fall back to the
            // largest reachable derivative (`_b`) only if `object_url` is ever absent.
            result.objectUrl?.absoluteString ?? flickrLargest(result, url)
        },
        "Dunedin City Council Archives Flickr": { result, url in
            // Same shape as Turnbull: `object_url` is the `_o` original (~100%); `_b` fallback.
            result.objectUrl?.absoluteString ?? flickrLargest(result, url)
        },
        "State Library of New South Wales Flickr": { result, url in
            // object_url is null; the originals (up to ~45 MP) need per-photo alternate secrets
            // recovered from the photo page. Scrape the landing page for the largest size.
            await flickrLandingLargest(result, url)
        },
        "Australian National Maritime Museum Flickr": { result, url in
            // High-res Commons account: object_url is the `_o` original (~100%) — serve it directly
            // (no fetch). Falls back to the page scrape (not just `_b`) on the rare null object_url.
            if let objectUrl = result.objectUrl?.absoluteString { return objectUrl }
            return await flickrLandingLargest(result, url)
        },
        "Kura Heritage Collections Online": { _, url in
            // CONTENTdm IIIF 2.0. The service caps at the native size (≤ 2000 px long side; no larger
            // master exists — verified the download endpoints return the same native). Request
            // `/full/max/` for the honest native resolution; the previous hardcoded `/full/2048,/`
            // upscaled every image (`sizeAboveFull`) to fake-interpolated 2048-wide pixels.
            ripId(
                from: url,
                to: { "https://kura.aucklandlibraries.govt.nz/iiif/2/photos:\($0)/full/max/0/default.jpg" },
                startString: "/image/photos/",
                endString: "/default.jpg"
            )
        },
        "Victoria and Albert Museum": { result, url in
            // V&A (London). The harvested `media.vam.ac.uk/.../collection_images/<batch>/<id>.jpg` is the
            // legacy image host (~768 px where present, 404 for ~⅓ of records). The V&A IIIF service at
            // `framemark.vam.ac.uk/collections/<id>/` serves the same asset (id == the harvested filename
            // stem) up to its 2500 px cap; `/full/max/` is honest native (≤ 2500, never upscaled). Strict
            // improvement: ≥ the media image for every record, 2500 px for the ~half with a high-res master
            // (median ~10.6×), and it fixes the ~⅓ dead-media records. Pure URL build, no request-time fetch.
            vamIIIFLargest(result, url)
        },
        "Mataura Museum NZMuseums": { result, url in
            // eHive: the harvested `_l` is 800 px-capped, but eHive's public IIIF service over the
            // master TIFF serves the full native (up to ~12 MP here) for every record. Pure URL build.
            ehiveIIIFLargest(result, url)
        },
        "Howick Historical Village NZMuseums": { result, url in
            // Re-opened (order 17 was wrongly closed as no-improvement): Howick's eHive account also
            // exposes the master TIFF via iiif.ehive.com — up to ~12 MP for records with a real master
            // (about half), and exactly the `_l` 800 px native for the rest (never a regression).
            ehiveIIIFLargest(result, url)
        },
        "New Zealand Portrait Gallery NZMuseums": { result, url in
            // eHive account 3272 — same IIIF master-TIFF route as Mataura/Howick.
            ehiveIIIFLargest(result, url)
        },
        "Te Hikoi Museum": { result, url in
            // eHive account 3278 — same IIIF master-TIFF route as Mataura/Howick/Portrait Gallery.
            // Te Hikoi's public master is capped at 1000 px (smaller than the ~12 MP Mataura masters):
            // a 70-record spread showed ~80% gain 800→1000 (×1.56 area) and the rest are already ≤ 800
            // and return their native size (never a regression; 70/70 IIIF ≥ `_l`, 0 worse). Pure URL build.
            ehiveIIIFLargest(result, url)
        },
        "Te Toi Uku, Crown Lynn and Clayworks Museum": { result, url in
            // eHive account 3384 — same IIIF master-TIFF route as Te Hikoi/Mataura/Howick/Portrait Gallery.
            // Public master capped at 1200 px: a 70-record spread showed ~97% gain 800→1200 (×2.25 area),
            // a couple at 1000, and one upscaled-`_l` anomaly (honest native 793 px vs the fake-800 `_l`) —
            // honest-native-always, consistent with orders 17/18. 68 bigger / 1 equal / 1 honest-smaller /
            // 0 failures. Pure URL build.
            ehiveIIIFLargest(result, url)
        },
        "Te Ūaka The Lyttelton Museum": { result, url in
            // eHive account 5362 — same IIIF master-TIFF route (ehiveIIIFLargest) as the rest of the eHive
            // cluster. Group B ADD (new collection; also added to collectionWeights). Mixed masters across a
            // 120-record full-collection sample: ~40% are 800 px native (parity), ~45% 1000 px (×1.56 area),
            // ~15% are full 4000 px / 12 MP (×25 area) — 60% gain, 0 failures, 0 honest-smaller. Handles the
            // older non-hex image ids (e.g. `ji3o28_cpap_l`) too (drop only the last `_<size>`). Pure URL build.
            ehiveIIIFLargest(result, url)
        },
        "Wyndham & Districts Historical Museum": { result, url in
            // eHive account 3102 — same IIIF master-TIFF route (ehiveIIIFLargest) as the rest of the eHive
            // cluster. Group B ADD (new collection; also added to collectionWeights). 4th boutique-mislabel-
            // actually-eHive in a row (cf. Te Hikoi 31 / Te Toi Uku 32 / Te Ūaka 33). A 120-record full-
            // collection sample: ~98% are an exact 1000 px master (×1.56 area over the 800 px `_l`) and ~2%
            // are large native masters (up to ~30 MP) — every IIIF full/full ≥ the `_l` (master min 1000 >
            // `_l` cap 800), so 0 worse / 0 failures. Pure URL build. (~1.5% of records are null-image at
            // source and hard-fail the pick — left as-is, cf. South Canterbury 29.)
            ehiveIIIFLargest(result, url)
        },
        "The University of Waikato Art Collection": { result, url in
            // eHive account 8668 — same IIIF master-TIFF route (ehiveIIIFLargest) as the rest of the eHive
            // cluster. Group B ADD (new collection; also added to collectionWeights). 5th boutique-mislabel-
            // actually-eHive (cf. Te Hikoi 31 / Te Toi Uku 32 / Te Ūaka 33 / Wyndham 34). The landing pages
            // (ehive.com/collections/8668/…) wire up OpenSeadragon over iiif.ehive.com, and /full/full serves
            // the native master 200 image/jpeg for every record regardless of the uniform "All rights reserved"
            // (35/35 in survey; not rights-gated, same as Howick et al.). Uniform 78-record sample of the
            // image-bearing records (35): IIIF native vs the 800 px `_l` = 28 win / 0 equal / 7 honest-smaller
            // (~20% — eHive fake-upscaled the `_l` from a smaller real master; the IIIF returns the honest
            // native, consistent with the user's eHive honest-native-always policy), area ratio median 2.25×,
            // max 95× (biggest native 7803×5202 ≈ 40.6 MP). Pure URL build, no deploy. NB ~61.5% of the 540
            // records are null-image at source (no large_thumbnail_url) and hard-fail the pick (HTTP 400 via
            // checkHasTitleAndLargeImage) — pre-existing Lambda behaviour, identical for the baseline; the low
            // weight reflects this. (cf. South Canterbury 29 / Wyndham 34 null-image hard-fails.)
            ehiveIIIFLargest(result, url)
        },
        // CollectiveAccess (Pawtucket) collection site at collection.teahumuseum.nz; was `boutique`-
        // mislabelled and NOT in the Lambda (Group B ADD). The harvested large_thumbnail_url
        // (`…/records/images/large/<NN>/<hash>.jpg`, S3/CloudFront) is the 800 px "large" derivative;
        // the "xlarge" media version (1200 px long side) is the largest PUBLIC one — `original`/
        // `fullsize`/`full`/`tilepic`/etc. all 403 (not public; CollectiveAccess gates originals behind
        // login). Strict 1.56–2.25× improvement (median 2.25×), present for 100% of the 506 records
        // (uniform survey: 0 null-image, xlarge 63 win / 0 equal / 0 smaller / 0 missing; ceiling
        // 1200 px ≈ 1.44 MP, since originals are 403-locked). `xlarge` never exceeds the master, so no
        // upscale/honest-smaller fork. Pure path-segment swap, no request-time fetch; a non-matching URL
        // (the substring is absent) passes through unchanged. The landing page is bot-walled (HTTP 202
        // challenge) but irrelevant — the /records/images/ CDN is not, and the swap needs no page fetch.
        "Te Ahu Museum": stringSwap(from: "/records/images/large/", to: "/records/images/xlarge/"),
        "Te Papa Collections Online": { result, url in
            await tePapaLargest(result, url)
        },
        "Auckland Museum Collections": { result, url in
            // The harvested `large_thumbnail_url` is only the 400 px `medium` derivative. The object's
            // master lives on the museum file server behind the cloudimg `_collectionsecure_` alias; the
            // path comes from the public API's `object_av_link`. Serve it at native resolution.
            await aklMuseumCloudimg(result, url)
        },
        "Hawke's Bay Knowledge Bank": { result, url in
            // The harvested `…-800x525.jpg` is an 800 px derivative; the CDN also has a true `/master/`
            // original (honest native). Scrape the landing page for it; fall back to the 800 px harvested
            // URL when no master is published (never the upscaled fixed `/images/<base>.jpg` rendition).
            await knowledgeBankMaster(result, url)
        },
        "TAPUHI": { result, url in
            // NDHA/Rosetta: the 5-step resolve reaches an 8 MP JP2 preservation master, but JP2 is
            // undecodable by ~98% of browsers (and by weserv). Resolve the FL JP2 stream URL, then emit
            // `<JP2_CONVERTER_URL>/?url=<encoded FL stream>` so the browser loads our self-hosted
            // Pillow converter (which decodes the JP2 to a displayable JPEG). Falls back to the 700 px
            // NLNZStreamGate access copy if the resolve fails or the converter URL is unset.
            await tapuhiConverter(result, url)
        },
        "Feilding Library": { result, url in
            // Recollect signed-IIIF: the harvested `large_thumbnail_url` is a CloudFront-signed IIIF
            // derivative capped at the site's ≤ 880 px box; larger IIIF sizes can't be forged (each size is
            // individually signed). The true original is a ~25 MP TIFF reached via the item page's
            // `…/files/<fileId>/download?variant=original` link (302 → short-lived presigned S3). TIFF isn't
            // browser-displayable and is too large for weserv (it 504s), so route it through our self-hosted
            // Pillow converter (TIFF→JPEG, downscaled ≤ 4000 px) — the same converter Lambda TAPUHI uses for
            // JP2. Degrades to the harvested signed JPEG on any failure (no landing URL, login-walled record
            // with no public original, converter unconfigured, or fetch failure); never serves a raw TIFF.
            await feildingConverter(result, url)
        },
        "War Art Online": { result, url in
            // NDHA/Rosetta (Archives NZ war-art paintings) — the same delivery platform as TAPUHI, but the
            // preservation master is a TIFF (not JP2). Resolve the IE → Rosetta METS → the largest image/tiff
            // master stream, then emit `<JP2_CONVERTER_URL>/?url=<encoded FL stream>` so the browser loads our
            // self-hosted Pillow converter (TIFF→JPEG, downscaled ≤ 4000 px) — the same now-generic JP2+TIFF
            // converter TAPUHI and Feilding use (and `ndhadeliver.natlib.govt.nz` is already host-allowlisted,
            // so this needs no redeploy). The harvested baseline is bimodal: ~80 % are a 900 px access
            // derivative (the converter is a ~20× win), but ~20 % are ALREADY a full-res ~5000 px JPEG
            // (re-rendering those at 4000 px would shrink them) and ~2 % are multi-page compilations whose
            // default stream is a PDF (not `<img>`-displayable). The resolver decides from the METS: an
            // already-large access JPEG → passthrough the native baseline; a PDF compilation → convert one
            // displayable TIFF page; otherwise → convert the master. Degrades to the harvested URL on any
            // failure (no IE PID, the rare oversized master above the converter's download cap, fetch failure,
            // or converter unset); never serves a raw TIFF.
            await warArtConverter(result, url)
        },
    ]

    func getLargerImage(for result: NZRecordsResult) async throws -> NZRecordsResult {
        guard let collection = result.collection else {
            throw URLProcessorError(
                kind: .nilCollection,
                data: ["result": result.customDescription()]
            )
        }

        if let strategy = Self.strategies[collection] {
            return try await handleUrl(
                result: result,
                urlModifier: { try await strategy(result, $0) }
            )
        }

        switch collection {
        case "Canterbury Museum",
             "Culture Waitaki":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    url.absoluteString.replacingOccurrences(
                        of: "large",
                        with: "xlarge"
                    )
                }
            )

        case "Tāmiro":

            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    try Self.recollectDownloadUrlString(
                        from: url,
                        collection: collection
                    )
                }
            )

        case "Antarctica NZ Digital Asset Manager",
             "National Publicity Studios black and white file prints",
             "South Canterbury Museum",
             "Waimate Museum and Archives PastPerfect",
             "V.C. Browne & Son NZ Aerial Photograph Collection":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    url.absoluteString
                }
            )

        case "Auckland Art Gallery Toi o Tāmaki":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    url.absoluteString.replacingOccurrences(
                        of: "medium",
                        with: "xlarge"
                    )
                }
            )

        case "National Army Museum":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    guard let landingUrl = result.landingUrl else { return url.absoluteString }

                    do {
                        let html = try String(contentsOf: landingUrl, encoding: .utf8)
                        let document: Document = try SwiftSoup.parse(html)

                        let imageMetaTag = try document
                            .select("meta")
                            .first { element in
                                try element.attr("property") == "og:image"
                            }

                        guard let contentUrlString = try imageMetaTag?.attr("content"),
                              let contentUrl = URL(string: contentUrlString),
                              let contentUrlHost = contentUrl.host
                        else {
                            return url.absoluteString
                        }

                        return Self.ripId(
                            from: contentUrl,
                            to: { "https://\(contentUrlHost)/assets/downloadwiz/\($0)" },
                            startString: "display/",
                            endString: "-max"
                        )
                    }
                    catch {
                        return url.absoluteString
                    }
                }
            )

        default:
            // For collections without special URL processing, pass through unchanged
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    url.absoluteString
                }
            )
        }
    }

    // MARK: Private

    // MARK: Reusable platform strategy functions
    //
    // Building blocks for the `strategies` registry, each with (a subset of) the
    // `URLStrategy` shape. They are pure/static so the static registry can compose
    // them. Migrated in one collection at a time during the high-res sweep.

    /// Return the current `large_thumbnail_url` unchanged.
    private static func passthrough(_ result: NZRecordsResult, _ url: URL) -> String {
        url.absoluteString
    }

    /// Use `result.objectUrl` directly when present (often the full-res original);
    /// otherwise fall back to the current URL.
    private static func objectUrlDirect(_ result: NZRecordsResult, _ url: URL) -> String {
        result.objectUrl?.absoluteString ?? url.absoluteString
    }

    /// Flickr (`live.staticflickr.com`): upgrade the size suffix to `_b` (Large, 1024 px on the
    /// long side). `_b` and every smaller size share the photo's base secret, so `_b` is reachable
    /// by a pure string swap — no API key, no page scrape. Flickr never upscales, so a photo whose
    /// original is smaller than 1024 px simply returns the original at the `_b` URL (safe for every
    /// record; never 404s). Sizes above 1024 (`_h`/`_k`/`_o`) require a per-photo *alternate* secret
    /// only available via the photo page / `getSizes` API, and are vanishingly rare in the harvested
    /// pools (0/63 sampled for Te Ara), so we don't pay a per-request fetch to chase them.
    ///
    /// URL shape: `https://live.staticflickr.com/<server>/<id>_<secret>[_<size>].jpg`. The `<id>`
    /// and `<secret>` never contain `_`, so splitting the filename on `_` cleanly isolates an
    /// optional trailing size token.
    private static func flickrLargest(_ result: NZRecordsResult, _ url: URL) -> String {
        let urlString = url.absoluteString

        guard urlString.contains("staticflickr.com"),
              let lastSlash = urlString.lastIndex(of: "/")
        else {
            return urlString
        }

        let prefix = urlString[...lastSlash]
        let file = String(urlString[urlString.index(after: lastSlash)...])

        guard file.hasSuffix(".jpg") else { return urlString }

        let stem = String(file.dropLast(".jpg".count))
        let parts = stem.split(separator: "_")

        // 2 parts => "<id>_<secret>" (no size token) -> append "_b".
        // 3+ parts => "<id>_<secret>_<size>" -> replace the size token with "b".
        let newStem: String
        if parts.count >= 3 {
            newStem = parts.dropLast().joined(separator: "_") + "_b"
        } else {
            newStem = stem + "_b"
        }

        return prefix + newStem + ".jpg"
    }

    /// Flickr size suffixes ranked by resolution (largest first). `o` = original.
    private static let flickrSizeRank: [String: Int] = [
        "o": 100, "6k": 90, "5k": 80, "4k": 70, "3k": 60, "k": 50, "h": 40,
        "b": 30, "c": 20, "z": 10, "w": 6, "m": 5, "n": 4, "q": 3, "t": 2, "s": 1,
    ]

    /// Flickr where `object_url` is null (e.g. State Library of NSW, the Te Ara pool): the largest
    /// derivatives (`_h`/`_k`/`_o`, up to the full original — often tens of megapixels) use per-photo
    /// *alternate* secrets that are NOT constructible from the harvested `_z` URL. They live only in
    /// the photo page's embedded size model (the `flickr.photos.getSizes` API needs a paid key). So
    /// fetch the landing (photo) page once, recover every size URL for THIS photo id, and return the
    /// largest by size rank. One bounded HTML GET at request time (the page is parsed, never the
    /// image). Falls back to `flickrLargest` (`_b`, 1024) when there is no landing URL, the fetch
    /// fails, or nothing parses — so a transient Flickr hiccup still yields a valid larger-than-
    /// thumbnail image.
    ///
    /// The size URLs are embedded JSON-escaped (`\/`); we normalise those to `/` before scanning, and
    /// filter strictly to `<photoId>_<secret>_<size>` so related/recommended photos on the page can't
    /// leak in.
    private static func flickrLandingLargest(_ result: NZRecordsResult, _ url: URL) async -> String {
        guard url.absoluteString.contains("staticflickr.com"),
              let photoId = url.lastPathComponent.split(separator: "_").first.map(String.init),
              let landing = result.landingUrl
        else {
            return flickrLargest(result, url)
        }

        guard let html = try? await NetworkRequestManager().fetchHTML(endpoint: landing.absoluteString) else {
            return flickrLargest(result, url)
        }

        let unescaped = html.replacingOccurrences(of: "\\/", with: "/")
        let pattern = "live\\.staticflickr\\.com/[0-9]+/\(photoId)_[0-9a-z]+_([0-9a-z]+)\\.(?:jpg|png|gif)"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return flickrLargest(result, url)
        }

        let nsString = unescaped as NSString
        var bestURL: String?
        var bestRank = -1

        regex.enumerateMatches(
            in: unescaped,
            range: NSRange(location: 0, length: nsString.length)
        ) { match, _, _ in
            guard let match else { return }
            let size = nsString.substring(with: match.range(at: 1))
            let rank = flickrSizeRank[size] ?? 0
            if rank > bestRank {
                bestRank = rank
                bestURL = "https://" + nsString.substring(with: match.range)
            }
        }

        return bestURL ?? flickrLargest(result, url)
    }

    /// eHive (Vernon Systems; the NZMuseums front-end). The public derivative the harvest gives us
    /// (`…_l.jpg`) is capped at 800 px on the long side, but eHive also runs a **public IIIF Image
    /// API 2.0 service over the master TIFF** at `iiif.ehive.com` (the OpenSeadragon viewer on each
    /// object page points an `info.json` there). Requesting `/full/full/` returns the full native
    /// master — frequently several megapixels (up to ~12 MP observed for Mataura), for every record
    /// regardless of rights, with no sign-in. Where a record's master happens to be ≤ 800 px the
    /// service simply returns that native size (never upscales), so this is always ≥ the `_l`
    /// derivative — a safe strict improvement.
    ///
    /// Transform (pure string construction, no request-time fetch):
    ///   `https://images.ehive.com/accounts/<a>/objects/images/<id>_<token>_l.jpg`
    ///   → identifier `accounts/<a>/objects/images/<id>_<token>.tif` (drop the `_l` size suffix; `.jpg`→`.tif`)
    ///   → `https://iiif.ehive.com/iiif/2/<identifier, "/"→"%2f">/full/full/0/default.jpg`.
    /// The image id (`<id>_<token>`) contains an underscore, so we drop only the *last* `_<size>`
    /// segment. The slashes are encoded as lowercase `%2f` to match the identifier eHive's own viewer
    /// uses. Falls back to the original URL if the host/filename shape is unexpected.
    private static func ehiveIIIFLargest(_ result: NZRecordsResult, _ url: URL) -> String {
        let urlString = url.absoluteString

        guard urlString.contains("images.ehive.com"),
              url.lastPathComponent.hasSuffix(".jpg")
        else {
            return urlString
        }

        let filename = url.lastPathComponent                  // e.g. "ce51j4_1i1a_l.jpg"
        let stem = String(filename.dropLast(".jpg".count))    // "ce51j4_1i1a_l"

        // Drop the trailing "_<size>" suffix (the id itself contains an underscore).
        guard let lastUnderscore = stem.lastIndex(of: "_") else { return urlString }
        let masterFilename = String(stem[..<lastUnderscore]) + ".tif" // "ce51j4_1i1a.tif"

        // Rebuild the asset path with the master filename ("/"-separated, no leading slash).
        var components = url.pathComponents.filter { $0 != "/" } // [accounts,4033,objects,images,<file>]
        guard !components.isEmpty else { return urlString }
        components[components.count - 1] = masterFilename
        let identifier = components.joined(separator: "/")      // "accounts/4033/objects/images/ce51j4_1i1a.tif"
        let encoded = identifier.replacingOccurrences(of: "/", with: "%2f")

        return "https://iiif.ehive.com/iiif/2/\(encoded)/full/full/0/default.jpg"
    }

    /// Victoria and Albert Museum (London). The harvested `large_thumbnail_url`
    /// (`media.vam.ac.uk/media/thira/collection_images/<batch>/<id>.jpg`) is the LEGACY image host:
    /// where present it serves only ~640–768 px, and it 404s for ~⅓ of records (the host is being
    /// retired). The V&A's IIIF Image API at `framemark.vam.ac.uk/collections/<id>/` serves the same
    /// asset — keyed by the SAME `<id>` (the harvested filename stem == the V&A API's `_iiif_image`
    /// identifier) — up to its 2500 px cap. `/full/max/` returns the honest native size (≤ 2500 px; a
    /// `/full/<w>,` request would clamp to 2500 too, but `max` also avoids upscaling the small-native
    /// records, since the service advertises `sizeAboveFull`). Strict improvement: ≥ the media image for
    /// every record (0/20 regressions sampled), 2500 px for the ~half with a high-res master (median
    /// ~10.6×), and it FIXES the ~⅓ dead-media records (framemark resolves 100%). framemark needs no
    /// browser UA and there is no larger public derivative (the IIIF maxWidth is 2500 and the manifest
    /// exposes nothing else). Pure URL construction (no request-time fetch); falls back to the harvested
    /// URL if the host/filename shape is unexpected.
    private static func vamIIIFLargest(_ result: NZRecordsResult, _ url: URL) -> String {
        let urlString = url.absoluteString

        guard urlString.contains("vam.ac.uk"),
              url.pathExtension.lowercased() == "jpg"
        else {
            return urlString
        }

        let stem = url.deletingPathExtension().lastPathComponent          // e.g. "2025PE4780"
        // Defensive: the harvested `large_thumbnail_url` is the bare `<id>.jpg`, but the `thumbnail_url`
        // variant adds a `_jpg_w` suffix; strip it so the IIIF identifier is the clean asset ref.
        let id = stem.hasSuffix("_jpg_w") ? String(stem.dropLast("_jpg_w".count)) : stem
        guard !id.isEmpty else { return urlString }

        return "https://framemark.vam.ac.uk/collections/\(id)/full/max/0/default.jpg"
    }

    /// Te Papa Collections Online (`media.tepapa.govt.nz/collection/<id>/<size>`). The harvested
    /// `large_thumbnail_url` is the `/preview` (≤ 1000 px long side). Te Papa also serves a much larger
    /// `/full` (commonly 2400–7200 px, up to ~29 MP) — but ONLY for open-access records; in-copyright
    /// ("All Rights Reserved") records return HTTP 500 for `/full`. `/full` can't be HEAD-probed (403)
    /// and weserv can't proxy it (404), but it embeds directly (no hotlink protection) and a 1-byte
    /// ranged GET cleanly distinguishes availability (206/200 vs 500) without downloading the image.
    ///
    /// So: probe `/full` with a ranged GET; serve it directly when present (always ≥ `/preview` for the
    /// records that have it); otherwise fall back to the weserv-proxied `/preview` (the prior behaviour,
    /// which also normalises any hotlink/format issues for in-copyright records). Falls back to weserv
    /// `/preview` on any unexpected URL shape or probe failure.
    private static func tePapaLargest(_ result: NZRecordsResult, _ url: URL) async -> String {
        let preview = url.absoluteString

        guard preview.contains("media.tepapa.govt.nz"), preview.hasSuffix("/preview") else {
            return weservProxy(result, url)
        }

        let full = String(preview.dropLast("/preview".count)) + "/full"
        let status = await NetworkRequestManager().rangeStatusFollowingRedirects(endpoint: full)

        if status == 200 || status == 206 {
            return full
        }

        return weservProxy(result, url)
    }

    /// Auckland Museum Collections. The harvested `large_thumbnail_url` is only the 400 px `medium`
    /// derivative (`collection-api.aucklandmuseum.com/records/images/medium/...`; the `large`/`full`
    /// tokens 403). The object's master is on the museum file server, exposed publicly only through the
    /// cloudimg `_collectionsecure_` storage alias (`ajrctguoxo.cloudimg.io`). The relative file path
    /// comes from the public API's `object_av_link` field (e.g. `J:\DocumentaryHeritage\...\full\X.jpg`).
    ///
    /// To reach the master we must (1) take the av_link's first value (before `|`), (2) turn `\`→`/`,
    /// (3) strip the leading drive letter (`J:`) — the alias root maps to it — and (4) percent-encode the
    /// path. Requesting it with `org_if_sml=1` and NO width/height returns the honest native master (no
    /// upscaling): observed 512 px – 8688×5792 (50 MP), i.e. 1.6×–471× the 400 px `medium`.
    ///
    /// NB: this fixes a long-standing bug — the previous code left the `J:` prefix in and did not encode
    /// the path, so cloudimg 404'd for EVERY record (the Lambda was serving a broken URL). On any failure
    /// (nil landing id, API/network error, missing `object_av_link`) it falls back to the harvested
    /// `large_thumbnail_url` (the 400 px medium) so the output is always a valid 200 image.
    private static func aklMuseumCloudimg(_ result: NZRecordsResult, _ url: URL) async -> String {
        let fallback = url.absoluteString

        guard let landingId = result.landingUrl?.absoluteString
            .split(separator: "/").last.map(String.init)
        else {
            return fallback
        }

        let avLinkFirstValue: String
        do {
            let museumResponse: AKLMuseumResponse = try await NetworkRequestManager().makeRequest(
                endpoint: "https://collection-publicapi.aucklandmuseum.com/api/v3/opacobjects/\(landingId)"
            )
            guard let value = museumResponse
                .opacObjectFieldSets?
                .first(where: { $0.identifier == "object_av_link" })?
                .opacObjectFields?
                .first?
                .value
            else {
                return fallback
            }
            avLinkFirstValue = value
        } catch {
            return fallback
        }

        // "J:\Dir\Sub\full\File.jpg|20||Rights..." -> "J:/Dir/Sub/full/File.jpg"
        guard var path = avLinkFirstValue
            .split(separator: "|").first.map(String.init)?
            .replacingOccurrences(of: "\\", with: "/")
        else {
            return fallback
        }

        // Strip a leading drive prefix ("J:" / "J:/"); the alias root maps to it.
        if path.count >= 2, path[path.index(path.startIndex, offsetBy: 1)] == ":" {
            path = String(path.dropFirst(2))
        }
        while path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        guard !path.isEmpty else { return fallback }

        // Percent-encode the path (so "/" -> "%2F", spaces etc. encoded) for cloudimg's
        // `ci_url_encoded=1` decode. Encode everything except RFC 3986 unreserved characters.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return fallback
        }

        return "https://ajrctguoxo.cloudimg.io/v7/_collectionsecure_%2F\(encoded)"
            + "?ci_url_encoded=1&force_format=jpeg&org_if_sml=1"
    }

    /// Hawke's Bay Knowledge Bank (`cdn.knowledgebank.org.nz/node/<id>/images/<base>-WxH.jpg`). The
    /// harvested URL is an 800 px-bounded derivative. The CDN serves three tiers:
    ///   - `…/images/<base>-WxH.jpg` — fixed-size derivatives (the harvest gives the 800 px one),
    ///   - `…/images/<base>.jpg` — a fixed 1400/1800 px rendition that **upscales** small originals
    ///     (fake interpolated pixels), and
    ///   - `…/master/<OriginalCaseName>.jpg` — the **true original** (honest native, variable size).
    ///
    /// We serve the honest native master. Its filename can't be built by string-munging the harvest —
    /// the `/images/` derivative is named either after a lowercased original name OR after the node id
    /// (`46746-800x538.jpg`), while the master keeps the original upload casing/name — so it must be read
    /// from the object page. Fetch the landing page (forced to the `www` host, which reliably lists the
    /// CDN links) and collect the `/node/<id>/master/…` links: if there is exactly one (single-image
    /// record), use it; if several (multi-image record), pick the one whose stem matches the harvested
    /// base (case-insensitively; the `/images/` base may carry a trailing `-<n>` variant the master
    /// lacks). Serve it directly (weserv 404s on this CDN; the CDN has no hotlink protection).
    ///
    /// Fallback (no landing URL / fetch fails / no published master / ambiguous multi-master with no
    /// stem match): the harvested 800 px URL itself — honest and never upscaled (we deliberately do NOT
    /// fall back to the fixed `/images/<base>.jpg` rendition, which is fake pixels for small originals;
    /// note the 800 px derivative can itself be a mild upscale, but it is what the harvest provides). This
    /// also fixes the prior shipped strategy, which weserv-proxied the URL and so returned HTTP 404 for
    /// every record (weserv cannot fetch from this CDN).
    private static func knowledgeBankMaster(_ result: NZRecordsResult, _ url: URL) async -> String {
        let harvested = url.absoluteString

        // Path shape: /node/<nodeId>/images/<file>
        let parts = url.pathComponents.filter { $0 != "/" }   // [node, <id>, images, <file>]
        guard harvested.contains("cdn.knowledgebank.org.nz"),
              parts.count >= 4, parts[0] == "node", parts[2] == "images",
              let landing = result.landingUrl
        else {
            return harvested
        }
        let nodeId = parts[1]
        let filename = url.lastPathComponent

        // Drop the .jpg/.jpeg extension (the harvest is always a JPEG derivative).
        let stem = filename.replacingOccurrences(
            of: #"\.jpe?g$"#, with: "", options: [.regularExpression, .caseInsensitive]
        )
        guard stem != filename else { return harvested }   // not a .jpg — unexpected shape
        // base = stem minus any "-WxH[-n]" size suffix (the harvest may be `<base>-800x525`,
        // `<base>-800x565-1`, or already the bare `<base>` with no size suffix).
        let base = stem.replacingOccurrences(
            of: #"-\d+x\d+(-\d+)?$"#, with: "", options: [.regularExpression, .caseInsensitive]
        )
        // Variant with any trailing "-<digits>" removed (the master often omits it).
        let baseVariant = base.replacingOccurrences(
            of: #"-\d+$"#, with: "", options: .regularExpression
        )
        let wanted = Set([base.lowercased(), baseVariant.lowercased()])

        // The landing page reliably exposes the CDN links on the www host.
        let landingURL = landing.absoluteString
            .replacingOccurrences(of: "https://knowledgebank.org.nz", with: "https://www.knowledgebank.org.nz")
        guard let html = try? await NetworkRequestManager().fetchHTML(endpoint: landingURL) else {
            return harvested
        }

        let pattern = "https://cdn\\.knowledgebank\\.org\\.nz/node/\(nodeId)/master/([^\"' <>]+?)\\.(?:jpg|jpeg|png)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return harvested
        }

        // Collect the distinct master links for this node (preserving order).
        let nsString = html as NSString
        var masters: [(url: String, stem: String)] = []
        regex.enumerateMatches(in: html, range: NSRange(location: 0, length: nsString.length)) { match, _, _ in
            guard let match else { return }
            let full = nsString.substring(with: match.range)
            guard !masters.contains(where: { $0.url == full }) else { return }
            masters.append((full, nsString.substring(with: match.range(at: 1)).lowercased()))
        }

        if masters.count == 1 {
            // Single-image record: the sole master is this record's original.
            return masters[0].url
        }
        if masters.count > 1 {
            // Multi-image record: disambiguate by stem.
            if let hit = masters.first(where: { wanted.contains($0.stem) }) {
                return hit.url
            }
        }

        return harvested
    }

    /// Proxy through images.weserv.nl at native resolution (bypasses hotlink
    /// protection). Note: weserv has a 71 MP cap and cannot decode JP2.
    private static func weservProxy(_ result: NZRecordsResult, _ url: URL) -> String {
        guard let escaped = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return url.absoluteString
        }
        return "https://images.weserv.nl/?url=\(escaped)"
    }

    /// Proxy through thumbnailer.digitalnz.org, normalising to JPEG.
    private static func thumbnailerProxy(_ result: NZRecordsResult, _ url: URL) -> String {
        guard let escaped = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return url.absoluteString
        }
        return "https://thumbnailer.digitalnz.org/?format=jpeg&src=\(escaped)"
    }

    /// Build a strategy that swaps a size token in the URL (e.g. `large` -> `xlarge`).
    private static func stringSwap(from: String, to: String) -> URLStrategy {
        { _, url in url.absoluteString.replacingOccurrences(of: from, with: to) }
    }

    /// TAPUHI / NDHA: resolve the FL JP2 preservation master stream, then hand it to our self-hosted
    /// Pillow JP2→JPEG converter Lambda (its Function URL is injected as `JP2_CONVERTER_URL`). The
    /// browser loads `<converter>/?url=<encoded FL stream>` and receives a displayable JPEG.
    ///
    /// Graceful, non-throwing: any failure degrades to the harvested `url` — the 700 px `NLNZStreamGate`
    /// access copy, a normal JPEG that renders everywhere — so TAPUHI never serves a broken image even if
    /// the resolve fails or the converter is unconfigured (it is NEVER weserv, never a raw JP2). The whole
    /// FL URL is percent-encoded with `.alphanumerics` (matching the prior weserv encoding convention) so
    /// it travels as a single `url` query-param value.
    private static func tapuhiConverter(_ result: NZRecordsResult, _ url: URL) async -> String {
        let flStreamURL: String
        do {
            flStreamURL = try await resolveTapuhiFLStreamURL(from: url)
        } catch {
            return url.absoluteString
        }

        guard let base = ProcessInfo.processInfo.environment["JP2_CONVERTER_URL"], !base.isEmpty,
              let encoded = flStreamURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        else {
            return url.absoluteString
        }

        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        return "\(trimmed)/?url=\(encoded)"
    }

    /// Feilding Library (Recollect, signed-IIIF). Resolve the item's original-TIFF download endpoint, then
    /// hand it to the self-hosted Pillow converter Lambda (its Function URL is injected as `JP2_CONVERTER_URL`,
    /// a generic master→JPEG proxy that also handles TIFF). The browser loads `<converter>/?url=<encoded
    /// download endpoint>` and receives a downscaled displayable JPEG of the ~25 MP original.
    ///
    /// The download endpoint (`/item/<uuid>/files/<fileId>/download?variant=original`) carries a `<fileId>`
    /// that exists ONLY in the item-page HTML, so one bounded HTML GET of the landing page recovers it. The
    /// converter follows the endpoint's 302 to the presigned S3 store itself (so the served URL stays short
    /// and the presigned URL never expires in transit).
    ///
    /// Graceful, non-throwing: any failure (no landing URL / not a Feilding page / converter unconfigured /
    /// fetch fails / no public original on a login-walled record) degrades to the harvested `url` — the
    /// CloudFront-signed ≤ 880 px IIIF JPEG, which renders everywhere. Never weserv, never a raw TIFF.
    private static func feildingConverter(_ result: NZRecordsResult, _ url: URL) async -> String {
        guard let landing = result.landingUrl,
              let host = landing.host, host.hasSuffix("feildingheritage.nz"),
              let base = ProcessInfo.processInfo.environment["JP2_CONVERTER_URL"], !base.isEmpty,
              let html = try? await NetworkRequestManager().fetchHTML(endpoint: landing.absoluteString),
              let pathRange = html.range(
                  of: #"/item/[0-9a-f-]+/files/[0-9a-f-]+/download\?variant=original"#,
                  options: .regularExpression
              )
        else {
            return url.absoluteString
        }

        let downloadURL = "\(landing.scheme ?? "https")://\(host)\(html[pathRange])"

        guard let encoded = downloadURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            return url.absoluteString
        }

        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        return "\(trimmed)/?url=\(encoded)"
    }

    /// War Art Online (Archives NZ via NDHA/Rosetta). Resolve the TIFF preservation master's FL stream and
    /// hand it to the self-hosted Pillow converter (`JP2_CONVERTER_URL`) for a displayable ≤ 4000 px JPEG.
    ///
    /// Graceful, non-throwing: any failure (no IE PID, the harvested baseline is already a full-res JPEG, a
    /// multi-page PDF with no convertible master, an oversized master above the converter's download cap, a
    /// fetch failure, or the converter being unconfigured) degrades to the harvested `url` — the NLNZStreamGate
    /// access copy (a normal JPEG that renders everywhere). Never serves a raw TIFF.
    private static func warArtConverter(_ result: NZRecordsResult, _ url: URL) async -> String {
        let flStreamURL: String
        do {
            flStreamURL = try await resolveWarArtFLStreamURL(from: url)
        } catch {
            return url.absoluteString
        }

        guard let base = ProcessInfo.processInfo.environment["JP2_CONVERTER_URL"], !base.isEmpty,
              let encoded = flStreamURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        else {
            return url.absoluteString
        }

        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        return "\(trimmed)/?url=\(encoded)"
    }

    /// Resolve the War Art Online TIFF preservation master FL stream URL
    /// (`…/DeliveryManagerServlet?dps_pid=FL<n>&dps_func=stream`). Throws when the harvested baseline should be
    /// served unchanged instead (already full-resolution, or no convertible master) — the caller
    /// (`warArtConverter`) treats a throw as "passthrough the harvested URL". Does NOT proxy.
    private static func resolveWarArtFLStreamURL(from url: URL) async throws -> String {
        let urlString = url.absoluteString
        let baseURL = "https://ndhadeliver.natlib.govt.nz"
        let requestManager = NetworkRequestManager()

        // Extract the IE PID from the harvested NLNZStreamGate URL (`…/get?dps_pid=IE<n>`).
        guard let match = urlString.range(of: #"IE\d+"#, options: .regularExpression) else {
            throw URLProcessorError(kind: .unableToExtractIEPID, data: ["url": urlString])
        }
        let iePID = String(urlString[match])

        // Stateless Rosetta METS GET: reliably enumerates every file with its MIME type and byte size.
        let metsURL = "\(baseURL)/delivery/DeliveryManagerServlet?dps_pid=\(iePID)&dps_func=mets"
        let metsXML = try await requestManager.fetchHTML(endpoint: metsURL)

        // Decide from the METS: the largest TIFF master to convert, or nil to passthrough the baseline.
        // `maxBytes` matches the converter's own download cap (110 MB) so the rare oversized master
        // (e.g. a ~900 MB scan) is rejected here and falls back to the already-full-res baseline.
        guard let flPID = warArtMasterFLPID(
            inMETS: metsXML,
            maxBytes: 110 * 1024 * 1024,
            accessPassthroughThreshold: 700 * 1024
        ) else {
            throw URLProcessorError(kind: .noFilesFound, data: ["url": urlString, "iePID": iePID])
        }

        return "\(baseURL)/delivery/DeliveryManagerServlet?dps_pid=\(flPID)&dps_func=stream"
    }

    /// Parse a Rosetta METS document and choose the FL PID of the TIFF preservation master to convert, or
    /// `nil` to passthrough the harvested baseline. Each file's technical metadata lives in its own
    /// `<mets:amdSec ID="FL<n>-amd"> … </mets:amdSec>` block carrying `<key id="fileMIMEType">` and
    /// `<key id="fileSizeBytes">`.
    ///
    /// Decision (Archives NZ delivers a bimodal access tier we cannot pixel-measure in-Lambda):
    /// - No `image/tiff` master ≤ `maxBytes` → `nil` (passthrough; nothing convertible under the cap).
    /// - A multi-page `application/pdf` compilation is present → convert the largest TIFF page (one
    ///   displayable image beats a PDF that won't render in an `<img>`).
    /// - The largest `image/jpeg` access derivative is ≥ `accessPassthroughThreshold` → `nil`: the baseline
    ///   is already a full-resolution ~5000 px JPEG (above the converter's 4000 px ceiling), so serve it
    ///   directly rather than downscale.
    /// - Otherwise (a small ~900 px access derivative) → convert the master.
    ///
    /// The byte threshold maps the bimodal access tiers (thumbnail ~900 px ≈ ≤ ~0.65 MB vs full ~5000 px ≈
    /// ≥ ~0.59 MB); the small overlap means a few-percent of records near the boundary may render at 4000 px
    /// instead of native ~5000 px (or vice-versa) — always graceful, never a broken image.
    static func warArtMasterFLPID(
        inMETS metsXML: String,
        maxBytes: Int64,
        accessPassthroughThreshold: Int64
    ) -> String? {
        let blockPattern = #"<mets:amdSec ID="(FL\d+)-amd">(.*?)</mets:amdSec>"#
        guard let regex = try? NSRegularExpression(pattern: blockPattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        var bestTIFFPID: String?
        var bestTIFFSize: Int64 = -1
        var largestAccessJPEG: Int64 = -1
        var hasPDF = false
        let whole = NSRange(metsXML.startIndex..., in: metsXML)

        for match in regex.matches(in: metsXML, range: whole) {
            guard let pidRange = Range(match.range(at: 1), in: metsXML),
                  let bodyRange = Range(match.range(at: 2), in: metsXML) else { continue }
            let body = metsXML[bodyRange]

            var size: Int64 = -1
            if let sizeRange = body.range(of: #"<key id="fileSizeBytes">\d+</key>"#, options: .regularExpression),
               let digitsRange = body[sizeRange].range(of: #"\d+"#, options: .regularExpression) {
                size = Int64(body[sizeRange][digitsRange]) ?? -1
            }

            if body.contains(#"<key id="fileMIMEType">image/tiff</key>"#) {
                if size <= maxBytes, size > bestTIFFSize {
                    bestTIFFSize = size
                    bestTIFFPID = String(metsXML[pidRange])
                }
            } else if body.contains(#"<key id="fileMIMEType">image/jpeg</key>"#) {
                if size > largestAccessJPEG { largestAccessJPEG = size }
            } else if body.contains(#"<key id="fileMIMEType">application/pdf</key>"#) {
                hasPDF = true
            }
        }

        // Nothing convertible under the converter's download cap → serve the harvested baseline.
        guard let tiffPID = bestTIFFPID else { return nil }
        // Multi-page compilation (PDF default stream): convert one displayable TIFF page.
        if hasPDF { return tiffPID }
        // The harvested access derivative is already full-resolution (> the converter's 4000 px ceiling).
        if largestAccessJPEG >= accessPassthroughThreshold { return nil }
        // Thumbnail-tier access (~900 px) → upgrade to the TIFF master via the converter.
        return tiffPID
    }

    /// Recollect (Recollect Ltd / NZMS): prefer the full-resolution master at
    /// `/assets/downloadwiz/<id>` (often 5000 px) and fall back to the largest display
    /// derivative `/assets/display/<id>-max` when no master is retained.
    ///
    /// Many records have no master: `downloadwiz` 302-redirects to an error page
    /// ("goDownload failed" / "Requested Asset does not exist"). A bare downloadwiz URL
    /// would then serve that HTML error instead of an image, so we probe it with a
    /// non-redirect-following HEAD and only use it when it returns 200; otherwise the
    /// `-max` derivative (the true ceiling for those records) is served. The master is
    /// delivered as a downloadable `application/octet-stream` JPEG, which is the highest
    /// resolution available and renders in an `<img>`.
    private static func recollectLargest(_ result: NZRecordsResult, _ url: URL) async -> String {
        guard let collection = result.collection,
              let domain = try? recollectDomain(for: collection),
              let id = url.absoluteString.slice(from: "display/", to: "-")
        else {
            return url.absoluteString
        }

        let downloadwiz = "https://\(domain)/assets/downloadwiz/\(id)"
        let maxDerivative = "https://\(domain)/assets/display/\(id)-max"

        let masterStatus = await NetworkRequestManager().headStatusFollowingRedirects(endpoint: downloadwiz)

        return masterStatus == 200 ? downloadwiz : maxDerivative
    }

    /// Recollect (Recollect Ltd / NZMS): serve the largest display derivative `/assets/display/<id>-max`
    /// directly. Use this for instances where the `downloadwiz` master is disabled for every
    /// record (so `recollectLargest`'s HEAD probe would always 404 and waste a round-trip) but
    /// the `-max` derivative is still larger than the harvested `-600` (e.g. a ~2000px display
    /// ceiling). Rips the asset id from the `large_thumbnail_url`; falls back to the original URL
    /// if the id can't be parsed.
    private static func recollectDisplayMax(_ result: NZRecordsResult, _ url: URL) -> String {
        guard let collection = result.collection,
              let domain = try? recollectDomain(for: collection),
              let id = url.absoluteString.slice(from: "display/", to: "-")
        else {
            return url.absoluteString
        }

        return "https://\(domain)/assets/display/\(id)-max"
    }

    /// Recollect "two-asset" records (e.g. National Army Museum, John Kinder Theological Library):
    /// the DigitalNZ `large_thumbnail_url` id is a master-less *display* derivative — its
    /// `/assets/downloadwiz/<id>` 404s ("goDownload failed") and `/assets/display/<id>-max` is
    /// capped ~1000 px — while the item/node page's `og:image` references a DIFFERENT *primary*
    /// asset whose `downloadwiz` master IS retained. `recollectLargest` (which rips the harvested
    /// id) would therefore regress every record to ~1000 px; we must scrape the node page's
    /// `og:image` to recover the primary asset id, then apply the same master-probe-else-`-max`
    /// logic as `recollectLargest` on THAT id, using the `og:image`'s own host.
    ///
    /// One bounded HTML GET of the landing page (the page is parsed, never the image). Falls back
    /// to the harvested `url` on any failure (no landing URL, fetch throws, no `og:image` meta, or
    /// an unparseable id) so the output is always a valid image.
    private static func recollectOgImageMaster(_ result: NZRecordsResult, _ url: URL) async -> String {
        guard let landing = result.landingUrl,
              let html = try? await NetworkRequestManager().fetchHTML(endpoint: landing.absoluteString)
        else {
            return url.absoluteString
        }

        do {
            let document = try SwiftSoup.parse(html)
            let imageMetaTag = try document
                .select("meta")
                .first { element in
                    try element.attr("property") == "og:image"
                }

            guard let content = try imageMetaTag?.attr("content"),
                  let ogUrl = URL(string: content),
                  let host = ogUrl.host,
                  let id = content.slice(from: "display/", to: "-")
            else {
                return url.absoluteString
            }

            let downloadwiz = "https://\(host)/assets/downloadwiz/\(id)"
            let maxDerivative = "https://\(host)/assets/display/\(id)-max"

            let masterStatus = await NetworkRequestManager().headStatusFollowingRedirects(endpoint: downloadwiz)
            return masterStatus == 200 ? downloadwiz : maxDerivative
        }
        catch {
            return url.absoluteString
        }
    }

    private static let recollectDomainMap = [
        "Tauranga City Libraries Other Collection": "paekoroki.tauranga.govt.nz",
        "Hastings Recollect": "hastings.recollect.co.nz",
        "Lower Hutt MyRecollect": "huttcity.recollect.co.nz",
        "Hocken Digital Collections": "hocken.recollect.co.nz",
        "National Army Museum": "nam.recollect.co.nz",
        "Tāmiro": "massey.recollect.co.nz",
        "He Purapura Marara Scattered Seeds": "dunedin.recollect.co.nz",
        // clutha.recollect.co.nz 301-redirects to the council vanity domain
        // heritage.cluthadc.govt.nz; both serve the identical master. We keep the
        // harvested *.recollect.co.nz host (the redirect is followed transparently by
        // headStatusFollowingRedirects and by browsers), consistent with the entries above.
        "Clutha Heritage": "clutha.recollect.co.nz",
    ]

    private static func recollectDownloadUrlString(
        from url: URL,
        collection: String
    )
        throws -> String
    {
        let domain = try recollectDomain(for: collection)

        return ripId(
            from: url,
            to: { "https://\(domain)/assets/downloadwiz/\($0)" },
            startString: "display/",
            endString: "-600"
        )
    }

    private static func recollectDomain(for collection: String) throws -> String {
        guard let domain = recollectDomainMap[collection] else {
            throw URLProcessorError(
                kind: .unableToFindRecollectDomain,
                data: ["collection": collection]
            )
        }

        return domain
    }

    private static func ripId(
        from url: URL,
        to: (String) -> String,
        startString: String,
        endString: String
    )
        -> String
    {
        guard let id = url.absoluteString.slice(
            from: startString,
            to: endString
        )
        else {
            return url.absoluteString
        }

        return to(id)
    }

    private func handleUrl(
        result: NZRecordsResult,
        urlModifier: (URL) async throws -> String
    )
        async throws -> NZRecordsResult
    {
        guard let url = result.largeThumbnailUrl else {
            throw URLProcessorError(
                kind: .nilUrl,
                data: ["result": result.customDescription()]
            )
        }

        let finalUrlString = try await urlModifier(url)

        guard let finalUrl = URL(string: finalUrlString) else {
            throw URLProcessorError(
                kind: .unableToCreateFinalUrl,
                data: ["result": result.customDescription()]
            )
        }

        var modifiableResult = result

        modifiableResult.largeThumbnailUrl = finalUrl

        return modifiableResult
    }

    /// NDHA/Rosetta 5-step resolve (IE→DVS→ieViewer→FL→HEAD-largest): returns the best FL preservation
    /// master stream URL (`…/DeliveryManagerServlet?dps_pid=FL<n>&dps_func=stream`, a JPEG 2000). The
    /// caller (`tapuhiConverter`) wraps it in the JP2→JPEG converter URL — this function does NOT proxy.
    private static func resolveTapuhiFLStreamURL(from url: URL) async throws -> String {
        let urlString = url.absoluteString
        let baseURL = "https://ndhadeliver.natlib.govt.nz"
        let requestManager = NetworkRequestManager()

        // Step 1: Extract IE PID from URL
        let iePID: String
        if let match = urlString.range(of: #"dps_pid=IE(\d+)"#, options: .regularExpression),
           let ieMatch = urlString[match].range(of: #"IE\d+"#, options: .regularExpression)
        {
            iePID = String(urlString[match][ieMatch])
        } else if let match = urlString.range(of: #"IE\d+"#, options: .regularExpression) {
            iePID = String(urlString[match])
        } else {
            throw URLProcessorError(
                kind: .unableToExtractIEPID,
                data: ["url": urlString]
            )
        }

        // Step 2: Fetch the Rosetta METS for the IE. Unlike the ieViewer page (a stateful,
        // JS-driven viewer whose HTML frequently omits the FL PIDs), the METS is a stateless
        // GET that reliably enumerates every file with its MIME type and byte size — including
        // the high-res JP2 access master the viewer hides. No DVS session needed.
        let metsURL = "\(baseURL)/delivery/DeliveryManagerServlet?dps_pid=\(iePID)&dps_func=mets"
        let metsXML = try await requestManager.fetchHTML(endpoint: metsURL)

        // Step 3: Choose the largest JP2 master the converter can handle. JP2 is the "HIGH"
        // access representation; the TIFF preservation masters (often 100s of MB) are
        // deliberately skipped — they exceed the converter's download/decode budget.
        guard let flPID = largestTapuhiJP2PID(inMETS: metsXML, maxBytes: 100 * 1024 * 1024) else {
            throw URLProcessorError(
                kind: .noFilesFound,
                data: ["url": urlString, "iePID": iePID]
            )
        }

        // Step 4: Return the JP2 FL stream URL. Wrapping it for the browser (JP2 -> JPEG) is
        // the converter's job (`tapuhiConverter`), not this resolver's.
        return "\(baseURL)/delivery/DeliveryManagerServlet?dps_pid=\(flPID)&dps_func=stream"
    }

    /// Parse a Rosetta METS document and return the FL PID of the largest `image/jp2` file
    /// no larger than `maxBytes`, or `nil` if there is none. Each file's technical metadata
    /// lives in its own `<mets:amdSec ID="FL<n>-amd"> … </mets:amdSec>` block carrying
    /// `<key id="fileMIMEType">` and `<key id="fileSizeBytes">` entries.
    static func largestTapuhiJP2PID(inMETS metsXML: String, maxBytes: Int64) -> String? {
        let blockPattern = #"<mets:amdSec ID="(FL\d+)-amd">(.*?)</mets:amdSec>"#
        guard let regex = try? NSRegularExpression(pattern: blockPattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        var bestPID: String?
        var bestSize: Int64 = -1
        let whole = NSRange(metsXML.startIndex..., in: metsXML)

        for match in regex.matches(in: metsXML, range: whole) {
            guard let pidRange = Range(match.range(at: 1), in: metsXML),
                  let bodyRange = Range(match.range(at: 2), in: metsXML) else { continue }
            let body = metsXML[bodyRange]

            // Keep only JP2 files; preservation TIFFs and the small access JPEG are skipped.
            guard body.contains(#"<key id="fileMIMEType">image/jp2</key>"#) else { continue }

            guard let sizeRange = body.range(of: #"<key id="fileSizeBytes">\d+</key>"#, options: .regularExpression),
                  let digitsRange = body[sizeRange].range(of: #"\d+"#, options: .regularExpression),
                  let size = Int64(body[sizeRange][digitsRange])
            else { continue }

            if size <= maxBytes, size > bestSize {
                bestSize = size
                bestPID = String(metsXML[pidRange])
            }
        }
        return bestPID
    }
}
