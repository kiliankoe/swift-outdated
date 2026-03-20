import Testing
import Version
@testable import Outdated

@Suite("UpdateScope Tests")
struct UpdateScopeTests {

    // MARK: - Patch scope

    @Test("Patch scope returns latest patch version")
    func patchScopeLatestPatch() {
        let current = Version(1, 2, 3)
        let available = [
            Version(1, 2, 3),
            Version(1, 2, 4),
            Version(1, 2, 9),
            Version(1, 3, 0),
            Version(2, 0, 0),
        ]
        let target = UpdateScope.patch.targetVersion(current: current, available: available, ignoringPrerelease: false)
        #expect(target == Version(1, 2, 9))
    }

    @Test("Patch scope returns nil when already at latest patch")
    func patchScopeAlreadyLatest() {
        let current = Version(1, 2, 9)
        let available = [
            Version(1, 2, 3),
            Version(1, 2, 9),
            Version(1, 3, 0),
        ]
        let target = UpdateScope.patch.targetVersion(current: current, available: available, ignoringPrerelease: false)
        #expect(target == nil)
    }

    // MARK: - Minor scope

    @Test("Minor scope returns latest minor version")
    func minorScopeLatestMinor() {
        let current = Version(1, 2, 3)
        let available = [
            Version(1, 2, 3),
            Version(1, 2, 9),
            Version(1, 5, 0),
            Version(2, 0, 0),
            Version(3, 0, 0),
        ]
        let target = UpdateScope.minor.targetVersion(current: current, available: available, ignoringPrerelease: false)
        #expect(target == Version(1, 5, 0))
    }

    @Test("Minor scope returns nil when already at latest minor")
    func minorScopeAlreadyLatest() {
        let current = Version(1, 5, 0)
        let available = [
            Version(1, 2, 3),
            Version(1, 5, 0),
            Version(2, 0, 0),
        ]
        let target = UpdateScope.minor.targetVersion(current: current, available: available, ignoringPrerelease: false)
        #expect(target == nil)
    }

    // MARK: - Major scope

    @Test("Major scope returns absolute latest version")
    func majorScopeAbsoluteLatest() {
        let current = Version(1, 2, 3)
        let available = [
            Version(1, 2, 3),
            Version(2, 0, 0),
            Version(3, 0, 0),
        ]
        let target = UpdateScope.major.targetVersion(current: current, available: available, ignoringPrerelease: false)
        #expect(target == Version(3, 0, 0))
    }

    @Test("Major scope returns nil when already at latest")
    func majorScopeAlreadyLatest() {
        let current = Version(3, 0, 0)
        let available = [
            Version(1, 0, 0),
            Version(2, 0, 0),
            Version(3, 0, 0),
        ]
        let target = UpdateScope.major.targetVersion(current: current, available: available, ignoringPrerelease: false)
        #expect(target == nil)
    }

    // MARK: - Prerelease filtering

    @Test("Prerelease versions are filtered when ignoringPrerelease is true")
    func prereleaseFiltering() {
        let current = Version(1, 0, 0)
        let available = [
            Version(1, 0, 0),
            Version(2, 0, 0),
            Version("3.0.0-beta1")!,
        ]
        let target = UpdateScope.major.targetVersion(current: current, available: available, ignoringPrerelease: true)
        #expect(target == Version(2, 0, 0))
    }

    @Test("Prerelease versions are included when ignoringPrerelease is false")
    func prereleaseIncluded() {
        let current = Version(1, 0, 0)
        let available = [
            Version(1, 0, 0),
            Version(2, 0, 0),
            Version("3.0.0-beta1")!,
        ]
        let target = UpdateScope.major.targetVersion(current: current, available: available, ignoringPrerelease: false)
        #expect(target == Version("3.0.0-beta1"))
    }

    // MARK: - Edge cases

    @Test("Empty available versions returns nil")
    func emptyAvailableVersions() {
        let current = Version(1, 0, 0)
        let target = UpdateScope.major.targetVersion(current: current, available: [], ignoringPrerelease: false)
        #expect(target == nil)
    }

    @Test("Only current version available returns nil")
    func onlyCurrentAvailable() {
        let current = Version(1, 0, 0)
        let available = [Version(1, 0, 0)]
        let target = UpdateScope.major.targetVersion(current: current, available: available, ignoringPrerelease: false)
        #expect(target == nil)
    }
}
