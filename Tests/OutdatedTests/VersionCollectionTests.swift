import Testing
import Version
@testable import Outdated

@Suite("Version Collection Tests")
struct VersionCollectionTests {
    
    init() {
        initializeTestLogging()
    }

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
    
    @Test("Two-component version tags are parsed (issue #56)")
    func twoComponentVersionTags() async {
        let mockProvider = MockGitRemoteProvider()
        let repositoryURL = "https://github.com/swiftlang/swift-subprocess.git"

        // swift-subprocess publishes two-component tags like "0.5" alongside
        // "0.2.1". Strict semver parsing dropped the two-component tags, leaving
        // "0.2.1" as the bogus "latest".
        mockProvider.setTagRefsResponse(for: repositoryURL, response: """
        44be5d56aa4b26dc2003a67c0288a6a68366a87d	refs/tags/0.1
        d781b8f079f3747f970bef3e4aadece29d4d0385	refs/tags/0.2
        44922dfe46380cd354ca4b0208e717a3e92b13dd	refs/tags/0.2.1
        ba5888ad7758cbcbe7abebac37860b1652af2d9c	refs/tags/0.3
        13d087685b95d64d6aac9b94500d347bbe84c39b	refs/tags/0.4
        11633673a41f509f8945f23c96c7acd4adafd679	refs/tags/0.5
        5715ed49b0a5493cb24f3904dc2d9736c180d949	refs/tags/development-snapshot-2025-07-21
        """)

        let package = SwiftPackage(
            package: "swift-subprocess",
            repositoryURL: repositoryURL,
            revision: nil,
            version: Version(0, 5, 0),
            gitProvider: mockProvider
        )

        let versions = package.availableVersions()

        // All six numeric tags parse; the snapshot tag is dropped.
        #expect(versions.count == 6)
        #expect(versions == [
            Version(0, 1, 0),
            Version(0, 2, 0),
            Version(0, 2, 1),
            Version(0, 3, 0),
            Version(0, 4, 0),
            Version(0, 5, 0),
        ])
        #expect(versions.last == Version(0, 5, 0))

        // The package pinned at 0.5.0 must be reported up to date, not outdated.
        let collection = await SwiftPackage.collectVersions(
            for: [package],
            ignoringPrerelease: false,
            onlyMajorUpdates: false
        )
        #expect(collection.outdatedPackages.isEmpty)
        #expect(collection.upToDatePackages.contains { $0.package == "swift-subprocess" })
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

    @Test("directDependencyURLs filters out transitive packages")
    func directDependencyURLsFiltersTransitive() async {
        let mockProvider = MockGitRemoteProvider()
        let directURL = "https://github.com/example/direct.git"
        let transitiveURL = "https://github.com/example/transitive.git"
        for url in [directURL, transitiveURL] {
            mockProvider.setTagRefsResponse(for: url, response: """
            d945937a1b87e8b2bafb749c8ec53610f337c403	refs/tags/1.0.0
            626c3d4b6b55354b4af3aa309f998fae9b31a3d9	refs/tags/2.0.0
            """)
        }
        let packages = [directURL, transitiveURL].map {
            SwiftPackage(package: $0, repositoryURL: $0, revision: nil, version: Version(1, 0, 0), gitProvider: mockProvider)
        }

        let filtered = await SwiftPackage.collectVersions(
            for: packages,
            ignoringPrerelease: false,
            onlyMajorUpdates: false,
            directDependencyURLs: [normalizeRepositoryURL(directURL)]
        )
        #expect(filtered.outdatedPackages.map(\.url) == [directURL])

        // A nil set must report both, matching the pre-filter behavior.
        let unfiltered = await SwiftPackage.collectVersions(
            for: packages,
            ignoringPrerelease: false,
            onlyMajorUpdates: false,
            directDependencyURLs: nil
        )
        #expect(unfiltered.outdatedPackages.count == 2)
    }

    @Test("A filtered-out transitive ref pin does not resurface as ignored")
    func transitiveRefPinIsDroppedNotIgnored() async {
        let mockProvider = MockGitRemoteProvider()
        let refPin = SwiftPackage(
            package: "TransitiveRefPin",
            repositoryURL: "https://github.com/example/transitive-ref.git",
            revision: "9f39744e025c7d377987f30b03770805dcb0bcd1",
            version: nil,
            gitProvider: mockProvider
        )

        let collection = await SwiftPackage.collectVersions(
            for: [refPin],
            ignoringPrerelease: false,
            onlyMajorUpdates: false,
            directDependencyURLs: [] // determined: no direct deps
        )
        #expect(collection.ignoredPackages.isEmpty)
        #expect(collection.outdatedPackages.isEmpty)
    }

    @Test("Ref-pinned packages are ignored when no checkout is available")
    func refPinnedPackagesAreIgnoredWithoutCheckout() async {
        let mockProvider = MockGitRemoteProvider()
        // A branch/revision pin resolves to a revision but has no version.
        let refPinned = SwiftPackage(
            package: "RefPinned",
            repositoryURL: "https://github.com/example/ref-pinned.git",
            revision: "9f39744e025c7d377987f30b03770805dcb0bcd1",
            version: nil,
            gitProvider: mockProvider
        )

        let collection = await SwiftPackage.collectVersions(
            for: [refPinned],
            ignoringPrerelease: false,
            onlyMajorUpdates: false
        )

        // Without a checkout locator, ref pins keep the historical behavior:
        // ignored, never queried, and not surfaced as outdated/up-to-date.
        #expect(collection.ignoredPackages.map(\.package) == ["RefPinned"])
        #expect(collection.outdatedPackages.isEmpty)
        #expect(collection.upToDatePackages.isEmpty)
    }
}
