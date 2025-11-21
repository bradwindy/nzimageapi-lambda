//
//  main.swift
//  CollectionLister
//
//  Lists all image collections from Digital NZ and their counts
//

import Alamofire
import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Models

struct FacetsResponse: Codable {
    let primaryCollection: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case primaryCollection = "primary_collection"
    }
}

struct SearchResponse: Codable {
    let facets: FacetsResponse?
}

struct DigitalNZResponse: Codable {
    let search: SearchResponse?
    let errors: [String]?
}

struct CollectionInfo: Codable {
    let name: String
    let count: Int
}

struct CollectionListOutput: Codable {
    let totalCollections: Int
    let collections: [CollectionInfo]
}

// MARK: - Main

@main
struct CollectionListerApp {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["DIGITALNZ_API_KEY"] else {
            fputs("Error: DIGITALNZ_API_KEY environment variable not set\n", stderr)
            exit(1)
        }

        let endpoint = "https://api.digitalnz.org/records.json"

        // Request with facets to get all collections
        // We set per_page to 0 to avoid getting actual results, just facets
        // facets_per_page set to maximum allowed (350)
        let parameters: [String: String] = [
            "per_page": "0",
            "and[category][]": "Images",
            "facets": "primary_collection",
            "facets_per_page": "350",
        ]

        let headers = HTTPHeaders(["Authentication-Token": apiKey])

        let response = try await AF.request(
            endpoint,
            parameters: parameters,
            headers: headers
        )
        .serializingDecodable(DigitalNZResponse.self)
        .value

        // Check for API errors
        if let errors = response.errors, !errors.isEmpty {
            fputs("API returned errors: \(errors.joined(separator: ", "))\n", stderr)
            exit(1)
        }

        guard let facetDict = response.search?.facets?.primaryCollection else {
            fputs("Error: No facet data returned from API\n", stderr)
            exit(1)
        }

        // Convert to our output format and sort by count (descending)
        let collections = facetDict.map { (name, count) in
            CollectionInfo(name: name, count: count)
        }.sorted { $0.count > $1.count }

        let output = CollectionListOutput(
            totalCollections: collections.count,
            collections: collections
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
