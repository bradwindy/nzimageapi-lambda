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
        guard let expected = ProcessInfo.processInfo.environment["SECRET"], !expected.isEmpty else {
            context.logger.log(level: .error, "SECRET env var not configured; refusing request")
            return APIGatewayV2Response(statusCode: .internalServerError)
        }

        guard let provided = event.headers.first(name: "secret"), Self.constantTimeEquals(provided, expected) else {
            return APIGatewayV2Response(statusCode: .unauthorized)
        }

        switch (event.context.http.path, event.context.http.method) {
        case ("/image", .get):
            let requestedCollection = event.queryStringParameters?["collection"]

            context.logger.log(level: .info, "Requested collection: \(requestedCollection ?? "random")")

            guard let image = await api.image(collection: requestedCollection, logger: { log in
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
    /// leaking the secret's value through response-timing side channels.
    private static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in x.indices { diff |= x[i] ^ y[i] }
        return diff == 0
    }
}
