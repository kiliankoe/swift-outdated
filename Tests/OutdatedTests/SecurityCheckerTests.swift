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

    // Assertions check glyphs/text rather than exact strings so ANSI color codes don't matter.

    @Test("OSV label reports the CVE count, pluralised")
    func osvLabelVulnerable() {
        let one = PackageCollection.SecurityLabel.osv(.vulnerable(count: 1, ids: ["CVE-1"]))
        #expect(one.contains("⚠"))
        #expect(one.contains("1 CVE"))
        #expect(!one.contains("CVEs"))
        #expect(PackageCollection.SecurityLabel.osv(.vulnerable(count: 3, ids: [])).contains("3 CVEs"))
    }

    @Test("OSV label distinguishes no-known-CVEs from unchecked")
    func osvLabelSafeVsUnknown() {
        #expect(PackageCollection.SecurityLabel.osv(.safe).contains("No CVEs"))
        #expect(PackageCollection.SecurityLabel.osv(.unknown).contains("?"))
        #expect(PackageCollection.SecurityLabel.osv(nil).contains("?"))
    }

    @Test("Score label flags low scores and shows the value")
    func scoreLabel() {
        let low = PackageCollection.SecurityLabel.score(2.9)
        #expect(low.contains("⚠"))
        #expect(low.contains("2.9/10"))
        let good = PackageCollection.SecurityLabel.score(7.3)
        #expect(good.contains("✓"))
        #expect(good.contains("7.3/10"))
        #expect(PackageCollection.SecurityLabel.score(nil).contains("?"))
    }

    @Test("Score label boundary: below 5 warns, 5 and above is fine")
    func scoreLabelBoundary() {
        #expect(PackageCollection.SecurityLabel.score(4.9).contains("⚠"))
        #expect(PackageCollection.SecurityLabel.score(5.0).contains("✓"))
    }
}
