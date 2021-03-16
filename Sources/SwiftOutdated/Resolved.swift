import Foundation
import Files

struct Resolved: Decodable {
    let object: Object
    let version: Int

    struct Object: Decodable {
        let pins: [Pin]
    }

    static func read() throws -> Resolved {
        if let rootResolved = try? File(path: "Package.resolved") {
            return try JSONDecoder().decode(Resolved.self, from: try rootResolved.read())
        } else if let rootResolved = try? File(path: ".package.resolved") {
            return try JSONDecoder().decode(Resolved.self, from: try rootResolved.read())
        }

        if let xcodeWorkspace = Folder.current.subfolders.first(where: { $0.name.hasSuffix("xcworkspace") }) {
            let resolvedPath = "xcshareddata/swiftpm/Package.resolved"
            guard xcodeWorkspace.containsFile(at: resolvedPath) else {
                throw Error.notFound
            }
            let xcodeResolved = try File(path: xcodeWorkspace.path + resolvedPath)
            return try JSONDecoder().decode(Resolved.self, from: try xcodeResolved.read())
        }

        if let xcodeProject = Folder.current.subfolders.first(where: { $0.name.hasSuffix("xcodeproj") }) {
            let resolvedPath = "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
            guard xcodeProject.containsFile(at: resolvedPath) else {
                print(xcodeProject.path)
                print(resolvedPath)
                throw Error.notFound
            }
            let xcodeResolved = try File(path: xcodeProject.path + resolvedPath)
            return try JSONDecoder().decode(Resolved.self, from: try xcodeResolved.read())
        }

        throw Error.notFound
    }
}

extension Resolved {
    enum Error: Swift.Error, LocalizedError {
        case notFound

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "No Package.resolved found in current working tree."
            }
        }
    }
}
