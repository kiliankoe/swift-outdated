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

        static let columnHeaders = ["Package", "Current", "Sec. Current", "Latest", "Sec. Latest", "URL"]

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
                securityLabel(for: security?.current),
                latestStr,
                securityLabel(for: security?.latest),
                base.url.blue
            ]
        }

        private func securityLabel(for info: SecurityInfo?) -> String {
            guard let info = info else { return "?".dim }
            switch info.osvStatus {
            case .vulnerable(let count, _):
                return "⚠ \(count) CVE\(count > 1 ? "s" : "")".red
            case .safe:
                if let score = info.scorecardScore {
                    let scoreStr = String(format: "%.1f/10", score)
                    return score < 5.0 ? "Score: \(scoreStr)".yellow : "✓ \(scoreStr)".green
                }
                return "✓ Safe".green
            case .unknown:
                return "?".dim
            }
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
