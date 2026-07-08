//
//  LambdaImageResponseTests.swift
//
//  Coverage for LambdaImageResponse.init(statusCode:body:) (Sources/Testing/LambdaTesting/
//  LambdaTesting.swift), the JSON-to-typed-fields parser used by CollectionTester/
//  CollectionReviewer to inspect a Lambda invoke response.
//

import Foundation
import XCTest
@testable import LambdaTesting

final class LambdaImageResponseTests: XCTestCase {
    private let fullBodyJSON = """
    {
        "id": 5,
        "title": "A Photograph",
        "description": "A description",
        "thumbnail_url": "https://example.com/thumb.jpg",
        "large_thumbnail_url": "https://example.com/large.jpg",
        "object_url": "https://example.com/object.jpg",
        "display_collection": "Test Collection",
        "landing_url": "https://example.com/item/1",
        "source_url": "https://example.com/source.jpg"
    }
    """

    func testWellFormedBodyMapsSnakeCaseKeysToTypedFields() {
        let data = Data(fullBodyJSON.utf8)
        let response = LambdaImageResponse(statusCode: 200, body: data)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.id, 5)
        XCTAssertEqual(response.title, "A Photograph")
        XCTAssertEqual(response.description, "A description")
        XCTAssertEqual(response.thumbnailUrl, "https://example.com/thumb.jpg")
        XCTAssertEqual(response.largeThumbnailUrl, "https://example.com/large.jpg")
        XCTAssertEqual(response.objectUrl, "https://example.com/object.jpg")
        XCTAssertEqual(response.displayCollection, "Test Collection")
        XCTAssertEqual(response.landingUrl, "https://example.com/item/1")
        XCTAssertEqual(response.sourceUrl, "https://example.com/source.jpg")
        XCTAssertEqual(response.rawBody, data)
    }

    func testMissingFieldsDecodeToNilWithoutCrashing() {
        let data = Data(#"{"id": 1, "title": "Only ID and Title"}"#.utf8)
        let response = LambdaImageResponse(statusCode: 200, body: data)

        XCTAssertEqual(response.id, 1)
        XCTAssertEqual(response.title, "Only ID and Title")
        XCTAssertNil(response.description)
        XCTAssertNil(response.thumbnailUrl)
        XCTAssertNil(response.largeThumbnailUrl)
        XCTAssertNil(response.objectUrl)
        XCTAssertNil(response.displayCollection)
        XCTAssertNil(response.landingUrl)
        XCTAssertNil(response.sourceUrl)
    }

    func testEmptyObjectBodyDecodesToAllNilFields() {
        let data = Data("{}".utf8)
        let response = LambdaImageResponse(statusCode: 200, body: data)

        XCTAssertNil(response.id)
        XCTAssertNil(response.title)
        XCTAssertNil(response.description)
        XCTAssertNil(response.thumbnailUrl)
        XCTAssertNil(response.largeThumbnailUrl)
        XCTAssertNil(response.objectUrl)
        XCTAssertNil(response.displayCollection)
        XCTAssertNil(response.landingUrl)
        XCTAssertNil(response.sourceUrl)
    }

    func testNonJsonBodyDecodesToAllNilFieldsButPreservesStatusCodeAndRawBody() {
        let data = Data("this is not json at all <html>404</html>".utf8)
        let response = LambdaImageResponse(statusCode: 404, body: data)

        XCTAssertEqual(response.statusCode, 404)
        XCTAssertEqual(response.rawBody, data)
        XCTAssertNil(response.id)
        XCTAssertNil(response.title)
        XCTAssertNil(response.description)
        XCTAssertNil(response.thumbnailUrl)
        XCTAssertNil(response.largeThumbnailUrl)
        XCTAssertNil(response.objectUrl)
        XCTAssertNil(response.displayCollection)
        XCTAssertNil(response.landingUrl)
        XCTAssertNil(response.sourceUrl)
    }

    func testEmptyBodyDecodesToAllNilFields() {
        let data = Data()
        let response = LambdaImageResponse(statusCode: 500, body: data)

        XCTAssertEqual(response.statusCode, 500)
        XCTAssertEqual(response.rawBody, data)
        XCTAssertNil(response.id)
        XCTAssertNil(response.title)
    }
}
