import Testing
import Version
@testable import Outdated

@Suite("ManifestEditor Tests")
struct ManifestEditorTests {

    // MARK: - Package.swift: from: pattern

    @Test("Updates from: pattern in Package.swift")
    func updateFromPattern() {
        let manifest = """
        let package = Package(
            name: "MyApp",
            dependencies: [
                .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
            ]
        )
        """
        let result = ManifestEditor.updatePackageSwift(
            manifest: manifest,
            repositoryURL: "https://github.com/apple/swift-log.git",
            newVersion: Version(1, 6, 0)
        )
        #expect(result != nil)
        #expect(result!.contains(#"from: "1.6.0""#))
        #expect(!result!.contains(#"from: "1.5.2""#))
    }

    // MARK: - Package.swift: .upToNextMajor pattern

    @Test("Updates .upToNextMajor pattern in Package.swift")
    func updateUpToNextMajor() {
        let manifest = """
        .package(url: "https://github.com/onevcat/Rainbow.git", .upToNextMajor(from: "3.2.0"))
        """
        let result = ManifestEditor.updatePackageSwift(
            manifest: manifest,
            repositoryURL: "https://github.com/onevcat/Rainbow.git",
            newVersion: Version(4, 0, 0)
        )
        #expect(result != nil)
        #expect(result!.contains(#".upToNextMajor(from: "4.0.0")"#))
    }

    // MARK: - Package.swift: .upToNextMinor pattern

    @Test("Updates .upToNextMinor pattern in Package.swift")
    func updateUpToNextMinor() {
        let manifest = """
        .package(url: "https://github.com/foo/bar.git", .upToNextMinor(from: "1.2.3"))
        """
        let result = ManifestEditor.updatePackageSwift(
            manifest: manifest,
            repositoryURL: "https://github.com/foo/bar.git",
            newVersion: Version(1, 3, 0)
        )
        #expect(result != nil)
        #expect(result!.contains(#".upToNextMinor(from: "1.3.0")"#))
    }

    // MARK: - Package.swift: exact: pattern

    @Test("Updates exact: pattern in Package.swift")
    func updateExactPattern() {
        let manifest = """
        .package(url: "https://github.com/foo/bar.git", exact: "2.0.0")
        """
        let result = ManifestEditor.updatePackageSwift(
            manifest: manifest,
            repositoryURL: "https://github.com/foo/bar.git",
            newVersion: Version(2, 1, 0)
        )
        #expect(result != nil)
        #expect(result!.contains(#"exact: "2.1.0""#))
    }

    // MARK: - Package.swift: URL matching

    @Test("URL matching is case-insensitive")
    func caseInsensitiveURL() {
        let manifest = """
        .package(url: "https://github.com/Apple/Swift-Log.git", from: "1.0.0")
        """
        let result = ManifestEditor.updatePackageSwift(
            manifest: manifest,
            repositoryURL: "https://github.com/apple/swift-log.git",
            newVersion: Version(1, 1, 0)
        )
        #expect(result != nil)
        #expect(result!.contains(#"from: "1.1.0""#))
    }

    @Test("URL matching tolerates .git suffix differences")
    func gitSuffixTolerance() {
        let manifest = """
        .package(url: "https://github.com/foo/bar.git", from: "1.0.0")
        """
        let result = ManifestEditor.updatePackageSwift(
            manifest: manifest,
            repositoryURL: "https://github.com/foo/bar",
            newVersion: Version(2, 0, 0)
        )
        #expect(result != nil)
        #expect(result!.contains(#"from: "2.0.0""#))
    }

    @Test("Returns nil when URL not found in Package.swift")
    func urlNotFoundInPackageSwift() {
        let manifest = """
        .package(url: "https://github.com/foo/bar.git", from: "1.0.0")
        """
        let result = ManifestEditor.updatePackageSwift(
            manifest: manifest,
            repositoryURL: "https://github.com/other/repo.git",
            newVersion: Version(2, 0, 0)
        )
        #expect(result == nil)
    }

    @Test("Only targeted package is modified in Package.swift")
    func onlyTargetedPackageModified() {
        let manifest = """
        let package = Package(
            dependencies: [
                .package(url: "https://github.com/foo/bar.git", from: "1.0.0"),
                .package(url: "https://github.com/baz/qux.git", from: "2.0.0"),
            ]
        )
        """
        let result = ManifestEditor.updatePackageSwift(
            manifest: manifest,
            repositoryURL: "https://github.com/foo/bar.git",
            newVersion: Version(1, 5, 0)
        )
        #expect(result != nil)
        #expect(result!.contains(#"url: "https://github.com/foo/bar.git", from: "1.5.0""#))
        #expect(result!.contains(#"url: "https://github.com/baz/qux.git", from: "2.0.0""#))
    }

    // MARK: - pbxproj: upToNextMajorVersion

