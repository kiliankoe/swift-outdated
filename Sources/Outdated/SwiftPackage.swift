import Foundation
import Files
import Rainbow
import ShellOut
import Version
import Logging

public struct SwiftPackage: Hashable {
    public let package: String
    public let repositoryURL: String
    public let revision: String?
    public let version: Version?
}

extension SwiftPackage: Encodable {}

extension SwiftPackage {
    public var hasResolvedVersion: Bool {
        self.version != nil
    }
    
    public func availableVersions() -> [Version] {
        do {
            log.trace("Running git ls-remote for \(self.package).")
            let lsRemote = try shellOut(
                to: "git",
                arguments: ["ls-remote", "--tags", self.repositoryURL]
            )
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
