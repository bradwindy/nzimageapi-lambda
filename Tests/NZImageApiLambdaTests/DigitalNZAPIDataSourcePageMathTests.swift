//
//  DigitalNZAPIDataSourcePageMathTests.swift
//
//  Regression coverage for the pageCount integer-division bug and the last-page
//  out-of-bounds random index bug (both fixed together in DigitalNZAPIDataSource).
//

import Foundation
import XCTest
@testable import NZImageApiLambda
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

/// Collects logger messages across an `async` call without capturing a bare mutable var in a
/// non-`@Sendable` closure (this project builds under Swift 6 strict concurrency).
private final class LogCollector: @unchecked Sendable {
    private(set) var messages: [String] = []
    func log(_ message: String) { messages.append(message) }
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

    // MARK: noResults error paths

    func testThrowsNoResultsWhenInitialResultCountIsZero() async {
        let dataSource = DigitalNZAPIDataSource(
            requestManager: MockValidatedRequestManager(resultCount: 0, secondPageResults: []),
            collectionWeights: [:],
            urlProcessor: URLProcessor()
        )

        await XCTAssertThrowsErrorAsync(try await dataSource.newResult(collection: "Any Collection") { _ in }) { error in
            guard let richError = error as? DigitalNZAPIDataSource.DigitalNZAPIDataSourceError else {
                XCTFail("expected DigitalNZAPIDataSourceError, got \(error)")
                return
            }
            XCTAssertEqual(richError.kind, .noResults)
        }
    }

    func testThrowsNoResultsWhenSecondPageReturnsEmptyResults() async {
        // resultCount > 0 so the pageCount guard passes and a second request is made, but that
        // second request's page happens to come back empty.
        let dataSource = DigitalNZAPIDataSource(
            requestManager: MockValidatedRequestManager(resultCount: 5, secondPageResults: []),
            collectionWeights: [:],
            urlProcessor: URLProcessor()
        )

        await XCTAssertThrowsErrorAsync(try await dataSource.newResult(collection: "Any Collection") { _ in }) { error in
            guard let richError = error as? DigitalNZAPIDataSource.DigitalNZAPIDataSourceError else {
                XCTFail("expected DigitalNZAPIDataSourceError, got \(error)")
                return
            }
            XCTAssertEqual(richError.kind, .noResults)
        }
    }

    // MARK: weighted-random collection selection

    func testNilCollectionResolvesUsingInjectedCollectionWeights() async throws {
        let mockResults = [
            NZRecordsResult(
                id: 99, title: "t", description: "d", thumbnailUrl: nil,
                largeThumbnailUrl: URL(string: "https://example.com/large.jpg"),
                objectUrl: nil, collection: "Weighted Collection", landingUrl: nil
            ),
        ]
        let dataSource = DigitalNZAPIDataSource(
            requestManager: MockValidatedRequestManager(resultCount: 1, secondPageResults: mockResults),
            collectionWeights: ["Weighted Collection": 1.0],
            urlProcessor: URLProcessor()
        )
        let logCollector = LogCollector()

        let result = try await dataSource.newResult(collection: nil) { logCollector.log($0) }

        XCTAssertEqual(result.id, 99)
        XCTAssertTrue(
            logCollector.messages.contains { $0.contains("Weighted Collection") },
            "expected a log message naming the weighted-random-picked collection, got \(logCollector.messages)"
        )
    }

    // MARK: end-to-end pure-strategy transform (data source -> URLProcessor wiring)

    func testNewResultAppliesVictoriaAndAlbertMuseumPureStrategyTransform() async throws {
        let vamResult = NZRecordsResult(
            id: 7, title: "t", description: "d", thumbnailUrl: nil,
            largeThumbnailUrl: URL(string: "https://media.vam.ac.uk/media/thira/collection_images/2025PE4780/2025PE4780.jpg"),
            objectUrl: nil, collection: "Victoria and Albert Museum", landingUrl: nil
        )
        let dataSource = DigitalNZAPIDataSource(
            requestManager: MockValidatedRequestManager(resultCount: 1, secondPageResults: [vamResult]),
            collectionWeights: [:],
            urlProcessor: URLProcessor()
        )

        let result = try await dataSource.newResult(collection: "Victoria and Albert Museum") { _ in }

        XCTAssertEqual(
            result.largeThumbnailUrl?.absoluteString,
            "https://framemark.vam.ac.uk/collections/2025PE4780/full/max/0/default.jpg"
        )
    }
}
