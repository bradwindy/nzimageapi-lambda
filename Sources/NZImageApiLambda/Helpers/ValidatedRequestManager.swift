//
//  RequestManager.swift
//  NZImage
//
//  Created by Bradley Windybank on 10/04/23.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

protocol ValidatedRequestManager: Sendable {
    /// Make an async, throwing request to an `endpoint` with an `apiKey` and `parameters`, returns response of `NonNullableResult`, useful
    /// for safe handling of API responses with nullable properties.
    func makeRequest<ResponseType: NonNullableResult & Sendable>(
        endpoint: String,
        apiKey: String?,
        parameters: [String: any Sendable]?
    )
        async throws -> ResponseType

    /// A closure used for validating the network response
    var validation: @Sendable (URLRequest?, HTTPURLResponse, Data?) -> Result<Void, Error> { get}
}
