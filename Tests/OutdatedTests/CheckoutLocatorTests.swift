import Foundation
import Testing
import Files
@testable import Outdated

@Suite("Checkout Locator Tests")
struct CheckoutLocatorTests {

    init() {
        initializeTestLogging()
    }

    private func locator() -> CheckoutLocator {
        CheckoutLocator(projectFolderPath: "/tmp", explicitPath: nil)
    }

    @Test("URL normalization - HTTPS with .git suffix")
    func normalizeHTTPSWithGit() {
        #expect(locator().normalizeURL("https://github.com/user/repo.git") == "github.com/user/repo")
    }

    @Test("URL normalization - HTTPS without .git suffix")
    func normalizeHTTPSWithoutGit() {
        #expect(locator().normalizeURL("https://github.com/user/repo") == "github.com/user/repo")
    }

    @Test("URL normalization - SSH and HTTPS match")
    func normalizeSSHMatchesHTTPS() {
        let l = locator()
        #expect(l.normalizeURL("git@github.com:user/repo.git") == "github.com/user/repo")
        #expect(l.normalizeURL("git@github.com:apple/swift-argument-parser.git")
            == l.normalizeURL("https://github.com/apple/swift-argument-parser.git"))
    }

    @Test("URL normalization - case insensitive")
    func normalizeCaseInsensitive() {
        let l = locator()
        #expect(l.normalizeURL("https://github.com/user/repo") == l.normalizeURL("https://GitHub.com/User/Repo"))
    }

    @Test("URL normalization - trailing slash and whitespace")
    func normalizeTrailingSlashAndWhitespace() {
        let l = locator()
        #expect(l.normalizeURL("  https://github.com/user/repo/  \n") == l.normalizeURL("https://github.com/user/repo"))
    }

    @Test("URL normalization - GitLab SSH and HTTPS match")
    func normalizeGitLab() {
        let l = locator()
        #expect(l.normalizeURL("https://gitlab.com/org/project.git") == l.normalizeURL("git@gitlab.com:org/project.git"))
    }

    @Test("No checkouts available in empty folder")
    func noCheckoutsInEmptyFolder() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "test-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        let locator = CheckoutLocator(projectFolder: tempFolder, explicitPath: nil)
        #expect(locator.hasCheckoutsAvailable() == false)
        #expect(locator.getCheckoutRoots().isEmpty)
    }

    @Test("Explicit path replaces auto-detected roots")
    func explicitPathReplacesRoots() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "test-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        _ = try tempFolder.createSubfolder(at: ".build/checkouts")
        let explicitCheckouts = try tempFolder.createSubfolder(named: "custom-checkouts")

        let locator = CheckoutLocator(projectFolder: tempFolder, explicitPath: explicitCheckouts.path)
        let roots = locator.getCheckoutRoots()

        #expect(roots.count == 1)
        #expect(roots.first?.path == explicitCheckouts.path)
    }

    @Test("Detects SwiftPM checkouts")
    func detectsSwiftPMCheckouts() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "test-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        let swiftpmCheckouts = try tempFolder.createSubfolder(at: ".build/checkouts")
        let locator = CheckoutLocator(projectFolder: tempFolder, explicitPath: nil)

        #expect(locator.getCheckoutRoots().map(\.path) == [swiftpmCheckouts.path])
        #expect(locator.hasCheckoutsAvailable() == true)
    }

    @Test("Detects Xcode SourcePackages checkouts")
    func detectsXcodeCheckouts() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "test-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        let xcodeCheckouts = try tempFolder.createSubfolder(at: "SourcePackages/checkouts")
        let locator = CheckoutLocator(projectFolder: tempFolder, explicitPath: nil)

        #expect(locator.getCheckoutRoots().map(\.path) == [xcodeCheckouts.path])
    }

    @Test("Detects both SwiftPM and Xcode checkouts")
    func detectsBothCheckoutTypes() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "test-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        let swiftpmCheckouts = try tempFolder.createSubfolder(at: ".build/checkouts")
        let xcodeCheckouts = try tempFolder.createSubfolder(at: "SourcePackages/checkouts")

        let locator = CheckoutLocator(projectFolder: tempFolder, explicitPath: nil)
        let roots = locator.getCheckoutRoots()

        #expect(roots.count == 2)
        #expect(roots.contains { $0.path == swiftpmCheckouts.path })
        #expect(roots.contains { $0.path == xcodeCheckouts.path })
    }
}
