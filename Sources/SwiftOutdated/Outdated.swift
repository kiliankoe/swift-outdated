import ArgumentParser
import Dispatch
import Foundation
import SwiftyTextTable
import Version

public struct Outdated: AsyncParsableCommand {
    public init() {}

    enum OutputFormat: String, ExpressibleByArgument {
        case markdown
        case json
        case xcode
    }

    @Option(name: .shortAndLong, help: "The output format (markdown, json, xcode).")
    var format: OutputFormat = .markdown

    public static let configuration = CommandConfiguration(
        commandName: "swift outdated",
        abstract: "Check for outdated dependencies.",
        discussion: """
        swift-outdated will output an overview of your outdated dependencies found in your Package.resolved file.
        Dependencies pinned to specific revisions or branches are ignored (and shown as such).

        The latest version for dependencies one major version behind is colored green, yellow for two major versions
        and red for anything above that.

        swift-outdated automatically detects if it is run via an Xcode run script phase and will emit warnings for
        Xcode's issue navigator.
        """,
        version: "0.3.7"
    )

    public func run() throws {
        // This should work without the semaphore by using `run() async` directly, but it doesn't. Why?
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            let pins = try SwiftPackage.currentPackagePins()
            let packages = await collectVersions(for: pins)
            output(packages)
            semaphore.signal()
        }
        semaphore.wait()
    }

    func collectVersions(for packages: [SwiftPackage]) async -> PackageCollection {
        let versions = await withTaskGroup(of: (SwiftPackage, [Version]?).self) { group in
            for package in packages where package.hasResolvedVersion {
                group.addTask {
                    if let availableVersions = try? package.availableVersions() {
                        return (package, availableVersions)
                    }
                    return (package, nil)
                }
            }

            var availableVersions = [SwiftPackage: [Version]]()
            for await (package, versions) in group {
                if let versions = versions {
                    availableVersions[package] = versions
                }
            }

            return availableVersions
        }

        let outdatedPackages = versions
            .compactMap { package, allVersions -> OutdatedPackage? in
                if let current = package.version, let latest = allVersions.last, current != latest {
                    return OutdatedPackage(package: package.package, currentVersion: current, latestVersion: latest)
                }
                return nil
            }
            .sorted(by: { $0.package < $1.package })
        let ignoredPackages = packages.filter { !$0.hasResolvedVersion }
        return PackageCollection(outdatedPackages: outdatedPackages, ignoredPackages: ignoredPackages)
    }

    func output(_ packages: PackageCollection) {
        guard !packages.outdatedPackages.isEmpty || !packages.ignoredPackages.isEmpty else { return }

        var outputFormat = format
        if isRunningInXcode {
            outputFormat = .xcode
        }

        switch outputFormat {
        case .xcode:
            packages.outdatedPackages.forEach {
                print("warning: Dependency \($0.package) is outdated (\($0.currentVersion) < \($0.latestVersion))")
            }
        case .json:
            let json = try! JSONEncoder().encode(packages)
            print(String(data: json, encoding: .utf8)!)
        case .markdown:
            var table = TextTable(objects: packages.outdatedPackages)

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

            if !packages.ignoredPackages.isEmpty {
                let ignoredString = packages.ignoredPackages.map { $0.package }.joined(separator: ", ")
                print("Ignored because of revision or branch pins: \(ignoredString)")
            }
        }
    }

    private var isRunningInXcode: Bool {
        ProcessInfo.processInfo.environment["XCODE_VERSION_ACTUAL"] != nil
    }
}

struct PackageCollection: Encodable {
    var outdatedPackages: [OutdatedPackage]
    var ignoredPackages: [SwiftPackage]
}
