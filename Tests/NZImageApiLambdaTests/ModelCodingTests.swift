//
//  ModelCodingTests.swift
//
//  Coverage for the Codable snake_case mapping and checkNonNull()/checkHasTitleAndLargeImage()
//  validation helpers on NZRecordsResult, NZRecordsResponse, NZRecordsSearch, and the AKLMuseum
//  models (Sources/NZImageApiLambda/Models/). These are pure decode/validate paths hit on every
//  DigitalNZ / Auckland Museum API response.
//

import XCTest
@testable import NZImageApiLambda

final class ModelCodingTests: XCTestCase {
    // MARK: NZRecordsResult decoding

    private let fullResultJSON = """
    {
        "id": 42,
        "title": "A Photograph",
        "description": "A description",
        "thumbnail_url": "https://example.com/thumb.jpg",
        "large_thumbnail_url": "https://example.com/large.jpg",
        "object_url": "https://example.com/object.jpg",
        "display_collection": "Test Collection",
        "landing_url": "https://example.com/item/1",
        "origin_url": "https://example.com/origin.jpg",
        "source_url": "https://example.com/source.jpg"
    }
    """

    func testNZRecordsResultDecodesSnakeCaseKeys() throws {
        let data = Data(fullResultJSON.utf8)
        let result = try JSONDecoder().decode(NZRecordsResult.self, from: data)

        XCTAssertEqual(result.id, 42)
        XCTAssertEqual(result.title, "A Photograph")
        XCTAssertEqual(result.description, "A description")
        XCTAssertEqual(result.thumbnailUrl, URL(string: "https://example.com/thumb.jpg"))
        XCTAssertEqual(result.largeThumbnailUrl, URL(string: "https://example.com/large.jpg"))
        XCTAssertEqual(result.objectUrl, URL(string: "https://example.com/object.jpg"))
        XCTAssertEqual(result.collection, "Test Collection")
        XCTAssertEqual(result.landingUrl, URL(string: "https://example.com/item/1"))
        XCTAssertEqual(result.originUrl, URL(string: "https://example.com/origin.jpg"))
        XCTAssertEqual(result.sourceUrl, URL(string: "https://example.com/source.jpg"))
    }

    func testNZRecordsResultEncodeDecodeRoundTrip() throws {
        // NZRecordsResult doesn't conform to Equatable, so compare field-by-field.
        let original = try JSONDecoder().decode(NZRecordsResult.self, from: Data(fullResultJSON.utf8))
        let reencoded = try JSONEncoder().encode(original)
        let roundTripped = try JSONDecoder().decode(NZRecordsResult.self, from: reencoded)

        XCTAssertEqual(original.id, roundTripped.id)
        XCTAssertEqual(original.title, roundTripped.title)
        XCTAssertEqual(original.description, roundTripped.description)
        XCTAssertEqual(original.thumbnailUrl, roundTripped.thumbnailUrl)
        XCTAssertEqual(original.largeThumbnailUrl, roundTripped.largeThumbnailUrl)
        XCTAssertEqual(original.objectUrl, roundTripped.objectUrl)
        XCTAssertEqual(original.collection, roundTripped.collection)
        XCTAssertEqual(original.landingUrl, roundTripped.landingUrl)
        XCTAssertEqual(original.originUrl, roundTripped.originUrl)
        XCTAssertEqual(original.sourceUrl, roundTripped.sourceUrl)
    }

    // MARK: NZRecordsResult.checkNonNull()

