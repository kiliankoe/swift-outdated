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

struct DependencyOutput {
    let name: String
    let requirement: String
    let current: String
    let latest: String
    let hasUpdate: Bool
}

extension DependencyOutput: TextTableRepresentable {
    static let columnHeaders = [
        "Name",
        "Requirement",
        "Current",
        "Latest"
    ]

    var tableValues: [CustomStringConvertible] {
        [
            name,
            requirement,
            hasUpdate ? current.red + " ⬆️" : current.green,
            latest
        ]
    }
}
