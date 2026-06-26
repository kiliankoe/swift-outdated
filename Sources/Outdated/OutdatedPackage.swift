import Foundation
import Version
import SwiftyTextTable
import Rainbow

public struct OutdatedPackage {
    public let package: String
    public let currentVersion: Version
    public let latestVersion: Version
    public let url: String

    public init(package: String, currentVersion: Version, latestVersion: Version, url: String) {
        self.package = package
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.url = url
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
            self.url.blue
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
