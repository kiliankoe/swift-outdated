import Foundation
import Rainbow
import SwiftyTextTable

public struct PackageCollection: Encodable {
    public var outdatedPackages: [OutdatedPackage]
    public var ignoredPackages: [SwiftPackage]
    public var upToDatePackages: [SwiftPackage]
    /// Version-pinned packages whose remote couldn't be reached (typically a private repo needing
    /// credentials); their latest version is unknown, not confirmed up to date.
    public var unknownPackages: [SwiftPackage] = []
    public var securityResults: [String: SecurityPair]?
    public var refPinnedPackages: [RefPinAnalysis] = []

    enum CodingKeys: String, CodingKey {
        case outdatedPackages, ignoredPackages, upToDatePackages, unknownPackages, securityResults, refPinnedPackages
    }
}

extension PackageCollection {
    public enum OutputFormat: String {
        case markdown
        case json
        case xcode
    }

    public func output(format: OutputFormat, includeUpToDatePackages: Bool = false) {
        guard !self.outdatedPackages.isEmpty || !self.ignoredPackages.isEmpty || !self.refPinnedPackages.isEmpty
            || !self.unknownPackages.isEmpty
            || (includeUpToDatePackages && !self.upToDatePackages.isEmpty) else { return }

        switch format {
        case .xcode:
            self.outdatedPackages.forEach {
                var warning = "warning: Dependency \"\($0.package)\" is outdated (\($0.currentVersion) < \($0.latestVersion)) → \($0.displayURL)"
                if case .vulnerable(let count, _)? = securityResults?[$0.package]?.currentOSV {
                    warning += " — \(count) known CVE\(count > 1 ? "s" : "")"
                }
                print(warning)
            }
            self.refPinnedPackages.filter { $0.isOutdated }.forEach {
                let pin = $0.branch.map { "branch \($0)" } ?? "a revision"
                let base = $0.baseTag.map { " (~v\($0))" } ?? ""
                let latest = $0.latestTag.map { "v\($0)" } ?? "a newer tag"
                print("warning: Dependency \"\($0.package)\" is pinned to \(pin) at \($0.shortRevision)\(base) but \(latest) is available → \($0.url)")
            }
            self.unknownPackages.forEach {
                print("warning: Could not check \"\($0.package)\" for updates, is it a private repository needing credentials? → \($0.displayURL)")
            }
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let json = try! encoder.encode(self)
            print(String(data: json, encoding: .utf8)!)
        case .markdown:
            // Everything folds into a single table. Branch/revision pins put their "Pinned" cell in
            // the Current column; up-to-date and ignored rows are distinguished by the Latest column
            // (a green check vs. a dim "?"). Behind pins show by default; with -u every package does.
            let refPins = includeUpToDatePackages ? refPinnedPackages : refPinnedPackages.filter { $0.isOutdated }

            if let securityResults = securityResults {
                var rows = outdatedPackages.map { OutdatedPackageWithSecurity(base: $0, security: securityResults[$0.package]).tableValues }
                rows += refPins.map { refPinSecurityRow($0) }
                rows += unknownPackages.map { unknownSecurityRow($0) }
                if includeUpToDatePackages {
                    rows += upToDatePackages.map { upToDateSecurityRow($0) }
                    rows += ignoredPackages.map { ignoredSecurityRow($0) }
                }
                renderRows(nil, headers: OutdatedPackageWithSecurity.columnHeaders, rows: rows)
            } else {
                var rows = outdatedPackages.map { $0.tableValues }
                rows += refPins.map { $0.tableValues }
                rows += unknownPackages.map { unknownRow($0) }
                if includeUpToDatePackages {
                    rows += upToDatePackages.map { upToDateRow($0) }
                    rows += ignoredPackages.map { ignoredRow($0) }
                }
                renderRows(nil, headers: OutdatedPackage.columnHeaders, rows: rows)
            }

            if !includeUpToDatePackages, !self.ignoredPackages.isEmpty {
                let ignoredString = self.ignoredPackages.map { $0.package }.joined(separator: ", ")
                print("Ignored because of revision or branch pins: \(ignoredString)")
            }
        }
    }
    
    private struct OutdatedPackageWithSecurity: TextTableRepresentable {
        let base: OutdatedPackage
        let security: SecurityPair?

        static let columnHeaders = ["Package", "Current", "Sec. Current", "Latest", "Sec. Latest", "Score", "URL"]

