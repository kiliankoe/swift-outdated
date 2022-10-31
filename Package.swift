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
            targets: ["swift-outdated"]),
        .library(
            name: "SwiftOutdated",
            targets: ["SwiftOutdated"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/mxcl/version.git", from: "2.0.0"),
        .package(url: "https://github.com/johnsundell/shellout.git", from: "2.3.0"),
        .package(url: "https://github.com/johnsundell/files.git", from: "4.0.0"),
        .package(url: "https://github.com/scottrhoyt/swiftytexttable.git", from: "0.9.0"),
        .package(url: "https://github.com/onevcat/rainbow.git", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "swift-outdated",
            dependencies: ["SwiftOutdated"]),
        .target(
            name: "SwiftOutdated",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Version", package: "version"),
                .product(name: "ShellOut", package: "shellout"),
                .product(name: "Files", package: "files"),
                .product(name: "SwiftyTextTable", package: "swiftytexttable"),
                .product(name: "Rainbow", package: "rainbow"),
            ]),
        .testTarget(
            name: "SwiftOutdatedTests",
            dependencies: ["SwiftOutdated"]),
    ]
)
