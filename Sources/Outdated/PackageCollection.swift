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
            render(includeUpToDatePackages ? "## Outdated packages": nil, self.outdatedPackages)
            
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
