import Foundation
import Dispatch
import ShellOut
import Version

struct Pin: Decodable, Hashable {
    let package: String
    let repositoryURL: String
    let state: State

    var version: Version? {
        guard let versionStr = self.state.version, let version = Version(versionStr) else { return nil }
        return version
    }

    struct State: Decodable, Hashable {
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

    func availableVersions(completion: @escaping ([Version]?) -> Void) {
        DispatchQueue.global().async {
            let versions = try? self.availableVersions()
            completion(versions)
        }
    }
}
