//
//  WeightedRandomPickTests.swift
//
//  Coverage for OrderedDictionary<String, Double>.weightedRandomPick()
//  (Sources/NZImageApiLambda/Extensions/OrderedDictionary+WeightedPick.swift). The RNG
//  (`Double.random(in: 0..<1)`) is not injectable, so this tests determinism at the
//  extremes (weights of exactly 0/1, which pin the outcome regardless of the draw) plus a
//  statistical check on a uniform distribution over many draws.
//

import OrderedCollections
import XCTest
@testable import NZImageApiLambda

final class WeightedRandomPickTests: XCTestCase {
    func testSingleEntryDictionaryAlwaysReturnsThatKey() {
        let dict: OrderedDictionary<String, Double> = ["only": 1.0]
        for _ in 0 ..< 1_000 {
            XCTAssertEqual(dict.weightedRandomPick(), "only")
        }
    }

    func testWeightOfOneEffectivelyAlwaysReturnsFirstKey() {
        // totalCombinedWeights reaches 1.0 on the first entry, and the random threshold is
        // drawn from [0, 1) (exclusive of 1), so 1.0 > threshold is guaranteed every time.
        let dict: OrderedDictionary<String, Double> = ["a": 1.0, "b": 0.0]
        for _ in 0 ..< 1_000 {
            XCTAssertEqual(dict.weightedRandomPick(), "a")
        }
    }

    func testWeightsSummingUnderOneFallThroughToLastKey() {
        // The historical bug's mechanism: when the loop never exceeds the random threshold
        // (weights summing to less than 1), `weightedRandomPick` falls through to
        // `self.elements[self.count - 1].key` — the LAST key — regardless of its own weight.
        // Zero weights make this deterministic: totalCombinedWeights never exceeds any
        // threshold in [0, 1), so the loop always falls through.
        let dict: OrderedDictionary<String, Double> = ["a": 0.0, "b": 0.0, "c": 0.0]
        for _ in 0 ..< 1_000 {
            XCTAssertEqual(dict.weightedRandomPick(), "c")
        }
    }

    func testUniformThreeKeyDistributionLandsWithinToleranceBand() {
        let dict: OrderedDictionary<String, Double> = ["a": 1.0 / 3.0, "b": 1.0 / 3.0, "c": 1.0 / 3.0]
        var counts: [String: Int] = ["a": 0, "b": 0, "c": 0]
        let draws = 12_000

        for _ in 0 ..< draws {
            counts[dict.weightedRandomPick(), default: 0] += 1
        }

        // Expected ~4000 each; allow a generous tolerance band to avoid statistical flakiness.
        let expected = Double(draws) / 3.0
        let tolerance = expected * 0.15
        for key in ["a", "b", "c"] {
            let count = Double(counts[key] ?? 0)
            XCTAssertEqual(
                count, expected, accuracy: tolerance,
                "key \(key) drawn \(count) times, expected ~\(expected) +/- \(tolerance)"
            )
        }
    }
}
