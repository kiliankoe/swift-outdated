import Foundation
import ShellOut
import Version

struct Pin: Decodable {
    let package: String
    let repositoryURL: String
    let state: State

    struct State: Decodable {
        let branch: String?
        let revision: String
        let version: String?

        var description: String {
            version ?? branch ?? revision
        }
    }

    var hasResolvedVersion: Bool {
        self.state.version != nil
    }

    func availableVersions() throws -> [Version] {
        let lsRemote = try shellOut(to: "git", arguments: ["ls-remote", "--tags", self.repositoryURL])
        return lsRemote
            .split(separator: "\n")
            .map {
                $0.split(separator: "\t")
                    .last!
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"refs\/tags\/(v(?=\d))?"#, with: "", options: .regularExpression)
            }
            .compactMap { Version($0) }
            .sorted()
    }

    var outdatedPin: OutdatedPin? {
        guard let versionStr = self.state.version,
              let version = Version(versionStr),
              let latest = try? self.availableVersions().last,
              version < latest
        else { return nil }

        return OutdatedPin(package: self.package, currentVersion: version, latestVersion: latest)
    }
}
