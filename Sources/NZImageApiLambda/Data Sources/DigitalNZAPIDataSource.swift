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

        let pageCount = validatedResultCount / secondRequestResultsPerPage

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

        let chosenResultPosition = Int.random(in: 0 ..< secondRequestResultsPerPage)

        let chosenResult = try validatedSearch
            .results!
            .throwingAccess(chosenResultPosition)
            .checkHasTitleAndLargeImage()

        return try await self.urlProcessor.getLargerImage(for: chosenResult)
    }

    // MARK: Private

    private let requestManager: ValidatedRequestManager
    private let collectionWeights: OrderedDictionary<String, Double>
    private let urlProcessor: URLProcessor
}
