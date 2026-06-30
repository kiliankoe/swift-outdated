import Foundation
import Files
import Rainbow
import ShellOut
import Version
import Logging

let log = Logger(label: "SwiftOutdated")

public struct SwiftPackage: Sendable {
    public let package: String
    public let repositoryURL: String
    public let revision: String?
    /// The branch a ref pin tracks, when pinned via `.branch(_:)` rather than a bare revision.
    public let branch: String?
    public let version: Version?

    private let gitProvider: GitRemoteProvider

    public init(package: String, repositoryURL: String, revision: String?, branch: String? = nil, version: Version?, gitProvider: GitRemoteProvider = ShellGitRemoteProvider()) {
        self.package = package
        self.repositoryURL = repositoryURL
        self.revision = revision
        self.branch = branch
        self.version = version
        self.gitProvider = gitProvider
    }
}

extension SwiftPackage: Encodable {
    enum CodingKeys: String, CodingKey {
        case package, repositoryURL, revision, branch, version
    }
}

extension SwiftPackage: Comparable {
    public static func < (lhs: SwiftPackage, rhs: SwiftPackage) -> Bool {
        return lhs.package < rhs.package
    }
}

extension SwiftPackage: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(package)
        hasher.combine(repositoryURL)
        hasher.combine(revision)
        hasher.combine(branch)
        hasher.combine(version)
    }

    public static func == (lhs: SwiftPackage, rhs: SwiftPackage) -> Bool {
        return lhs.package == rhs.package &&
               lhs.repositoryURL == rhs.repositoryURL &&
               lhs.revision == rhs.revision &&
               lhs.branch == rhs.branch &&
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
                            of: #"refs\/tags\/"#,
                            with: "",
                            options: .regularExpression
                        )
                }
                // Filter annotated tags, we just need a list of available tags, not the specific
                // commits they point to.
                .filter { !$0.contains("^{}") }
                // Use the tolerant parser so two-component tags (e.g. "0.5") and
                // a leading "v" are normalized rather than dropped.
                .compactMap { Version(tolerant: $0) }
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
                "project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
                "Tuist/Package.resolved"
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
                    branch: $0.state.branch,
                    version: Version($0.state.version ?? "")
                )
            }
        } else if let resolvedV2 = try? JSONDecoder().decode(ResolvedV2.self, from: data) {
            return resolvedV2.pins.map {
                SwiftPackage(
                    package: $0.identity,
                    repositoryURL: $0.location,
                    revision: $0.state.revision,
                    branch: $0.state.branch,
                    version: Version($0.state.version ?? "")
                )
            }
        } else {
            return []
        }
    }
}

extension SwiftPackage {
    private static func fetchAvailableVersions(
        for packages: [SwiftPackage]
    ) async -> [(SwiftPackage, [Version])] {
        await withTaskGroup(of: (SwiftPackage, [Version]).self) { group in
            for package in packages where package.hasResolvedVersion {
                log.info("Package \(package.package) has resolved version, queueing version fetch.")
                group.addTask {
                    let availableVersions = package.availableVersions()
                    log.info("Found \(availableVersions.count) versions for \(package.package).")
                    return (package, availableVersions)
                }
            }

            var result = [(SwiftPackage, [Version])]()
            for await pair in group {
                result.append(pair)
            }
            return result
        }
    }

    public static func collectVersions(for allPackages: [SwiftPackage], ignoringPrerelease: Bool, onlyMajorUpdates: Bool, checkSecurity: Bool = false, checkoutLocator: CheckoutLocator? = nil, directDependencyURLs: Set<String>? = nil) async -> PackageCollection {
        // Filter before any analysis so transitive pins are dropped uniformly — a transitive ref
        // pin should disappear entirely, not resurface in the "ignored" bucket. A nil set means
        // direct deps couldn't be determined, so keep every package.
        let packages = filterToDirectDependencies(allPackages, directDependencyURLs: directDependencyURLs)

        log.info("Collecting versions for \(packages.map { $0.package }.joined(separator: ", ")).")
        let versions = await fetchAvailableVersions(for: packages)

        var upToDatePackages: [SwiftPackage] = []
        var outdatedPackages: [OutdatedPackage] = []

        for (package, allVersions) in versions {
            guard let current = package.version else {
                continue
            }

            if let latest = getLatestVersion(from: allVersions, currentVersion: current, ignoringPrerelease: ignoringPrerelease, onlyMajorUpdates: onlyMajorUpdates),
               current != latest {
                log.info("Package \(package.package) is outdated.")
                outdatedPackages.append(
                    OutdatedPackage(
                        package: package.package,
                        currentVersion: current,
                        latestVersion: latest,
                        url: package.repositoryURL
                    )
                )
            } else {
                log.info("Package \(package.package) is up to date.")
                upToDatePackages.append(
                    SwiftPackage(
                        package: package.package,
                        repositoryURL: package.repositoryURL,
                        revision: package.revision,
                        branch: package.branch,
                        version: package.version
                    )
                )
            }
        }

        // Branch/revision pins: analyze against a local checkout when one is available, otherwise
        // keep the historical "ignored" behavior.
        let (refPinnedPackages, ignoredPackages) = await analyzeRefPins(
            packages.filter { !$0.hasResolvedVersion },
            ignoringPrerelease: ignoringPrerelease,
            onlyMajorUpdates: onlyMajorUpdates,
            checkoutLocator: checkoutLocator
        )
        if !ignoredPackages.isEmpty {
            log.info("Ignoring \(ignoredPackages.map { $0.package }.joined(separator: ", ")) because of non-version pins.")
        }

        var securityResults: [String: SecurityPair]?
        if checkSecurity && !outdatedPackages.isEmpty {
            let toCheck = outdatedPackages.map { (name: $0.package, url: $0.url, currentVersion: $0.currentVersion.description, latestVersion: $0.latestVersion.description) }
            securityResults = await SecurityChecker.check(packages: toCheck)
        }

        return PackageCollection(
            outdatedPackages: outdatedPackages.sorted(),
            ignoredPackages: ignoredPackages.sorted(),
            upToDatePackages: upToDatePackages.sorted(),
            securityResults: securityResults,
            refPinnedPackages: refPinnedPackages.sorted()
        )
    }

