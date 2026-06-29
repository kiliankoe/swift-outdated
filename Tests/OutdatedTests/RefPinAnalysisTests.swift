import Testing
import Version
@testable import Outdated

@Suite("Ref Pin Analysis Tests")
struct RefPinAnalysisTests {

    init() {
        initializeTestLogging()
    }

    @Test("Short revision truncates to 7 characters")
    func shortRevisionTruncation() {
        let analysis = RefPinAnalysis(
            package: "test-package",
            revision: "abc1234567890def",
            baseTag: Version(1, 0, 0),
            latestTag: Version(2, 0, 0),
            url: "https://github.com/test/repo"
        )
        #expect(analysis.shortRevision == "abc1234")
    }

    @Test("Current display with base tag")
    func currentDisplayWithBaseTag() {
        let analysis = RefPinAnalysis(
            package: "test-package",
            revision: "abc1234567890def",
            baseTag: Version(1, 2, 3),
            latestTag: Version(2, 0, 0),
            url: "https://github.com/test/repo"
        )
        #expect(analysis.currentDisplay == "abc1234 (v1.2.3)")
    }

    @Test("Current display without base tag")
    func currentDisplayWithoutBaseTag() {
        let analysis = RefPinAnalysis(
            package: "test-package",
            revision: "abc1234567890def",
            baseTag: nil,
            latestTag: Version(2, 0, 0),
            url: "https://github.com/test/repo"
        )
        #expect(analysis.currentDisplay == "abc1234")
    }

    @Test("Current display includes branch name")
    func currentDisplayWithBranch() {
        let analysis = RefPinAnalysis(
            package: "test-package",
            branch: "main",
            revision: "abc1234567890def",
            baseTag: Version(1, 2, 3),
            latestTag: Version(2, 0, 0),
            url: "https://github.com/test/repo"
        )
        #expect(analysis.currentDisplay == "main @ abc1234 (v1.2.3)")
    }

    @Test("Is outdated when latest is newer than base")
    func isOutdatedWhenLatestNewer() {
        let analysis = RefPinAnalysis(
            package: "p", revision: "abc1234",
            baseTag: Version(1, 0, 0), latestTag: Version(2, 0, 0),
            url: "https://github.com/test/repo"
        )
        #expect(analysis.isOutdated == true)
    }

    @Test("Is not outdated when latest equals base")
    func isNotOutdatedWhenLatestEqualsBase() {
        let analysis = RefPinAnalysis(
            package: "p", revision: "abc1234",
            baseTag: Version(2, 0, 0), latestTag: Version(2, 0, 0),
            url: "https://github.com/test/repo"
        )
        #expect(analysis.isOutdated == false)
    }

    @Test("Is not outdated when base or latest tag is nil")
    func isNotOutdatedWhenTagNil() {
        let noBase = RefPinAnalysis(package: "p", revision: "abc", baseTag: nil, latestTag: Version(2, 0, 0), url: "")
        let noLatest = RefPinAnalysis(package: "p", revision: "abc", baseTag: Version(1, 0, 0), latestTag: nil, url: "")
        #expect(noBase.isOutdated == false)
        #expect(noLatest.isOutdated == false)
    }

    @Test("Sorting by package name")
    func sortingByPackageName() {
        let analyses = [
            RefPinAnalysis(package: "z-package", revision: "abc", baseTag: nil, latestTag: nil, url: ""),
            RefPinAnalysis(package: "a-package", revision: "abc", baseTag: nil, latestTag: nil, url: ""),
            RefPinAnalysis(package: "m-package", revision: "abc", baseTag: nil, latestTag: nil, url: ""),
        ]
        #expect(analyses.sorted().map(\.package) == ["a-package", "m-package", "z-package"])
    }

    @Test("Table values include all fields")
    func tableValuesIncludeAllFields() {
        let analysis = RefPinAnalysis(
            package: "test-package",
            revision: "abc1234567890def",
            baseTag: Version(1, 0, 0),
            latestTag: Version(2, 0, 0),
            url: "https://github.com/test/repo"
        )
        let values = analysis.tableValues
        #expect(values.count == 4)
        #expect(values[0].description == "test-package")
        #expect(values[1].description == "abc1234 (v1.0.0)")
        // values[2] may carry ANSI color codes, so assert on substring.
        #expect(values[2].description.contains("2.0.0"))
        #expect(values[3].description.contains("github.com/test/repo"))
    }

    @Test("Table values show N/A when no latest tag")
    func tableValuesShowNAWhenNoLatestTag() {
        let analysis = RefPinAnalysis(
            package: "test-package",
            revision: "abc1234567890def",
            baseTag: Version(1, 0, 0),
            latestTag: nil,
            url: "https://github.com/test/repo"
        )
        #expect(analysis.tableValues[2].description == "N/A")
    }
}
