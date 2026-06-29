import Foundation
import Rainbow
import SwiftyTextTable
import Version

/// How outdated a branch/revision-pinned dependency is. A pure value type: the `baseTag` (the tag at
/// or before the pinned revision, via a local checkout) and `latestTag` (the newest available tag, via
/// `ls-remote`) are computed by the caller and handed in, so this type stays trivially testable.
public struct RefPinAnalysis: Sendable {
    public let package: String
    public let branch: String?
    public let revision: String
    public let baseTag: Version?       // Tag at or before the pinned commit
    public let latestTag: Version?     // Latest available tag
    public let url: String

    public init(
        package: String,
        branch: String? = nil,
        revision: String,
        baseTag: Version?,
        latestTag: Version?,
        url: String
    ) {
        self.package = package
        self.branch = branch
        self.revision = revision
        self.baseTag = baseTag
        self.latestTag = latestTag
        self.url = url
    }

    /// Short revision (first 7 characters).
    public var shortRevision: String {
        String(revision.prefix(7))
    }

    /// Current pin display, e.g. `main @ abc1234 (v1.2.0)`, `abc1234 (v1.2.0)`, or just `abc1234`.
    public var currentDisplay: String {
        var display = shortRevision
        if let branch {
            display = "\(branch) @ \(display)"
        }
        if let base = baseTag {
            display += " (v\(base))"
        }
        return display
    }

    /// Whether a newer tag exists than the one the pinned revision sits at.
    public var isOutdated: Bool {
        guard let base = baseTag, let latest = latestTag else {
            return false
        }
        return latest > base
    }
}

extension RefPinAnalysis: Encodable {}

extension RefPinAnalysis: Comparable {
    public static func < (lhs: RefPinAnalysis, rhs: RefPinAnalysis) -> Bool {
        lhs.package < rhs.package
    }
}

extension RefPinAnalysis: TextTableRepresentable {
    public static let columnHeaders = [
        "Package",
        "Pinned",
        "Latest",
        "URL"
    ]

    public var tableValues: [CustomStringConvertible] {
        let latestDisplay: String
        if let latest = latestTag {
            var latestStr = "v\(latest)"
            if isOutdated {
                // Color by how many major versions the latest tag is ahead of the base, matching
                // the main outdated table's convention.
                switch (baseTag.map { latest.major - $0.major }) ?? 0 {
                case 1: latestStr = latestStr.green
                case 2: latestStr = latestStr.yellow
                case 3...: latestStr = latestStr.red
                default: break
                }
            }
            latestDisplay = latestStr
        } else {
            latestDisplay = "N/A"
        }

        return [
            self.package,
            self.currentDisplay,
            latestDisplay,
            self.url.blue
        ]
    }
}
