import Foundation

struct PinV1: Decodable {
    let package: String
    let repositoryURL: String
    let state: State

    struct State: Decodable {
        let branch: String?
        let revision: String
        let version: String?
    }
}

struct PinV2: Decodable {
    let identity: String
    // "remoteSourceControl", "localSourceControl" or "registry". Registry pins carry no location.
    let kind: String?
    let location: String?
    let state: State

    struct State: Decodable {
        let branch: String?
        let revision: String?
        let version: String?
    }
}
