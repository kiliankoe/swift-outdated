import Foundation
import Files
import Yams

/// Optional `.swift-outdated.yml` in the project root. Currently only carries fork→upstream
/// mappings, but the list-of-objects shape leaves room for per-entry options and further keys.
public struct OutdatedConfig: Decodable {
    public var forks: [ForkMapping]

    public struct ForkMapping: Decodable {
        /// The fork repository as pinned in Package.resolved (matched by normalized URL).
        public let fork: String
        /// The repository whose tags determine outdatedness instead of the fork's.
        public let upstream: String
    }

    public init(forks: [ForkMapping] = []) {
        self.forks = forks
    }

    private enum CodingKeys: String, CodingKey {
        case forks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.forks = try container.decodeIfPresent([ForkMapping].self, forKey: .forks) ?? []
    }

    public static func parse(_ yaml: String) throws -> OutdatedConfig {
        try YAMLDecoder().decode(OutdatedConfig.self, from: yaml)
    }

    /// `normalized fork URL → raw upstream URL`. The upstream is passed verbatim to `git
    /// ls-remote`, so it is kept unnormalized; only the lookup key is normalized for matching.
    public func forkUpstreamMap() -> [String: String] {
        Dictionary(
            forks.map { (normalizeRepositoryURL($0.fork), $0.upstream) },
            // Last mapping wins on duplicate forks rather than crashing.
            uniquingKeysWith: { _, last in last }
        )
    }

    /// An absent config is normal (empty result); a present-but-broken one is logged rather than
    /// failing the run, matching the tool's resilient, non-fatal style.
    public static func load(in folder: Folder, explicitPath: String?) -> OutdatedConfig {
        guard let file = configFile(in: folder, explicitPath: explicitPath) else {
            return OutdatedConfig()
        }
        do {
            return try parse(try file.readAsString())
        } catch {
            log.error("Could not read config at \(file.path): \(error)")
            return OutdatedConfig()
        }
    }

    private static func configFile(in folder: Folder, explicitPath: String?) -> File? {
        if let explicitPath {
            guard let file = try? File(path: explicitPath) else {
                log.error("Config file not found at \(explicitPath)")
                return nil
            }
            return file
        }
        return [".swift-outdated.yml", ".swift-outdated.yaml"]
            .lazy
            .compactMap { try? folder.file(named: $0) }
            .first
    }
}
