import Testing
@testable import Outdated

@Suite("SecurityChecker Tests")
struct SecurityCheckerTests {

    @Test("osvPackageName strips .git and normalises URL")
    func osvPackageName() {
        #expect(SecurityChecker.osvPackageName(from: "https://github.com/apple/swift-argument-parser.git") == "github.com/apple/swift-argument-parser")
        #expect(SecurityChecker.osvPackageName(from: "https://github.com/apple/swift-argument-parser") == "github.com/apple/swift-argument-parser")
        #expect(SecurityChecker.osvPackageName(from: "https://github.com/johnsundell/Files.git") == "github.com/johnsundell/Files")
    }

    @Test("osvPackageName returns nil for invalid URLs")
    func osvPackageNameInvalid() {
        #expect(SecurityChecker.osvPackageName(from: "") == nil)
        #expect(SecurityChecker.osvPackageName(from: "not-a-url") == nil)
    }

    @Test("scorecardProject extracts github.com/owner/repo")
    func scorecardProject() {
        #expect(SecurityChecker.scorecardProject(from: "https://github.com/apple/swift-log.git") == "github.com/apple/swift-log")
        #expect(SecurityChecker.scorecardProject(from: "https://github.com/apple/swift-log") == "github.com/apple/swift-log")
    }

    @Test("scorecardProject returns nil for non-GitHub URLs")
    func scorecardProjectNonGitHub() {
        #expect(SecurityChecker.scorecardProject(from: "https://gitlab.com/owner/repo.git") == nil)
        #expect(SecurityChecker.scorecardProject(from: "") == nil)
    }
}
