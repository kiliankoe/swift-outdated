import Foundation
import Files
import ShellOut

/// Runs `swift package dump-package` to obtain a project's manifest as JSON.
/// Abstracted behind a protocol so tests can inject canned output instead of shelling out.
public protocol ManifestDumpProvider: Sendable {
    /// Runs `swift package dump-package --package-path <dir>` and returns its raw JSON output.
    func dumpPackage(packagePath: String) throws -> Data
}

public struct ShellManifestDumpProvider: ManifestDumpProvider {
    public init() {}

    public func dumpPackage(packagePath: String) throws -> Data {
        log.trace("swift package dump-package --package-path \(packagePath)")
        let output = try shellOut(
            to: "swift",
            arguments: ["package", "dump-package", "--package-path", packagePath]
        )
        return Data(output.utf8)
    }
}

/// The slice of `swift package dump-package` JSON we care about: the direct dependencies and
/// their remote URLs. All fields are optional so variant manifest shapes decode instead of throwing.
private struct DumpedManifest: Decodable {
    let dependencies: [Dependency]

    struct Dependency: Decodable {
        // Only source-control deps carry a remote URL; fileSystem/registry deps lack `sourceControl`.
        let sourceControl: [SourceControl]?
    }
    struct SourceControl: Decodable {
        let identity: String?
        let location: Location?
    }
    struct Location: Decodable {
        let remote: [Remote]?
    }
    struct Remote: Decodable {
        let urlString: String?
    }
}

/// Determines the set of *direct* dependencies of a project, so transitive pins in the flat
/// `Package.resolved` can be filtered out.
public struct DirectDependencyResolver: Sendable {
    private let dumpProvider: ManifestDumpProvider

    public init(dumpProvider: ManifestDumpProvider = ShellManifestDumpProvider()) {
        self.dumpProvider = dumpProvider
    }

    /// Normalized repository URLs of the project's direct dependencies.
    ///
    /// Returns `nil` when direct dependencies cannot be determined (unknown project type, a failed
    /// `dump-package`, or an unreadable pbxproj) so callers can tell "could not determine, show
    /// everything" apart from an empty set, which means "determined: zero remote direct deps".
    public func directDependencyURLs(in folder: Folder) -> Set<String>? {
        guard let type = PackageUpdater.detectProjectType(in: folder) else {
            log.info("Could not detect project type; cannot determine direct dependencies.")
            return nil
        }

        switch type {
        case .spm(let manifestPath), .tuist(let manifestPath):
            let dir = (manifestPath as NSString).deletingLastPathComponent
            do {
                let data = try dumpProvider.dumpPackage(packagePath: dir)
                return Self.parseDumpPackageURLs(data)
            } catch {
                log.info("swift package dump-package failed: \(error)")
                return nil
            }
        case .xcode(let pbxprojPath):
            guard let content = try? String(contentsOfFile: pbxprojPath, encoding: .utf8) else {
                log.info("Could not read \(pbxprojPath); cannot determine direct dependencies.")
                return nil
            }
            return Self.parsePbxprojURLs(content)
        }
    }

    // MARK: - Pure parsers

    /// Collect normalized remote URLs from `swift package dump-package` JSON.
    /// Returns `nil` if the JSON can't be decoded at all.
    static func parseDumpPackageURLs(_ data: Data) -> Set<String>? {
        guard let manifest = try? JSONDecoder().decode(DumpedManifest.self, from: data) else {
            return nil
        }
        let urls = manifest.dependencies
            .compactMap(\.sourceControl).flatMap { $0 }
            .compactMap(\.location?.remote).flatMap { $0 }
            .compactMap(\.urlString)
        return Set(urls.map(normalizeRepositoryURL))
    }

    /// Collect normalized remote URLs from a project's `project.pbxproj`. `repositoryURL` only
    /// appears inside `XCRemoteSwiftPackageReference` blocks, which list direct package
    /// dependencies — transitive deps are not recorded in the pbxproj.
    static func parsePbxprojURLs(_ pbxproj: String) -> Set<String> {
        let pattern = #"repositoryURL\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(pbxproj.startIndex..., in: pbxproj)
        let urls = regex.matches(in: pbxproj, range: range).compactMap { match -> String? in
            guard let urlRange = Range(match.range(at: 1), in: pbxproj) else { return nil }
            return normalizeRepositoryURL(String(pbxproj[urlRange]))
        }
        return Set(urls)
    }
}
