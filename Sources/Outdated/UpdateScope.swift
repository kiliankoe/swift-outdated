import Version

public enum UpdateScope: String, Sendable, CaseIterable {
    case patch
    case minor
    case major

    /// Returns the best target version for the given scope, or nil if already up to date.
    public func targetVersion(current: Version, available: [Version], ignoringPrerelease: Bool) -> Version? {
        var candidates = available

        if ignoringPrerelease {
            candidates = candidates.filter { $0.prereleaseIdentifiers.isEmpty }
        }

        switch self {
        case .patch:
            candidates = candidates.filter { $0.major == current.major && $0.minor == current.minor }
        case .minor:
            candidates = candidates.filter { $0.major == current.major }
        case .major:
            break
        }

        guard let best = candidates.last, best > current else {
            return nil
        }
        return best
    }
}
