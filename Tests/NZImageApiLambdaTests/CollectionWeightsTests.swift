//
//  CollectionWeightsTests.swift
//
//  Regression coverage for the collectionWeights-not-summing-to-1 bug: the old hardcoded
//  weights summed to 0.837, silently giving the last dictionary entry an extra ~16% pick
//  chance via weightedRandomPick's fallthrough (`return self.elements[self.count - 1].key`).
//  Weights are now derived from collectionImageCounts, which makes this invariant structural
//  rather than manually maintained, but this test guards against a future edit to
//  collectionImageCounts (e.g. adding a collection with a zero/negative count) breaking it again.
//

import XCTest
@testable import NZImageApiLambda

final class CollectionWeightsTests: XCTestCase {
    func testCollectionWeightsSumToOne() {
        let total = NZImageApi.collectionWeights.values.reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.000_001)
    }

    func testEveryCollectionHasAPositiveWeight() {
        for (name, weight) in NZImageApi.collectionWeights {
            XCTAssertGreaterThan(weight, 0, "\(name) has a non-positive weight")
        }
    }

    func testCollectionWeightsAndImageCountsHaveMatchingKeysInOrder() {
        XCTAssertEqual(
            Array(NZImageApi.collectionWeights.keys),
            Array(NZImageApi.collectionImageCounts.keys)
        )
    }
}
