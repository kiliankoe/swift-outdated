import Testing
import Version
@testable import Outdated

@Suite("Version Collection Tests")
struct VersionCollectionTests {
    
    @Test("Available versions parsing")
    func availableVersionsParsing() {
        let mockProvider = MockGitRemoteProvider()
        let repositoryURL = "https://github.com/example/repo.git"
        
        mockProvider.setTagRefsResponse(for: repositoryURL, response: """
        d945937a1b87e8b2bafb749c8ec53610f337c403	refs/tags/1.0.0
        a95a41cd1853ee5a4b195bbd8dc01e38ff9c1dc4	refs/tags/1.0.0^{}
        e75adf01468423e7b7a49475e6d403f7cd886789	refs/tags/2.0.0
        f69961599ad524251d677fbec9e4bac57385d6fc	refs/tags/2.0.0^{}
        626c3d4b6b55354b4af3aa309f998fae9b31a3d9	refs/tags/3.2.0
        1234567890abcdef1234567890abcdef12345678	refs/tags/4.0.0
        16da5c62dd737258c6df2e8c430f8a3202f655a7	refs/tags/4.0.0^{}
        """)
        
        let package = SwiftPackage(
            package: "TestPackage",
            repositoryURL: repositoryURL,
            revision: nil,
            version: Version(1, 0, 0),
            gitProvider: mockProvider
        )

        let versions = package.availableVersions()

        #expect(versions.count == 4)
        #expect(versions.contains(Version(1, 0, 0)))
        #expect(versions.contains(Version(2, 0, 0)))
        #expect(versions.contains(Version(3, 2, 0)))
        #expect(versions.contains(Version(4, 0, 0)))

        #expect(versions == versions.sorted())
    }
    
    @Test("Versions with prefixes")
    func versionsWithPrefixes() {
        let mockProvider = MockGitRemoteProvider()
        let repositoryURL = "https://github.com/example/repo.git"
        
        mockProvider.setTagRefsResponse(for: repositoryURL, response: """
        d945937a1b87e8b2bafb749c8ec53610f337c403	refs/tags/v1.0.0
        e75adf01468423e7b7a49475e6d403f7cd886789	refs/tags/2.0.0
        626c3d4b6b55354b4af3aa309f998fae9b31a3d9	refs/tags/v3.2.0
        """)
        
        let package = SwiftPackage(
            package: "TestPackage",
            repositoryURL: repositoryURL,
            revision: nil,
            version: Version(1, 0, 0),
            gitProvider: mockProvider
        )

        let versions = package.availableVersions()

        #expect(versions.count == 3)
        #expect(versions.contains(Version(1, 0, 0)))
        #expect(versions.contains(Version(2, 0, 0)))
        #expect(versions.contains(Version(3, 2, 0)))
    }
    
    @Test("Invalid versions filtered")
    func invalidVersionsFiltered() {
        let mockProvider = MockGitRemoteProvider()
        let repositoryURL = "https://github.com/example/repo.git"
        
        mockProvider.setTagRefsResponse(for: repositoryURL, response: """
        d945937a1b87e8b2bafb749c8ec53610f337c403	refs/tags/1.0.0
        e75adf01468423e7b7a49475e6d403f7cd886789	refs/tags/invalid-tag
        626c3d4b6b55354b4af3aa309f998fae9b31a3d9	refs/tags/2.0.0
        abcd1234567890abcdef1234567890abcdef1234	refs/tags/another-invalid
        """)
        
        let package = SwiftPackage(
            package: "TestPackage",
            repositoryURL: repositoryURL,
            revision: nil,
            version: Version(1, 0, 0),
            gitProvider: mockProvider
        )

        let versions = package.availableVersions()

        #expect(versions.count == 2)
        #expect(versions.contains(Version(1, 0, 0)))
        #expect(versions.contains(Version(2, 0, 0)))
    }
    
    @Test("Get latest version logic")
    func getLatestVersionLogic() async {
        let mockProvider = MockGitRemoteProvider()
        mockProvider.setTagRefsResponse(for: "https://github.com/example/repo.git", response: """
        d945937a1b87e8b2bafb749c8ec53610f337c403	refs/tags/1.0.0
        abcd1234567890abcdef1234567890abcdef1234	refs/tags/1.1.0
        626c3d4b6b55354b4af3aa309f998fae9b31a3d9	refs/tags/2.0.0
        16da5c62dd737258c6df2e8c430f8a3202f655a7	refs/tags/3.0.0
        e75adf01468423e7b7a49475e6d403f7cd886789	refs/tags/4.0.0-beta1
        """)

        let packages = [
            SwiftPackage(
                package: "TestPackage",
                repositoryURL: "https://github.com/example/repo.git",
                revision: nil,
                version: Version(1, 0, 0),
                gitProvider: mockProvider
            )
        ]

        let packageCollection = await SwiftPackage.collectVersions(
            for: packages,
            ignoringPrerelease: false,
            onlyMajorUpdates: false
        )

        #expect(packageCollection.outdatedPackages.count == 1)
        #expect(packageCollection.ignoredPackages.isEmpty)

        let outdatedPackage = packageCollection.outdatedPackages.first!
        #expect(outdatedPackage.package == "TestPackage")
        #expect(outdatedPackage.currentVersion == Version(1, 0, 0))
        #expect(outdatedPackage.latestVersion == Version("4.0.0-beta1"))
        #expect(outdatedPackage.url == "https://github.com/example/repo.git")

        let packageCollectionWithPrerelease = await SwiftPackage.collectVersions(
            for: packages,
            ignoringPrerelease: true,
            onlyMajorUpdates: false
        )
        #expect(packageCollectionWithPrerelease.outdatedPackages.count == 1)
        #expect(packageCollectionWithPrerelease.outdatedPackages.first?.latestVersion == Version(3, 0, 0))

        let packageCollectionMajorOnly = await SwiftPackage.collectVersions(
            for: packages,
            ignoringPrerelease: true,
            onlyMajorUpdates: true
        )
        #expect(packageCollectionMajorOnly.outdatedPackages.count == 1)
        #expect(packageCollectionMajorOnly.outdatedPackages.first?.latestVersion == Version(3, 0, 0))
    }
}
