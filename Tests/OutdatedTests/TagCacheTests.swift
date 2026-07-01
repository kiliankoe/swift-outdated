import Testing
import Files
import Foundation
@testable import Outdated

@Suite("Tag Cache Tests")
struct TagCacheTests {

    init() {
        initializeTestLogging()
    }

    private func tempDirectory() throws -> URL {
        let folder = try Folder.temporary.createSubfolder(named: "swift-outdated-cache-\(UUID().uuidString)")
        return URL(fileURLWithPath: folder.path)
    }

    @Test("A stored value is returned within the TTL")
    func hitWithinTTL() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = TagCache(directory: dir, ttl: 3600, now: { Date(timeIntervalSince1970: 1000) })

        cache.store("refs/tags/1.0.0", forKey: "git:example")
        #expect(cache.value(forKey: "git:example") == "refs/tags/1.0.0")
    }

    @Test("A value older than the TTL is treated as a miss")
    func expiry() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let writer = TagCache(directory: dir, ttl: 3600, now: { Date(timeIntervalSince1970: 1000) })
        writer.store("payload", forKey: "git:example")

        // Same directory, but the clock has advanced past the TTL.
        let reader = TagCache(directory: dir, ttl: 3600, now: { Date(timeIntervalSince1970: 1000 + 4000) })
        #expect(reader.value(forKey: "git:example") == nil)
    }

    @Test("A missing key yields nil")
    func missingKey() throws {
        let dir = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = TagCache(directory: dir, ttl: 3600)
        #expect(cache.value(forKey: "git:absent") == nil)
    }

    @Test("A nonexistent directory yields nil without throwing")
    func nonexistentDirectory() {
        let dir = URL(fileURLWithPath: "/nonexistent/swift-outdated-\(UUID().uuidString)")
        let cache = TagCache(directory: dir, ttl: 3600)
        #expect(cache.value(forKey: "git:example") == nil)
    }
}
