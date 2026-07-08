//
//  CollectionSafeTests.swift
//
//  Coverage for Collection[safe:], Collection.throwingAccess(_:), and Collection.snapshot(limit:)
//  (Sources/NZImageApiLambda/Extensions/Collection+Safe.swift). `throwingAccess` guards the
//  random-index access into the DigitalNZ second-page results array in DigitalNZAPIDataSource.
//

import XCTest
@testable import NZImageApiLambda

final class CollectionSafeTests: XCTestCase {
    // MARK: subscript(safe:)

    func testSafeSubscriptInBounds() {
        let array = ["a", "b", "c"]
        XCTAssertEqual(array[safe: 0], "a")
        XCTAssertEqual(array[safe: 2], "c")
    }

    func testSafeSubscriptOutOfBoundsReturnsNil() {
        let array = ["a", "b", "c"]
        XCTAssertNil(array[safe: 3])
        XCTAssertNil(array[safe: -1])
        XCTAssertNil(([] as [String])[safe: 0])
    }

    // MARK: throwingAccess(_:)

    func testThrowingAccessReturnsElementInBounds() throws {
        let array = ["a", "b", "c"]
        XCTAssertEqual(try array.throwingAccess(1), "b")
    }

    func testThrowingAccessThrowsOnOutOfBounds() {
        let array = ["a", "b", "c"]
        XCTAssertThrowsError(try array.throwingAccess(5)) { error in
            guard let oobError = error as? CollectionIndexOutOfBoundsError else {
                XCTFail("expected CollectionIndexOutOfBoundsError, got \(error)")
                return
            }
            XCTAssertEqual(oobError.index, 5)
            XCTAssertEqual(oobError.count, 3)
            XCTAssertEqual(oobError.snapshot, "[a, b, c]")
        }
    }

    func testThrowingAccessOnEmptyCollectionThrowsWithZeroCount() {
        let array: [String] = []
        XCTAssertThrowsError(try array.throwingAccess(0)) { error in
            guard let oobError = error as? CollectionIndexOutOfBoundsError else {
                XCTFail("expected CollectionIndexOutOfBoundsError, got \(error)")
                return
            }
            XCTAssertEqual(oobError.index, 0)
            XCTAssertEqual(oobError.count, 0)
            XCTAssertEqual(oobError.snapshot, "[]")
        }
    }

    // MARK: snapshot(limit:)

    func testSnapshotUnderLimitListsEveryElement() {
        let array = [1, 2, 3]
        XCTAssertEqual(array.snapshot(limit: 5), "[1, 2, 3]")
    }

    func testSnapshotAtExactLimitListsEveryElementWithNoTruncationNote() {
        let array = [1, 2, 3, 4, 5]
        XCTAssertEqual(array.snapshot(limit: 5), "[1, 2, 3, 4, 5]")
    }

    func testSnapshotOverLimitTruncatesWithCount() {
        let array = [1, 2, 3, 4, 5, 6, 7]
        XCTAssertEqual(array.snapshot(limit: 5), "[1, 2, 3, 4, 5, ... and 2 more items]")
    }

    func testSnapshotDefaultLimitIsFive() {
        let array = Array(1 ... 8)
        XCTAssertEqual(array.snapshot(), "[1, 2, 3, 4, 5, ... and 3 more items]")
    }
}
