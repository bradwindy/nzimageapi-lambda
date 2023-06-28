//
//  DigitalNZAPIDataSource.swift
//  NZImage
//
//  Created by Bradley Windybank on 25/03/23.
//

import Foundation
import OrderedCollections
import RichError

class DigitalNZAPIDataSource {
    // MARK: Lifecycle

    init(requestManager: ValidatedRequestManager, collectionWeights: OrderedDictionary<String, Double>) {
        self.requestManager = requestManager
        self.collectionWeights = collectionWeights
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

    func newResult(logger: (String) -> ()) async throws -> NZRecordsResult {
        let collection = collectionWeights.weightedRandomPick()
        let secondRequestResultsPerPage = 100
        let endpoint = "https://api.digitalnz.org/records.json"
        let apiKey: String? = nil

        let initialRequestParameters: [String: Any] = ["page": 1,
                                                       "per_page": 0,
                                                       "and[category][]": "Images",
                                                       "and[primary_collection][]": collection]
        
        logger("Making initial request for collection: \(collection)")

        let initialResponse: NZRecordsResponse = try await requestManager.makeRequest(endpoint: endpoint,
                                                                                      apiKey: apiKey,
                                                                                      parameters: initialRequestParameters)
        
        logger("Got initial response: \(initialResponse.customDescription())")

        let validatedResultCount = try initialResponse
            .checkNonNull()
            .search!
            .checkNonNull()
            .resultCount!

        let pageCount = validatedResultCount / secondRequestResultsPerPage

        guard pageCount > 0 else { throw DigitalNZAPIDataSourceError(kind: .noResults, data: ["initial response": initialResponse.customDescription()]) }

        let pageNumber = Int.random(in: 1 ... pageCount)

        let secondaryRequestParameters: [String: Any] = ["page": pageNumber,
                                                         "per_page": secondRequestResultsPerPage,
                                                         "and[category][]": "Images",
                                                         "and[primary_collection][]": collection]
        
        logger("Making second request. pageNumber: \(pageNumber), resultsPerPage: \(secondRequestResultsPerPage), collection: \(collection)")

        let secondaryResponse: NZRecordsResponse = try await requestManager.makeRequest(endpoint: endpoint,
                                                                                        apiKey: apiKey,
                                                                                        parameters: secondaryRequestParameters)
        
        logger("Got second response, result count \(String(describing: secondaryResponse.search?.resultCount))")

        let validatedSearch = try secondaryResponse.checkNonNull().search!.checkNonNull()

        let chosenResultPosition = Int.random(in: 0 ..< secondRequestResultsPerPage)

        return try validatedSearch
            .results!
            .throwingAccess(chosenResultPosition)
            .checkHasTitleAndLargeImage()
    }

    // MARK: Private

    private let requestManager: ValidatedRequestManager
    private let collectionWeights: OrderedDictionary<String, Double>
}
