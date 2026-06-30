import Files
import Foundation
import ShellOut

/// Locates the local package checkouts that SwiftPM (`.build/checkouts`) or Xcode
/// (`SourcePackages/checkouts`) already create, so ref/branch-pinned dependencies can be analyzed
/// against a real clone without cloning anything ourselves. Purely best-effort: when nothing is
/// found it simply yields no roots and callers fall back to the existing "ignored" behavior.
public struct CheckoutLocator: Sendable {
    let projectFolderPath: String
    let explicitPath: String?

    public init(projectFolder: Folder, explicitPath: String? = nil) {
        self.projectFolderPath = projectFolder.path
        self.explicitPath = explicitPath
    }

    public init(projectFolderPath: String, explicitPath: String? = nil) {
        self.projectFolderPath = projectFolderPath
        self.explicitPath = explicitPath
    }

    /// Path to the checkout for the given package, or `nil` if no validated checkout exists.
    public func findCheckout(for identity: String, repositoryURL: String) -> String? {
        let roots = getCheckoutRoots()

        // Fast path: SwiftPM usually names the checkout dir after the repo's last path component,
        // which typically equals the identity. Match by name, then confirm via origin URL.
        for root in roots {
            if let match = root.subfolders.first(where: { $0.name.lowercased() == identity.lowercased() }),
               validateCheckout(at: match.path, expectedURL: repositoryURL) {
                return match.path
            }
        }

        // Fallback: the dir name can diverge from the identity, so match purely by validated origin URL.
        for root in roots {
            for subfolder in root.subfolders where validateCheckout(at: subfolder.path, expectedURL: repositoryURL) {
                return subfolder.path
            }
        }

        return nil
    }

    /// Search order:
    /// 1. Explicit `--checkouts-path` if provided (replaces all auto-detection — sole root)
    /// 2. `.build/checkouts` (SwiftPM)
    /// 3. `SourcePackages/checkouts` (Xcode), incl. inside a sibling `.xcodeproj`/`.xcworkspace`
    public func getCheckoutRoots() -> [Folder] {
        guard let projectFolder = try? Folder(path: projectFolderPath) else {
            return []
        }

        // An explicit path replaces auto-detection entirely.
        if let explicit = explicitPath {
            if let folder = try? Folder(path: explicit) {
                return [folder]
            }
            return []
        }

        var roots: [Folder] = []

        if let swiftpmCheckouts = try? projectFolder.subfolder(at: ".build/checkouts") {
            roots.append(swiftpmCheckouts)
        }

        if let xcodeCheckouts = try? projectFolder.subfolder(at: "SourcePackages/checkouts") {
            roots.append(xcodeCheckouts)
        }

        let xcodeProjects = projectFolder.subfolders.filter {
            $0.name.hasSuffix(".xcodeproj") || $0.name.hasSuffix(".xcworkspace")
        }
        for project in xcodeProjects {
            let parentFolder = project.parent ?? projectFolder
            if let xcodeCheckouts = try? parentFolder.subfolder(at: "SourcePackages/checkouts"),
               !roots.contains(where: { $0.path == xcodeCheckouts.path }) {
                roots.append(xcodeCheckouts)
            }
        }

        return roots
    }

    public func hasCheckoutsAvailable() -> Bool {
        !getCheckoutRoots().isEmpty
    }

    private func validateCheckout(at path: String, expectedURL: String) -> Bool {
        do {
            let originURL = try shellOut(to: "git", arguments: ["-C", path, "remote", "get-url", "origin"])

            // SwiftPM/Xcode checkouts point at a local bare mirror (`.build/repositories/…` or
            // `SourcePackages/repositories/…`); follow that one more hop to the real remote.
            if originURL.contains(".build/repositories/") || originURL.contains("SourcePackages/repositories/") {
                let bareRepoOrigin = try shellOut(
                    to: "git",
                    arguments: ["-C", originURL.trimmingCharacters(in: .whitespacesAndNewlines), "remote", "get-url", "origin"]
                )
                return normalizeURL(bareRepoOrigin) == normalizeURL(expectedURL)
            }

            return normalizeURL(originURL) == normalizeURL(expectedURL)
        } catch {
            log.trace("Failed to get origin URL for \(path): \(error)")
            return false
        }
    }
}

extension CheckoutLocator {
    /// Normalize a repository URL for comparison, e.g.
    /// `git@github.com:user/repo.git` and `https://github.com/user/repo` both → `github.com/user/repo`.
    func normalizeURL(_ url: String) -> String {
        normalizeRepositoryURL(url)
    }
}
