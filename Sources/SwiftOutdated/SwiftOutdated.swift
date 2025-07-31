import ArgumentParser
import Dispatch
import Files
import Foundation
import Logging
import Outdated

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
        version: "0.9.1"
    )

    public func run() async throws {
        setupLogging()
        let pins = try SwiftPackage.currentPackagePins(in: Folder(path: path))
        let packages = await SwiftPackage.collectVersions(for: pins, ignoringPrerelease: ignorePrerelease, onlyMajorUpdates: onlyMajor)
        packages.output(format: isRunningInXcode ? .xcode : format.libFormat)
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
