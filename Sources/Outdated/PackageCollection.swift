import Foundation
import SwiftyTextTable

public struct PackageCollection: Encodable {
    public var outdatedPackages: [OutdatedPackage]
    public var ignoredPackages: [SwiftPackage]
    public var upToDatePackages: [SwiftPackage]
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
            if includeUpToDatePackages {
                print("## Outdated packages")
            }
            let rendered = render(self.outdatedPackages)
            print(rendered)
            
            if includeUpToDatePackages {
                print("## Up to date packages")
                let renderedValidPackages = render(self.upToDatePackages)
                print(renderedValidPackages)
                
                print("## Ignored packages")
                let renderedIgnoredPackages = render(self.ignoredPackages)
                print(renderedIgnoredPackages)
            } else {
                if !self.ignoredPackages.isEmpty {
                    let ignoredString = self.ignoredPackages.map { $0.package }.joined(separator: ", ")
                    print("Ignored because of revision or branch pins: \(ignoredString)")
                }
            }
        }
    }
    
    private func render<T: TextTableRepresentable>(_ objects: [T]) -> String {
        var table = TextTable(objects: objects)

        // table in Markdown style.
        table.cornerFence = "|"
        let rendered = table.render()
        // Remove unnecessary separators for Markdown table (first and last fences).
        return rendered
            .components(separatedBy: "\n")
            .dropFirst()
            .dropLast(1)
            .joined(separator: "\n")
    }
}
