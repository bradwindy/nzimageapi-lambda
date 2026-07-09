//
//  NetworkRequestManagerValidationTests.swift
//
//  Coverage for NetworkRequestManager.validation (Sources/NZImageApiLambda/Helpers/
//  NetworkRequestManager.swift) — a pure closure given a constructed HTTPURLResponse, so it's
//  testable without any actual network request.
//

import Foundation
import XCTest
@testable import NZImageApiLambda
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class NetworkRequestManagerValidationTests: XCTestCase {
    private func response(statusCode: Int, contentType: String?) -> HTTPURLResponse {
        var headers: [String: String] = [:]
        if let contentType { headers["Content-Type"] = contentType }

        return HTTPURLResponse(
            url: URL(string: "https://api.digitalnz.org/records.json")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }

    private func validate(statusCode: Int, contentType: String?) -> Result<Void, Error> {
        NetworkRequestManager().validation(nil, response(statusCode: statusCode, contentType: contentType), nil)
    }

    func testSucceedsFor200WithJSONContentType() {
        let result = validate(statusCode: 200, contentType: "application/json")
        if case .failure(let error) = result {
            XCTFail("expected success, got failure: \(error)")
        }
    }

    func testSucceedsForOtherStatusesInThe2xxRange() {
        for statusCode in [201, 204, 299] {
            let result = validate(statusCode: statusCode, contentType: "application/json")
            if case .failure(let error) = result {
                XCTFail("expected success for \(statusCode), got failure: \(error)")
            }
        }
    }

    func testFailsWithNon200StatusCodeForNon2xxStatus() {
        for statusCode in [400, 404, 500, 199, 300] {
            let result = validate(statusCode: statusCode, contentType: "application/json")
            guard case .failure(let error) = result,
                  let richError = error as? NetworkRequestManager.NetworkRequestManagerError
            else {
                XCTFail("expected non200StatusCode failure for \(statusCode), got \(result)")
                continue
            }
            XCTAssertEqual(richError.kind, .non200StatusCode)
        }
    }

    func testFailsWithNonJsonResponseFor2xxWithNonJsonMimeType() {
        let result = validate(statusCode: 200, contentType: "text/html")
        guard case .failure(let error) = result,
              let richError = error as? NetworkRequestManager.NetworkRequestManagerError
        else {
            XCTFail("expected nonJsonResponse failure, got \(result)")
            return
        }
        XCTAssertEqual(richError.kind, .nonJsonResponse)
    }

    func testFailsWithNonJsonResponseFor2xxWithMissingContentType() {
        let result = validate(statusCode: 200, contentType: nil)
        guard case .failure(let error) = result,
              let richError = error as? NetworkRequestManager.NetworkRequestManagerError
        else {
            XCTFail("expected nonJsonResponse failure, got \(result)")
            return
        }
        XCTAssertEqual(richError.kind, .nonJsonResponse)
    }

    func testNon200StatusCodeIsCheckedBeforeContentType() {
        // A non-2xx status with a non-JSON content type should still surface as
        // non200StatusCode (the status check happens first), not nonJsonResponse.
        let result = validate(statusCode: 404, contentType: "text/html")
        guard case .failure(let error) = result,
              let richError = error as? NetworkRequestManager.NetworkRequestManagerError
        else {
            XCTFail("expected non200StatusCode failure, got \(result)")
            return
        }
        XCTAssertEqual(richError.kind, .non200StatusCode)
    }
}
