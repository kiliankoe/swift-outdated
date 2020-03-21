import ArgumentParser
import SwiftyTextTable

public struct Outdated: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "swift outdated",
        abstract: "Check for outdated dependencies."
    )

    public func run() throws {
        let swiftpm = try SwiftPM()
        var table = TextTable(objects: swiftpm.manifest.dependencies)
        table.cornerFence = " "
        table.columnFence = " "
        print(table.render())
    }
}
