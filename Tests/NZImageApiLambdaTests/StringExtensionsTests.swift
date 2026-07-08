//
//  StringExtensionsTests.swift
//
//  Coverage for String.slice(from:to:) and String.numberOfOccurrences(of:)
//  (Sources/NZImageApiLambda/Extensions/String+Extensions.swift), used throughout
//  URLProcessor's id-ripping helpers.
//

import XCTest
@testable import NZImageApiLambda

final class StringExtensionsTests: XCTestCase {
    // MARK: slice(from:to:)

    func testSliceFindsSubstringBetweenMarkers() {
        XCTAssertEqual("display/12345-600".slice(from: "display/", to: "-600"), "12345")
        XCTAssertEqual("prefix[BODY]suffix".slice(from: "[", to: "]"), "BODY")
    }

    func testSliceReturnsNilWhenFromMarkerAbsent() {
        XCTAssertNil("display/12345-600".slice(from: "nope/", to: "-600"))
    }

    func testSliceReturnsNilWhenToMarkerAbsent() {
        XCTAssertNil("display/12345-600".slice(from: "display/", to: "-nope"))
    }

    func testSliceReturnsNilWhenToMarkerBeforeFromMarker() {
        // "to" only searched in the range AFTER "from"'s upperBound, so an occurrence of
        // "to" that appears earlier in the string must not be found.
        XCTAssertNil("-600display/12345".slice(from: "display/", to: "-600"))
    }

    func testSliceReturnsEmptyStringForAdjacentMarkers() {
        XCTAssertEqual("display/-600".slice(from: "display/", to: "-600"), "")
    }

    func testSliceFindsFirstOccurrenceWhenMarkersRepeat() {
        // "from" is found via range(of:) (first occurrence); "to" is searched from there.
        XCTAssertEqual("display/A-600display/B-600".slice(from: "display/", to: "-600"), "A")
    }

    // MARK: numberOfOccurrences(of:)

    func testNumberOfOccurrencesIsZeroWhenAbsent() {
        XCTAssertEqual("hello world".numberOfOccurrences(of: "xyz"), 0)
    }

    func testNumberOfOccurrencesIsOneForSingleMatch() {
        XCTAssertEqual("hello world".numberOfOccurrences(of: "world"), 1)
    }

    func testNumberOfOccurrencesCountsMultipleMatches() {
        XCTAssertEqual("a_b_c_d".numberOfOccurrences(of: "_"), 3)
    }

    func testNumberOfOccurrencesCountsNonOverlappingMatches() {
        // components(separatedBy:) splits on non-overlapping occurrences, so "aa" in "aaaa"
        // is found twice (positions 0 and 2), not three times.
        XCTAssertEqual("aaaa".numberOfOccurrences(of: "aa"), 2)
    }
}
