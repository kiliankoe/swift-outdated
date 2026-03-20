import Foundation
import Files
import Version
import ShellOut
import Logging
import SwiftyTextTable

public struct PackageUpdater: Sendable {

    public enum ProjectType: Sendable {
        case spm(packageSwiftPath: String)
        case xcode(pbxprojPath: String)
    }

    public struct UpdateResult: Sendable {
        public let package: String
        public let url: String
        public let previousVersion: Version
        public let targetVersion: Version
        public let status: Status

        public enum Status: Sendable {
            case updated
            case wouldUpdate
            case notFoundInManifest
        }
    }

    /// Detect the project type from the given folder.
    public static func detectProjectType(in folder: Folder) -> ProjectType? {
        if folder.containsFile(named: "Package.swift") {
            let path = folder.url.appendingPathComponent("Package.swift").path
            return .spm(packageSwiftPath: path)
        }

        let xcodeProjects = folder.subfolders.filter { $0.name.hasSuffix(".xcodeproj") }
        if let xcodeProject = xcodeProjects.first {
            let pbxprojPath = xcodeProject.url.appendingPathComponent("project.pbxproj").path
            if FileManager.default.fileExists(atPath: pbxprojPath) {
                return .xcode(pbxprojPath: pbxprojPath)
            }
        }

        return nil
    }

    /// Run the full update flow.
    public static func update(
        in folder: Folder,
        packages: [(package: String, url: String, current: Version, target: Version)],
        dryRun: Bool
    ) throws -> [UpdateResult] {
        guard let projectType = detectProjectType(in: folder) else {
            throw SwiftPackage.Error.manifestNotFound
        }

        let manifestPath: String
        switch projectType {
        case .spm(let path):
            manifestPath = path
        case .xcode(let path):
            manifestPath = path
        }

        var manifest = try String(contentsOfFile: manifestPath, encoding: .utf8)
        var results: [UpdateResult] = []

        for pkg in packages {
            let edited: String?
            switch projectType {
            case .spm:
                edited = ManifestEditor.updatePackageSwift(
                    manifest: manifest,
                    repositoryURL: pkg.url,
                    newVersion: pkg.target
                )
            case .xcode:
                edited = ManifestEditor.updatePbxproj(
                    manifest: manifest,
                    repositoryURL: pkg.url,
                    newVersion: pkg.target
                )
            }

            if let edited = edited {
                manifest = edited
                results.append(UpdateResult(
                    package: pkg.package,
                    url: pkg.url,
                    previousVersion: pkg.current,
                    targetVersion: pkg.target,
                    status: dryRun ? .wouldUpdate : .updated
                ))
            } else {
                results.append(UpdateResult(
                    package: pkg.package,
                    url: pkg.url,
                    previousVersion: pkg.current,
                    targetVersion: pkg.target,
                    status: .notFoundInManifest
                ))
            }
        }

        let hasEdits = results.contains { $0.status == .updated }
        if !dryRun && hasEdits {
            let originalManifest = try String(contentsOfFile: manifestPath, encoding: .utf8)
            try manifest.write(toFile: manifestPath, atomically: true, encoding: .utf8)

            do {
                switch projectType {
                case .spm:
                    log.info("Running swift package update...")
                    try shellOut(to: "swift", arguments: ["package", "update"], at: folder.path)
                case .xcode:
                    log.info("Running xcodebuild -resolvePackageDependencies...")
                    try shellOut(to: "xcodebuild", arguments: ["-resolvePackageDependencies"], at: folder.path)
                }
            } catch {
                log.info("Dependency resolution failed, restoring original manifest...")
                try originalManifest.write(toFile: manifestPath, atomically: true, encoding: .utf8)
                throw error
            }
        }

        return results
    }

    /// Render update results as a markdown table.
    public static func printResults(_ results: [UpdateResult]) {
        guard !results.isEmpty else { return }
        var table = TextTable(objects: results)
        table.cornerFence = "|"
        let rendered = table.render()
            .components(separatedBy: "\n")
            .dropFirst()
            .dropLast(1)
            .joined(separator: "\n")
        print(rendered)
    }
}

extension PackageUpdater.UpdateResult: TextTableRepresentable {
    public static let columnHeaders = ["Package", "Current", "Target", "Status"]

    public var tableValues: [CustomStringConvertible] {
        let statusString: String
        switch status {
        case .updated: statusString = "Updated"
        case .wouldUpdate: statusString = "Would update"
        case .notFoundInManifest: statusString = "Not found in manifest"
        }
        return [package, previousVersion.description, targetVersion.description, statusString]
    }
}
