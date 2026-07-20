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
    targets: [
        .target(
            name: "LocalhostCore",
            path: "Sources/LocalhostCore"
        ),
        .executableTarget(
            name: "LocalhostBar",
            dependencies: ["LocalhostCore"],
            path: "Sources/LocalhostBar"
        ),
        .testTarget(
            name: "LocalhostCoreTests",
            dependencies: ["LocalhostCore"],
            path: "Tests/LocalhostCoreTests"
        )
    ]
)
