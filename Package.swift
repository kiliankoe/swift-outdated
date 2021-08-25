// swift-tools-version:5.3

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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.2"),
        .package(name: "Version", url: "https://github.com/mxcl/version.git", from: "2.0.0"),
        .package(name: "ShellOut", url: "https://github.com/johnsundell/shellout.git", from: "2.3.0"),
        .package(name: "Files", url: "https://github.com/johnsundell/files.git", from: "4.0.0"),
        .package(name: "SwiftyTextTable", url: "https://github.com/scottrhoyt/swiftytexttable.git", from: "0.9.0"),
        .package(name: "Rainbow", url: "https://github.com/onevcat/rainbow.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "swift-outdated",
            dependencies: ["SwiftOutdated"]),
        .target(
            name: "SwiftOutdated",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
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
