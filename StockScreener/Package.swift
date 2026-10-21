// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StockScreener",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StockScreener",
            path: "Sources/StockScreener"
        ),
        .testTarget(
            name: "StockScreenerTests",
            dependencies: ["StockScreener"],
            path: "Tests/StockScreenerTests"
        ),
    ]
)
