//
//  NetworkRequestManagerSessionTests.swift
//
//  Regression coverage for the intermittent Lambda crash where a request completed all of its
//  work and then the process aborted with:
//
//      Object 0x... of class _MultiHandle deallocated with non-zero retain count 2.
//
//  NetworkRequestManager used to build a fresh Alamofire `Session` on every call. On Linux that
//  `Session` owns a `URLSession`, and releasing it runs swift-corelibs-foundation's
//  `URLSession._MultiHandle.deinit`, which re-enters libcurl's timer callback and takes a strong
//  reference to the object being deinitialized. The Swift runtime turns that into a fatal error,
//  which API Gateway surfaced as a 500 on roughly one request in four.
//
//  These tests pin the fix: the sessions are process-lifetime shared instances (so nothing is ever
//  deallocated), and each still carries the request configuration its callers depend on.
//

import Alamofire
import Foundation
import XCTest
@testable import NZImageApiLambda

final class NetworkRequestManagerSessionTests: XCTestCase {
    // MARK: No per-call sessions

    // The invariant this file exists to protect is "the Lambda target never constructs an HTTP
    // session outside the shared static factory". That cannot be observed at runtime -- the
    // statics are the same object however they are reached -- so it is checked against the source
    // itself, which is what a regression would actually change.

    func testTheLambdaTargetConstructsSessionsOnlyInTheSharedFactory() throws {
        var offenders: [String] = []

        for file in try Self.lambdaSourceFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)

            for (offset, line) in Self.codeLines(of: source) {
                guard line.contains("Session(configuration") || line.contains("URLSession(") else { continue }

                // The one legitimate construction site.
                let isSharedFactory = file.lastPathComponent == "NetworkRequestManager.swift"
                    && line.contains("return Session(configuration: configuration)")

                if !isSharedFactory {
                    offenders.append("\(file.lastPathComponent):\(offset + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }

        XCTAssertEqual(
            offenders,
            [],
            """
            A session is being constructed outside NetworkRequestManager.makeSession. On Linux, \
            releasing a URLSession runs _MultiHandle.deinit, which aborts the process and turns a \
            completed request into a 500. Add a process-lifetime static session instead.
            """
        )
    }

    func testTheSharedFactoryProducesExactlyTheThreeExpectedSessions() throws {
        let source = try String(contentsOf: Self.networkRequestManagerSource(), encoding: .utf8)
        let constructions = Self.codeLines(of: source).filter { $0.line.contains("Session(configuration") }
        let factoryCalls = Self.codeLines(of: source).filter { $0.line.contains("makeSession(") }

        XCTAssertEqual(constructions.count, 1, "Exactly one Session(configuration:) call is expected.")
        // The three static properties, plus the factory's own declaration line.
        XCTAssertEqual(factoryCalls.count, 4, "Expected three shared sessions built by one factory.")
    }

    // MARK: Configuration preserved

    func testBrowserSessionSendsBrowserUserAgentAndNoRequestTimeoutOverride() {
        let headers = Self.additionalHeaders(of: NetworkRequestManager.browserSession)

        XCTAssertEqual(headers["User-Agent"], NetworkRequestManager.browserUserAgent)
        XCTAssertNil(headers["Range"])
        // Untouched, so it keeps URLSessionConfiguration.default's 60s.
        XCTAssertEqual(NetworkRequestManager.browserSession.session.configuration.timeoutIntervalForRequest, 60)
    }

    func testShortTimeoutSessionKeepsTheFifteenSecondProbeTimeout() {
        let headers = Self.additionalHeaders(of: NetworkRequestManager.shortTimeoutBrowserSession)

        XCTAssertEqual(headers["User-Agent"], NetworkRequestManager.browserUserAgent)
        XCTAssertNil(headers["Range"])
        XCTAssertEqual(
            NetworkRequestManager.shortTimeoutBrowserSession.session.configuration.timeoutIntervalForRequest,
            15
        )
    }

    func testRangeProbeSessionKeepsTheSingleByteRangeHeader() {
        // Without this header the "does the high-res original exist" probes would download the
        // whole asset instead of one byte.
        let headers = Self.additionalHeaders(of: NetworkRequestManager.rangeProbeSession)

        XCTAssertEqual(headers["User-Agent"], NetworkRequestManager.browserUserAgent)
        XCTAssertEqual(headers["Range"], "bytes=0-0")
        XCTAssertEqual(NetworkRequestManager.rangeProbeSession.session.configuration.timeoutIntervalForRequest, 15)
    }

    func testBrowserUserAgentLooksLikeABrowser() {
        // Several sources 403 anything that does not present a browser UA.
        XCTAssertTrue(NetworkRequestManager.browserUserAgent.hasPrefix("Mozilla/5.0"))
    }

    // MARK: Helpers

    /// The repository root, derived from this file's own path.
    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // NZImageApiLambdaTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
    }

    private static func networkRequestManagerSource() -> URL {
        repositoryRoot()
            .appendingPathComponent("Sources/NZImageApiLambda/Helpers/NetworkRequestManager.swift")
    }

    private static func lambdaSourceFiles() throws -> [URL] {
        let root = repositoryRoot().appendingPathComponent("Sources/NZImageApiLambda")

        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw NSError(domain: "NetworkRequestManagerSessionTests", code: 1)
        }

        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Source lines with comment-only lines removed, so the doc comments that *mention*
    /// `Session(configuration:)` do not register as constructions.
    private static func codeLines(of source: String) -> [(offset: Int, line: String)] {
        source
            .components(separatedBy: "\n")
            .enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .map { (offset: $0.offset, line: $0.element) }
    }

    private static func additionalHeaders(of session: Session) -> [String: String] {
        var headers: [String: String] = [:]

        for (key, value) in session.session.configuration.httpAdditionalHeaders ?? [:] {
            guard let key = key as? String, let value = value as? String else { continue }
            headers[key] = value
        }

        return headers
    }
}
