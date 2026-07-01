import Testing
import Files
import Foundation
@testable import Outdated

@Suite("Caching Provider Tests")
struct CachingProviderTests {

    init() {
        initializeTestLogging()
    }

    private func tempDirectory() throws -> URL {
        let folder = try Folder.temporary.createSubfolder(named: "swift-outdated-cache-\(UUID().uuidString)")
        return URL(fileURLWithPath: folder.path)
    }

    @Test("Git tags are served from the cache within the TTL")
    func gitCacheHit() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = TagCache(directory: dir, ttl: 3600, now: { Date(timeIntervalSince1970: 1000) })

        let mock = MockGitRemoteProvider()
        mock.setTagRefsResponse(for: "https://example.com/repo.git", response: "original")
        let provider = CachingGitRemoteProvider(wrapped: mock, cache: cache)

        #expect(try provider.getRemoteTags(repositoryURL: "https://example.com/repo.git") == "original")

        // Changing the underlying response proves the second read comes from the cache, not the mock.
        mock.setTagRefsResponse(for: "https://example.com/repo.git", response: "changed")
        #expect(try provider.getRemoteTags(repositoryURL: "https://example.com/repo.git") == "original")
    }

    @Test("Git tags are refetched once the cache entry expires")
    func gitCacheExpiry() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let mock = MockGitRemoteProvider()
        mock.setTagRefsResponse(for: "https://example.com/repo.git", response: "original")

        let writer = CachingGitRemoteProvider(
            wrapped: mock,
            cache: TagCache(directory: dir, ttl: 3600, now: { Date(timeIntervalSince1970: 1000) })
        )
        #expect(try writer.getRemoteTags(repositoryURL: "https://example.com/repo.git") == "original")

        mock.setTagRefsResponse(for: "https://example.com/repo.git", response: "changed")
        let reader = CachingGitRemoteProvider(
            wrapped: mock,
            cache: TagCache(directory: dir, ttl: 3600, now: { Date(timeIntervalSince1970: 1000 + 4000) })
        )
        #expect(try reader.getRemoteTags(repositoryURL: "https://example.com/repo.git") == "changed")
    }

    @Test("Registry release JSON round-trips through the cache intact")
    func registryCacheHit() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = TagCache(directory: dir, ttl: 3600, now: { Date(timeIntervalSince1970: 1000) })

        let json = #"{ "releases": { "1.0.0": { "url": "x" } } }"#
        let mock = MockRegistryProvider()
        mock.setReleasesResponse(forIdentity: "mona.linkedlist", json: json)
        let provider = CachingRegistryProvider(wrapped: mock, cache: cache)

        #expect(try provider.listReleases(identity: "mona.linkedlist") == Data(json.utf8))

        mock.setReleasesResponse(forIdentity: "mona.linkedlist", json: #"{ "releases": {} }"#)
        #expect(try provider.listReleases(identity: "mona.linkedlist") == Data(json.utf8))
    }
}