    /// Builds NZRecordsResult JSON with every required field present except those named in
    /// `keysToNull`, which are set to explicit JSON `null`. `id` is the one non-string field,
    /// handled specially so it stays a bare numeric literal (or `null`) rather than a quoted one.
    private func decodeResult(omitting keysToNull: Set<String>) throws -> NZRecordsResult {
        let stringFields: [(key: String, value: String)] = [
            ("title", "A Photograph"),
            ("description", "A description"),
            ("thumbnail_url", "https://example.com/thumb.jpg"),
            ("large_thumbnail_url", "https://example.com/large.jpg"),
            ("object_url", "https://example.com/object.jpg"),
            ("display_collection", "Test Collection"),
            ("landing_url", "https://example.com/item/1"),
        ]

        var pairs: [String] = [
            keysToNull.contains("id") ? "\"id\": null" : "\"id\": 42"
        ]
        for field in stringFields {
            let literal = keysToNull.contains(field.key) ? "null" : "\"\(field.value)\""
            pairs.append("\"\(field.key)\": \(literal)")
        }

        let json = "{ \(pairs.joined(separator: ", ")) }"
        return try JSONDecoder().decode(NZRecordsResult.self, from: Data(json.utf8))
    }

    func testCheckNonNullPassesWhenAllEightRequiredFieldsSet() throws {
        let result = try decodeResult(omitting: [])
        XCTAssertNoThrow(try result.checkNonNull())
    }

    func testCheckNonNullPassesEvenWhenOriginAndSourceUrlAreNil() throws {
        // origin_url / source_url are not part of checkNonNull's required set.
        let result = try decodeResult(omitting: [])
        XCTAssertNil(result.originUrl)
        XCTAssertNil(result.sourceUrl)
        XCTAssertNoThrow(try result.checkNonNull())
    }

    func testCheckNonNullThrowsWhenEachRequiredFieldIsIndividuallyNil() throws {
        let requiredKeys = [
            "id", "title", "description", "thumbnail_url",
            "large_thumbnail_url", "object_url", "display_collection", "landing_url",
        ]

        for key in requiredKeys {
            let result = try decodeResult(omitting: [key])
            XCTAssertThrowsError(try result.checkNonNull(), "expected throw when \(key) is nil") { error in
                guard let richError = error as? NZRecordsResult.NZRecordsResultError else {
                    XCTFail("expected NZRecordsResultError for \(key), got \(error)")
                    return
                }
                XCTAssertEqual(richError.kind, .nullResultContent)
            }
        }
    }

    // MARK: NZRecordsResult.checkHasTitleAndLargeImage()

    func testCheckHasTitleAndLargeImagePassesOnIdTitleAndLargeThumbnail() {
        let result = NZRecordsResult(
            id: 1, title: "T", description: nil, thumbnailUrl: nil,
            largeThumbnailUrl: URL(string: "https://example.com/l.jpg"), objectUrl: nil,
            collection: nil, landingUrl: nil
        )
        XCTAssertNoThrow(try result.checkHasTitleAndLargeImage())
    }

    func testCheckHasTitleAndLargeImageThrowsWhenLargeThumbnailMissing() {
        let result = NZRecordsResult(
            id: 1, title: "T", description: "d", thumbnailUrl: nil,
            largeThumbnailUrl: nil, objectUrl: nil, collection: "c", landingUrl: nil
        )
        XCTAssertThrowsError(try result.checkHasTitleAndLargeImage()) { error in
            guard let richError = error as? NZRecordsResult.NZRecordsResultError else {
                XCTFail("expected NZRecordsResultError, got \(error)")
                return
            }
            XCTAssertEqual(richError.kind, .nullImageOrTitle)
        }
    }

    func testCheckHasTitleAndLargeImageThrowsWhenTitleMissing() {
        let result = NZRecordsResult(
            id: 1, title: nil, description: nil, thumbnailUrl: nil,
            largeThumbnailUrl: URL(string: "https://example.com/l.jpg"), objectUrl: nil,
            collection: nil, landingUrl: nil
        )
        XCTAssertThrowsError(try result.checkHasTitleAndLargeImage()) { error in
            guard let richError = error as? NZRecordsResult.NZRecordsResultError else {
                XCTFail("expected NZRecordsResultError, got \(error)")
                return
            }
            XCTAssertEqual(richError.kind, .nullImageOrTitle)
        }
    }

