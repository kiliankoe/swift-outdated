import Foundation
import Dispatch
import ArgumentParser
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
        version: "0.3.0"
    )

    public func run() throws {
        let resolved = try Resolved.read()
        collectVersions(for: resolved)
    }

    func collectVersions(for resolved: Resolved) {
        let group = DispatchGroup()
        var versions: [Pin: [Version]] = [:]

        for pin in resolved.object.pins where pin.hasResolvedVersion {
            group.enter()
            pin.availableVersions { availableVersions in
                if let availableVersions = availableVersions {
                    versions[pin] = availableVersions
                }
                group.leave()
            }
        }

        let semaphore = DispatchSemaphore(value: 0)

        group.notify(queue: .global()) {
            let ignoredPackages = resolved.object.pins.filter { !$0.hasResolvedVersion }
            self.outputOutdatedPins(versions: versions, ignoredPackages: ignoredPackages)
            semaphore.signal()
        }

        group.wait()
        semaphore.wait()
    }

    func outputOutdatedPins(versions: [Pin: [Version]], ignoredPackages: [Pin]) {
        let outdatedPins = versions
            .compactMap { pin, allVersions -> OutdatedPin? in
                if let current = pin.version, let latest = allVersions.last, current != latest {
                    return OutdatedPin(package: pin.package, currentVersion: current, latestVersion: latest)
                }
                return nil
            }
            .sorted(by: { $0.package < $1.package })

        guard !outdatedPins.isEmpty || !ignoredPackages.isEmpty else { return }

        if isRunningInXcode() {
            for pin in outdatedPins {
                print("warning: Dependency \(pin.package) is outdated (\(pin.currentVersion) < \(pin.latestVersion))")
            }
        } else {
            var table = TextTable(objects: outdatedPins)
            table.cornerFence = " "
            table.columnFence = " "
            print(table.render())

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
