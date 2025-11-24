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

    func getLargerImage(for result: NZRecordsResult) async throws -> NZRecordsResult {
        guard let collection = result.collection else {
            throw URLProcessorError(
                kind: .nilCollection,
                data: ["result": result.customDescription()]
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
                    ripId(
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

        case "Tauranga City Libraries Other Collection",
             "Tāmiro",
             "He Purapura Marara Scattered Seeds":

            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    try recollectDownloadUrlString(
                        from: url,
                        collection: collection
                    )
                }
            )

        case "Wellington City Recollect":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    guard let landingUrl = result.landingUrl else { return url.absoluteString }

                    do {
                        let html = try String(contentsOf: landingUrl, encoding: .utf8)
                        let document: Document = try SwiftSoup.parse(html)

                        // Find the og:image meta tag which contains the actual asset ID
                        let imageMetaTag = try document
                            .select("meta")
                            .first { element in
                                try element.attr("property") == "og:image"
                            }

                        guard let contentUrlString = try imageMetaTag?.attr("content"),
                              let contentUrl = URL(string: contentUrlString)
                        else {
                            return url.absoluteString
                        }

                        // Extract asset ID from the og:image URL
                        // Format: https://wellington.recollect.co.nz/assets/display/18277-max?u=...
                        return ripId(
                            from: contentUrl,
                            to: { "https://wellington.recollect.co.nz/assets/downloadwiz/\($0)" },
                            startString: "display/",
                            endString: "-max"
                        )
                    }
                    catch {
                        return url.absoluteString
                    }
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
             "V.C. Browne & Son NZ Aerial Photograph Collection",
             "Presbyterian Research Centre":
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
                    try await self.fetchTapuhiHighResUrl(from: url)
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

        case "Alexander Turnbull Library Flickr":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    guard let objectUrl = result.objectUrl?.absoluteString else {
                        return url.absoluteString
                    }

                    return objectUrl
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

                        return ripId(
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
            throw URLProcessorError(
                kind: .unknownCollectionName,
                data: ["result": result.customDescription()]
            )
        }
    }

    // MARK: Private

    private let recollectDomainMap = [
        "Tauranga City Libraries Other Collection": "paekoroki.tauranga.govt.nz",
        "National Army Museum": "nam.recollect.co.nz",
        "Wellington City Recollect": "wellington.recollect.co.nz",
        "Tāmiro": "massey.recollect.co.nz",
        "He Purapura Marara Scattered Seeds": "dunedin.recollect.co.nz",
    ]

    private func recollectDownloadUrlString(
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

    private func recollectDomain(for collection: String) throws -> String {
        guard let domain = recollectDomainMap[collection] else {
            throw URLProcessorError(
                kind: .unableToFindRecollectDomain,
                data: ["collection": collection]
            )
        }

        return domain
    }

    private func ripId(
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

    private func fetchTapuhiHighResUrl(from url: URL) async throws -> String {
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
