import Testing
import Version
import Foundation
@testable import Outdated

@Suite("Outdated Package Tests")
struct OutdatedPackageTests {

    init() {
        initializeTestLogging()
    }

    @Test("Normal package display")
    func normalPackageDisplay() {
        let package = OutdatedPackage(
            package: "TestPackage",
            currentVersion: Version(1, 0, 0),
            latestVersion: Version(2, 0, 0),
            url: "https://github.com/example/test.git"
        )

        let tableValues = package.tableValues

        #expect(tableValues[0] as? String == "TestPackage")
        #expect(tableValues[1] as? String == "1.0.0")
        // We can't easily test the colored output, but we can verify structure
        #expect(tableValues[2] is String) // Latest version (potentially colored)
        #expect(tableValues[3] is String) // URL (potentially colored)
    }

    @Test("Encodable support")
    func encodableSupport() {
        let package = OutdatedPackage(
            package: "EncodableTest",
            currentVersion: Version(1, 0, 0),
            latestVersion: Version(2, 0, 0),
            url: "https://github.com/example/encodable.git"
        )

        do {
            _ = try JSONEncoder().encode(package)
        } catch {
            #expect(Bool(false), "JSONEncoder should not throw: \(error)")
        }

        let data = try! JSONEncoder().encode(package)
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["package"] as? String == "EncodableTest")
        #expect(json["currentVersion"] as? String == "1.0.0")
        #expect(json["latestVersion"] as? String == "2.0.0")
        #expect(json["url"] as? String == "https://github.com/example/encodable.git")
    }
}
