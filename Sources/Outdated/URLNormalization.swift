import Foundation

/// Normalize a repository URL for comparison, e.g.
/// `git@github.com:user/repo.git` and `https://github.com/user/repo` both → `github.com/user/repo`.
func normalizeRepositoryURL(_ url: String) -> String {
    var normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)

    // SSH shorthand: git@host:owner/repo → host/owner/repo
    if normalized.hasPrefix("git@") {
        normalized = String(normalized.dropFirst(4))
        if let colonIndex = normalized.firstIndex(of: ":") {
            normalized = String(normalized[..<colonIndex]) + "/" + String(normalized[normalized.index(after: colonIndex)...])
        }
    }

    if let protocolRange = normalized.range(of: "://") {
        normalized = String(normalized[protocolRange.upperBound...])
    }

    if normalized.hasSuffix(".git") {
        normalized = String(normalized.dropLast(4))
    }

    if normalized.hasSuffix("/") {
        normalized = String(normalized.dropLast())
    }

    return normalized.lowercased()
}