    /// Restrict the pins to direct dependencies. A `nil` set means direct deps couldn't be
    /// determined, so nothing is filtered. As a safety net, a non-nil set that matches *none* of
    /// the pins also reports everything: that signals our determination missed (e.g. a Tuist or
    /// local-package layout whose pins aren't expressed in the inspected manifest), and hiding
    /// every package would look like the tool is broken.
    static func filterToDirectDependencies(_ packages: [SwiftPackage], directDependencyURLs: Set<String>?) -> [SwiftPackage] {
        guard let directURLs = directDependencyURLs else { return packages }
        let filtered = packages.filter { directURLs.contains(normalizeRepositoryURL($0.repositoryURL)) }
        guard !filtered.isEmpty || packages.isEmpty else {
            log.info("Direct dependencies matched no resolved packages; reporting all.")
            return packages
        }
        log.info("Reporting \(filtered.count) of \(packages.count) packages (direct dependencies only).")
        return filtered
    }

    /// For each ref/branch pin, locate its checkout and derive how outdated it is: the base tag comes
    /// from the local commit graph (`git describe`), the latest from `ls-remote` (fresh). Pins without a
    /// usable checkout are returned as `ignored`, matching the pre-existing behavior.
    private static func analyzeRefPins(
        _ refPinned: [SwiftPackage],
        ignoringPrerelease: Bool,
        onlyMajorUpdates: Bool,
        checkoutLocator: CheckoutLocator?
    ) async -> (analyses: [RefPinAnalysis], ignored: [SwiftPackage]) {
        guard let locator = checkoutLocator, !refPinned.isEmpty else {
            return ([], refPinned)
        }

        let localGit = ShellLocalGitProvider()
        let results: [(SwiftPackage, RefPinAnalysis?)] = await withTaskGroup(of: (SwiftPackage, RefPinAnalysis?).self) { group in
            for package in refPinned {
                group.addTask {
                    guard let revision = package.revision,
                          let checkoutPath = locator.findCheckout(for: package.package, repositoryURL: package.repositoryURL)
                    else {
                        return (package, nil)
                    }

                    let baseTag = ((try? localGit.describeTag(revision: revision, checkoutPath: checkoutPath)) ?? nil)
                        .flatMap { Version(tolerant: $0) }
                    let latest = getLatestVersion(
                        from: package.availableVersions(),
                        currentVersion: baseTag ?? Version(0, 0, 0),
                        ignoringPrerelease: ignoringPrerelease,
                        onlyMajorUpdates: onlyMajorUpdates
                    )
                    return (package, RefPinAnalysis(
                        package: package.package,
                        branch: package.branch,
                        revision: revision,
                        baseTag: baseTag,
                        latestTag: latest,
                        url: package.repositoryURL
                    ))
                }
            }

            var out = [(SwiftPackage, RefPinAnalysis?)]()
            for await result in group {
                out.append(result)
            }
            return out
        }

        var analyses = [RefPinAnalysis]()
        var ignored = [SwiftPackage]()
        for (package, analysis) in results {
            if let analysis {
                analyses.append(analysis)
            } else {
                ignored.append(package)
            }
        }
        return (analyses, ignored)
    }

    /// Collect versions for update mode, returning tuples suitable for PackageUpdater.
    public static func collectVersionsForUpdate(
        for packages: [SwiftPackage],
        ignoringPrerelease: Bool,
        scope: UpdateScope,
        filterPackages: [String] = []
    ) async -> [(package: String, url: String, current: Version, target: Version)] {
        let filtered = filterPackages.isEmpty ? packages : packages.filter { filterPackages.contains($0.package) }
        let versions = await fetchAvailableVersions(for: filtered)

        var updates = [(package: String, url: String, current: Version, target: Version)]()
        for (package, availableVersions) in versions {
            guard let current = package.version else { continue }
            if let target = scope.targetVersion(current: current, available: availableVersions, ignoringPrerelease: ignoringPrerelease) {
                updates.append((package: package.package, url: package.repositoryURL, current: current, target: target))
            }
        }

        return updates.sorted { $0.package < $1.package }
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
        case manifestNotFound

        public var errorDescription: String? {
            switch self {
            case .notFound:
                return "No Package.resolved found in current working tree."
            case .notReadable:
                return "No Package.resolved read in current working tree."
            case .manifestNotFound:
                return "No Package.swift or .xcodeproj found in current working tree."
            }
        }
    }
}

import SwiftyTextTable
extension SwiftPackage: TextTableRepresentable {
    public static let columnHeaders = [
        "Package",
        "Current",
        "URL"
    ]

    public var tableValues: [CustomStringConvertible] {
        return [
            self.package,
            self.version ?? self.revision ?? "N/A",
            self.repositoryURL.blue
        ]
    }
}
