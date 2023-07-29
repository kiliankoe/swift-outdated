// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "SwiftOutdated",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "swift-outdated",
            targets: ["SwiftOutdated"]),
        .library(
            name: "Outdated",
            targets: ["Outdated"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
        .package(url: "https://github.com/mxcl/Version.git", from: "2.0.0"),
        .package(url: "https://github.com/johnsundell/ShellOut.git", from: "2.3.0"),
        .package(url: "https://github.com/johnsundell/Files.git", from: "4.0.0"),
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable.git", from: "0.9.0"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "Outdated",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                "Files",
                "Rainbow",
                "ShellOut",
                "SwiftyTextTable",
                "Version",
            ]
        ),
        .executableTarget(
            name: "SwiftOutdated",
            dependencies: [
                "Outdated",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                "Version",
                "SwiftyTextTable",
            ]
        ),
    ]
)
