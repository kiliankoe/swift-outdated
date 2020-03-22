import Foundation
import ShellOut
import Files

struct SwiftPM {
    let manifest: Manifest
    let resolved: Resolved

    init() throws {
        let json = try shellOut(to: "swift", arguments: ["package", "dump-package"])
        self.manifest = try JSONDecoder().decode(Manifest.self, from: json.data(using: .utf8)!)

        self.resolved = try Resolved.read()
    }

    func fetchDependencyUpdates() throws {
        for dependency in manifest.dependencies {
            try dependency.fetchRepository()
        }
    }

    func output() -> [DependencyOutput] {
        manifest.dependencies.map { dep in
            let current = self.resolved.object.pins.first { $0.package.lowercased() == dep.packageName.lowercased() }
            let isOutdated = try? dep.requirementIsOutdated()
            let latestVersion = try? dep.availableVersions().last?.description

            return DependencyOutput(
                name: dep.packageName,
                requirement: dep.requirement.tableText,
                current: current?.state.description ?? "n/a",
                latest: latestVersion ?? "n/a",
                hasUpdate: isOutdated ?? false)
        }
    }
}
