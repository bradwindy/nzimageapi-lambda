// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NZImageApiLambda",
    platforms: [.macOS(.v12)],
    products: [
      .executable(name: "NZImageApiLambda", targets: ["NZImageApiLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", .upToNextMajor(from: "1.0.0-alpha.3")),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/bradwindy/RichError.git", from: "2.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", .upToNextMajor(from: "2.6.0")),
    ],
    targets: [
        .executableTarget(
            name: "NZImageApiLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "RichError", package: "RichError"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ]
        ),
    ]
)