        var tableValues: [CustomStringConvertible] {
            return [
                base.package,
                base.currentVersion.description,
                SecurityLabel.osv(security?.currentOSV),
                base.coloredLatestVersion,
                SecurityLabel.osv(security?.latestOSV),
                SecurityLabel.score(security?.scorecardScore),
                base.displayURL.blue
            ]
        }
    }

    /// Renders the security columns. CVE status (OSV) is version-specific; the Scorecard score rates the repository.
    enum SecurityLabel {
        static func osv(_ status: OSVStatus?) -> String {
            switch status {
            case .vulnerable(let count, _):
                return "⚠ \(count) CVE\(count > 1 ? "s" : "")".red
            case .safe:
                return "✓ No CVEs".green
            case .unknown, .none:
                // Couldn't determine CVE status (no advisory data or the query failed) — not the same as "safe".
                return "?".dim
            }
        }

        static func score(_ score: Double?) -> String {
            guard let score = score else { return "?".dim }
            let scoreStr = String(format: "%.1f/10", score)
            return score < 5.0 ? "⚠ \(scoreStr)".yellow : "✓ \(scoreStr)".green
        }
    }

    /// Up-to-date packages aren't behind any release, so the Latest cell shows a check rather than a version.
    private func upToDateRow(_ pkg: SwiftPackage) -> [CustomStringConvertible] {
        [pkg.package, pkg.version?.description ?? pkg.revision ?? "N/A", "✓".green, pkg.displayURL.blue]
    }

    /// Ignored pins couldn't be analyzed against a checkout, so the latest tag is unknown.
    private func ignoredRow(_ pkg: SwiftPackage) -> [CustomStringConvertible] {
        [pkg.package, pkg.version?.description ?? pkg.revision ?? "N/A", "?".dim, pkg.displayURL.blue]
    }

    /// A version-pinned package whose remote couldn't be reached: current version is known, latest isn't.
    private func unknownRow(_ pkg: SwiftPackage) -> [CustomStringConvertible] {
        [pkg.package, pkg.version?.description ?? pkg.revision ?? "N/A", "?".dim, pkg.displayURL.blue]
    }

    /// Up-to-date packages aren't security-scanned, so the CVE/score cells are unknown.
    private func upToDateSecurityRow(_ pkg: SwiftPackage) -> [CustomStringConvertible] {
        [pkg.package, pkg.version?.description ?? pkg.revision ?? "N/A", "?".dim, "✓".green, "?".dim, "?".dim, pkg.displayURL.blue]
    }

    /// Ignored pins are neither analyzed nor security-scanned, so every derived cell is unknown.
    private func ignoredSecurityRow(_ pkg: SwiftPackage) -> [CustomStringConvertible] {
        [pkg.package, pkg.version?.description ?? pkg.revision ?? "N/A", "?".dim, "?".dim, "?".dim, "?".dim, pkg.displayURL.blue]
    }

    /// An unreachable version-pinned package can't be security-scanned either, so latest and every
    /// security cell is unknown; only its current version is known.
    private func unknownSecurityRow(_ pkg: SwiftPackage) -> [CustomStringConvertible] {
        [pkg.package, pkg.version?.description ?? pkg.revision ?? "N/A", "?".dim, "?".dim, "?".dim, "?".dim, pkg.displayURL.blue]
    }

    /// Ref pins aren't security-scanned, so the CVE/score cells are unknown.
    private func refPinSecurityRow(_ analysis: RefPinAnalysis) -> [CustomStringConvertible] {
        [
            analysis.package,
            analysis.currentDisplay,
            "?".dim,
            analysis.latestDisplay,
            "?".dim,
            "?".dim,
            analysis.url.blue,
        ]
    }

    /// Renders rows from possibly-heterogeneous sources under a shared set of headers, in the
    /// repository's Markdown table style.
    private func renderRows(_ title: String?, headers: [String], rows: [[CustomStringConvertible]]) {
        guard !rows.isEmpty else { return }

        var table = TextTable(columns: headers.map { TextTableColumn(header: $0) })
        table.cornerFence = "|"
        rows.forEach { table.addRow(values: $0) }

        let rendered = table.render()
        // Remove unnecessary separators for Markdown table (first and last fences).
        let tableOutput = rendered
            .components(separatedBy: "\n")
            .dropFirst()
            .dropLast(1)
            .joined(separator: "\n")

        if let title {
            print(title)
        }
        print(tableOutput)
    }
}
