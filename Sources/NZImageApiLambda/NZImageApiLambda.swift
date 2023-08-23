//
//  main.swift
//
//
//  Created by Bradley Windybank on 17/06/23.
//

import AWSLambdaEvents
import AWSLambdaRuntime
import Foundation
import OrderedCollections
import RichError

@main
final class NZImageApiLambda: SimpleLambdaHandler {
    // MARK: Lifecycle

    init() {
        let requestManager = NetworkRequestManager()
        let urlProcessor = URLProcessor()
        
        self.digitalNZAPIDataSource = DigitalNZAPIDataSource(requestManager: requestManager,
                                                             collectionWeights: NZImageApiLambda.collectionWeights,
                                                             urlProcessor: urlProcessor)
    }

    // MARK: Internal

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        switch (event.context.http.path, event.context.http.method) {
        case ("/image", .GET):
            guard let image = await image(context: context) else {
                return APIGatewayV2Response(statusCode: .badRequest)
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

    // MARK: Private

    private static let collectionWeights: OrderedDictionary = ["Auckland Museum Collections": 1.0]

    private let jsonEncoder = JSONEncoder()

    private let digitalNZAPIDataSource: DigitalNZAPIDataSource

    private func image(context: LambdaContext) async -> NZRecordsResult? {
        do {
            let result = try await digitalNZAPIDataSource.newResult(logger: { log in
                context.logger.log(level: .trace, "\(log)")
            })
            return result
        }
        catch {
            if let richError = error as? (any RichError) {
                // Get the raw value from the enum that defines the kind of error. Messy due to RichError being a protocol and the nested associated types.
                let kind = (richError.kind as any RawRepresentable).rawValue as? String ?? "unknownKind"
                
                context.logger.error("A rich error occurred. Kind: \(kind), Data: \(richError.data)")
            }
            else {
                context.logger.error("An unexpected error occurred: \(error.localizedDescription)")
            }
        }

        return nil
    }
}
