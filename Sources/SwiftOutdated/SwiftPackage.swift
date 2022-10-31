import Foundation
import Files
import ShellOut
import Version

public struct SwiftPackage: Hashable {
    let package: String
    let repositoryURL: String
    let revision: String?
    let version: Version?
}

extension SwiftPackage: Encodable {}

extension SwiftPackage {
    var hasResolvedVersion: Bool {
        self.version != nil
    }
    
    func availableVersions() throws -> [Version] {
        let lsRemote = try shellOut(to: "git", arguments: ["ls-remote", "--tags", self.repositoryURL])
        return lsRemote
            .split(separator: "\n")
            .map {
                $0.split(separator: "\t")
                    .last!
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"refs\/tags\/(v(?=\d))?"#, with: "", options: .regularExpression)
            }
            .compactMap { Version($0) }
            .sorted()
    }
    
    static func currentPackagePins() throws -> [Self] {
        let file: File = try {
            
            if let rootResolved = try? File(path: "Package.resolved") {
                return rootResolved
            } else if let rootResolved = try? File(path: ".package.resolved") {
                return rootResolved
            }

            if let xcodeWorkspace = Folder.current.subfolders.first(where: { $0.name.hasSuffix("xcworkspace") }) {
                let resolvedPath = "xcshareddata/swiftpm/Package.resolved"
                guard xcodeWorkspace.containsFile(at: resolvedPath) else {
                    throw Error.notFound
                }
                return try File(path: xcodeWorkspace.path + resolvedPath)
            }

            if let xcodeProject = Folder.current.subfolders.first(where: { $0.name.hasSuffix("xcodeproj") }) {
                let resolvedPath = "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
                guard xcodeProject.containsFile(at: resolvedPath) else {
                    print(xcodeProject.path)
                    print(resolvedPath)
                    throw Error.notFound
                }
                return try File(path: xcodeProject.path + resolvedPath)
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
    
    enum Error: Swift.Error, LocalizedError {
        case notFound
        case notReadable
        
        var errorDescription: String? {
            switch self {
            case .notFound:
                return "No Package.resolved found in current working tree."
            case .notReadable:
                return "No Package.resolved read in current working tree."
            }
        }
    }
}
