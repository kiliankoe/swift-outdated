import ArgumentParser
import Dispatch
import Files
import Foundation
import Logging
import Outdated
import Version

let log = Logger(label: "SwiftOutdated")

@main
public struct SwiftOutdated: AsyncParsableCommand, Sendable {
    public init() {}

    @Option(name: .shortAndLong, help: "The output format (markdown, json, xcode).")
    var format: CLIOutputFormat = .markdown

    @Flag(name: .shortAndLong, help: "Ignore pre-release versions.")
    var ignorePrerelease: Bool = false

    @Flag(name: [.customShort("m"), .long], help: "Output only packages with major version updates")
    var onlyMajor: Bool = false

    @Flag(name: .short, help: "Verbose output.")
    var verbose: Bool = false

    @Argument(help: "The directory containing the Package.resolved file", completion: .directory)
    var path: String = ""

    @Flag(name: [ .customShort("u"), .long], help: "Include up to date packages")
    var includeUpToDate: Bool = false

    @Option(name: .long, help: "Update outdated packages (patch, minor, major).")
    var update: CLIUpdateScope?

    @Option(name: .long, parsing: .singleValue, help: "Only update specific packages (repeatable).")
    var package: [String] = []

    @Flag(name: .long, help: "Show what would be updated without making changes.")
    var dryRun: Bool = false

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

        Use --update to automatically update outdated packages:
          swift-outdated --update patch    Update to latest patch versions
          swift-outdated --update minor    Update to latest minor versions
          swift-outdated --update major    Update to absolute latest versions
        """,
        version: "dev"
    )

    public func run() async throws {
        setupLogging()
        let folder = try Folder(path: path)
        let pins = try SwiftPackage.currentPackagePins(in: folder)

        if let update = update {
            try await runUpdate(scope: update.libScope, folder: folder, pins: pins)
        } else {
            let packages = await SwiftPackage.collectVersions(for: pins, ignoringPrerelease: ignorePrerelease, onlyMajorUpdates: onlyMajor)
            packages.output(format: isRunningInXcode ? .xcode : format.libFormat, includeUpToDatePackages: includeUpToDate)
        }
    }

    private func runUpdate(scope: UpdateScope, folder: Folder, pins: [SwiftPackage]) async throws {
        print("Updating packages (scope: \(scope.rawValue))...\(dryRun ? " (dry run)" : "")")
        print("")

        let updates = await SwiftPackage.collectVersionsForUpdate(
            for: pins,
            ignoringPrerelease: ignorePrerelease,
            scope: scope,
            filterPackages: package
        )

        guard !updates.isEmpty else {
            print("All packages are up to date.")
            return
        }

        let results = try PackageUpdater.update(
            in: folder,
            packages: updates,
            dryRun: dryRun
        )

        PackageUpdater.printResults(results)

        let updatedCount = results.filter { $0.status == .updated || $0.status == .wouldUpdate }.count
        print("")
        if dryRun {
            print("\(updatedCount) package(s) would be updated.")
        } else {
            print("\(updatedCount) package(s) updated.")
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

enum CLIOutputFormat: String, ExpressibleByArgument {
    case markdown
    case json
    case xcode

    var libFormat: PackageCollection.OutputFormat {
        .init(rawValue: self.rawValue)! // lol
    }
}

enum CLIUpdateScope: String, ExpressibleByArgument, CaseIterable {
    case patch
    case minor
    case major

    var libScope: UpdateScope {
        .init(rawValue: self.rawValue)!
    }
}
