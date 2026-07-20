// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalhostBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "LocalhostCore", targets: ["LocalhostCore"]),
        .executable(name: "LocalhostBar", targets: ["LocalhostBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "LocalhostCore",
            path: "Sources/LocalhostCore"
        ),
        .executableTarget(
            name: "LocalhostBar",
            dependencies: [
                "LocalhostCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/LocalhostBar"
        ),
        .testTarget(
            name: "LocalhostCoreTests",
            dependencies: ["LocalhostCore"],
            path: "Tests/LocalhostCoreTests"
        )
    ]
)
