import Foundation
@testable import Outdated

public class MockGitRemoteProvider: GitRemoteProvider {
    private var tagRefsResponses: [String: String] = [:]

    public init() {}

    public func setTagRefsResponse(for repositoryURL: String, response: String) {
        tagRefsResponses[repositoryURL] = response
    }

    public func getRemoteTags(repositoryURL: String) throws -> String {
        guard let response = tagRefsResponses[repositoryURL] else {
            throw MockError.noResponseConfigured(repositoryURL: repositoryURL, type: "tags")
        }
        return response
    }
}

public enum MockError: Error, LocalizedError {
    case noResponseConfigured(repositoryURL: String, type: String)

    public var errorDescription: String? {
        switch self {
        case .noResponseConfigured(let repositoryURL, let type):
            return "No mock response configured for \(type) at \(repositoryURL)"
        }
    }
}
