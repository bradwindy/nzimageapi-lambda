// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NZImageApiLambda",
    platforms: [.macOS(.v15)],
    products: [
      .executable(name: "NZImageApiLambda", targets: ["NZImageApiLambda"]),
      .executable(name: "CollectionTester", targets: ["CollectionTester"]),
      .executable(name: "ImageResolutionChecker", targets: ["ImageResolutionChecker"]),
      .executable(name: "CollectionLister", targets: ["CollectionLister"]),
      .executable(name: "CollectionReviewer", targets: ["CollectionReviewer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/awslabs/swift-aws-lambda-runtime.git", from: "2.11.0"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "1.5.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.12.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.6.0"),
        .package(url: "https://github.com/bradwindy/RichError.git", from: "2.1.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.15.1"),
        // Pinned explicitly (not just a transitive dep of swift-service-lifecycle) to force
        // resolution past 1.1.3: 1.1.4 fixes region-isolation errors that the newer Swift
        // compiler flags as build failures in this package's own source.
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.1.4"),
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
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "Crypto", package: "swift-crypto")
            ]
        ),
        .testTarget(
            name: "NZImageApiLambdaTests",
            dependencies: ["NZImageApiLambda"],
            path: "Tests/NZImageApiLambdaTests"
        ),
        .target(
            name: "LambdaTesting",
            dependencies: [],
            path: "Sources/Testing/LambdaTesting"
        ),
        .testTarget(
            name: "LambdaTestingTests",
            dependencies: ["LambdaTesting"]
        ),
        .executableTarget(
            name: "CollectionTester",
            dependencies: ["LambdaTesting"],
            path: "Sources/Testing/CollectionTester"
        ),
        .executableTarget(
            name: "ImageResolutionChecker",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "RichError", package: "RichError"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ],
            path: "Sources/Testing/ImageResolutionChecker"
        ),
        .executableTarget(
            name: "CollectionLister",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "Sources/Testing/CollectionLister"
        ),
        .executableTarget(
            name: "CollectionReviewer",
            dependencies: ["LambdaTesting"],
            path: "Sources/Testing/CollectionReviewer"
        ),
    ]
)
