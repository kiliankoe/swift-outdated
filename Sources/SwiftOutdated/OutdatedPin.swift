import Foundation
import Version
import SwiftyTextTable

struct OutdatedPin {
    let package: String
    let currentVersion: Version
    let latestVersion: Version
}

extension OutdatedPin: TextTableRepresentable {
    static let columnHeaders = [
        "Package",
        "Current",
        "Latest"
    ]

    var tableValues: [CustomStringConvertible] {
        [
            self.package,
            self.currentVersion.description,
            self.latestVersion.description
        ]
    }
}
