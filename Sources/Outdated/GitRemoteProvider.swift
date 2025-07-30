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
