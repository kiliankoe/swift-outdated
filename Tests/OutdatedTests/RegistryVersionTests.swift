import Testing
import Version
import Foundation
@testable import Outdated

@Suite("Registry Version Tests")
struct RegistryVersionTests {

    init() {
        initializeTestLogging()
    }

    @Test("Parses release versions, skipping problem entries")
    func parsesReleases() {
        // Version strings are the keys; "1.1.0" carries a problem (withdrawn) and must be dropped.
        let json = """
        {
          "releases": {
            "1.0.0": { "url": "https://reg.example.com/mona/linkedlist/1.0.0" },
            "1.1.0": { "problem": { "status": 410, "detail": "this release was removed" } },
            "2.0.0": { "url": "https://reg.example.com/mona/linkedlist/2.0.0" }
          }
        }
        """
        let versions = SwiftPackage.parseRegistryReleases(Data(json.utf8))
        #expect(versions == [Version(1, 0, 0), Version(2, 0, 0)])
    }

    @Test("Malformed registry JSON yields no versions")
    func malformedJSON() {
        #expect(SwiftPackage.parseRegistryReleases(Data("not json".utf8)).isEmpty)
    }

    @Test("availableVersions queries the registry for a registry package")
    func availableVersionsFromRegistry() {
        let mock = MockRegistryProvider()
        mock.setReleasesResponse(forIdentity: "mona.linkedlist", json: """
        { "releases": { "1.0.0": { "url": "x" }, "2.0.0": { "url": "y" } } }
        """)

        let package = SwiftPackage(
            package: "mona.linkedlist",
            repositoryURL: "",
            revision: nil,
            version: Version(1, 0, 0),
            registryIdentity: "mona.linkedlist",
            registryProvider: mock
        )

        #expect(package.availableVersions() == [Version(1, 0, 0), Version(2, 0, 0)])
    }

    @Test("A registry package is reported outdated against its latest release (issue #42)")
    func registryPackageOutdated() async {
        let mock = MockRegistryProvider()
        mock.setReleasesResponse(forIdentity: "mona.linkedlist", json: """
        { "releases": { "1.0.0": { "url": "x" }, "2.0.0": { "url": "y" } } }
        """)

        let package = SwiftPackage(
            package: "mona.linkedlist",
            repositoryURL: "",
            revision: nil,
            version: Version(1, 0, 0),
            registryIdentity: "mona.linkedlist",
            registryProvider: mock
        )

        let collection = await SwiftPackage.collectVersions(
            for: [package],
            ignoringPrerelease: false,
            onlyMajorUpdates: false
        )

        #expect(collection.outdatedPackages.count == 1)
        let outdated = collection.outdatedPackages.first
        #expect(outdated?.latestVersion == Version(2, 0, 0))
        #expect(outdated?.url == "")
        #expect(outdated?.displayURL == "registry: mona.linkedlist")
    }

    @Test("A registry package with no newer release is up to date")
    func registryPackageUpToDate() async {
        let mock = MockRegistryProvider()
        mock.setReleasesResponse(forIdentity: "mona.linkedlist", json: """
        { "releases": { "1.0.0": { "url": "x" } } }
        """)

        let package = SwiftPackage(
            package: "mona.linkedlist",
            repositoryURL: "",
            revision: nil,
            version: Version(1, 0, 0),
            registryIdentity: "mona.linkedlist",
            registryProvider: mock
        )

        let collection = await SwiftPackage.collectVersions(
            for: [package],
            ignoringPrerelease: false,
            onlyMajorUpdates: false
        )

        #expect(collection.outdatedPackages.isEmpty)
        #expect(collection.upToDatePackages.contains { $0.package == "mona.linkedlist" })
    }
}
