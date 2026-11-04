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

    func testExtrasDefaultsPerStarter() {
        var settings = AppSettings()
        settings.applyExtras(for: .simple)
        let simpleOn = StarterExtra.allCases.filter { $0.isOn(in: settings) }
        XCTAssertEqual(Set(simpleOn), [.terminalsTogether, .awakeInMenuBar, .agentChime, .usageCounts], "simple: only the gentle ones, keeping what is on by default")
        XCTAssertEqual(settings.swipeFingers, .off)
        XCTAssertEqual(settings.windowSwitcherShortcut, .off)

        settings.applyExtras(for: .power)
        for extra in StarterExtra.allCases {
            let expected = ![.windowSwitcher, .swipe, .keepAvailable].contains(extra)
            XCTAssertEqual(extra.isOn(in: settings), expected, "power: \(extra)")
        }
        XCTAssertEqual(settings.eveningSchedule, .sun)
        XCTAssertTrue(settings.edgeSnapping)
    }

    func testExtrasRoundTripAndLeaveOtherChoicesAlone() {
        var settings = AppSettings()
        for extra in StarterExtra.allCases {
            extra.set(true, in: &settings)
            XCTAssertTrue(extra.isOn(in: settings), "\(extra) on")
            extra.set(false, in: &settings)
            XCTAssertFalse(extra.isOn(in: settings), "\(extra) off")
        }
        // Turning the ⌘Tab switcher off keeps a ⌥Tab choice; turning the sun schedule off keeps a fixed one.
        settings.windowSwitcherShortcut = .optionTab
        StarterExtra.windowSwitcher.set(false, in: &settings)
        XCTAssertEqual(settings.windowSwitcherShortcut, .optionTab)
        settings.eveningSchedule = .scheduled
        StarterExtra.eveningSunset.set(false, in: &settings)
        XCTAssertEqual(settings.eveningSchedule, .scheduled)
        XCTAssertFalse(StarterExtra.newInThisVersion.isEmpty)
        XCTAssertTrue(StarterExtra.newInThisVersion.allSatisfy { !$0.isOn(in: AppSettings()) }, "new features start off")
    }
}
