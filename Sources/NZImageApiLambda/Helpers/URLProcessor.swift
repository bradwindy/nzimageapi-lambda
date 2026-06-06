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
        "Ministry for Culture and Heritage Te Ara Flickr": { result, url in
            flickrLargest(result, url)
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
        case "Auckland Libraries Heritage Images Collection":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    guard let escapedUrlString = url
                        .absoluteString
                        .addingPercentEncoding(
                            withAllowedCharacters: .urlHostAllowed
                        )
                    else {
                        throw URLProcessorError(
                            kind: .unableToEscapeUrl,
                            data: ["result": result.customDescription()]
                        )
                    }

                    let baseUrlString = "https://thumbnailer.digitalnz.org/?format=jpeg&src="
                    let finalUrlString = baseUrlString + escapedUrlString

                    return finalUrlString
                }
            )

        case "Auckland Museum Collections":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    var urlString = url.absoluteString

                    if let tailRange = urlString.range(of: "?rendering=standard.jpg") {
                        urlString.removeSubrange(tailRange)
                    }

                    guard let landingUrlString = result.landingUrl?.absoluteString,
                          let landingId = landingUrlString.components(separatedBy: "/").last
                    else {
                        return urlString
                    }

                    let requestManager = NetworkRequestManager()

                    let museumResponse: AKLMuseumResponse = try await requestManager.makeRequest(
                        endpoint: "https://collection-publicapi.aucklandmuseum.com/api/v3/opacobjects/\(landingId)"
                    )

                    guard let unprocessedUrlStub = museumResponse
                        .opacObjectFieldSets?
                        .first(
                            where: { fieldSet in
                                fieldSet.identifier == "object_av_link"
                            }
                        )?
                        .opacObjectFields?
                        .first?
                        .value,

                        let processedUrlStub = unprocessedUrlStub
                        .components(separatedBy: "|")
                        .first?
                        .replacingOccurrences(of: "\\", with: "/")
                    else {
                        return urlString
                    }

                    return "https://ajrctguoxo.cloudimg.io/v7/_collectionsecure_/\(processedUrlStub)?c=11?ci_url_encoded=1&force_format=jpeg&height=1000"
                }
            )

        case "Kura Heritage Collections Online":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    Self.ripId(
                        from: url,
                        to: { "https://kura.aucklandlibraries.govt.nz/iiif/2/photos:\($0)/full/2048,/0/default.jpg" },
                        startString: "/image/photos/",
                        endString: "/default.jpg"
                    )
                }
            )

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

        case "Te Papa Collections Online":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    // Use images.weserv.nl proxy to bypass hotlinking protection
                    guard let escapedUrl = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
                        return url.absoluteString
                    }
                    return "https://images.weserv.nl/?url=\(escapedUrl)"
                }
            )

        case "Antarctica NZ Digital Asset Manager",
             "National Publicity Studios black and white file prints",
             "South Canterbury Museum",
             "Howick Historical Village NZMuseums",
             "Waimate Museum and Archives PastPerfect",
             "Te Toi Uku, Crown Lynn and Clayworks Museum",
             "Te Hikoi Museum",
             "V.C. Browne & Son NZ Aerial Photograph Collection":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    url.absoluteString
                }
            )

        case "TAPUHI":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    try await Self.fetchTapuhiHighResUrl(from: url)
                }
            )

        case "Hawke's Bay Knowledge Bank":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    var urlString = url.absoluteString

                    if urlString.numberOfOccurrences(of: "-") > 1 {
                        let dashPosition = urlString.count - 12

                        let startIndex = urlString.index(
                            urlString.startIndex,
                            offsetBy: dashPosition
                        )

                        let endIndex = urlString.index(
                            urlString.startIndex,
                            offsetBy: dashPosition + 7
                        )

                        urlString.removeSubrange(startIndex ... endIndex)
                    }

                    // Use images.weserv.nl proxy to bypass hotlinking protection
                    guard let escapedUrl = urlString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
                        return urlString
                    }
                    return "https://images.weserv.nl/?url=\(escapedUrl)"
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

    /// TAPUHI / NDHA: resolve the largest FL stream and serve it via the weserv proxy.
    private static func tapuhi(_ result: NZRecordsResult, _ url: URL) async throws -> String {
        try await fetchTapuhiHighResUrl(from: url)
    }

    /// Recollect (Axiell): prefer the full-resolution master at
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

    /// Recollect (Axiell): serve the largest display derivative `/assets/display/<id>-max`
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

    private static let recollectDomainMap = [
        "Tauranga City Libraries Other Collection": "paekoroki.tauranga.govt.nz",
        "Hastings Recollect": "hastings.recollect.co.nz",
        "Lower Hutt MyRecollect": "huttcity.recollect.co.nz",
        "Hocken Digital Collections": "hocken.recollect.co.nz",
        "National Army Museum": "nam.recollect.co.nz",
        "Tāmiro": "massey.recollect.co.nz",
        "He Purapura Marara Scattered Seeds": "dunedin.recollect.co.nz",
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

    private static func fetchTapuhiHighResUrl(from url: URL) async throws -> String {
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

        // Step 2: Get DVS session from delivery manager
        let deliveryURL = "\(baseURL)/delivery/DeliveryManagerServlet?dps_pid=\(iePID)"
        let deliveryHTML = try await requestManager.fetchHTML(endpoint: deliveryURL)

        guard let dvsMatch = deliveryHTML.range(of: #"dps_dvs=[\d~]+"#, options: .regularExpression) else {
            throw URLProcessorError(
                kind: .unableToExtractDVS,
                data: ["url": urlString, "iePID": iePID]
            )
        }
        let dvs = String(deliveryHTML[dvsMatch]).replacingOccurrences(of: "dps_dvs=", with: "")

        // Step 3: Get viewer page with FL PIDs
        let viewerURL = "\(baseURL)/view/action/ieViewer.do?dps_dvs=\(dvs)&dps_pid=\(iePID)"
        let viewerHTML = try await requestManager.fetchHTML(endpoint: viewerURL)

        // Extract all FL PIDs
        var flPIDs: [String] = []
        let flPattern = #"FL\d+"#
        var searchRange = viewerHTML.startIndex ..< viewerHTML.endIndex

        while let match = viewerHTML.range(of: flPattern, options: .regularExpression, range: searchRange) {
            let flPID = String(viewerHTML[match])
            if !flPIDs.contains(flPID) {
                flPIDs.append(flPID)
            }
            searchRange = match.upperBound ..< viewerHTML.endIndex
        }

        guard !flPIDs.isEmpty else {
            throw URLProcessorError(
                kind: .noFilesFound,
                data: ["url": urlString, "iePID": iePID]
            )
        }

        // Step 4: Get metadata for each file and find largest
        var bestURL = urlString
        var maxSize: Int64 = 0

        for flPID in flPIDs {
            let streamURL = "\(baseURL)/delivery/DeliveryManagerServlet?dps_pid=\(flPID)&dps_func=stream"
            do {
                let metadata = try await requestManager.headRequest(endpoint: streamURL)
                if metadata.contentLength > maxSize {
                    maxSize = metadata.contentLength
                    bestURL = streamURL
                }
            } catch {
                continue
            }
        }

        // Use weserv.nl proxy to convert JP2 to WebP for browser compatibility
        guard let encoded = bestURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            return bestURL
        }
        return "https://images.weserv.nl/?url=\(encoded)&output=webp"
    }
}
