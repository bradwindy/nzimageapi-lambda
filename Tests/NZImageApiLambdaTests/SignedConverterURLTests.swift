//
//  SignedConverterURLTests.swift
//
//  Cross-language signer round-trip: asserts Swift's `URLProcessor.signedConverterURL`
//  produces the SAME hex HMAC-SHA256 digest that the Python converter (`converter/app.py`)
//  computes for the identical (key, message) pair. The reference hex below was generated once,
//  independently, via:
//    python3 -c "import hmac, hashlib; \
//      print(hmac.new(b'test-signing-key-for-unit-tests', \
//        b'https://ndhadeliver.natlib.govt.nz/delivery/DeliveryManagerServlet?dps_pid=FL12345&dps_func=stream', \
//        hashlib.sha256).hexdigest())"
//

import Foundation
import XCTest
@testable import NZImageApiLambda
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

final class SignedConverterURLTests: XCTestCase {
    override func tearDown() {
        unsetenv("JP2_CONVERTER_URL")
        unsetenv("CONVERTER_SIGNING_KEY")
        super.tearDown()
    }

    func testSignatureMatchesPythonHMACReferenceVector() throws {
        let key = "test-signing-key-for-unit-tests"
        let sourceURL = "https://ndhadeliver.natlib.govt.nz/delivery/DeliveryManagerServlet?dps_pid=FL12345&dps_func=stream"
        let expectedHex = "ad32460761cd4e437111196c73a7b36aae697c3fd1217fa3dcf975307232e00f"

        setenv("JP2_CONVERTER_URL", "https://converter.example.com", 1)
        setenv("CONVERTER_SIGNING_KEY", key, 1)

        let signedURL = try XCTUnwrap(URLProcessor.signedConverterURL(for: sourceURL))

        XCTAssertTrue(
            signedURL.hasSuffix("&sig=\(expectedHex)"),
            "expected signature \(expectedHex) as a suffix of \(signedURL)"
        )
    }

    func testReturnsNilWhenSigningKeyUnset() {
        unsetenv("CONVERTER_SIGNING_KEY")
        setenv("JP2_CONVERTER_URL", "https://converter.example.com", 1)

        XCTAssertNil(URLProcessor.signedConverterURL(for: "https://example.com/master.tif"))
    }

    func testReturnsNilWhenConverterURLUnset() {
        unsetenv("JP2_CONVERTER_URL")
        setenv("CONVERTER_SIGNING_KEY", "some-key", 1)

        XCTAssertNil(URLProcessor.signedConverterURL(for: "https://example.com/master.tif"))
    }
}
