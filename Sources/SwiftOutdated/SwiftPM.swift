import Foundation
import ShellOut
import Files

struct SwiftPM {
    let manifest: Manifest

    init() throws {
        let json = try shellOut(to: "swift", arguments: ["package", "dump-package"])
        self.manifest = try JSONDecoder().decode(Manifest.self, from: json.data(using: .utf8)!)

    }

    func fetchDependencyUpdates() throws {
        for dependency in manifest.dependencies {
            try dependency.fetchRepository()
        }
    }
}
