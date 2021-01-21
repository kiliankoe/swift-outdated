import Foundation
import ArgumentParser
import SwiftyTextTable

public struct Outdated: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "swift outdated",
        abstract: "Check for outdated dependencies.",
        version: "0.2.4"
    )

    public func run() throws {
        let resolved = try Resolved.read()

        let outdatedPins = resolved.object.pins
            .filter(\.hasResolvedVersion)
            .compactMap { $0.outdatedPin }

        let ignoredPackages = resolved.object.pins.filter { !$0.hasResolvedVersion }

        guard !outdatedPins.isEmpty || !ignoredPackages.isEmpty else { return }

        if ProcessInfo.processInfo.environment["XCODE_VERSION_ACTUAL"] != nil {
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
}
