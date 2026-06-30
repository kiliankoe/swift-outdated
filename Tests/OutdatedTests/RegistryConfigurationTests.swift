import Testing
import Files
import Foundation
@testable import Outdated

@Suite("Registry Configuration Tests")
struct RegistryConfigurationTests {

    init() {
        initializeTestLogging()
    }

    private func projectFolder(withRegistriesJSON json: String) throws -> Folder {
        let folder = try Folder.temporary.createSubfolder(named: "swift-outdated-tests-\(UUID().uuidString)")
        let configDir = try folder.createSubfolder(at: ".swiftpm/configuration")
        try configDir.createFile(named: "registries.json").write(json)
        return folder
    }

    @Test("The [default] registry resolves for any scope")
    func defaultRegistry() throws {
        let folder = try projectFolder(withRegistriesJSON: """
        { "registries": { "[default]": { "url": "https://default.example.com" } }, "version": 1 }
        """)
        defer { try? folder.delete() }

        let url = RegistryConfiguration.baseURL(forScope: "mona", projectPath: folder.path)
        #expect(url?.absoluteString == "https://default.example.com")
    }

    @Test("A scope-specific registry overrides the default")
    func scopeOverridesDefault() throws {
        let folder = try projectFolder(withRegistriesJSON: """
        {
          "registries": {
            "[default]": { "url": "https://default.example.com" },
            "mona": { "url": "https://mona.example.com" }
          },
          "version": 1
        }
        """)
        defer { try? folder.delete() }

        #expect(RegistryConfiguration.baseURL(forScope: "mona", projectPath: folder.path)?.absoluteString
                == "https://mona.example.com")
        // A scope without its own entry still falls back to the default.
        #expect(RegistryConfiguration.baseURL(forScope: "example", projectPath: folder.path)?.absoluteString
                == "https://default.example.com")
    }

    @Test("No configuration yields nil")
    func missingConfiguration() throws {
        let folder = try Folder.temporary.createSubfolder(named: "swift-outdated-tests-\(UUID().uuidString)")
        defer { try? folder.delete() }

        #expect(RegistryConfiguration.baseURL(forScope: "mona", projectPath: folder.path) == nil)
    }
}
