//
//  URLProcessorPureHelperTests.swift
//
//  Direct coverage for URLProcessor's pure (non-network) platform helper functions, made
//  `internal` (from `private`) specifically so they can be unit-tested here — see
//  CLAUDE.md / .claude/rules/architecture.md "URLProcessor strategy-registry pattern".
//

import XCTest
@testable import NZImageApiLambda

final class URLProcessorPureHelperTests: XCTestCase {
    private func makeResult(
        collection: String? = "Some Collection",
        objectUrl: URL? = nil,
        largeThumbnailUrl: URL? = nil
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

    // MARK: flickrLargest

    func testFlickrLargestAppendsBSuffixWhenNoSizeToken() {
        let url = URL(string: "https://live.staticflickr.com/1234/9999_abcde.jpg")!
        XCTAssertEqual(
            URLProcessor.flickrLargest(makeResult(), url),
            "https://live.staticflickr.com/1234/9999_abcde_b.jpg"
        )
    }

    func testFlickrLargestReplacesExistingSizeTokenWithB() {
        let url = URL(string: "https://live.staticflickr.com/1234/9999_abcde_z.jpg")!
        XCTAssertEqual(
            URLProcessor.flickrLargest(makeResult(), url),
            "https://live.staticflickr.com/1234/9999_abcde_b.jpg"
        )
    }

    func testFlickrLargestPassthroughForNonFlickrHost() {
        let url = URL(string: "https://example.com/9999_abcde_z.jpg")!
        XCTAssertEqual(URLProcessor.flickrLargest(makeResult(), url), url.absoluteString)
    }

    func testFlickrLargestPassthroughForNonJpgExtension() {
        let url = URL(string: "https://live.staticflickr.com/1234/9999_abcde.png")!
        XCTAssertEqual(URLProcessor.flickrLargest(makeResult(), url), url.absoluteString)
    }

    // MARK: ehiveIIIFLargest

    func testEhiveIIIFLargestBuildsMasterTIFFIIIFURL() {
        let url = URL(string: "https://images.ehive.com/accounts/4033/objects/images/ce51j4_1i1a_l.jpg")!
        XCTAssertEqual(
            URLProcessor.ehiveIIIFLargest(makeResult(), url),
            "https://iiif.ehive.com/iiif/2/accounts%2f4033%2fobjects%2fimages%2fce51j4_1i1a.tif/full/full/0/default.jpg"
        )
    }

    func testEhiveIIIFLargestPassthroughForNonEhiveHost() {
        let url = URL(string: "https://example.com/accounts/4033/objects/images/ce51j4_1i1a_l.jpg")!
        XCTAssertEqual(URLProcessor.ehiveIIIFLargest(makeResult(), url), url.absoluteString)
    }

    func testEhiveIIIFLargestPassthroughWhenStemHasNoUnderscore() {
        let url = URL(string: "https://images.ehive.com/accounts/4033/objects/images/abcdefgh.jpg")!
        XCTAssertEqual(URLProcessor.ehiveIIIFLargest(makeResult(), url), url.absoluteString)
    }

    // MARK: vamIIIFLargest

    func testVamIIIFLargestBuildsFramemarkURL() {
        let url = URL(string: "https://media.vam.ac.uk/media/thira/collection_images/2025PE4780/2025PE4780.jpg")!
        XCTAssertEqual(
            URLProcessor.vamIIIFLargest(makeResult(), url),
            "https://framemark.vam.ac.uk/collections/2025PE4780/full/max/0/default.jpg"
        )
    }

    func testVamIIIFLargestStripsJpgWSuffix() {
        let url = URL(string: "https://media.vam.ac.uk/media/thira/collection_images/2025PE4780/2025PE4780_jpg_w.jpg")!
        XCTAssertEqual(
            URLProcessor.vamIIIFLargest(makeResult(), url),
            "https://framemark.vam.ac.uk/collections/2025PE4780/full/max/0/default.jpg"
        )
    }

    func testVamIIIFLargestPassthroughForNonVamHost() {
        let url = URL(string: "https://example.com/2025PE4780.jpg")!
        XCTAssertEqual(URLProcessor.vamIIIFLargest(makeResult(), url), url.absoluteString)
    }

    // MARK: weservProxy / thumbnailerProxy

    func testWeservProxyBuildsPercentEncodedProxyURL() {
        let url = URL(string: "https://example.com/some/image.jpg?a=b&c=d")!
        let result = URLProcessor.weservProxy(makeResult(), url)

        XCTAssertTrue(result.hasPrefix("https://images.weserv.nl/?url="))
        let encoded = String(result.dropFirst("https://images.weserv.nl/?url=".count))
        XCTAssertEqual(encoded.removingPercentEncoding, url.absoluteString)
    }

    func testThumbnailerProxyBuildsPercentEncodedProxyURL() {
        let url = URL(string: "https://example.com/some/image.jpg?a=b&c=d")!
        let result = URLProcessor.thumbnailerProxy(makeResult(), url)

        XCTAssertTrue(result.hasPrefix("https://thumbnailer.digitalnz.org/?format=jpeg&src="))
        let encoded = String(result.dropFirst("https://thumbnailer.digitalnz.org/?format=jpeg&src=".count))
        XCTAssertEqual(encoded.removingPercentEncoding, url.absoluteString)
    }

    // MARK: stringSwap

    func testStringSwapSwapsToken() async throws {
        let strategy = URLProcessor.stringSwap(from: "/records/images/large/", to: "/records/images/xlarge/")
        let url = URL(string: "https://example.com/records/images/large/1/hash.jpg")!

        let result = try await strategy(makeResult(), url)

        XCTAssertEqual(result, "https://example.com/records/images/xlarge/1/hash.jpg")
    }

    func testStringSwapLeavesNonMatchingURLUnchanged() async throws {
        let strategy = URLProcessor.stringSwap(from: "/records/images/large/", to: "/records/images/xlarge/")
        let url = URL(string: "https://example.com/foo.jpg")!

        let result = try await strategy(makeResult(), url)

        XCTAssertEqual(result, url.absoluteString)
    }

    // MARK: ripId

    func testRipIdSlicesIdAndAppliesTransform() {
        let url = URL(string: "https://kura.aucklandlibraries.govt.nz/image/photos/ABC123/default.jpg")!

        let result = URLProcessor.ripId(
            from: url,
            to: { "id-was-\($0)" },
            startString: "/image/photos/",
            endString: "/default.jpg"
        )

        XCTAssertEqual(result, "id-was-ABC123")
    }

    func testRipIdReturnsOriginalURLWhenMarkerAbsent() {
        let url = URL(string: "https://example.com/other/path.jpg")!

        let result = URLProcessor.ripId(
            from: url,
            to: { "id-was-\($0)" },
            startString: "/image/photos/",
            endString: "/default.jpg"
        )

        XCTAssertEqual(result, url.absoluteString)
    }

    // MARK: recollectDomain

    func testRecollectDomainReturnsDomainForKnownCollection() throws {
        XCTAssertEqual(try URLProcessor.recollectDomain(for: "Hastings Recollect"), "hastings.recollect.co.nz")
        XCTAssertEqual(try URLProcessor.recollectDomain(for: "Hocken Digital Collections"), "hocken.recollect.co.nz")
    }

    func testRecollectDomainThrowsForUnknownCollection() {
        XCTAssertThrowsError(try URLProcessor.recollectDomain(for: "Not A Recollect Collection")) { error in
            guard let richError = error as? URLProcessor.URLProcessorError else {
                XCTFail("expected URLProcessorError, got \(error)")
                return
            }
            XCTAssertEqual(richError.kind, .unableToFindRecollectDomain)
        }
    }

    // MARK: recollectDownloadUrlString / recollectDisplayMax

    func testRecollectDownloadUrlStringBuildsDownloadwizPath() throws {
        let url = URL(string: "https://hastings.recollect.co.nz/assets/display/12345-600")!

        let result = try URLProcessor.recollectDownloadUrlString(from: url, collection: "Hastings Recollect")

        XCTAssertEqual(result, "https://hastings.recollect.co.nz/assets/downloadwiz/12345")
    }

    func testRecollectDownloadUrlStringThrowsForUnknownCollection() {
        let url = URL(string: "https://example.com/assets/display/12345-600")!

        XCTAssertThrowsError(try URLProcessor.recollectDownloadUrlString(from: url, collection: "Unknown"))
    }

    func testRecollectDisplayMaxBuildsMaxDisplayPath() {
        let url = URL(string: "https://hocken.recollect.co.nz/assets/display/98765-600")!
        let result = makeResult(collection: "Hocken Digital Collections")

        XCTAssertEqual(
            URLProcessor.recollectDisplayMax(result, url),
            "https://hocken.recollect.co.nz/assets/display/98765-max"
        )
    }

    func testRecollectDisplayMaxFallsBackToURLForUnknownCollection() {
        let url = URL(string: "https://example.com/assets/display/98765-600")!
        let result = makeResult(collection: "Unknown Collection")

        XCTAssertEqual(URLProcessor.recollectDisplayMax(result, url), url.absoluteString)
    }

    // MARK: passthrough / objectUrlDirect

    func testPassthroughReturnsCurrentURLUnchanged() {
        let url = URL(string: "https://example.com/img.jpg")!
        XCTAssertEqual(URLProcessor.passthrough(makeResult(), url), url.absoluteString)
    }

    func testObjectUrlDirectReturnsObjectUrlWhenPresent() {
        let objectUrl = URL(string: "https://example.com/object.jpg")!
        let url = URL(string: "https://example.com/other.jpg")!
        let result = makeResult(objectUrl: objectUrl)

        XCTAssertEqual(URLProcessor.objectUrlDirect(result, url), objectUrl.absoluteString)
    }

    func testObjectUrlDirectFallsBackToCurrentURLWhenObjectUrlNil() {
        let url = URL(string: "https://example.com/other.jpg")!
        let result = makeResult(objectUrl: nil)

        XCTAssertEqual(URLProcessor.objectUrlDirect(result, url), url.absoluteString)
    }
}
