//
//  FilteredCollectionWeightsTests.swift
//
//  Coverage for the `?exclude=` renormalization path (`NZImageApi.filteredCollectionWeights`).
//  The invariant mirrors CollectionWeightsTests but over the FILTERED set: dropping collections
//  must re-derive weights as `count / filtered-total` so they still sum to 1, rather than
//  subtracting-then-leaving-unnormalized (which would reintroduce the weightedRandomPick
//  fallthrough bug the unfiltered path already guards against).
//

import OrderedCollections
import XCTest
@testable import NZImageApiLambda

final class FilteredCollectionWeightsTests: XCTestCase {
    func testFilteredWeightsSumToOne() throws {
        let exclude: Set<String> = ["Te Papa Collections Online", "Kura Heritage Collections Online"]
        let weights = try NZImageApi.filteredCollectionWeights(excluding: exclude)
        let total = weights.values.reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.000_001)
    }

    func testExcludedCollectionsAreAbsent() throws {
        let exclude: Set<String> = ["Te Papa Collections Online", "Kura Heritage Collections Online"]
        let weights = try NZImageApi.filteredCollectionWeights(excluding: exclude)
        for excluded in exclude {
            XCTAssertNil(weights[excluded], "\(excluded) should not appear in the filtered weights")
        }
    }

    func testFilteredWeightsPreserveRemainingCollections() throws {
        let exclude: Set<String> = ["Te Papa Collections Online"]
        let weights = try NZImageApi.filteredCollectionWeights(excluding: exclude)
        XCTAssertEqual(
            weights.count,
            NZImageApi.collectionImageCounts.count - exclude.count
        )
        // A large non-excluded collection must still be present with a positive weight, proving
        // the remaining proportions were renormalized rather than dropped.
        XCTAssertNotNil(weights["Kura Heritage Collections Online"])
        for (name, weight) in weights {
            XCTAssertGreaterThan(weight, 0, "\(name) has a non-positive weight")
        }
    }

    func testRenormalizationRedistributesProportionally() throws {
        // Removing a collection should scale every survivor's weight up by exactly
        // 1 / (1 - removedShare), preserving relative proportions among survivors.
        let removed = "Te Papa Collections Online"
        let unfiltered = NZImageApi.collectionWeights
        let removedShare = unfiltered[removed]!
        let filtered = try NZImageApi.filteredCollectionWeights(excluding: [removed])

        let scale = 1.0 / (1.0 - removedShare)
        for (name, filteredWeight) in filtered {
            XCTAssertEqual(filteredWeight, unfiltered[name]! * scale, accuracy: 0.000_001)
        }
    }

    func testExcludingEveryCollectionThrows() {
        let all = Set(NZImageApi.collectionImageCounts.keys)
        XCTAssertThrowsError(try NZImageApi.filteredCollectionWeights(excluding: all)) { error in
            XCTAssertTrue(error is NZImageApi.NoEligibleCollectionsError)
        }
    }

    func testEmptyExcludeMatchesUnfilteredWeights() throws {
        // An empty exclude set is a degenerate filter: it must reproduce the canonical
        // unfiltered weights exactly (same keys, same order, same values).
        let filtered = try NZImageApi.filteredCollectionWeights(excluding: [])
        XCTAssertEqual(Array(filtered.keys), Array(NZImageApi.collectionWeights.keys))
        for (name, weight) in filtered {
            XCTAssertEqual(weight, NZImageApi.collectionWeights[name]!, accuracy: 0.000_001)
        }
    }
}
