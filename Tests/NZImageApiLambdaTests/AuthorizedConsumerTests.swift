//
//  AuthorizedConsumerTests.swift
//
//  Coverage for NZImageApiLambda.authorizedConsumer, which parses the `API_CLIENT_SECRETS`
//  "name:secret,name:secret" format and authorizes a request against every configured consumer.
//

import XCTest
@testable import NZImageApiLambda

final class AuthorizedConsumerTests: XCTestCase {
    private let allowed = "site:AbC123,mobile:XyZ789"

    func testMatchingSecretReturnsItsConsumerName() {
        XCTAssertEqual(NZImageApiLambda.authorizedConsumer(presented: "AbC123", allowed: allowed), "site")
        XCTAssertEqual(NZImageApiLambda.authorizedConsumer(presented: "XyZ789", allowed: allowed), "mobile")
    }

    func testNonMatchingSecretReturnsNil() {
        XCTAssertNil(NZImageApiLambda.authorizedConsumer(presented: "wrong-secret", allowed: allowed))
        XCTAssertNil(NZImageApiLambda.authorizedConsumer(presented: "", allowed: allowed))
    }

    func testEmptyAllowedListReturnsNil() {
        XCTAssertNil(NZImageApiLambda.authorizedConsumer(presented: "AbC123", allowed: ""))
    }

    func testMalformedEntryWithoutColonIsSkippedNotCrashed() {
        // A misconfigured entry (missing ":") should be ignored rather than matched or crash.
        XCTAssertNil(NZImageApiLambda.authorizedConsumer(presented: "malformed", allowed: "malformed,site:AbC123"))
        XCTAssertEqual(NZImageApiLambda.authorizedConsumer(presented: "AbC123", allowed: "malformed,site:AbC123"), "site")
    }

    func testSecretContainingColonIsPreservedAfterFirstColon() {
        // firstIndex(of: ":") means only the consumer name is split on; a secret with extra
        // characters after the first ":" must still match in full.
        XCTAssertEqual(NZImageApiLambda.authorizedConsumer(presented: "AbC:123", allowed: "site:AbC:123"), "site")
    }

    func testSinglePairListStillMatches() {
        XCTAssertEqual(NZImageApiLambda.authorizedConsumer(presented: "solo-secret", allowed: "only:solo-secret"), "only")
    }

    // The comparison hashes each operand to a fixed 32-byte SHA-256 digest before the
    // constant-time XOR, so it is length-independent. These pin that unequal-length inputs
    // still resolve correctly (the previous implementation early-returned on a length mismatch).

    func testPresentedShorterThanSecretReturnsNil() {
        XCTAssertNil(NZImageApiLambda.authorizedConsumer(presented: "AbC12", allowed: allowed))
    }

    func testPresentedLongerThanSecretReturnsNil() {
        XCTAssertNil(NZImageApiLambda.authorizedConsumer(presented: "AbC1234", allowed: allowed))
    }

    func testSecretThatIsAPrefixOfPresentedReturnsNil() {
        // "AbC123" is the real secret; a longer value that starts with it must not match.
        XCTAssertNil(NZImageApiLambda.authorizedConsumer(presented: "AbC123XYZ", allowed: allowed))
    }

    func testExactMatchStillResolvesAfterHashCompare() {
        XCTAssertEqual(NZImageApiLambda.authorizedConsumer(presented: "AbC123", allowed: allowed), "site")
    }
}
