// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AptosSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "AptosSDK",
            targets: ["AptosSDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", from: "0.18.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.4.0"),
    ],
    targets: [
        .target(
            name: "AptosSDK",
            dependencies: [
                .product(name: "P256K", package: "secp256k1.swift"),
                .product(name: "BigInt", package: "BigInt"),
            ],
            path: "Sources/AptosSDK"
        ),
        .testTarget(
            name: "AptosSDKTests",
            dependencies: ["AptosSDK"],
            path: "Tests/AptosSDKTests"
        ),
    ]
)
