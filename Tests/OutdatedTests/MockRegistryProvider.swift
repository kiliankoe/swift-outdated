import Foundation
@testable import Outdated

public final class MockRegistryProvider: RegistryProvider, @unchecked Sendable {
    private var responses: [String: Data] = [:]

    public init() {}

    public func setReleasesResponse(forIdentity identity: String, json: String) {
        responses[identity] = Data(json.utf8)
    }

    public func listReleases(identity: String) throws -> Data {
        guard let data = responses[identity] else {
            throw MockError.noResponseConfigured(repositoryURL: identity, type: "registry releases")
        }
        return data
    }
}
