import Foundation
import ShellOut

public protocol GitRemoteProvider: Sendable {
    func getRemoteTags(repositoryURL: String) throws -> String
}

public struct ShellGitRemoteProvider: GitRemoteProvider {
    public init() {}

    public func getRemoteTags(repositoryURL: String) throws -> String {
        log.trace("git ls-remote --tags \(repositoryURL)")
        return try shellOut(to: "git", arguments: ["ls-remote", "--tags", repositoryURL])
    }
}

/// Reads information that requires a *local* clone's commit graph — distinct from
/// `GitRemoteProvider`, which only sees `ls-remote` output and therefore has no ancestry.
public protocol LocalGitProvider: Sendable {
    /// The nearest tag at or before `revision` (`git describe --tags --abbrev=0`), or `nil`
    /// when the revision has no ancestor tags.
    func describeTag(revision: String, checkoutPath: String) throws -> String?
}

public struct ShellLocalGitProvider: LocalGitProvider {
    public init() {}

    public func describeTag(revision: String, checkoutPath: String) throws -> String? {
        log.trace("git -C \(checkoutPath) describe --tags --abbrev=0 \(revision)")
        let output = try shellOut(
            to: "git",
            arguments: ["-C", checkoutPath, "describe", "--tags", "--abbrev=0", revision]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
}
