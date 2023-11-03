import Foundation
import SwiftyTextTable

public struct PackageCollection: Encodable {
    public var outdatedPackages: [OutdatedPackage]
    public var ignoredPackages: [SwiftPackage]
}

extension PackageCollection {
    public enum OutputFormat: String {
        case markdown
        case json
        case xcode
    }

    public func output(format: OutputFormat) {
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
            var table = TextTable(objects: self.outdatedPackages)

            // table in Markdown style.
            table.cornerFence = "|"
            var rendered = table.render()
            // Remove unnecessary separators for Markdown table (first and last fences).
            rendered = rendered
                .components(separatedBy: "\n")
                .dropFirst()
                .dropLast(1)
                .joined(separator: "\n")

            print(rendered)

            if !self.ignoredPackages.isEmpty {
                let ignoredString = self.ignoredPackages.map { $0.package }.joined(separator: ", ")
                print("Ignored because of revision or branch pins: \(ignoredString)")
            }
        }
    }
}
