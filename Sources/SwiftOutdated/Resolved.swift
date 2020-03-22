import Foundation
import Files

struct Resolved: Decodable {
    let object: Object
    let version: Int

    struct Object: Decodable {
        let pins: [Pin]

        struct Pin: Decodable {
            let package: String
            let repositoryURL: String
            let state: State

            struct State: Decodable {
                let branch: String?
                let revision: String
                let version: String?

                var description: String {
                    version ?? branch ?? revision
                }
            }
        }
    }

    static func read() throws -> Resolved {
        let packageResolved = try File(path: "Package.resolved")
        return try JSONDecoder().decode(Resolved.self, from: try packageResolved.read())
    }
}
