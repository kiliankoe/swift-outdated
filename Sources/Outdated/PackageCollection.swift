import Foundation
import Rainbow
import SwiftyTextTable

public struct PackageCollection: Encodable {
    public var outdatedPackages: [OutdatedPackage]
    public var ignoredPackages: [SwiftPackage]
    public var upToDatePackages: [SwiftPackage]
    public var securityResults: [String: SecurityPair]?

    enum CodingKeys: String, CodingKey {
        case outdatedPackages, ignoredPackages, upToDatePackages
    }
}

extension PackageCollection {
    public enum OutputFormat: String {
        case markdown
        case json
        case xcode
    }

    public func output(format: OutputFormat, includeUpToDatePackages: Bool = false) {
        guard !self.outdatedPackages.isEmpty || !self.ignoredPackages.isEmpty else { return }

        switch format {
        case .xcode:
            self.outdatedPackages.forEach {
                print("warning: Dependency \"\($0.package)\" is outdated (\($0.currentVersion) < \($0.latestVersion)) → \($0.url)")
            }
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let json = try! encoder.encode(self)
            print(String(data: json, encoding: .utf8)!)
        case .markdown:
            if let securityResults = securityResults {
                let enriched = outdatedPackages.map { OutdatedPackageWithSecurity(base: $0, security: securityResults[$0.package]) }
                render(includeUpToDatePackages ? "## Outdated packages" : nil, enriched)
            } else {
                render(includeUpToDatePackages ? "## Outdated packages": nil, self.outdatedPackages)
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
            let majorDiff = base.latestVersion.major - base.currentVersion.major
            var latestStr = base.latestVersion.description
            switch majorDiff {
            case 1: latestStr = latestStr.green
            case 2: latestStr = latestStr.yellow
            case 3...: latestStr = latestStr.red
            default: break
            }
            return [
                base.package,
                base.currentVersion.description,
                osvLabel(for: security?.currentOSV),
                latestStr,
                osvLabel(for: security?.latestOSV),
                scoreLabel(for: security?.scorecardScore),
                base.url.blue
            ]
        }

        private func osvLabel(for status: OSVStatus?) -> String {
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

        // Scorecard rates the repository (0–10), independent of version. Low scores are flagged.
        private func scoreLabel(for score: Double?) -> String {
            guard let score = score else { return "?".dim }
            let scoreStr = String(format: "%.1f/10", score)
            return score < 5.0 ? "⚠ \(scoreStr)".yellow : "✓ \(scoreStr)".green
        }
    }

    private func render<T: TextTableRepresentable>(_ title: String?, _ objects: [T]) {
        guard !objects.isEmpty else { return }
        
        var table = TextTable(objects: objects)

        // table in Markdown style.
        table.cornerFence = "|"
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
