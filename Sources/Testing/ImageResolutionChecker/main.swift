//
//  main.swift
//  ImageResolutionChecker
//
//  Checks image resolutions for Digital NZ collections
//

import Alamofire
import Foundation
import ImageIO
import OrderedCollections
import RichError

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Models

struct NZRecordsResult: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case thumbnailUrl = "thumbnail_url"
        case largeThumbnailUrl = "large_thumbnail_url"
        case objectUrl = "object_url"
        case collection = "display_collection"
        case landingUrl = "landing_url"
        case originUrl = "origin_url"
        case sourceUrl = "source_url"
    }

    var id: Int?
    var title: String?
    var description: String?
    var thumbnailUrl: URL?
    var largeThumbnailUrl: URL?
    var objectUrl: URL?
    var collection: String?
    var landingUrl: URL?
    var originUrl: URL?
    var sourceUrl: URL?
}

struct NZRecordsSearch: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case resultCount = "result_count"
        case results
    }

    var resultCount: Int?
    var results: [NZRecordsResult]?
}

struct NZRecordsResponse: Codable, Sendable {
    var search: NZRecordsSearch?
}

struct ImageResolution: Codable {
    let width: Int
    let height: Int
}

struct ImageCheckResult: Codable {
    let url: String
    let resolution: ImageResolution?
    let error: String?
}

struct ResolutionCheckOutput: Codable {
    let collection: String
    let recordId: Int?
    let title: String?
    let largeThumbnailUrl: ImageCheckResult?
    let objectUrl: ImageCheckResult?
}

// MARK: - Image Resolution Checker

func getImageResolution(from url: URL) async -> ImageResolution? {
    do {
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int
        else {
            return nil
        }

        return ImageResolution(width: width, height: height)
    } catch {
        return nil
    }
}

func checkImageURL(_ url: URL?) async -> ImageCheckResult? {
    guard let url = url else { return nil }

    let resolution = await getImageResolution(from: url)

    return ImageCheckResult(
        url: url.absoluteString,
        resolution: resolution,
        error: resolution == nil ? "Failed to retrieve image dimensions" : nil
    )
}

// MARK: - Digital NZ API Request

func fetchDigitalNZResult(collection: String, apiKey: String) async throws -> NZRecordsResult? {
    let endpoint = "https://api.digitalnz.org/records.json"

    // First request to get total count
    let initialParameters: [String: String] = [
        "page": "1",
        "per_page": "0",
        "and[category][]": "Images",
        "and[primary_collection][]": collection,
    ]

    let headers = HTTPHeaders(["Authentication-Token": apiKey])

    let initialResponse = try await AF.request(
        endpoint,
        parameters: initialParameters,
        headers: headers
    )
    .serializingDecodable(NZRecordsResponse.self)
    .value

    guard let resultCount = initialResponse.search?.resultCount, resultCount > 0 else {
        return nil
    }

    // Second request to get actual result
    let resultsPerPage = 100
    let pageCount = max(1, resultCount / resultsPerPage)
    let randomPage = Int.random(in: 1 ... pageCount)

    let secondParameters: [String: String] = [
        "page": String(randomPage),
        "per_page": String(resultsPerPage),
        "and[category][]": "Images",
        "and[primary_collection][]": collection,
    ]

    let secondResponse = try await AF.request(
        endpoint,
        parameters: secondParameters,
        headers: headers
    )
    .serializingDecodable(NZRecordsResponse.self)
    .value

    guard let results = secondResponse.search?.results, !results.isEmpty else {
        return nil
    }

    // Get a random result
    let randomIndex = Int.random(in: 0 ..< results.count)
    return results[randomIndex]
}

// MARK: - Main

@main
struct ImageResolutionCheckerApp {
    static func main() async throws {
        let arguments = CommandLine.arguments

        guard arguments.count >= 2 else {
            fputs("Usage: ImageResolutionChecker <collection_name>\n", stderr)
            exit(1)
        }

        let collection = arguments[1]

        guard let apiKey = ProcessInfo.processInfo.environment["DIGITALNZ_API_KEY"] else {
            fputs("Error: DIGITALNZ_API_KEY environment variable not set\n", stderr)
            exit(1)
        }

        // Fetch a result from Digital NZ
        guard let result = try await fetchDigitalNZResult(collection: collection, apiKey: apiKey) else {
            fputs("Error: No results found for collection '\(collection)'\n", stderr)
            exit(1)
        }

        // Check resolutions
        let largeThumbnailResult = await checkImageURL(result.largeThumbnailUrl)
        let objectUrlResult = await checkImageURL(result.objectUrl)

        // Create output
        let output = ResolutionCheckOutput(
            collection: collection,
            recordId: result.id,
            title: result.title,
            largeThumbnailUrl: largeThumbnailResult,
            objectUrl: objectUrlResult
        )

        // Output as JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(output)

        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
}
