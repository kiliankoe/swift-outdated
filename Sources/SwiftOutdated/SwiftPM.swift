import Foundation
import ShellOut
import Files
import Version

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
            let requirementIsOutdated = try? dep.requirementIsOutdated()
            let latestVersion = try? dep.availableVersions().last

            var currentIsOutdated = false
            if let currentVersionStr = current?.state.version,
                let currentVersion = Version(currentVersionStr),
                let latestVersion = latestVersion
            {
                currentIsOutdated = currentVersion < latestVersion
            }

            return DependencyOutput(
                name: dep.packageName,
                requirement: dep.requirement.tableText,
                current: current?.state.description ?? "n/a",
                latest: latestVersion?.description ?? "n/a",
                requirementIsOutdated: requirementIsOutdated ?? false,
                currentIsOutdated: currentIsOutdated)
        }
    }
}