    @Test("Updates upToNextMajorVersion in pbxproj")
    func updatePbxprojMajor() {
        let manifest = """
        /* Begin XCRemoteSwiftPackageReference section */
            ABC123 /* XCRemoteSwiftPackageReference "swift-log" */ = {
                isa = XCRemoteSwiftPackageReference;
                repositoryURL = "https://github.com/apple/swift-log.git";
                requirement = {
                    kind = upToNextMajorVersion;
                    minimumVersion = 1.5.2;
                };
            };
        /* End XCRemoteSwiftPackageReference section */
        """
        let result = ManifestEditor.updatePbxproj(
            manifest: manifest,
            repositoryURL: "https://github.com/apple/swift-log.git",
            newVersion: Version(1, 6, 0)
        )
        #expect(result != nil)
        #expect(result!.contains("minimumVersion = 1.6.0;"))
        #expect(!result!.contains("minimumVersion = 1.5.2;"))
    }

    // MARK: - pbxproj: upToNextMinorVersion

    @Test("Updates upToNextMinorVersion in pbxproj")
    func updatePbxprojMinor() {
        let manifest = """
            ABC123 = {
                isa = XCRemoteSwiftPackageReference;
                repositoryURL = "https://github.com/foo/bar.git";
                requirement = {
                    kind = upToNextMinorVersion;
                    minimumVersion = 2.3.0;
                };
            };
        """
        let result = ManifestEditor.updatePbxproj(
            manifest: manifest,
            repositoryURL: "https://github.com/foo/bar.git",
            newVersion: Version(2, 4, 0)
        )
        #expect(result != nil)
        #expect(result!.contains("minimumVersion = 2.4.0;"))
    }

    // MARK: - pbxproj: exactVersion

    @Test("Updates exactVersion in pbxproj")
    func updatePbxprojExact() {
        let manifest = """
            ABC123 = {
                isa = XCRemoteSwiftPackageReference;
                repositoryURL = "https://github.com/foo/bar.git";
                requirement = {
                    kind = exactVersion;
                    version = 3.0.0;
                };
            };
        """
        let result = ManifestEditor.updatePbxproj(
            manifest: manifest,
            repositoryURL: "https://github.com/foo/bar.git",
            newVersion: Version(3, 1, 0)
        )
        #expect(result != nil)
        #expect(result!.contains("version = 3.1.0;"))
        #expect(!result!.contains("version = 3.0.0;"))
    }

    // MARK: - pbxproj: URL matching

    @Test("Returns nil when URL not found in pbxproj")
    func urlNotFoundInPbxproj() {
        let manifest = """
            ABC123 = {
                isa = XCRemoteSwiftPackageReference;
                repositoryURL = "https://github.com/foo/bar.git";
                requirement = {
                    kind = upToNextMajorVersion;
                    minimumVersion = 1.0.0;
                };
            };
        """
        let result = ManifestEditor.updatePbxproj(
            manifest: manifest,
            repositoryURL: "https://github.com/other/repo.git",
            newVersion: Version(2, 0, 0)
        )
        #expect(result == nil)
    }

    @Test("Only targeted package is modified in pbxproj")
    func onlyTargetedPackageModifiedPbxproj() {
        let manifest = """
            ABC123 = {
                isa = XCRemoteSwiftPackageReference;
                repositoryURL = "https://github.com/foo/bar.git";
                requirement = {
                    kind = upToNextMajorVersion;
                    minimumVersion = 1.0.0;
                };
            };
            DEF456 = {
                isa = XCRemoteSwiftPackageReference;
                repositoryURL = "https://github.com/baz/qux.git";
                requirement = {
                    kind = upToNextMajorVersion;
                    minimumVersion = 2.0.0;
                };
            };
        """
        let result = ManifestEditor.updatePbxproj(
            manifest: manifest,
            repositoryURL: "https://github.com/foo/bar.git",
            newVersion: Version(1, 5, 0)
        )
        #expect(result != nil)
        #expect(result!.contains("minimumVersion = 1.5.0;"))
        #expect(result!.contains("minimumVersion = 2.0.0;"))
    }

    @Test("pbxproj URL matching tolerates .git suffix differences")
    func pbxprojGitSuffixTolerance() {
        let manifest = """
            ABC123 = {
                isa = XCRemoteSwiftPackageReference;
                repositoryURL = "https://github.com/foo/bar.git";
                requirement = {
                    kind = upToNextMajorVersion;
                    minimumVersion = 1.0.0;
                };
            };
        """
        let result = ManifestEditor.updatePbxproj(
            manifest: manifest,
            repositoryURL: "https://github.com/foo/bar",
            newVersion: Version(2, 0, 0)
        )
        #expect(result != nil)
        #expect(result!.contains("minimumVersion = 2.0.0;"))
    }
}
