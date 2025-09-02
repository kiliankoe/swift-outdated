import Testing
import Version
import Files
import Foundation
@testable import Outdated

@Suite("Package Resolved Tests")
struct PackageResolvedTests {
    
    init() {
        initializeTestLogging()
    }

    @Test("Package.resolved v2 parsing")
    func packageResolvedV2Parsing() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "swift-outdated-tests-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        let resolvedContent = """
        {
          "pins" : [
            {
              "identity" : "rainbow",
              "kind" : "remoteSourceControl",
              "location" : "https://github.com/onevcat/Rainbow.git",
              "state" : {
                "revision" : "626c3d4b6b55354b4af3aa309f998fae9b31a3d9",
                "version" : "3.2.0"
              }
            },
            {
              "identity" : "swift-argument-parser",
              "kind" : "remoteSourceControl",
              "location" : "https://github.com/apple/swift-argument-parser.git",
              "state" : {
                "revision" : "9f39744e025c7d377987f30b03770805dcb0bcd1"
              }
            }
          ],
          "version" : 2
        }
        """
        
        let resolvedFile = try tempFolder.createFile(named: "Package.resolved")
        try resolvedFile.write(resolvedContent)

        let packages = try SwiftPackage.currentPackagePins(in: tempFolder)

        #expect(packages.count == 2)
        
        let rainbow = packages.first { $0.package == "rainbow" }
        #expect(rainbow != nil)
        #expect(rainbow?.repositoryURL == "https://github.com/onevcat/Rainbow.git")
        #expect(rainbow?.revision == "626c3d4b6b55354b4af3aa309f998fae9b31a3d9")
        #expect(rainbow?.version == Version(3, 2, 0))
        #expect(rainbow?.hasResolvedVersion == true)
        
        let argumentParser = packages.first { $0.package == "swift-argument-parser" }
        #expect(argumentParser != nil)
        #expect(argumentParser?.repositoryURL == "https://github.com/apple/swift-argument-parser.git")
        #expect(argumentParser?.revision == "9f39744e025c7d377987f30b03770805dcb0bcd1")
        #expect(argumentParser?.version == nil)
        #expect(argumentParser?.hasResolvedVersion == false)
    }
    
    @Test("Package.resolved v1 parsing")
    func packageResolvedV1Parsing() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "swift-outdated-tests-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        let resolvedContent = """
        {
          "object": {
            "pins": [
              {
                "package": "Rainbow",
                "repositoryURL": "https://github.com/onevcat/Rainbow.git",
                "state": {
                  "branch": null,
                  "revision": "626c3d4b6b55354b4af3aa309f998fae9b31a3d9",
                  "version": "3.2.0"
                }
              },
              {
                "package": "SwiftArgumentParser",
                "repositoryURL": "https://github.com/apple/swift-argument-parser.git",
                "state": {
                  "branch": null,
                  "revision": "9f39744e025c7d377987f30b03770805dcb0bcd1",
                  "version": null
                }
              }
            ]
          },
          "version": 1
        }
        """
        
        let resolvedFile = try tempFolder.createFile(named: "Package.resolved")
        try resolvedFile.write(resolvedContent)

        let packages = try SwiftPackage.currentPackagePins(in: tempFolder)

        #expect(packages.count == 2)
        
        let rainbow = packages.first { $0.package == "Rainbow" }
        #expect(rainbow != nil)
        #expect(rainbow?.repositoryURL == "https://github.com/onevcat/Rainbow.git")
        #expect(rainbow?.revision == "626c3d4b6b55354b4af3aa309f998fae9b31a3d9")
        #expect(rainbow?.version == Version(3, 2, 0))
    }
    
    @Test("Package.resolved Xcode workspace")
    func packageResolvedXcodeWorkspace() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "swift-outdated-tests-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        let workspace = try tempFolder.createSubfolder(named: "TestProject.xcworkspace")
        let xcshareddata = try workspace.createSubfolder(named: "xcshareddata")
        let swiftpm = try xcshareddata.createSubfolder(named: "swiftpm")
        
        let resolvedContent = """
        {
          "pins" : [
            {
              "identity" : "test-package",
              "kind" : "remoteSourceControl",
              "location" : "https://github.com/example/test-package.git",
              "state" : {
                "revision" : "abc123",
                "version" : "1.0.0"
              }
            }
          ],
          "version" : 2
        }
        """
        
        let resolvedFile = try swiftpm.createFile(named: "Package.resolved")
        try resolvedFile.write(resolvedContent)

        let packages = try SwiftPackage.currentPackagePins(in: tempFolder)

        #expect(packages.count == 1)
        #expect(packages[0].package == "test-package")
    }
    
    @Test("Package.resolved not found")
    func packageResolvedNotFound() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "swift-outdated-tests-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        #expect(throws: SwiftPackage.Error.self) {
            try SwiftPackage.currentPackagePins(in: tempFolder)
        }
    }
    
    @Test("Empty Package.resolved")
    func emptyPackageResolved() throws {
        let tempFolder = try Folder.temporary.createSubfolder(named: "swift-outdated-tests-\(UUID().uuidString)")
        defer { try? tempFolder.delete() }

        let resolvedContent = """
        {
          "pins" : [],
          "version" : 2
        }
        """
        
        let resolvedFile = try tempFolder.createFile(named: "Package.resolved")
        try resolvedFile.write(resolvedContent)

        let packages = try SwiftPackage.currentPackagePins(in: tempFolder)

        #expect(packages.count == 0)
    }
}
