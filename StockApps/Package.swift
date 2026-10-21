// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StockApps",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "StockScreener", targets: ["StockScreener"]),
        .executable(name: "StockEvaluator", targets: ["StockEvaluator"]),
    ],
    targets: [
        // Shared Yahoo Finance client, indicators and views.
        .target(
            name: "StockCore",
            path: "Sources/StockCore"
        ),
        .executableTarget(
            name: "StockScreener",
            dependencies: ["StockCore"],
            path: "Sources/StockScreener"
        ),
        .executableTarget(
            name: "StockEvaluator",
            dependencies: ["StockCore"],
            path: "Sources/StockEvaluator"
        ),
        .testTarget(
            name: "StockCoreTests",
            dependencies: ["StockCore"],
            path: "Tests/StockCoreTests"
        ),
        .testTarget(
            name: "StockScreenerTests",
            dependencies: ["StockScreener", "StockCore"],
            path: "Tests/StockScreenerTests"
        ),
        .testTarget(
            name: "StockEvaluatorTests",
            dependencies: ["StockEvaluator", "StockCore"],
            path: "Tests/StockEvaluatorTests"
        ),
    ]
)
