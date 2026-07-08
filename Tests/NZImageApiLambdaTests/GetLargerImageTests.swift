//
//  GetLargerImageTests.swift
//
//  End-to-end coverage for URLProcessor.getLargerImage(for:), exercising the real
//  strategies/switch dispatch for collections whose strategy is pure (no network I/O): the
//  registry lookup, the legacy `switch` fallback, and the two top-level error branches.
//  Network-backed strategies (recollectLargest, Flickr landing scrape, Te Papa, Auckland
//  Museum, converters, Vernon HEAD-probe) are deliberately NOT exercised here — they need
//  live IO and are out of the hermetic scope for this suite.
//

import XCTest
@testable import NZImageApiLambda

final class GetLargerImageTests: XCTestCase {
    private func makeResult(
        collection: String?,
        largeThumbnailUrl: URL?,
        objectUrl: URL? = nil
    )
        -> NZRecordsResult
    {
        NZRecordsResult(
            id: 1,
            title: "Title",
            description: "Description",
            thumbnailUrl: nil,
            largeThumbnailUrl: largeThumbnailUrl,
            objectUrl: objectUrl,
            collection: collection,
            landingUrl: nil
        )
    }

    // MARK: Errors

    func testThrowsNilCollectionWhenCollectionIsNil() async {
        let result = makeResult(collection: nil, largeThumbnailUrl: URL(string: "https://example.com/x.jpg"))

        await XCTAssertThrowsErrorAsync(try await URLProcessor().getLargerImage(for: result)) { error in
            guard let richError = error as? URLProcessor.URLProcessorError else {
                XCTFail("expected URLProcessorError, got \(error)")
                return
            }
            XCTAssertEqual(richError.kind, .nilCollection)
        }
    }

    func testThrowsNilUrlWhenLargeThumbnailUrlIsNil() async {
        let result = makeResult(collection: "Some Unrecognised Collection", largeThumbnailUrl: nil)

        await XCTAssertThrowsErrorAsync(try await URLProcessor().getLargerImage(for: result)) { error in
            guard let richError = error as? URLProcessor.URLProcessorError else {
                XCTFail("expected URLProcessorError, got \(error)")
                return
            }
            XCTAssertEqual(richError.kind, .nilUrl)
        }
    }

    // MARK: Registry pure strategies

    func testKuraHeritageContentdmIIIF() async throws {
        let result = makeResult(
            collection: "Kura Heritage Collections Online",
            largeThumbnailUrl: URL(string: "https://kura.aucklandlibraries.govt.nz/image/photos/ABC123/default.jpg")
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(
            final.largeThumbnailUrl?.absoluteString,
            "https://kura.aucklandlibraries.govt.nz/iiif/2/photos:ABC123/full/max/0/default.jpg"
        )
    }

    func testVictoriaAndAlbertMuseumIIIF() async throws {
        let result = makeResult(
            collection: "Victoria and Albert Museum",
            largeThumbnailUrl: URL(string: "https://media.vam.ac.uk/media/thira/collection_images/2025PE4780/2025PE4780.jpg")
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(
            final.largeThumbnailUrl?.absoluteString,
            "https://framemark.vam.ac.uk/collections/2025PE4780/full/max/0/default.jpg"
        )
    }

    func testMatauraMuseumEhiveIIIF() async throws {
        let result = makeResult(
            collection: "Mataura Museum NZMuseums",
            largeThumbnailUrl: URL(string: "https://images.ehive.com/accounts/4033/objects/images/ce51j4_1i1a_l.jpg")
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(
            final.largeThumbnailUrl?.absoluteString,
            "https://iiif.ehive.com/iiif/2/accounts%2f4033%2fobjects%2fimages%2fce51j4_1i1a.tif/full/full/0/default.jpg"
        )
    }

    func testTeAhuMuseumVernonStringSwap() async throws {
        let result = makeResult(
            collection: "Te Ahu Museum",
            largeThumbnailUrl: URL(string: "https://cdn.example.com/records/images/large/01/hash.jpg")
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(final.largeThumbnailUrl?.absoluteString, "https://cdn.example.com/records/images/xlarge/01/hash.jpg")
    }

    func testHockenRecollectDisplayMax() async throws {
        let result = makeResult(
            collection: "Hocken Digital Collections",
            largeThumbnailUrl: URL(string: "https://hocken.recollect.co.nz/assets/display/98765-600")
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(final.largeThumbnailUrl?.absoluteString, "https://hocken.recollect.co.nz/assets/display/98765-max")
    }

    func testAlexanderTurnbullLibraryFlickrPrefersObjectUrl() async throws {
        let objectUrl = URL(string: "https://example.com/original.jpg")!
        let result = makeResult(
            collection: "Alexander Turnbull Library Flickr",
            largeThumbnailUrl: URL(string: "https://live.staticflickr.com/1234/9999_abcde.jpg"),
            objectUrl: objectUrl
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(final.largeThumbnailUrl?.absoluteString, objectUrl.absoluteString)
    }

    // MARK: Legacy switch pure branches

    func testCanterburyMuseumLargeToXlarge() async throws {
        let result = makeResult(
            collection: "Canterbury Museum",
            largeThumbnailUrl: URL(string: "https://example.com/path/large/image.jpg")
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(final.largeThumbnailUrl?.absoluteString, "https://example.com/path/xlarge/image.jpg")
    }

    func testCultureWaitakiLargeToXlarge() async throws {
        let result = makeResult(
            collection: "Culture Waitaki",
            largeThumbnailUrl: URL(string: "https://example.com/path/large/image.jpg")
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(final.largeThumbnailUrl?.absoluteString, "https://example.com/path/xlarge/image.jpg")
    }

    func testAucklandArtGalleryMediumToXlarge() async throws {
        let result = makeResult(
            collection: "Auckland Art Gallery Toi o Tāmaki",
            largeThumbnailUrl: URL(string: "https://example.com/path/medium/image.jpg")
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(final.largeThumbnailUrl?.absoluteString, "https://example.com/path/xlarge/image.jpg")
    }

    func testTamiroRecollectDownloadUrlString() async throws {
        let result = makeResult(
            collection: "Tāmiro",
            largeThumbnailUrl: URL(string: "https://massey.recollect.co.nz/assets/display/55555-600")
        )

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(final.largeThumbnailUrl?.absoluteString, "https://massey.recollect.co.nz/assets/downloadwiz/55555")
    }

    func testSouthCanterburyMuseumPassthrough() async throws {
        let url = URL(string: "https://example.com/path/original/image.jpg")!
        let result = makeResult(collection: "South Canterbury Museum", largeThumbnailUrl: url)

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(final.largeThumbnailUrl?.absoluteString, url.absoluteString)
    }

    func testUnknownCollectionDefaultsToPassthrough() async throws {
        let url = URL(string: "https://example.com/path/original/image.jpg")!
        let result = makeResult(collection: "Some Totally Unrecognised Collection", largeThumbnailUrl: url)

        let final = try await URLProcessor().getLargerImage(for: result)

        XCTAssertEqual(final.largeThumbnailUrl?.absoluteString, url.absoluteString)
    }
}

/// `XCTAssertThrowsError` has no async overload in the XCTest version this package pins;
/// this awaits the throwing expression first and then hands the caught error to a synchronous
/// verification closure, mirroring `XCTAssertThrowsError`'s shape for async call sites.
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
)
    async
{
    do {
        _ = try await expression()
        XCTFail("expected an error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
