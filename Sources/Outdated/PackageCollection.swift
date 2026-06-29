import Foundation
import Rainbow
import SwiftyTextTable

public struct PackageCollection: Encodable {
    public var outdatedPackages: [OutdatedPackage]
    public var ignoredPackages: [SwiftPackage]
    public var upToDatePackages: [SwiftPackage]
    public var securityResults: [String: SecurityPair]?
    public var refPinnedPackages: [RefPinAnalysis] = []

    enum CodingKeys: String, CodingKey {
        case outdatedPackages, ignoredPackages, upToDatePackages, securityResults, refPinnedPackages
    }
}

extension PackageCollection {
    public enum OutputFormat: String {
        case markdown
        case json
        case xcode
    }

    public func output(format: OutputFormat, includeUpToDatePackages: Bool = false) {
        guard !self.outdatedPackages.isEmpty || !self.ignoredPackages.isEmpty || !self.refPinnedPackages.isEmpty else { return }

        switch format {
        case .xcode:
            self.outdatedPackages.forEach {
                var warning = "warning: Dependency \"\($0.package)\" is outdated (\($0.currentVersion) < \($0.latestVersion)) → \($0.url)"
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
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let json = try! encoder.encode(self)
            print(String(data: json, encoding: .utf8)!)
        case .markdown:
            // Branch/revision pins share the outdated table: their "Pinned" cell sits in the Current
            // column. Behind pins show by default; all of them when including up-to-date packages.
            let refPins = includeUpToDatePackages ? refPinnedPackages : refPinnedPackages.filter { $0.isOutdated }
            let title = includeUpToDatePackages ? "## Outdated packages" : nil

            if let securityResults = securityResults {
                var rows = outdatedPackages.map { OutdatedPackageWithSecurity(base: $0, security: securityResults[$0.package]).tableValues }
                rows += refPins.map { refPinSecurityRow($0) }
                renderRows(title, headers: OutdatedPackageWithSecurity.columnHeaders, rows: rows)
            } else {
                var rows = outdatedPackages.map { $0.tableValues }
                rows += refPins.map { $0.tableValues }
                renderRows(title, headers: OutdatedPackage.columnHeaders, rows: rows)
            }

            if includeUpToDatePackages {
                render("## Up to date packages", self.upToDatePackages)
                render("## Ignored packages", self.ignoredPackages)
            } else {
                if !self.ignoredPackages.isEmpty {
                    let ignoredString = self.ignoredPackages.map { $0.package }.joined(separator: ", ")
                    print("Ignored because of revision or branch pins: \(ignoredString)")
                }
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
                base.url.blue
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

    private func render<T: TextTableRepresentable>(_ title: String?, _ objects: [T]) {
        guard !objects.isEmpty else { return }
        renderRows(title, headers: T.columnHeaders, rows: objects.map { $0.tableValues })
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
