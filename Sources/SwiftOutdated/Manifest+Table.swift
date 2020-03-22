import SwiftyTextTable
import Rainbow

extension Dependency.Requirement {
    var tableText: String {
        switch self {
        case .range(let range):
            return "\(range.lowerBound)..<\(range.upperBound)"
        case .exact(let exact):
            return exact
        case .branch(let branch):
            return branch
        case .revision(let revision):
            return revision
        case .localPackage:
            return "local"
        }
    }
}

extension Dependency: TextTableRepresentable {
    static let columnHeaders = [
        "Name",
        "Requirement",
        "Latest"
    ]

    var tableValues: [CustomStringConvertible] {
        let isOutdated = (try? requirementIsOutdated()) ?? false
        let latestVersion = (try? availableVersions().last?.description) ?? "n/a"
        return [
            packageName,
            isOutdated ? requirement.tableText.red + " ⬆️" : requirement.tableText,
            latestVersion
        ]
    }
}
