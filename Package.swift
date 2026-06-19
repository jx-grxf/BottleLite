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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.3")
    ],
    targets: [
        .executableTarget(
            name: "BottleLite",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/BottleLite"
        ),
        .testTarget(
            name: "BottleLiteTests",
            dependencies: ["BottleLite"],
            path: "Tests/BottleLiteTests"
        )
    ]
)
