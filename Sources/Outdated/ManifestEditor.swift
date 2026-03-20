import Foundation
import Version

public enum ManifestEditor {

    // MARK: - Package.swift

    /// Edit a Package.swift manifest, updating the version constraint for the given repository URL.
    /// Returns the modified manifest, or nil if the URL was not found.
    public static func updatePackageSwift(manifest: String, repositoryURL: String, newVersion: Version) -> String? {
        // Build a pattern that matches the repository URL with optional .git suffix, case-insensitive
        let urlPattern = Self.urlPattern(for: repositoryURL)

        // Patterns we support:
        //   .package(url: "URL", from: "X.Y.Z")
        //   .package(url: "URL", .upToNextMajor(from: "X.Y.Z"))
        //   .package(url: "URL", .upToNextMinor(from: "X.Y.Z"))
        //   .package(url: "URL", exact: "X.Y.Z")
        let patterns: [String] = [
            // from: "X.Y.Z"
            #"(\.package\s*\(\s*url\s*:\s*""# + urlPattern + #""\s*,\s*from\s*:\s*")\d+\.\d+\.\d+(")"#,
            // .upToNextMajor(from: "X.Y.Z")
            #"(\.package\s*\(\s*url\s*:\s*""# + urlPattern + #""\s*,\s*\.upToNextMajor\s*\(\s*from\s*:\s*")\d+\.\d+\.\d+("\s*\))"#,
            // .upToNextMinor(from: "X.Y.Z")
            #"(\.package\s*\(\s*url\s*:\s*""# + urlPattern + #""\s*,\s*\.upToNextMinor\s*\(\s*from\s*:\s*")\d+\.\d+\.\d+("\s*\))"#,
            // exact: "X.Y.Z"
            #"(\.package\s*\(\s*url\s*:\s*""# + urlPattern + #""\s*,\s*exact\s*:\s*")\d+\.\d+\.\d+(")"#,
        ]

        let versionString = "\(newVersion.major).\(newVersion.minor).\(newVersion.patch)"

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(manifest.startIndex..., in: manifest)
            let result = regex.stringByReplacingMatches(
                in: manifest,
                range: range,
                withTemplate: "$1" + versionString + "$2"
            )
            if result != manifest {
                return result
            }
        }

        return nil
    }

    // MARK: - .pbxproj

    /// Edit a .pbxproj file, updating the version for the given repository URL.
    /// Returns the modified content, or nil if the URL was not found.
    public static func updatePbxproj(manifest: String, repositoryURL: String, newVersion: Version) -> String? {
        let urlPattern = Self.urlPattern(for: repositoryURL)
        let versionString = "\(newVersion.major).\(newVersion.minor).\(newVersion.patch)"

        // Match an XCRemoteSwiftPackageReference block containing our URL and a requirement block.
        // We need to find the block, then replace the version within it.
        //
        // Pattern:
        //   repositoryURL = "URL";
        //   requirement = {
        //       kind = upToNextMajorVersion;
        //       minimumVersion = X.Y.Z;
        //   };
        //
        // Kinds: upToNextMajorVersion, upToNextMinorVersion use minimumVersion
        //        exactVersion uses version

        // First, find all ranges of blocks that contain our URL
        let blockPattern = #"repositoryURL\s*=\s*""# + urlPattern + #""\s*;[\s\S]*?requirement\s*=\s*\{[^}]*\}\s*;"#
        guard let blockRegex = try? NSRegularExpression(pattern: blockPattern, options: [.caseInsensitive]) else {
            return nil
        }

        let fullRange = NSRange(manifest.startIndex..., in: manifest)
        guard let blockMatch = blockRegex.firstMatch(in: manifest, range: fullRange) else {
            return nil
        }

        guard let blockRange = Range(blockMatch.range, in: manifest) else {
            return nil
        }

        let block = String(manifest[blockRange])

        // Within the block, replace minimumVersion or version
        let versionPatterns: [(String, String)] = [
            (#"(minimumVersion\s*=\s*)\d+\.\d+\.\d+(\s*;)"#, "$1" + versionString + "$2"),
            (#"(version\s*=\s*)\d+\.\d+\.\d+(\s*;)"#, "$1" + versionString + "$2"),
        ]

        for (pattern, template) in versionPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let blockNSRange = NSRange(block.startIndex..., in: block)
            let updatedBlock = regex.stringByReplacingMatches(
                in: block,
                range: blockNSRange,
                withTemplate: template
            )
            if updatedBlock != block {
                var result = manifest
                result.replaceSubrange(blockRange, with: updatedBlock)
                return result
            }
        }

        return nil
    }

    // MARK: - Helpers

    /// Build a regex pattern that matches a repository URL, tolerating .git suffix and case differences.
    private static func urlPattern(for repositoryURL: String) -> String {
        // Remove trailing .git if present, then escape for regex, then allow optional .git
        let base = repositoryURL
            .replacingOccurrences(of: ".git", with: "", options: [.backwards, .anchored])
        let escaped = NSRegularExpression.escapedPattern(for: base)
        return escaped + #"(?:\.git)?"#
    }
}
