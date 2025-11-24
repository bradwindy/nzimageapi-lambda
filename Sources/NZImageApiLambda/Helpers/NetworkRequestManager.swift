//
//  NetworkRequestManager.swift
//  NZImage
//
//  Created by Bradley Windybank on 26/03/23.
//

import Alamofire
import Foundation
import RichError
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

final class NetworkRequestManager: ValidatedRequestManager {
    struct NetworkRequestManagerError: RichError {
        typealias ErrorKind = NetworkRequestManagerErrorKind

        enum NetworkRequestManagerErrorKind: String {
            case non200StatusCode
            case nonJsonResponse
        }

        var kind: NetworkRequestManagerErrorKind
        var data: [String: String]
    }

    let validation: @Sendable (URLRequest?, HTTPURLResponse, Data?) -> Result<Void, Error> = { request, response, data in
        let acceptableStatusCodes = 200 ..< 300

        let errorData: [String: String] = [
            "request": request?.description ?? "nil request",
            "response": response.description,
            "data": data?.description ?? "nil data",
        ]

        guard acceptableStatusCodes.contains(response.statusCode) else {
            return .failure(NetworkRequestManagerError(kind: .non200StatusCode, data: errorData))
        }

        guard response.mimeType == "application/json" else {
            return .failure(NetworkRequestManagerError(kind: .nonJsonResponse, data: errorData))
        }

        return .success(())
    }

    func makeRequest<ResponseType: NonNullableResult & Sendable>(
        endpoint: String,
        apiKey: String? = nil,
        parameters: [String: any Sendable]? = nil
    )
        async throws -> ResponseType
    {
        var headers: HTTPHeaders? = nil

        if let apiKey {
            headers = HTTPHeaders(["Authentication-Token": apiKey])
        }

        let request = AF.request(endpoint, parameters: parameters, headers: headers)

        let result = await request
            .validate(validation)
            .serializingDecodable(ResponseType.self)
            .result

        switch result {
        case let .success(value):
            return value

        case let .failure(error):
            throw error
        }
    }

    func fetchHTML(endpoint: String) async throws -> String {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        ]

        let session = Session(configuration: configuration)
        let response = await session.request(endpoint).serializingString().response

        switch response.result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }

    func headRequest(endpoint: String) async throws -> (contentType: String, contentLength: Int64) {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        ]

        let session = Session(configuration: configuration)
        let response = await session.request(endpoint, method: .head).serializingData().response

        guard let httpResponse = response.response else {
            throw NetworkRequestManagerError(
                kind: .non200StatusCode,
                data: ["endpoint": endpoint, "error": "No response received"]
            )
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        let contentLength = Int64(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "0") ?? 0

        return (contentType, contentLength)
    }
}
