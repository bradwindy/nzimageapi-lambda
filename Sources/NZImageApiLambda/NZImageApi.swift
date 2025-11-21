//
//  NZImageApi.swift
//
//
//  Created by Bradley Windybank on 17/06/23.
//

import Foundation
import HTTPTypes
import OrderedCollections
import RichError

public struct NZImageApi: Sendable {
    // MARK: Lifecycle

    public init() {
        let requestManager = NetworkRequestManager()
        let urlProcessor = URLProcessor()

        self.digitalNZAPIDataSource = DigitalNZAPIDataSource(
            requestManager: requestManager,
            collectionWeights: NZImageApi.collectionWeights,
            urlProcessor: urlProcessor
        )
    }

    // MARK: Public

    // Collection weights are not yet final
    public static let collectionWeights: OrderedDictionary = [
        "Auckland Libraries Heritage Images Collection": 0.182,
        "Auckland Museum Collections": 0.162,
        "Te Papa Collections Online": 0.119,
        "Kura Heritage Collections Online": 0.116,
        "Canterbury Museum": 0.048,
        "Antarctica NZ Digital Asset Manager": 0.048,
        "National Publicity Studios black and white file prints": 0.037,
        "Tauranga City Libraries Other Collection": 0.032,
        "Hawke's Bay Knowledge Bank": 0.029,
        "South Canterbury Museum": 0.023,
        "Howick Historical Village NZMuseums": 0.015,
        "Presbyterian Research Centre": 0.014,
        "National Army Museum": 0.013,
        "TAPUHI": 0.011,
        "Auckland Art Gallery Toi o Tāmaki": 0.01,
        "Waimate Museum and Archives PastPerfect": 0.01,
        "Te Toi Uku, Crown Lynn and Clayworks Museum": 0.009,
        "Culture Waitaki": 0.009,
        "Wellington City Recollect": 0.006,
        "Te Hikoi Museum": 0.006,
        "V.C. Browne & Son NZ Aerial Photograph Collection": 0.005,
        "Tāmiro": 0.005,
        "Alexander Turnbull Library Flickr": 0.005,
        "He Purapura Marara Scattered Seeds": 0.005,
    ]

    public func image(collection: String?, logger: @Sendable (String) -> Void = { _ in }) async -> NZRecordsResult? {
        do {
            let result = try await digitalNZAPIDataSource.newResult(
                collection: collection,
                logger: logger
            )
            return result
        }
        catch {
            if let richError = error as? (any RichError) {
                // Get the raw value from the enum that defines the kind of error. Messy due to RichError being a protocol and the nested
                // associated types.
                let kind = (richError.kind as any RawRepresentable).rawValue as? String ?? "unknownKind"

                logger("A rich error occurred. Kind: \(kind), Data: \(richError.data)")
            }
            else {
                logger("An unexpected error occurred: \(error.localizedDescription)")
            }
        }

        return nil
    }

    // MARK: Private

    private let digitalNZAPIDataSource: DigitalNZAPIDataSource
}