    func testCheckHasTitleAndLargeImagePassesEvenWhenFullValidationWouldFail() {
        // description/thumbnailUrl/objectUrl/collection/landingUrl are all nil here — this
        // would fail checkNonNull() but must still pass the narrower checkHasTitleAndLargeImage().
        let result = NZRecordsResult(
            id: 1, title: "T", description: nil, thumbnailUrl: nil,
            largeThumbnailUrl: URL(string: "https://example.com/l.jpg"), objectUrl: nil,
            collection: nil, landingUrl: nil
        )
        XCTAssertThrowsError(try result.checkNonNull())
        XCTAssertNoThrow(try result.checkHasTitleAndLargeImage())
    }

    // MARK: NZRecordsResponse / NZRecordsSearch

    func testNZRecordsResponseDecodesResultCountAndNestedResults() throws {
        let json = """
        {
            "search": {
                "result_count": 2,
                "results": [\(fullResultJSON), \(fullResultJSON)]
            }
        }
        """
        let response = try JSONDecoder().decode(NZRecordsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.search?.resultCount, 2)
        XCTAssertEqual(response.search?.results?.count, 2)
        XCTAssertNoThrow(try response.checkNonNull())
        XCTAssertNoThrow(try response.search!.checkNonNull())
    }

    func testNZRecordsResponseCheckNonNullThrowsWhenSearchNil() {
        let response = NZRecordsResponse(search: nil)
        XCTAssertThrowsError(try response.checkNonNull())
    }

    func testNZRecordsSearchCheckNonNullThrowsWhenResultCountNil() {
        let search = NZRecordsSearch(resultCount: nil, results: [])
        XCTAssertThrowsError(try search.checkNonNull())
    }

    func testNZRecordsSearchCheckNonNullThrowsWhenResultsNil() {
        let search = NZRecordsSearch(resultCount: 0, results: nil)
        XCTAssertThrowsError(try search.checkNonNull())
    }

    func testNZRecordsSearchCheckNonNullPassesWithEmptyResultsArray() {
        // An empty (non-nil) results array is valid at the model level; it's the data source's
        // job (not the model's) to treat "zero results" as an error.
        let search = NZRecordsSearch(resultCount: 0, results: [])
        XCTAssertNoThrow(try search.checkNonNull())
    }

    // MARK: AKLMuseum models

    func testAKLMuseumResponseDecodesAndValidates() throws {
        let json = """
        {
            "opacObjectFieldSets": [
                {
                    "identifier": "object_av_link",
                    "opacObjectFields": [
                        { "value": "J:\\\\Dir\\\\Sub\\\\full\\\\File.jpg|20||Rights" }
                    ]
                }
            ]
        }
        """
        let response = try JSONDecoder().decode(AKLMuseumResponse.self, from: Data(json.utf8))
        XCTAssertNoThrow(try response.checkNonNull())

        let fieldSet = try XCTUnwrap(response.opacObjectFieldSets?.first)
        XCTAssertEqual(fieldSet.identifier, "object_av_link")
        XCTAssertNoThrow(try fieldSet.checkNonNull())

        let field = try XCTUnwrap(fieldSet.opacObjectFields?.first)
        XCTAssertEqual(field.value, "J:\\Dir\\Sub\\full\\File.jpg|20||Rights")
        XCTAssertNoThrow(try field.checkNonNull())
    }

    func testAKLMuseumResponseCheckNonNullThrowsWhenFieldSetsNil() {
        let response = AKLMuseumResponse(opacObjectFieldSets: nil)
        XCTAssertThrowsError(try response.checkNonNull())
    }

    func testOpacObjectFieldSetCheckNonNullThrowsWhenIdentifierNil() {
        let fieldSet = OpacObjectFieldSet(identifier: nil, opacObjectFields: [])
        XCTAssertThrowsError(try fieldSet.checkNonNull())
    }

    func testOpacObjectFieldSetCheckNonNullThrowsWhenFieldsNil() {
        let fieldSet = OpacObjectFieldSet(identifier: "x", opacObjectFields: nil)
        XCTAssertThrowsError(try fieldSet.checkNonNull())
    }

    func testOpacObjectFieldCheckNonNullThrowsWhenValueNil() {
        let field = OpacObjectField(value: nil)
        XCTAssertThrowsError(try field.checkNonNull())
    }
}
