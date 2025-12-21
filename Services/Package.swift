// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Services",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .executable(name: "LightningAddressDetailsProxy", targets: ["LightningAddressDetailsProxy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-cloud/swift-cloud", branch: "main"),
        .package(url: "https://github.com/awslabs/swift-aws-lambda-runtime", from: "2.4.0"),
        .package(url: "https://github.com/awslabs/swift-aws-lambda-events", from: "1.4.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.30.1"),
        .package(url: "https://github.com/swift-cloud/Compute", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "LightningAddressDetailsProxy",
            dependencies: [
                .product(name: "CloudSDK", package: "swift-cloud"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            path: "Sources/LightningAddressDetailsProxy"
        ),
        .executableTarget(name: "Infra",
            dependencies: [
                .product(name: "Cloud", package: "swift-cloud"),
            ],
            path: "Sources/Infra"
        ),
    ]
)

