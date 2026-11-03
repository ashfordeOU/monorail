import Foundation
import MonorailCore
import XCTest

final class StarterSetupTests: XCTestCase {
    func testSimpleHidesAdvancedSettingsAndPowerShowsThem() {
        var settings = AppSettings()
        XCTAssertFalse(settings.showAllSettings, "new installs start simple")
        settings.apply(StarterSetup.power)
        XCTAssertTrue(settings.showAllSettings)
        XCTAssertTrue(settings.showNavigationArrows)
        settings.apply(StarterSetup.simple)
        XCTAssertFalse(settings.showAllSettings)
        XCTAssertFalse(settings.fitByDefault)
        settings.apply(StarterSetup.switching)
        XCTAssertTrue(settings.showAllSettings)
    }

    func testEssentialSectionsAlwaysShow() {
        for tab in ["basics", "shortcuts", "appearance", "evening", "awake", "about"] {
            XCTAssertTrue(SettingsVisibility.isShown(tab, showAll: false), tab)
        }
        XCTAssertFalse(SettingsVisibility.isShown("automation", showAll: false))
        XCTAssertTrue(SettingsVisibility.isShown("automation", showAll: true))
    }

    func testTheSwitchIsSaved() throws {
        var settings = AppSettings()
        settings.showAllSettings = true
        XCTAssertTrue(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings)).showAllSettings)
    }
}
