// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tack",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "Tack", targets: ["Tack"]),
        .executable(name: "TackCLI", targets: ["TackCLI"]),
        .library(name: "TackKit", targets: ["TackKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.12.0", traits: ["Tagged"]),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.10.1"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.1"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),
        .package(url: "https://github.com/pointfreeco/swift-debug-snapshots", from: "0.5.1"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
    ],
    targets: [
        .target(
            name: "TackKit",
            dependencies: [
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "Tagged", package: "swift-tagged"),
                .product(name: "DebugSnapshots", package: "swift-debug-snapshots"),
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .target(
            name: "TackUI",
            dependencies: [
                "TackKit",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .executableTarget(
            name: "Tack",
            dependencies: ["TackKit", "TackUI"]
        ),
        .executableTarget(
            name: "TackCLI",
            dependencies: [
                "TackKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "TackKitTests",
            dependencies: [
                "TackKit",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "DebugSnapshots", package: "swift-debug-snapshots"),
            ],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "TackUITests",
            dependencies: ["TackUI", "TackKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
