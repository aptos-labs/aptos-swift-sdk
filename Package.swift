// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AptosSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AptosSDK", targets: ["AptosSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift", from: "0.18.0"),
        .package(url: "https://github.com/attaswift/BigInt", from: "5.4.0"),
    ],
    targets: [
        .target(
            name: "AptosSDK",
            dependencies: [
                .product(name: "P256K", package: "secp256k1.swift"),
                .product(name: "BigInt", package: "BigInt"),
            ]
        ),
        .testTarget(
            name: "AptosSDKTests",
            dependencies: ["AptosSDK"]
        ),
    ]
)
