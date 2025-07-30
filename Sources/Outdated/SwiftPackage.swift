import Foundation
import Files
import Rainbow
import ShellOut
import Version
import Logging

let log = Logger(label: "SwiftOutdated")

public struct SwiftPackage {
    public let package: String
    public let repositoryURL: String
    public let revision: String?
    public let version: Version?
    
    private let gitProvider: GitRemoteProvider
    
    public init(package: String, repositoryURL: String, revision: String?, version: Version?, gitProvider: GitRemoteProvider = ShellGitRemoteProvider()) {
        self.package = package
        self.repositoryURL = repositoryURL
        self.revision = revision
        self.version = version
        self.gitProvider = gitProvider
    }
}

extension SwiftPackage: Encodable {
    enum CodingKeys: String, CodingKey {
        case package, repositoryURL, revision, version
    }
}

extension SwiftPackage: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(package)
        hasher.combine(repositoryURL)
        hasher.combine(revision)
        hasher.combine(version)
    }
    
    public static func == (lhs: SwiftPackage, rhs: SwiftPackage) -> Bool {
        return lhs.package == rhs.package &&
               lhs.repositoryURL == rhs.repositoryURL &&
               lhs.revision == rhs.revision &&
               lhs.version == rhs.version
    }
}

extension SwiftPackage {
    public var hasResolvedVersion: Bool {
        self.version != nil
    }
    
    public func availableVersions() -> [Version] {
        do {
            log.trace("Running git ls-remote for \(self.package).")
            let lsRemote = try gitProvider.getRemoteTags(repositoryURL: self.repositoryURL)
            return lsRemote
                .split(separator: "\n")
                .map {
                    $0.split(separator: "\t")
                        .last!
                        .trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(
                            of: #"refs\/tags\/(v(?=\d))?"#,
                            with: "",
                            options: .regularExpression
                        )
                }
                // Filter annotated tags, we just need a list of available tags, not the specific
                // commits they point to.
                .filter { !$0.contains("^{}") }
                .compactMap { Version($0) }
                .sorted()
        } catch {
            log.error("Error on git ls-remote for \(package): \(error)")
            return []
        }
    }
    
    public static func currentPackagePins(in folder: Folder) throws -> [Self] {
        let file: File = try {
            let possibleRootResolvedPaths = [
                "Package.resolved",
                ".package.resolved",
                "xcshareddata/swiftpm/Package.resolved",
                "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
            ]
            if let resolvedPath = possibleRootResolvedPaths.lazy.compactMap({ try? folder.file(at: $0) }).first {
                log.info("Found package pins at \(resolvedPath.path(relativeTo: folder))")
                return resolvedPath
            }

            let xcodeWorkspaces = folder.subfolders.filter { $0.name.hasSuffix("xcworkspace") }
            if let xcodeWorkspace = xcodeWorkspaces.first {
                if xcodeWorkspaces.count > 1 {
                    print("Multiple workspaces found. Using \(xcodeWorkspace.path(relativeTo: folder))".yellow)
                }
                let resolvedPath = "xcshareddata/swiftpm/Package.resolved"
                guard xcodeWorkspace.containsFile(at: resolvedPath) else {
                    log.info("Found workspace package pins at \(resolvedPath)")
                    throw Error.notFound
                }
                return try xcodeWorkspace.file(at: resolvedPath)
            }

            let xcodeProjects = folder.subfolders.filter { $0.name.hasSuffix("xcodeproj") }
            if let xcodeProject = xcodeProjects.first {
                if xcodeProjects.count > 1 {
                    print("Multiple projects found. Using \(xcodeProject.path(relativeTo: folder))".yellow)
                }
                let resolvedPath = "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
                guard xcodeProject.containsFile(at: resolvedPath) else {
                    log.info("Found project package pins at \(resolvedPath)")
                    throw Error.notFound
                }
                return try xcodeProject.file(at: resolvedPath)
            }

            throw Error.notFound
        }()
        
        guard let data = try? file.read() else {
            throw Error.notReadable
        }
        
        if let resolvedV1 = try? JSONDecoder().decode(ResolvedV1.self, from: data) {
            return resolvedV1.object.pins.map {
                SwiftPackage(
                    package: $0.package,
                    repositoryURL: $0.repositoryURL,
                    revision: $0.state.revision,
                    version: Version($0.state.version ?? "")
                )
            }
        } else if let resolvedV2 = try? JSONDecoder().decode(ResolvedV2.self, from: data) {
            return resolvedV2.pins.map {
                SwiftPackage(
                    package: $0.identity,
                    repositoryURL: $0.location,
                    revision: $0.state.revision,
                    version: Version($0.state.version ?? "")
                )
            }
        } else {
            return []
        }
    }
}

extension SwiftPackage {
    public static func collectVersions(for packages: [SwiftPackage], ignoringPrerelease: Bool, onlyMajorUpdates: Bool) async -> PackageCollection {
        log.info("Collecting versions for \(packages.map { $0.package }.joined(separator: ", ")).")
        let versions = await withTaskGroup(of: (SwiftPackage, [Version]?).self) { group in
            for package in packages where package.hasResolvedVersion {
                log.info("Package \(package.package) has resolved version, queueing version fetch.")
                group.addTask {
                    let availableVersions = package.availableVersions()
                    log.info("Found \(availableVersions.count) versions for \(package.package).")
                    return (package, availableVersions)
                }
            }

            var availableVersions = [SwiftPackage: [Version]]()
            for await (package, versions) in group {
                if let versions = versions {
                    availableVersions[package] = versions
                }
            }

            return availableVersions
        }

        let outdatedPackages = versions
            .compactMap { package, allVersions -> OutdatedPackage? in
                if let current = package.version, 
                   let latest = getLatestVersion(from: allVersions, currentVersion: current, ignoringPrerelease: ignoringPrerelease, onlyMajorUpdates: onlyMajorUpdates),
                   current != latest
                {
                    log.info("Package \(package.package) is outdated.")
                    return OutdatedPackage(package: package.package, currentVersion: current, latestVersion: latest, url: package.repositoryURL)
                } else {
                    log.info("Package \(package.package) is up to date.")
                }
                return nil
            }
            .sorted(by: { $0.package < $1.package })
        let ignoredPackages = packages.filter { !$0.hasResolvedVersion }
        if !ignoredPackages.isEmpty {
            log.info("Ignoring \(ignoredPackages.map { $0.package }.joined(separator: ", ")) because of non-version pins.")
        }
        return PackageCollection(outdatedPackages: outdatedPackages, ignoredPackages: ignoredPackages)
    }

    private static func getLatestVersion(from allVersions: [Version], currentVersion: Version, ignoringPrerelease: Bool, onlyMajorUpdates: Bool) -> Version? {
        var validVersions: [Version] = allVersions

        if ignoringPrerelease {
            validVersions = validVersions.filter { $0.prereleaseIdentifiers.isEmpty }
        }

        if onlyMajorUpdates {
            validVersions = validVersions.filter { ($0.major - currentVersion.major) > 0 }
        }

        return validVersions.last
    }
}

extension SwiftPackage {
    public enum Error: Swift.Error, LocalizedError {
        case notFound
        case notReadable
        
        public var errorDescription: String? {
            switch self {
            case .notFound:
                return "No Package.resolved found in current working tree."
            case .notReadable:
                return "No Package.resolved read in current working tree."
            }
        }
    }
}
