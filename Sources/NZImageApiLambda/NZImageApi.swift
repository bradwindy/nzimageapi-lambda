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

    /// Raw DigitalNZ `category=Images` result counts per collection (same query
    /// `DigitalNZAPIDataSource` uses for its own `per_page=0` count request), fetched 2026-07-06
    /// via `Sources/Testing/CollectionLister`. `collectionWeights` below normalizes these to
    /// proportions, so a collection's odds of being picked track its actual share of available
    /// images instead of a hand-picked number. The previous hardcoded weights only summed to
    /// 0.837 (not 1.0), which silently gave the last dictionary entry an extra ~16% pick chance
    /// via `weightedRandomPick`'s fallthrough — see git history and CLAUDE.md "Collection
    /// weights" section. Re-run CollectionLister and paste in fresh counts periodically as
    /// collections grow; the derived weights will always sum to 1 as long as this stays counts,
    /// not fractions.
    public static let collectionImageCounts: OrderedDictionary<String, Int> = [
        "Auckland Museum Collections": 267_710,
        "Te Papa Collections Online": 388_639,
        "Kura Heritage Collections Online": 390_626,
        "Canterbury Museum": 295_981,
        "Antarctica NZ Digital Asset Manager": 59_376,
        "National Publicity Studios black and white file prints": 33_796,
        "Tauranga City Libraries Other Collection": 65_298,
        "Hawke's Bay Knowledge Bank": 29_348,
        "South Canterbury Museum": 22_582,
        "Howick Historical Village NZMuseums": 13_450,
        "National Army Museum": 14_035,
        "TAPUHI": 301_621,
        "Auckland Art Gallery Toi o Tāmaki": 18_204,
        "Waimate Museum and Archives PastPerfect": 8_667,
        "Te Toi Uku, Crown Lynn and Clayworks Museum": 8_106,
        "Culture Waitaki": 10_631,
        "Te Hikoi Museum": 8_714,
        "V.C. Browne & Son NZ Aerial Photograph Collection": 31_506,
        "Tāmiro": 5_636,
        "Alexander Turnbull Library Flickr": 4_307,
        "He Purapura Marara Scattered Seeds": 10_746,
        "Hastings Recollect": 4_015,
        "Lower Hutt MyRecollect": 2_225,
        "Hocken Digital Collections": 56_791,
        "Ministry for Culture and Heritage Te Ara Flickr": 15_714,
        "Dunedin City Council Archives Flickr": 1_768,
        "State Library of New South Wales Flickr": 177,
        "Australian National Maritime Museum Flickr": 126,
        "Mataura Museum NZMuseums": 3_446,
        "New Zealand Portrait Gallery NZMuseums": 136,
        "Te Ūaka The Lyttelton Museum": 18_588,
        "Wyndham & Districts Historical Museum": 3_937,
        "Feilding Library": 3_592,
        "Clutha Heritage": 2_888,
        "John Kinder Theological Library": 2_719,
        "Tasman Heritage": 2_921,
        "Western Bay Community Archives": 2_442,
        "War Art Online": 1_477,
        "Far North District Libraries Rediscovery": 1_435,
        "Pakiaka Rotorua Heritage Online": 1_571,
        "Victoria and Albert Museum": 564,
        "The University of Waikato Art Collection": 540,
        "Te Ahu Museum": 506,
        "Ngā Puhipuhi o Te Herenga Waka—Victoria University of Wellington Art Collection": 488,
        "Nelson Provincial Museum": 198_770,
        "Puke Ariki": 134_911,
        "Kete Horowhenua": 24_375,
        "Manawatū Heritage": 26_055,
    ]

    /// Derived from `collectionImageCounts`, not hand-set — see the comment above. This
    /// guarantees the weights sum to 1 (mod floating-point rounding), which is exactly the
    /// invariant `weightedRandomPick()` depends on.
    public static var collectionWeights: OrderedDictionary<String, Double> {
        let total = Double(collectionImageCounts.values.reduce(0, +))
        return collectionImageCounts.mapValues { Double($0) / total }
    }

    /// Thrown when `exclude` removes every collection, leaving nothing eligible to pick from.
    /// Surfaced to the handler so it can return a `.badRequest` rather than silently falling
    /// back to the full unfiltered set.
    public struct NoEligibleCollectionsError: Error {}

    /// Weights over `collectionImageCounts` minus `exclude`, re-derived as `count / filtered-total`
    /// so they still sum to 1 (mod float rounding) over the remaining set — never
    /// subtract-then-leave-unnormalized, which reintroduces the documented "weights don't sum to 1"
    /// bug. Throws `NoEligibleCollectionsError` if `exclude` removes every collection.
    public static func filteredCollectionWeights(excluding exclude: Set<String>) throws -> OrderedDictionary<String, Double> {
        let filteredCounts = collectionImageCounts.filter { !exclude.contains($0.key) }
        guard !filteredCounts.isEmpty else { throw NoEligibleCollectionsError() }
        let total = Double(filteredCounts.values.reduce(0, +))
        return filteredCounts.mapValues { Double($0) / total }
    }

    public func image(
        collection: String?,
        exclude: Set<String> = [],
        logger: @Sendable (String) -> Void = { _ in }
    ) async -> NZRecordsResult? {
        do {
            // An explicit single collection always wins; `exclude` is only consulted for the
            // random path. When `exclude` is non-empty we filter+renormalize the canonical counts.
            var weightsOverride: OrderedDictionary<String, Double>? = nil
            if collection == nil, !exclude.isEmpty {
                weightsOverride = try NZImageApi.filteredCollectionWeights(excluding: exclude)
            }

            let result = try await digitalNZAPIDataSource.newResult(
                collection: collection,
                weightsOverride: weightsOverride,
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
