@testable import MonorailCore
import XCTest

final class MonorailNudgeTests: XCTestCase {
    func testOnlyWhenItWouldHelp() {
        XCTAssertEqual(MonorailNudge.reason(.init(windowsOnScreen: 11, daysSinceInstall: 3)), .manyWindows(11))
        XCTAssertEqual(MonorailNudge.reason(.init(windowsOnScreen: 3, appSwitchesLastHour: 52, daysSinceInstall: 3)), .manySwitches(52))
        XCTAssertNil(MonorailNudge.reason(.init(windowsOnScreen: 3, appSwitchesLastHour: 5, daysSinceInstall: 3)))
    }

    func testRespectfulTiming() {
        XCTAssertNil(MonorailNudge.reason(.init(windowsOnScreen: 20, daysSinceInstall: 1)), "not in the first two days")
        XCTAssertNil(MonorailNudge.reason(.init(windowsOnScreen: 20, daysSinceInstall: 9, daysSinceShown: 3)), "at most weekly")
        XCTAssertNotNil(MonorailNudge.reason(.init(windowsOnScreen: 20, daysSinceInstall: 9, daysSinceShown: 8)))
        XCTAssertNil(MonorailNudge.reason(.init(windowsOnScreen: 20, daysSinceInstall: 9, dismissals: 3)), "stops after three no-thanks")
        XCTAssertNil(MonorailNudge.reason(.init(windowsOnScreen: 20, daysSinceInstall: 9, monorailInstalled: true)))
    }

    func testEditionNotes() {
        let section = ["### Added", "- **Both.** For everyone.", "- **Strip.** Windows. <!-- monorail -->", "- **Station bit.** Only here. <!-- station -->"]
        XCTAssertEqual(EditionNotes.lines(section, for: .station), ["### Added", "- **Both.** For everyone.", "- **Station bit.** Only here."])
        XCTAssertEqual(EditionNotes.lines(section, for: .monorail), ["### Added", "- **Both.** For everyone.", "- **Strip.** Windows."])
        XCTAssertEqual(EditionNotes.monorailOnly(section), ["### Added", "- **Strip.** Windows."])
        XCTAssertEqual(ReleaseNotes.highlights(EditionNotes.monorailOnly(section)).map(\.title), ["Strip"])
    }
}
