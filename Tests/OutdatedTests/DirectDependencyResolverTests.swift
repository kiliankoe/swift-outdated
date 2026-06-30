import Testing
import Foundation
@testable import Outdated

@Suite("DirectDependencyResolver Tests")
struct DirectDependencyResolverTests {

    init() {
        initializeTestLogging()
    }

    // MARK: - swift package dump-package

    @Test("Parses remote URLs from dump-package JSON")
    func parsesDumpPackageURLs() {
        let json = """
        {
          "dependencies": [
            {"sourceControl": [{"identity": "swift-log",
              "location": {"remote": [{"urlString": "https://github.com/apple/swift-log.git"}]}}]},
            {"sourceControl": [{"identity": "rainbow",
              "location": {"remote": [{"urlString": "https://github.com/onevcat/Rainbow.git"}]}}]}
          ]
        }
        """
        let urls = DirectDependencyResolver.parseDumpPackageURLs(Data(json.utf8))
        #expect(urls == [
            "github.com/apple/swift-log",
            "github.com/onevcat/rainbow",
        ])
    }

    @Test("Local (fileSystem) dependencies are excluded — they carry no remote URL")
    func excludesLocalDependencies() {
        let json = """
        {
          "dependencies": [
            {"sourceControl": [{"identity": "rainbow",
              "location": {"remote": [{"urlString": "https://github.com/onevcat/Rainbow.git"}]}}]},
            {"fileSystem": [{"identity": "local-pkg", "path": "/some/local/path"}]}
          ]
        }
        """
        let urls = DirectDependencyResolver.parseDumpPackageURLs(Data(json.utf8))
        #expect(urls == ["github.com/onevcat/rainbow"])
    }

    @Test("Malformed dump-package JSON yields nil, not an empty set")
    func malformedJSONYieldsNil() {
        #expect(DirectDependencyResolver.parseDumpPackageURLs(Data("not json".utf8)) == nil)
    }

    // MARK: - project.pbxproj

    @Test("Parses and dedupes repository URLs from pbxproj remote references")
    func parsesPbxprojURLs() {
        // SSH and HTTPS forms of the same repo must collapse to one normalized entry.
        let pbxproj = """
        /* Begin XCRemoteSwiftPackageReference section */
            ABC /* XCRemoteSwiftPackageReference "Alamofire" */ = {
                isa = XCRemoteSwiftPackageReference;
                repositoryURL = "https://github.com/Alamofire/Alamofire.git";
                requirement = { kind = upToNextMajorVersion; minimumVersion = 5.0.0; };
            };
            DEF /* XCRemoteSwiftPackageReference "Rainbow" */ = {
                isa = XCRemoteSwiftPackageReference;
                repositoryURL = "git@github.com:onevcat/Rainbow.git";
                requirement = { kind = upToNextMajorVersion; minimumVersion = 3.2.0; };
            };
        /* End XCRemoteSwiftPackageReference section */
        """
        let urls = DirectDependencyResolver.parsePbxprojURLs(pbxproj)
        #expect(urls == [
            "github.com/alamofire/alamofire",
            "github.com/onevcat/rainbow",
        ])
    }

    @Test("A pbxproj with no remote references yields an empty set")
    func pbxprojWithoutRemotesYieldsEmpty() {
        #expect(DirectDependencyResolver.parsePbxprojURLs("// no package references here") == [])
    }
}
