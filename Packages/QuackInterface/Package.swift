// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "QuackInterface",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "QuackInterface", targets: ["QuackInterface"])
    ],
    dependencies: [
        .package(path: "../../../AgentRunKit")
    ],
    targets: [
        .target(
            name: "QuackInterface",
            dependencies: [
                .product(name: "AgentRunKit", package: "AgentRunKit"),
                .product(name: "AgentRunKitFoundationModels", package: "AgentRunKit")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
