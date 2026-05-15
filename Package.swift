// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeDock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClaudeDock", targets: ["ClaudeDock"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeDock",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/ClaudeDock",
            exclude: ["Resources/Info.plist", "Resources/AppIcon.icns"],
            resources: []
        ),
        .testTarget(
            name: "ClaudeDockTests",
            dependencies: ["ClaudeDock"],
            path: "Tests/ClaudeDockTests"
        ),
    ]
)
