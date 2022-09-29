import ArgumentParser
import Dispatch
import Foundation
import SwiftyTextTable
import Version

public struct Outdated: ParsableCommand {
    public init() {}

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
        version: "0.3.4"
    )

    public func run() throws {
        let packages = try SwiftPackage.read()
        collectVersions(for: packages)
    }

    func collectVersions(for packages: [SwiftPackage]) {
        let group = DispatchGroup()
        let versions = ConcurrentDictionary<SwiftPackage, [Version]>()

        for package in packages where package.hasResolvedVersion {
            group.enter()
            package.availableVersions { availableVersions in
                if let availableVersions = availableVersions {
                    versions[package] = availableVersions
                }
                group.leave()
            }
        }

        let semaphore = DispatchSemaphore(value: 0)

        group.notify(queue: .global()) {
            let ignoredPackages = packages.filter { !$0.hasResolvedVersion }
            self.outputOutdatedPins(versions: versions, ignoredPackages: ignoredPackages)
            semaphore.signal()
        }

        group.wait()
        semaphore.wait()
    }

    func outputOutdatedPins(versions: ConcurrentDictionary<SwiftPackage, [Version]>, ignoredPackages: [SwiftPackage]) {
        let outdatedPackages = versions
            .compactMap { package, allVersions -> OutdatedPackage? in
                if let current = package.version, let latest = allVersions.last, current != latest {
                    return OutdatedPackage(package: package.package, currentVersion: current, latestVersion: latest)
                }
                return nil
            }
            .sorted(by: { $0.package < $1.package })

        guard !outdatedPackages.isEmpty || !ignoredPackages.isEmpty else { return }

        if isRunningInXcode() {
            outdatedPackages.forEach {
                print("warning: Dependency \($0.package) is outdated (\($0.currentVersion) < \($0.latestVersion))")
            }
        } else {
            var table = TextTable(objects: outdatedPackages)

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

            if !ignoredPackages.isEmpty {
                let ignoredString = ignoredPackages.map { $0.package }.joined(separator: ", ")
                print("Ignored because of revision or branch pins: \(ignoredString)")
            }
        }
    }

    func isRunningInXcode() -> Bool {
        ProcessInfo.processInfo.environment["XCODE_VERSION_ACTUAL"] != nil
    }
}
