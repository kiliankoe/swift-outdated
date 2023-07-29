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

extension OutdatedPackage: TextTableRepresentable {
    public static let columnHeaders = [
        "Package",
        "Current",
        "Latest",
        "URL"
    ]

    public var tableValues: [CustomStringConvertible] {
        let majorDiff = latestVersion.major - currentVersion.major
        var latestVersion = self.latestVersion.description
        switch majorDiff {
        case 1:
            latestVersion = latestVersion.green
        case 2:
            latestVersion = latestVersion.yellow
        case 3...:
            latestVersion = latestVersion.red
        default:
            break
        }
        return [
            self.package,
            self.currentVersion.description,
            latestVersion,
            self.url.blue
        ]
    }
}
