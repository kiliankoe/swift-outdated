import ArgumentParser
import SwiftyTextTable

public struct Outdated: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "swift outdated",
        abstract: "Check for outdated dependencies.",
        version: "0.1.0"
    )

    public func run() throws {
        let swiftpm = try SwiftPM()
        try swiftpm.fetchDependencyUpdates()

        var table = TextTable(objects: swiftpm.output())
        table.cornerFence = " "
        table.columnFence = " "
        print(table.render())
    }
}
