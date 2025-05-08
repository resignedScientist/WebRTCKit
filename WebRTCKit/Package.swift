// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebRTCKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WebRTCKit",
            targets: ["WebRTCKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC.git", .upToNextMajor(from: "136.0.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WebRTCKit",
            dependencies: [
                .product(name: "WebRTC", package: "WebRTC")
            ]
        ),
        .testTarget(
            name: "WebRTCKitTests",
            dependencies: ["WebRTCKit"]
        ),
    ]
)
