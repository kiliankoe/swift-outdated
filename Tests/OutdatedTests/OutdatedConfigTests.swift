import Testing
@testable import Outdated

@Suite("OutdatedConfig Tests")
struct OutdatedConfigTests {

    init() {
        initializeTestLogging()
    }

    @Test("Parses fork mappings from YAML")
    func parsesForkMappings() throws {
        let yaml = """
        forks:
          - fork: https://github.com/mycompany/SomeLib.git
            upstream: https://github.com/original/SomeLib.git
          - fork: https://github.com/mycompany/Other.git
            upstream: https://github.com/original/Other.git
        """
        let config = try OutdatedConfig.parse(yaml)
        #expect(config.forks.count == 2)
        #expect(config.forks.first?.fork == "https://github.com/mycompany/SomeLib.git")
        #expect(config.forks.first?.upstream == "https://github.com/original/SomeLib.git")
    }

    @Test("Fork keys are normalized; upstreams are kept verbatim")
    func forkUpstreamMapNormalizesKeys() throws {
        // SSH and a .git suffix must collapse to the same key a resolved pin normalizes to.
        let yaml = """
        forks:
          - fork: git@github.com:mycompany/SomeLib.git
            upstream: https://github.com/original/SomeLib.git
        """
        let map = try OutdatedConfig.parse(yaml).forkUpstreamMap()
        #expect(map == ["github.com/mycompany/somelib": "https://github.com/original/SomeLib.git"])
    }

    @Test("An absent forks key yields an empty map")
    func emptyConfigYieldsEmptyMap() throws {
        #expect(try OutdatedConfig.parse("{}").forkUpstreamMap().isEmpty)
    }

    @Test("Malformed YAML throws")
    func malformedYAMLThrows() {
        #expect(throws: (any Error).self) {
            try OutdatedConfig.parse("forks: [this is: not valid")
        }
    }
}
