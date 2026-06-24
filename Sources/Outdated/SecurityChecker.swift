import Foundation

public struct SecurityInfo: Sendable {
    public enum OSVStatus: Sendable {
        case safe
        case vulnerable(count: Int, ids: [String])
        case unknown
    }

    public let osvStatus: OSVStatus
    public let scorecardScore: Double?
}

public struct SecurityPair: Sendable {
    public let current: SecurityInfo
    public let latest: SecurityInfo
}

public enum SecurityChecker {
    public static func check(
        packages: [(name: String, url: String, currentVersion: String, latestVersion: String)]
    ) async -> [String: SecurityPair] {
        await withTaskGroup(of: (String, SecurityPair).self) { group in
            for pkg in packages {
                group.addTask {
                    let pair = await checkPackage(url: pkg.url, currentVersion: pkg.currentVersion, latestVersion: pkg.latestVersion)
                    return (pkg.name, pair)
                }
            }
            var results = [String: SecurityPair]()
            for await (name, pair) in group {
                results[name] = pair
            }
            return results
        }
    }

    private static func checkPackage(url: String, currentVersion: String, latestVersion: String) async -> SecurityPair {
        async let currentOSV = checkOSV(url: url, version: currentVersion)
        async let latestOSV = checkOSV(url: url, version: latestVersion)
        async let score = checkScorecard(url: url)
        let (c, l, s) = await (currentOSV, latestOSV, score)
        return SecurityPair(
            current: SecurityInfo(osvStatus: c, scorecardScore: s),
            latest: SecurityInfo(osvStatus: l, scorecardScore: s)
        )
    }

    // MARK: - OSV

    private static func checkOSV(url: String, version: String) async -> SecurityInfo.OSVStatus {
        guard let packageName = osvPackageName(from: url) else { return .unknown }

        let body: [String: Any] = [
            "package": ["ecosystem": "SwiftURL", "name": packageName],
            "version": version
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body),
              let endpoint = URL(string: "https://api.osv.dev/v1/query") else { return .unknown }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        guard let (responseData, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return .unknown
        }

        guard let vulns = json["vulns"] as? [[String: Any]], !vulns.isEmpty else {
            return .safe
        }

        let ids = vulns.compactMap { $0["id"] as? String }
        return .vulnerable(count: vulns.count, ids: ids)
    }

    // Normalise a repository URL to the "host/owner/repo" form OSV expects.
    // e.g. "https://github.com/apple/swift-argument-parser.git" → "github.com/apple/swift-argument-parser"
    static func osvPackageName(from url: String) -> String? {
        var s = url
        if s.hasSuffix(".git") { s = String(s.dropLast(4)) }
        guard let parsed = URL(string: s),
              let host = parsed.host else { return nil }
        let path = parsed.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty else { return nil }
        return "\(host)/\(path)"
    }

    // MARK: - OpenSSF Scorecard

    private static func checkScorecard(url: String) async -> Double? {
        guard let project = scorecardProject(from: url),
              let endpoint = URL(string: "https://api.securityscorecards.dev/projects/\(project)") else {
            return nil
        }

        guard let (data, _) = try? await URLSession.shared.data(from: endpoint),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let score = json["score"] as? Double else {
            return nil
        }

        return score
    }

    // Extracts "github.com/owner/repo" for Scorecard (only GitHub repos are supported).
    static func scorecardProject(from url: String) -> String? {
        var s = url
        if s.hasSuffix(".git") { s = String(s.dropLast(4)) }
        guard let parsed = URL(string: s),
              let host = parsed.host,
              host.lowercased() == "github.com" else { return nil }
        let path = parsed.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = path.split(separator: "/")
        guard components.count >= 2 else { return nil }
        return "github.com/\(components[0])/\(components[1])"
    }
}
