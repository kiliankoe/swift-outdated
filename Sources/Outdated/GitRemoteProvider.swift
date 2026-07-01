import Foundation
import ShellOut

public protocol GitRemoteProvider: Sendable {
    func getRemoteTags(repositoryURL: String) throws -> String
}

public struct ShellGitRemoteProvider: GitRemoteProvider {
    public init() {}

    public func getRemoteTags(repositoryURL: String) throws -> String {
        log.trace("git ls-remote --tags \(repositoryURL)")
        // Fail fast instead of blocking on an invisible credential/passphrase prompt (issues #17, #30).
        // A fresh Process per call keeps the concurrent fetches independent; ShellOut leaves the
        // environment and stdin we set here untouched.
        let process = Process()
        process.environment = nonInteractiveGitEnvironment(base: ProcessInfo.processInfo.environment)
        process.standardInput = FileHandle.nullDevice
        return try shellOut(to: "git", arguments: ["ls-remote", "--tags", repositoryURL], process: process)
    }
}

/// `GIT_TERMINAL_PROMPT=0` blocks the HTTPS `Username for …` prompt (#30); ssh `BatchMode=yes` blocks the
/// key-passphrase and host-key prompts (#17). An existing `GIT_SSH_COMMAND` is preserved and extended.
func nonInteractiveGitEnvironment(base: [String: String]) -> [String: String] {
    var env = base
    env["GIT_TERMINAL_PROMPT"] = "0"
    let ssh = env["GIT_SSH_COMMAND"] ?? "ssh"
    env["GIT_SSH_COMMAND"] = ssh.contains("BatchMode") ? ssh : ssh + " -oBatchMode=yes"
    return env
}

/// Turns an auth-shaped git failure into an actionable hint (rather than leaving the user stuck, as #17
/// asked), or `nil` for unrelated failures. Takes the raw stderr text so it's decoupled from
/// `ShellOutError` and easy to test.
func gitAuthHint(stderr: String) -> String? {
    let text = stderr.lowercased()
    let markers = ["authentication failed", "permission denied", "could not read username",
                   "terminal prompts disabled", "host key verification failed", "publickey"]
    guard markers.contains(where: text.contains) else { return nil }
    return "authentication was required. Use ssh-agent (ssh-add) for password-protected SSH keys, or a "
         + "credential helper (git config --global credential.helper osxkeychain) for private HTTPS repos."
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
