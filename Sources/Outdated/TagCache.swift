import Foundation

/// Short-lived on-disk cache for raw version-fetch responses (the `git ls-remote` text and the
/// registry release JSON). Running as an Xcode Run Script Phase otherwise refetches every
/// dependency's versions on every build (issue #4); caching the raw payload keeps all parsing in
/// `SwiftPackage` while sparing the network round-trips.
public struct TagCache: Sendable {
    public static let defaultTTL: TimeInterval = 3600

    let directory: URL
    let ttl: TimeInterval
    // Injectable so tests can simulate expiry; there is no shared clock abstraction to reuse.
    let now: @Sendable () -> Date

    public init(
        directory: URL = TagCache.defaultDirectory,
        ttl: TimeInterval,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.directory = directory
        self.ttl = ttl
        self.now = now
    }

    public static var defaultDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("swift-outdated", isDirectory: true)
    }

    /// The cached payload for `key`, or `nil` when absent, unreadable, or older than `ttl`.
    func value(forKey key: String) -> String? {
        guard let data = try? Data(contentsOf: fileURL(forKey: key)),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else {
            return nil
        }
        let age = now().timeIntervalSince1970 - entry.fetchedAt
        return age < ttl ? entry.payload : nil
    }

    /// Best-effort write; a cache failure must never fail the run, so errors are swallowed.
    func store(_ payload: String, forKey key: String) {
        let entry = CacheEntry(fetchedAt: now().timeIntervalSince1970, payload: payload)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(forKey: key), options: .atomic)
    }

    /// URL-safe Base64 of the key keeps the filename deterministic and collision-free without a
    /// crypto dependency (keys are short git URLs / registry identities).
    private func fileURL(forKey key: String) -> URL {
        let name = Data(key.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return directory.appendingPathComponent(name).appendingPathExtension("json")
    }

    private struct CacheEntry: Codable {
        let fetchedAt: Double
        let payload: String
    }
}

/// Wraps a `GitRemoteProvider`, serving cached `ls-remote` output within the TTL and otherwise
/// fetching and caching it.
struct CachingGitRemoteProvider: GitRemoteProvider {
    let wrapped: GitRemoteProvider
    let cache: TagCache

    func getRemoteTags(repositoryURL: String) throws -> String {
        let key = "git:" + repositoryURL
        if let cached = cache.value(forKey: key) {
            log.trace("Cache hit for tags of \(repositoryURL)")
            return cached
        }
        let fresh = try wrapped.getRemoteTags(repositoryURL: repositoryURL)
        cache.store(fresh, forKey: key)
        return fresh
    }
}

/// Wraps a `RegistryProvider`, serving cached release JSON within the TTL. The payload is JSON text,
/// so it round-trips through the string-backed cache as UTF-8.
struct CachingRegistryProvider: RegistryProvider {
    let wrapped: RegistryProvider
    let cache: TagCache

    func listReleases(identity: String) throws -> Data {
        let key = "registry:" + identity
        if let cached = cache.value(forKey: key) {
            log.trace("Cache hit for releases of \(identity)")
            return Data(cached.utf8)
        }
        let fresh = try wrapped.listReleases(identity: identity)
        cache.store(String(decoding: fresh, as: UTF8.self), forKey: key)
        return fresh
    }
}
