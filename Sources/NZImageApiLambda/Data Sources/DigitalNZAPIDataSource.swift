//
//  DigitalNZAPIDataSource.swift
//  NZImage
//
//  Created by Bradley Windybank on 25/03/23.
//

import Foundation
import OrderedCollections
import RichError

final class DigitalNZAPIDataSource: Sendable {
    // MARK: Lifecycle

    init(
        requestManager: ValidatedRequestManager,
        collectionWeights: OrderedDictionary<String, Double>,
        urlProcessor: URLProcessor
    ) {
        self.requestManager = requestManager
        self.collectionWeights = collectionWeights
        self.urlProcessor = urlProcessor
    }

    // MARK: Internal

    struct DigitalNZAPIDataSourceError: RichError {
        typealias ErrorKind = DigitalNZAPIDataSourceErrorKind

        enum DigitalNZAPIDataSourceErrorKind: String {
            case noResults
        }

        var kind: DigitalNZAPIDataSourceErrorKind
        var data: [String: String]
    }

    func newResult(
        collection: String?,
        logger: (String) -> Void
    )
        async throws -> NZRecordsResult
    {
        let chosenCollection: String

        if let collection {
            chosenCollection = collection
        }
        else {
            chosenCollection = collectionWeights.weightedRandomPick()
        }

        let secondRequestResultsPerPage = 100
        let endpoint = "https://api.digitalnz.org/records.json"
        let apiKey = ProcessInfo.processInfo.environment["DIGITALNZ_API_KEY"]

        let initialRequestParameters: [String: any Sendable] = [
            "page": 1,
            "per_page": 0,
            "and[category][]": "Images",
            "and[primary_collection][]": chosenCollection,
        ]

        logger("Making initial request for collection: \(chosenCollection)")

        let initialResponse: NZRecordsResponse = try await requestManager.makeRequest(
            endpoint: endpoint,
            apiKey: apiKey,
            parameters: initialRequestParameters
        )

        logger("Got initial response: \(initialResponse.customDescription())")

        let validatedResultCount = try initialResponse
            .checkNonNull()
            .search!
            .checkNonNull()
            .resultCount!

        // DigitalNZ hard-caps `page` at 50000 regardless of how many results actually exist.
        let pageCount = min(
            Self.pageCount(forResultCount: validatedResultCount, perPage: secondRequestResultsPerPage),
            50_000
        )

        guard pageCount > 0 else { throw DigitalNZAPIDataSourceError(
            kind: .noResults,
            data: ["initial response": initialResponse.customDescription()]
        ) }

        let pageNumber = Int.random(in: 1 ... pageCount)

        let secondaryRequestParameters: [String: any Sendable] = [
            "page": pageNumber,
            "per_page": secondRequestResultsPerPage,
            "and[category][]": "Images",
            "and[primary_collection][]": chosenCollection,
        ]

        logger(
            "Making second request. pageNumber: \(pageNumber), resultsPerPage: \(secondRequestResultsPerPage), collection: \(chosenCollection)"
        )

        let secondaryResponse: NZRecordsResponse = try await requestManager.makeRequest(
            endpoint: endpoint,
            apiKey: apiKey,
            parameters: secondaryRequestParameters
        )

        logger("Got second response, result count \(String(describing: secondaryResponse.search?.resultCount))")

        let validatedSearch = try secondaryResponse.checkNonNull().search!.checkNonNull()
        let results = validatedSearch.results!

        guard !results.isEmpty else { throw DigitalNZAPIDataSourceError(
            kind: .noResults,
            data: ["secondary response": secondaryResponse.customDescription()]
        ) }

        // The last page is usually not full, so pick within the ACTUAL returned page size
        // rather than assuming every page has `secondRequestResultsPerPage` results.
        let chosenResultPosition = Int.random(in: 0 ..< results.count)

        let chosenResult = try results
            .throwingAccess(chosenResultPosition)
            .checkHasTitleAndLargeImage()

        return try await self.urlProcessor.getLargerImage(for: chosenResult)
    }

    /// Ceiling-divides `resultCount` by `perPage` to get the number of pages, so collections with
    /// fewer than `perPage` results still get `pageCount >= 1` instead of always throwing `noResults`
    /// (the previous integer division truncated any remainder to 0).
    static func pageCount(forResultCount resultCount: Int, perPage: Int) -> Int {
        guard perPage > 0, resultCount > 0 else { return 0 }
        return (resultCount + perPage - 1) / perPage
    }

    // MARK: Private

    private let requestManager: ValidatedRequestManager
    private let collectionWeights: OrderedDictionary<String, Double>
    private let urlProcessor: URLProcessor
}
