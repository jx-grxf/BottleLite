// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BottleLite",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BottleLite", targets: ["BottleLite"])
    ],
    targets: [
        .executableTarget(
            name: "BottleLite",
            path: "Sources/BottleLite"
        ),
        .testTarget(
            name: "BottleLiteTests",
            dependencies: ["BottleLite"],
            path: "Tests/BottleLiteTests"
        )
    ]
)
