import Foundation
import Testing
import Files
@testable import Outdated

@Suite("Local Git Provider Tests")
struct LocalGitProviderTests {

    init() {
        initializeTestLogging()
    }

    /// Runs git in an isolated environment (no user/global config, no signing) and returns stdout.
    @discardableResult
    private func git(_ args: [String], in dir: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", dir,
                             "-c", "user.email=test@example.com",
                             "-c", "user.name=Test",
                             "-c", "commit.gpgsign=false"] + args
        var env = ProcessInfo.processInfo.environment
        env["GIT_CONFIG_GLOBAL"] = "/dev/null"
        env["GIT_CONFIG_SYSTEM"] = "/dev/null"
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw GitTestError.commandFailed(args.joined(separator: " "), status: process.terminationStatus)
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum GitTestError: Error { case commandFailed(String, status: Int32) }

    /// Builds a repo: commit A (untagged) → commit B (tagged 1.0.0) → commit C (untagged HEAD).
    private func makeRepo() throws -> (path: String, cleanup: () -> Void, shaA: String) {
        let folder = try Folder.temporary.createSubfolder(named: "refpin-\(UUID().uuidString)")
        let path = folder.path
        try git(["init", "-q"], in: path)
        try folder.createFile(named: "a.txt").write("a")
        try git(["add", "."], in: path)
        try git(["commit", "-q", "-m", "A"], in: path)
        let shaA = try git(["rev-parse", "HEAD"], in: path)
        try folder.createFile(named: "b.txt").write("b")
        try git(["add", "."], in: path)
        try git(["commit", "-q", "-m", "B"], in: path)
        try git(["tag", "1.0.0"], in: path)
        try folder.createFile(named: "c.txt").write("c")
        try git(["add", "."], in: path)
        try git(["commit", "-q", "-m", "C"], in: path)
        return (path, { try? folder.delete() }, shaA)
    }

    @Test("describeTag resolves the nearest ancestor tag")
    func describeTagResolvesAncestorTag() throws {
        let repo = try makeRepo()
        defer { repo.cleanup() }

        let provider = ShellLocalGitProvider()
        // HEAD (commit C) and the tagged commit B both have 1.0.0 as nearest ancestor tag.
        #expect(try provider.describeTag(revision: "HEAD", checkoutPath: repo.path) == "1.0.0")
    }

    @Test("describeTag throws when the revision has no ancestor tag")
    func describeTagThrowsWithoutAncestorTag() throws {
        let repo = try makeRepo()
        defer { repo.cleanup() }

        let provider = ShellLocalGitProvider()
        // Commit A precedes the only tag, so there is no tag at or before it.
        #expect(throws: (any Error).self) {
            try provider.describeTag(revision: repo.shaA, checkoutPath: repo.path)
        }
    }
}
