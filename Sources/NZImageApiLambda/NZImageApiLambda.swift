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

@main
final class NZImageApiLambda: SimpleLambdaHandler {
    // MARK: Lifecycle

    init() {
        let requestManager = NetworkRequestManager()
        self.digitalNZAPIDataSource = DigitalNZAPIDataSource(requestManager: requestManager, collectionWeights: NZImageApiLambda.collectionWeights)
    }

    // MARK: Internal

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        switch (event.context.http.path, event.context.http.method) {
        case ("/image", .GET):
            guard let image = await image(context: context) else {
                return APIGatewayV2Response(statusCode: .badRequest)
            }

            return try APIGatewayV2Response(statusCode: .ok, headers: ["content-type": "application/json"], body: jsonEncoder.encodeAsString(image))

        default:
            return APIGatewayV2Response(statusCode: .notFound)
        }
    }

    // MARK: Private

    private static let collectionWeights: OrderedDictionary = ["Auckland Libraries Heritage Images Collection": 0.1546,
                                                               "Auckland Museum Collections": 0.1291,
                                                               "Te Papa Collections Online": 0.1193,
                                                               "TAPUHI": 0.1125,
                                                               "Nelson Provincial Museum": 0.088,
                                                               "Puke Ariki": 0.0812,
                                                               "Canterbury Museum": 0.0505,
                                                               "Kura Heritage Collections Online": 0.0408,
                                                               "Antarctica NZ Digital Asset Manager": 0.0317,
                                                               "Kete Christchurch": 0.0246,
                                                               "MOTAT": 0.0178,
                                                               "Hawke's Bay Knowledge Bank": 0.0148,
                                                               "Kete New Plymouth": 0.0146,
                                                               "Picture Wairarapa": 0.0141,
                                                               "Te Ara - The Encyclopedia of New Zealand": 0.0133,
                                                               "Auckland Art Gallery Toi o Tāmaki": 0.0099,
                                                               "Ministry for Culture and Heritage Te Ara Flickr": 0.0095,
                                                               "MTG Hawke's Bay": 0.0092,
                                                               "Europeana": 0.0084,
                                                               "Howick Historical Village NZMuseums": 0.0065,
                                                               "Te Awamutu Museum": 0.0064,
                                                               "Hamilton Heritage Collections": 0.0056,
                                                               "The James Wallace Arts Trust": 0.0053,
                                                               "Christchurch City Libraries Heritage Images Collection": 0.0045,
                                                               "Culture Waitaki": 0.0044,
                                                               "NZHistory": 0.0041,
                                                               "Archives Central": 0.004,
                                                               "Waikato Museum Te Whare Taonga o Waikato": 0.0038,
                                                               "Tairāwhiti Museum Te Whare Taonga o Tairāwhiti": 0.0037,
                                                               "Archives New Zealand Te Rua Mahara o te Kāwanatanga Flickr": 0.0029,
                                                               "Otago University Research Heritage": 0.0028,
                                                               "Sarjeant Gallery Te Whare o Rehua Whanganui": 0.0026]

    private let jsonEncoder = JSONEncoder()

    private let digitalNZAPIDataSource: DigitalNZAPIDataSource

    private func image(context: LambdaContext) async -> NZRecordsResult? {
        do {
            let result = try await digitalNZAPIDataSource.newResult()
            return result
        }
        catch {
            context.logger.error("An unexpected error occurred: \(error.localizedDescription)")
        }

        return nil
    }
}
