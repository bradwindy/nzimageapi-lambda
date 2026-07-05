//
//  DigitalNZAPIDataSourcePageMathTests.swift
//
//  Regression coverage for the pageCount integer-division bug and the last-page
//  out-of-bounds random index bug (both fixed together in DigitalNZAPIDataSource).
//

import Foundation
import XCTest
@testable import NZImageApiLambda

/// Stands in for the real network-backed `ValidatedRequestManager`. Returns a canned
/// `NZRecordsResponse` for both the initial (`per_page=0`, count-only) and secondary
/// (`per_page=100`) requests `DigitalNZAPIDataSource.newResult` makes, without any network I/O.
private final class MockValidatedRequestManager: ValidatedRequestManager, @unchecked Sendable {
    let resultCount: Int
    let secondPageResults: [NZRecordsResult]

    init(resultCount: Int, secondPageResults: [NZRecordsResult]) {
        self.resultCount = resultCount
        self.secondPageResults = secondPageResults
    }

    let validation: @Sendable (URLRequest?, HTTPURLResponse, Data?) -> Result<Void, Error> = { _, _, _ in .success(()) }

    func makeRequest<ResponseType: NonNullableResult & Sendable>(
        endpoint: String,
        apiKey: String?,
        parameters: [String: any Sendable]?
    )
        async throws -> ResponseType
    {
        let perPage = parameters?["per_page"] as? Int ?? 0
        let results = perPage == 0 ? [] : secondPageResults
        let response = NZRecordsResponse(search: NZRecordsSearch(resultCount: resultCount, results: results))

        guard let typed = response as? ResponseType else {
            preconditionFailure("MockValidatedRequestManager only supports NZRecordsResponse, got \(ResponseType.self)")
        }
        return typed
    }
}

final class DigitalNZAPIDataSourcePageMathTests: XCTestCase {
    // MARK: pure page-count math

    func testPageCountUsesCeilingDivision() {
        // The bug: 50 / 100 == 0 (integer division), which always threw `noResults` for any
        // collection with fewer than `perPage` records.
        XCTAssertEqual(DigitalNZAPIDataSource.pageCount(forResultCount: 50, perPage: 100), 1)
        XCTAssertEqual(DigitalNZAPIDataSource.pageCount(forResultCount: 1, perPage: 100), 1)
        XCTAssertEqual(DigitalNZAPIDataSource.pageCount(forResultCount: 100, perPage: 100), 1)
        XCTAssertEqual(DigitalNZAPIDataSource.pageCount(forResultCount: 101, perPage: 100), 2)
        XCTAssertEqual(DigitalNZAPIDataSource.pageCount(forResultCount: 250, perPage: 100), 3)
    }

    func testPageCountIsZeroForEmptyOrInvalidInput() {
        XCTAssertEqual(DigitalNZAPIDataSource.pageCount(forResultCount: 0, perPage: 100), 0)
        XCTAssertEqual(DigitalNZAPIDataSource.pageCount(forResultCount: 50, perPage: 0), 0)
    }

    // MARK: end-to-end: small collection (< perPage) with a mocked request manager

    /// A collection with only 5 records: the pre-fix `pageCount` (5 / 100 == 0) always threw
    /// `noResults`, and even if that guard were bypassed, the pre-fix random index
    /// (`0 ..< 100`) would be out of bounds for a 5-element results array 95% of the time. The
    /// fix must make this collection resolvable, deterministically, every time.
    func testSmallCollectionResolvesWithoutOutOfBoundsOrNoResults() async throws {
        let mockResults = (0 ..< 5).map { (i: Int) in
            NZRecordsResult(
                id: i,
                title: "title \(i)",
                description: "description \(i)",
                thumbnailUrl: URL(string: "https://example.com/\(i)-thumb.jpg"),
                largeThumbnailUrl: URL(string: "https://example.com/\(i)-large.jpg"),
                objectUrl: URL(string: "https://example.com/\(i)-object.jpg"),
                collection: "Test Collection XYZ",
                landingUrl: URL(string: "https://example.com/\(i)")
            )
        }

        let dataSource = DigitalNZAPIDataSource(
            requestManager: MockValidatedRequestManager(resultCount: 5, secondPageResults: mockResults),
            collectionWeights: [:],
            urlProcessor: URLProcessor()
        )

        // Repeat: the chosen index is random, so this exercises the full 0..<5 range across runs.
        for _ in 0 ..< 30 {
            let result = try await dataSource.newResult(collection: "Test Collection XYZ") { _ in }
            let id = try XCTUnwrap(result.id)
            XCTAssertTrue((0 ..< 5).contains(id), "chosen result id \(id) was outside the actual 5-result page")
        }
    }
}
