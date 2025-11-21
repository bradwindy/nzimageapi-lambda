// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NZImageApiLambda",
    platforms: [.macOS(.v15)],
    products: [
      .executable(name: "NZImageApiLambda", targets: ["NZImageApiLambda"]),
      .executable(name: "CollectionTester", targets: ["CollectionTester"]),
      .executable(name: "CollectionFetcher", targets: ["CollectionFetcher"]),
      .library(name: "NZImageApiLambdaLib", targets: ["NZImageApiLambdaLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/awslabs/swift-aws-lambda-runtime.git", from: "2.3.1"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "0.4.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
        .package(url: "https://github.com/bradwindy/RichError.git", from: "2.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "NZImageApiLambdaLib",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "RichError", package: "RichError"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ],
            path: "Sources/NZImageApiLambdaLib"
        ),
        .executableTarget(
            name: "NZImageApiLambda",
            dependencies: [
                "NZImageApiLambdaLib",
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ]
        ),
        .executableTarget(
            name: "CollectionTester",
            dependencies: [
                "NZImageApiLambdaLib"
            ]
        ),
        .executableTarget(
            name: "CollectionFetcher",
            dependencies: []
        ),
    ]
)
