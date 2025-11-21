//
//  App.swift
//
//
//  Created by Bradley Windybank on 17/06/23.
//

import AWSLambdaEvents
import AWSLambdaRuntime

@main
struct Main {
    static func main() async throws {
        let handler = NZImageApiLambda()

        let runtime = LambdaRuntime { (event: APIGatewayV2Request, context: LambdaContext) in
            try await handler.handle(event, context: context)
        }

        try await runtime.run()
    }
}
