import Foundation
import Version
import SwiftyTextTable
import Rainbow

public struct OutdatedPackage {
    public let package: String
    public let currentVersion: Version
    public let latestVersion: Version
    public let url: String
    /// Registry identity (`scope.name`) for registry dependencies; nil for source-control ones.
    public let registryIdentity: String?

    public init(package: String, currentVersion: Version, latestVersion: Version, url: String, registryIdentity: String? = nil) {
        self.package = package
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.url = url
        self.registryIdentity = registryIdentity
    }

    /// The locator shown in output: a `registry:` marker for registry packages, otherwise the git URL.
    public var displayURL: String {
        registryIdentity.map { "registry: \($0)" } ?? url
    }
}

extension OutdatedPackage: Encodable {}

extension OutdatedPackage: Comparable {
    public static func < (lhs: OutdatedPackage, rhs: OutdatedPackage) -> Bool {
        return lhs.package < rhs.package
    }
}

extension OutdatedPackage: TextTableRepresentable {
    public static let columnHeaders = [
        "Package",
        "Current",
        "Latest",
        "URL"
    ]

    public var tableValues: [CustomStringConvertible] {
        return [
            self.package,
            self.currentVersion.description,
            self.coloredLatestVersion,
            self.displayURL.blue
        ]
    }

    /// The latest version string, colored by how many major versions behind the current version is.
    var coloredLatestVersion: String {
        let latest = self.latestVersion.description
        switch latestVersion.major - currentVersion.major {
        case 1: return latest.green
        case 2: return latest.yellow
        case 3...: return latest.red
        default: return latest
        }
    }
}
