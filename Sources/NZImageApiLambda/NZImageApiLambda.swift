//
//  NZImageApiLambda.swift
//
//
//  Created by Bradley Windybank on 17/06/23.
//

import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation
import HTTPTypes

struct NZImageApiLambda {
    let api = NZImageApi()

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        guard let clients = ProcessInfo.processInfo.environment["API_CLIENT_SECRETS"], !clients.isEmpty else {
            context.logger.log(level: .error, "API_CLIENT_SECRETS env var not configured; refusing request")
            return APIGatewayV2Response(statusCode: .internalServerError)
        }

        guard let provided = event.headers.first(name: "secret"),
              let consumer = Self.authorizedConsumer(presented: provided, allowed: clients)
        else {
            return APIGatewayV2Response(statusCode: .unauthorized)
        }
        context.logger.log(level: .info, "Authorized consumer: \(consumer)")

        switch (event.context.http.path, event.context.http.method) {
        case ("/collections", .get):
            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = .withoutEscapingSlashes
            let jsonData = try jsonEncoder.encode(Array(NZImageApi.collectionImageCounts.keys))
            let jsonString = String(data: jsonData, encoding: .utf8)

            return APIGatewayV2Response(statusCode: .ok, headers: ["content-type": "application/json"], body: jsonString)

        case ("/image", .get):
            let requestedCollection = event.queryStringParameters?["collection"]

            // `collection` (single explicit override) wins over `exclude`; only consult `exclude`
            // when no explicit collection was requested.
            let exclude: Set<String>
            if requestedCollection != nil {
                exclude = []
            }
            else if let excludeParam = event.queryStringParameters?["exclude"], !excludeParam.isEmpty {
                exclude = Set(excludeParam.split(separator: ",").map(String.init))
            }
            else {
                exclude = []
            }

            context.logger.log(level: .info, "Requested collection: \(requestedCollection ?? "random")")
            context.logger.log(level: .info, "Excluded collections: \(exclude.isEmpty ? "none" : exclude.sorted().joined(separator: ", "))")

            guard let image = await api.image(collection: requestedCollection, exclude: exclude, logger: { log in
                context.logger.log(level: .info, "\(log)")
            }) else {
                context.logger.log(level: .error, "Failed to get image for collection: \(requestedCollection ?? "random")")
                return APIGatewayV2Response(statusCode: .badRequest, body: "Failed to get image for collection: \(requestedCollection ?? "random")")
            }

            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = .withoutEscapingSlashes
            let jsonData = try jsonEncoder.encode(image)
            let jsonString = String(data: jsonData, encoding: .utf8)

            return APIGatewayV2Response(statusCode: .ok, headers: ["content-type": "application/json"], body: jsonString)

        default:
            return APIGatewayV2Response(statusCode: .notFound)
        }
    }

    /// Compares two strings in constant time (independent of where they first differ), to avoid
    /// leaking a secret's value through response-timing side channels.
    private static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in x.indices { diff |= x[i] ^ y[i] }
        return diff == 0
    }

    /// `allowed` is `API_CLIENT_SECRETS`: a comma-separated list of `name:secret` pairs, one per
    /// approved consumer (e.g. `"site:AbC…,mobile:XyZ…"`). Returns the name of the consumer whose
    /// secret matches `presented`, or nil if none match. Checks every entry rather than returning on
    /// the first match, so response timing doesn't reveal which -- or how many -- entries matched.
    /// Not private, so it's directly unit-testable via `@testable import`.
    static func authorizedConsumer(presented: String, allowed: String) -> String? {
        var matched: String?
        for entry in allowed.split(separator: ",") {
            guard let separator = entry.firstIndex(of: ":") else { continue }
            let name = String(entry[..<separator])
            let secret = String(entry[entry.index(after: separator)...])
            if constantTimeEquals(presented, secret) { matched = name }
        }
        return matched
    }
}
