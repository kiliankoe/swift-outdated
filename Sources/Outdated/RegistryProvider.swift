import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetches the available releases of a SwiftPM registry package (SE-0292). The registry counterpart
/// to `GitRemoteProvider`: abstracted behind a protocol so tests can feed canned JSON instead of
/// hitting the network. Returns the raw "list package releases" response so the version parsing
/// stays in `SwiftPackage`, alongside the equivalent git-tag parsing.
public protocol RegistryProvider: Sendable {
    /// Raw "list package releases" JSON for a registry identity (`scope.name`).
    func listReleases(identity: String) throws -> Data
}

public enum RegistryError: Swift.Error, LocalizedError {
    case malformedIdentity(String)
    case noRegistryConfigured(scope: String)
    case requestFailed(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .malformedIdentity(let identity):
            return "Registry identity \"\(identity)\" is not of the form scope.name"
        case .noRegistryConfigured(let scope):
            return "No registry configured for scope \"\(scope)\" in registries.json"
        case .requestFailed(let statusCode):
            return "Registry request failed with status \(statusCode)"
        }
    }
}

public struct HTTPRegistryProvider: RegistryProvider {
    /// Per-request network timeout, matching `SecurityChecker`. Keeps the run from hanging on a slow registry.
    private static let requestTimeout: TimeInterval = 10

    private let projectPath: String?

    /// `projectPath` lets the configuration lookup prefer a project-local `.swiftpm` registry over the
    /// user-level one. Library callers without a project context get the user-level config only.
    public init(projectPath: String? = nil) {
        self.projectPath = projectPath
    }

    public func listReleases(identity: String) throws -> Data {
        let (scope, name) = try Self.splitIdentity(identity)
        guard let base = RegistryConfiguration.baseURL(forScope: scope, projectPath: projectPath) else {
            throw RegistryError.noRegistryConfigured(scope: scope)
        }
        let url = base.appendingPathComponent(scope).appendingPathComponent(name)
        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.setValue("application/vnd.swift.registry.v1+json", forHTTPHeaderField: "Accept")
        log.trace("Registry list-releases GET \(url.absoluteString)")

        // availableVersions() is synchronous and already blocks on `git ls-remote` inside its task
        // group, so blocking here keeps the registry path consistent rather than going async. The
        // semaphore guarantees the closure writes `box` before `wait()` returns.
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox()
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                box.result = .failure(error)
            } else if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                box.result = .failure(RegistryError.requestFailed(statusCode: http.statusCode))
            } else {
                box.result = .success(data ?? Data())
            }
        }.resume()
        semaphore.wait()
        return try box.result.get()
    }

    /// Carries the network result across the semaphore-bridged callback. Safe to mark unchecked: the
    /// semaphore enforces a happens-before between the closure's write and the `wait()`-side read.
    private final class ResultBox: @unchecked Sendable {
        var result: Result<Data, Swift.Error> = .failure(RegistryError.requestFailed(statusCode: -1))
    }

    /// Splits a registry identity into its scope and name on the first dot, e.g.
    /// `mona.linkedlist` → `("mona", "linkedlist")`.
    static func splitIdentity(_ identity: String) throws -> (scope: String, name: String) {
        guard let dot = identity.firstIndex(of: ".") else {
            throw RegistryError.malformedIdentity(identity)
        }
        let scope = String(identity[..<dot])
        let name = String(identity[identity.index(after: dot)...])
        guard !scope.isEmpty, !name.isEmpty else {
            throw RegistryError.malformedIdentity(identity)
        }
        return (scope, name)
    }
}

/// Reads SwiftPM's `registries.json` to resolve the base URL for a registry scope.
enum RegistryConfiguration {
    private struct File: Decodable {
        let registries: [String: Entry]
        struct Entry: Decodable { let url: String }
    }

    /// Base URL for `scope`, or `nil` when no registry is configured. A scope-specific entry wins
    /// over `[default]`, and a project-local config wins over the user-level one — matching SwiftPM's
    /// own precedence.
    static func baseURL(forScope scope: String, projectPath: String?) -> URL? {
        for path in candidatePaths(projectPath: projectPath) {
            guard let data = FileManager.default.contents(atPath: path),
                  let config = try? JSONDecoder().decode(File.self, from: data) else { continue }
            if let entry = config.registries[scope] ?? config.registries["[default]"],
               let url = URL(string: entry.url) {
                return url
            }
        }
        return nil
    }

    private static func candidatePaths(projectPath: String?) -> [String] {
        var paths: [String] = []
        if let projectPath {
            paths.append((projectPath as NSString).appendingPathComponent(".swiftpm/configuration/registries.json"))
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        paths.append((home as NSString).appendingPathComponent(".swiftpm/configuration/registries.json"))
        return paths
    }
}
