// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "SwiftOutdated",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .executable(
            name: "swift-outdated",
            targets: ["swift-outdated"]),
        .library(
            name: "SwiftOutdated",
            targets: ["SwiftOutdated"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "0.0.0")),
        .package(url: "https://github.com/mxcl/version.git", from: "2.0.0"),
        .package(url: "https://github.com/johnsundell/shellout.git", from: "2.3.0"),
        .package(url: "https://github.com/johnsundell/files.git", from: "4.0.0"),
        .package(url: "https://github.com/scottrhoyt/swiftytexttable.git", from: "0.9.0"),
        .package(url: "https://github.com/onevcat/rainbow.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "swift-outdated",
            dependencies: ["SwiftOutdated"]),
        .target(
            name: "SwiftOutdated",
            dependencies: [
                "ArgumentParser",
                "Version",
                "ShellOut",
                "Files",
                "SwiftyTextTable",
                "Rainbow",
            ]),
        .testTarget(
            name: "SwiftOutdatedTests",
            dependencies: ["SwiftOutdated"]),
    ]
)
