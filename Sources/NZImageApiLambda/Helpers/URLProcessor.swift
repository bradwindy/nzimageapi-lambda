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
             "Wellington City Recollect",
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

        case "Antarctica NZ Digital Asset Manager",
             "Te Papa Collections Online",
             "National Publicity Studios black and white file prints",
             "South Canterbury Museum",
             "Howick Historical Village NZMuseums",
             "Waimate Museum and Archives PastPerfect",
             "Te Toi Uku, Crown Lynn and Clayworks Museum",
             "Te Hikoi Museum",
             "V.C. Browne & Son NZ Aerial Photograph Collection",
             "Presbyterian Research Centre",
             "TAPUHI":
            return try await handleUrl(
                result: result,
                urlModifier: { url in
                    url.absoluteString
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

                    return urlString
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
}
