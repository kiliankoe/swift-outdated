import Foundation
import Version
import SwiftyTextTable
import Rainbow

struct OutdatedPackage {
    let package: String
    let currentVersion: Version
    let latestVersion: Version
    let url: String
}

extension OutdatedPackage: Encodable {}

extension OutdatedPackage: TextTableRepresentable {
    static let columnHeaders = [
        "Package",
        "Current",
        "Latest",
        "URL"
    ]

    var tableValues: [CustomStringConvertible] {
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
