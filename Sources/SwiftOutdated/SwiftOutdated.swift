import ArgumentParser
import Dispatch
import Foundation
import Logging
import Outdated
import SwiftyTextTable
import Version

let log = Logger(label: "SwiftOutdated")

@main
public struct SwiftOutdated: AsyncParsableCommand {
    public init() {}

    enum OutputFormat: String, ExpressibleByArgument {
        case markdown
        case json
        case xcode
    }

    @Option(name: .shortAndLong, help: "The output format (markdown, json, xcode).")
    var format: OutputFormat = .markdown

    @Flag(name: .shortAndLong, help: "Ignore pre-release versions.")
    var ignorePrerelease: Bool = false

    @Flag(name: .short, help: "Verbose output.")
    var verbose: Bool = false

    public static let configuration = CommandConfiguration(
        commandName: "swift-outdated",
        abstract: "Check for outdated dependencies.",
        discussion: """
        swift-outdated will output an overview of your outdated dependencies found in your Package.resolved file.
        Dependencies pinned to specific revisions or branches are ignored (and shown as such).

        The latest version for dependencies one major version behind is colored green, yellow for two major versions
        and red for anything above that.

        swift-outdated automatically detects if it is run via an Xcode run script phase and will emit warnings for
        Xcode's issue navigator.
        """,
        version: "0.6.0"
    )

    public func run() async throws {
        setupLogging()
        let pins = try SwiftPackage.currentPackagePins()
        let packages = await collectVersions(for: pins)
        output(packages)
    }

    func collectVersions(for packages: [SwiftPackage]) async -> PackageCollection {
        log.info("Collecting versions for \(packages.map { $0.package }.joined(separator: ", ")).")
        let versions = await withTaskGroup(of: (SwiftPackage, [Version]?).self) { group in
            for package in packages where package.hasResolvedVersion {
                log.info("Package \(package.package) has resolved version, queueing version fetch.")
                group.addTask {
                    let availableVersions = package.availableVersions()
                    log.info("Found \(availableVersions.count) versions for \(package.package).")
                    return (package, availableVersions)
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
                if let current = package.version, let latest = getLatestVersion(from: allVersions), current != latest {
                    log.info("Package \(package.package) is outdated.")
                    return OutdatedPackage(package: package.package, currentVersion: current, latestVersion: latest, url: package.repositoryURL)
                } else {
                    log.info("Package \(package.package) is up to date.")
                }
                return nil
            }
            .sorted(by: { $0.package < $1.package })
        let ignoredPackages = packages.filter { !$0.hasResolvedVersion }
        if !ignoredPackages.isEmpty {
            log.info("Ignoring \(ignoredPackages.map { $0.package }.joined(separator: ", ")) because of non-version pins.")
        }
        return PackageCollection(outdatedPackages: outdatedPackages, ignoredPackages: ignoredPackages)
    }

    private func getLatestVersion(from allVersions: [Version]) -> Version? {
        if ignorePrerelease {
            return allVersions.last(where: { $0.prereleaseIdentifiers.isEmpty })
        } else {
            return allVersions.last
        }
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
                print("warning: Dependency \"\($0.package)\" is outdated (\($0.currentVersion) < \($0.latestVersion)) → \($0.url)")
            }
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let json = try! encoder.encode(packages)
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

    private func setupLogging() {
        LoggingSystem.bootstrap { label in
            var logHandler = StreamLogHandler.standardError(label: label)
            if verbose {
                #if DEBUG
                logHandler.logLevel = .trace
                #else
                logHandler.logLevel = .info
                #endif
            } else {
                logHandler.logLevel = .error
            }
            return logHandler
        }
    }
}
