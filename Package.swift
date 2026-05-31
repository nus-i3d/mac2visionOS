// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Mac2VisionOS",
    platforms: [
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Mac2VisionOS",
            type: .dynamic,
            targets: ["Mac2VisionOS"]
        )
    ],
    targets: [
        .target(
            name: "Mac2VisionOS"
        ),
        .testTarget(
            name: "Mac2VisionOSTests",
            dependencies: ["Mac2VisionOS"]
        )
    ]
)
