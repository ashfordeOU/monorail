import Foundation
@testable import MonorailCore
import XCTest

/// The window switcher's keys and order, edge snapping, display targets, stashing, the sun
/// schedule and display modes.
final class HoldSwitcherTests: XCTestCase {
    func testOffNeverTakesTab() {
        var keys = HoldSwitcherKeys(shortcut: .off)
        XCTAssertNil(keys.keyDown(KeyCode.tab, modifiers: [.command]))
        XCTAssertNil(keys.flagsChanged([]))
    }

    func testHoldTabStepAndRelease() {
        var keys = HoldSwitcherKeys(shortcut: .commandTab)
        XCTAssertNil(keys.keyDown(KeyCode.tab, modifiers: [.option]), "⌥Tab isn't the trigger")
        XCTAssertNil(keys.keyDown(KeyCode.a, modifiers: [.command]), "⌘A passes through")
        XCTAssertEqual(keys.keyDown(KeyCode.tab, modifiers: [.command]), .open(backward: false))
        XCTAssertTrue(keys.isOpen)
        XCTAssertEqual(keys.keyDown(KeyCode.tab, modifiers: [.command]), .step(1))
        XCTAssertEqual(keys.keyDown(KeyCode.tab, modifiers: [.command, .shift]), .step(-1))
        XCTAssertEqual(keys.keyDown(KeyCode.down, modifiers: [.command]), .row(1))
        XCTAssertEqual(keys.keyDown(KeyCode.w, modifiers: [.command]), .closeWindow)
        XCTAssertNil(keys.flagsChanged([.command, .shift]), "still held")
        XCTAssertEqual(keys.flagsChanged([]), .commit)
        XCTAssertFalse(keys.isOpen)
        XCTAssertNil(keys.flagsChanged([]))
    }

    func testOptionTabBackwardsAndEscape() {
        var keys = HoldSwitcherKeys(shortcut: .optionTab)
        XCTAssertNil(keys.keyDown(KeyCode.tab, modifiers: [.command]))
        XCTAssertEqual(keys.keyDown(KeyCode.tab, modifiers: [.option, .shift]), .open(backward: true))
        XCTAssertEqual(keys.keyDown(KeyCode.escape, modifiers: [.option]), .cancel)
        XCTAssertNil(keys.flagsChanged([]), "cancelled: letting go does nothing")
    }

    func testOrderIsMostRecentFirst() {
        XCTAssertEqual(HoldSwitcher.order([1, 2, 3, 4], recentFirst: [3, 9, 1]), [3, 1, 2, 4])
        XCTAssertEqual(HoldSwitcher.order([1, 2], recentFirst: []), [1, 2])
    }

    func testSelectionWrapsAndRowsStayInside() {
        XCTAssertEqual(HoldSwitcher.initialSelection(count: 5, backward: false), 1)
        XCTAssertEqual(HoldSwitcher.initialSelection(count: 5, backward: true), 4)
        XCTAssertEqual(HoldSwitcher.initialSelection(count: 1, backward: false), 0)
        XCTAssertEqual(HoldSwitcher.step(4, by: 1, count: 5), 0)
        XCTAssertEqual(HoldSwitcher.step(0, by: -1, count: 5), 4)
        XCTAssertEqual(HoldSwitcher.step(0, by: 1, count: 0), 0)
        XCTAssertEqual(HoldSwitcher.row(1, by: 1, count: 10, columns: 4), 5)
        XCTAssertEqual(HoldSwitcher.row(8, by: 1, count: 10, columns: 4), 8)
        XCTAssertEqual(HoldSwitcher.row(1, by: -1, count: 10, columns: 4), 1)
    }

    func testGridColumns() {
        XCTAssertEqual(HoldSwitcher.columns(for: 3), 3)
        XCTAssertEqual(HoldSwitcher.columns(for: 6), 6)
        XCTAssertEqual(HoldSwitcher.columns(for: 7), 4)
        XCTAssertEqual(HoldSwitcher.columns(for: 13), 5)
        XCTAssertEqual(HoldSwitcher.columns(for: 0), 1)
    }

    func testSettingDefaultsOffAndDecodes() throws {
        XCTAssertEqual(AppSettings().windowSwitcherShortcut, .off)
        XCTAssertFalse(AppSettings().edgeSnapping)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"windowSwitcherShortcut":"optionTab","eveningSchedule":"sun"}"#.utf8))
        XCTAssertEqual(decoded.windowSwitcherShortcut, .optionTab)
        XCTAssertEqual(decoded.eveningSchedule, .sun)
    }
}

final class EdgeSnapTests: XCTestCase {
    let screen = Rect(x: 0, y: 0, width: 1440, height: 900)

    func testEdgesAndCorners() {
        XCTAssertEqual(EdgeSnapZones.position(x: 0, y: 450, in: screen), .leftHalf)
        XCTAssertEqual(EdgeSnapZones.position(x: 1439, y: 450, in: screen), .rightHalf)
        XCTAssertEqual(EdgeSnapZones.position(x: 720, y: 0, in: screen), .maximize)
        XCTAssertEqual(EdgeSnapZones.position(x: 0, y: 10, in: screen), .topLeft)
        XCTAssertEqual(EdgeSnapZones.position(x: 30, y: 0, in: screen), .topLeft)
        XCTAssertEqual(EdgeSnapZones.position(x: 1439, y: 899, in: screen), .bottomRight)
        XCTAssertEqual(EdgeSnapZones.position(x: 20, y: 899, in: screen), .bottomLeft)
        XCTAssertNil(EdgeSnapZones.position(x: 720, y: 899, in: screen), "the Dock's edge")
        XCTAssertNil(EdgeSnapZones.position(x: 720, y: 450, in: screen))
        XCTAssertNil(EdgeSnapZones.position(x: 3000, y: 450, in: screen), "another display")
    }

    func testSharedEdgesDontSnap() {
        XCTAssertNil(EdgeSnapZones.position(x: 1439, y: 450, in: screen, sharedEdges: [.right]))
        XCTAssertEqual(EdgeSnapZones.position(x: 0, y: 450, in: screen, sharedEdges: [.right]), .leftHalf)
    }

    func testOffsetDisplay() {
        let second = Rect(x: 1440, y: -200, width: 1920, height: 1080)
        XCTAssertEqual(EdgeSnapZones.position(x: 3359, y: 300, in: second), .rightHalf)
        XCTAssertEqual(EdgeSnapZones.position(x: 2000, y: -200, in: second), .maximize)
    }
}

final class DisplayTargetsTests: XCTestCase {
    // Laptop in the middle, a monitor each side, one above the laptop.
    let frames = [
        Rect(x: 0, y: 0, width: 1512, height: 982),          // 0: laptop
        Rect(x: -2560, y: -400, width: 2560, height: 1440),  // 1: left monitor
        Rect(x: 1512, y: -300, width: 1920, height: 1080),   // 2: right monitor
        Rect(x: 0, y: -1080, width: 1920, height: 1080),     // 3: above
    ]

    func testNumberingLeftToRight() {
        XCTAssertEqual(DisplayTargets.numbered(frames), [1, 3, 0, 2], "same left edge: the upper one first")
        XCTAssertEqual(DisplayTargets.index(ofNumber: 1, in: frames), 1)
        XCTAssertEqual(DisplayTargets.index(ofNumber: 4, in: frames), 2)
        XCTAssertNil(DisplayTargets.index(ofNumber: 5, in: frames))
    }

    func testNeighbours() {
        XCTAssertEqual(DisplayTargets.neighbour(of: 0, .left, in: frames), 1)
        XCTAssertEqual(DisplayTargets.neighbour(of: 0, .right, in: frames), 2)
        XCTAssertEqual(DisplayTargets.neighbour(of: 0, .up, in: frames), 3)
        XCTAssertNil(DisplayTargets.neighbour(of: 0, .down, in: frames))
        XCTAssertEqual(DisplayTargets.neighbour(of: 1, .right, in: frames), 0, "the nearer one")
        XCTAssertEqual(DisplayTargets.neighbour(of: 3, .down, in: frames), 0)
        XCTAssertNil(DisplayTargets.neighbour(of: 9, .left, in: frames))
    }

    func testTransferKeepsProportionAndFits() {
        let from = Rect(x: 0, y: 0, width: 1000, height: 800)
        let to = Rect(x: 2000, y: 100, width: 500, height: 400)
        let moved = DisplayTargets.transfer(Rect(x: 500, y: 200, width: 400, height: 300), from: from, to: to)
        XCTAssertEqual(moved.width, 400)
        XCTAssertEqual(moved.height, 300)
        XCTAssertEqual(moved.x, 2000 + (500.0 / 600.0) * 100, accuracy: 1)
        let big = DisplayTargets.transfer(Rect(x: 0, y: 0, width: 1000, height: 800), from: from, to: to)
        XCTAssertEqual(big, Rect(x: 2000, y: 100, width: 500, height: 400))
    }

    func testSharedEdges() {
        XCTAssertEqual(DisplayTargets.sharedEdges(of: 0, in: frames), [.left, .right, .top])
        XCTAssertEqual(DisplayTargets.sharedEdges(of: 1, in: frames), [.right])
        XCTAssertEqual(DisplayTargets.sharedEdges(of: 0, in: [frames[0]]), [])
    }

    func testDisplayActions() {
        XCTAssertEqual(Action.focusDisplayLeft.displayDirection, .left)
        XCTAssertEqual(Action.sendToDisplayDown.displayDirection, .down)
        XCTAssertTrue(Action.sendToDisplayDown.sendsToDisplay)
        XCTAssertEqual(Action.focusDisplay3.displayNumber, 3)
        XCTAssertEqual(Action.sendToDisplay9.displayNumber, 9)
        XCTAssertNil(Action.focusDisplayLeft.displayNumber)
        XCTAssertNil(Action.focusNextDisplay.displayDirection)
        XCTAssertEqual(Action(url: "monorail://send-to-display-2"), .sendToDisplay2)
        XCTAssertTrue(Action.unboundByDefault.contains(.stashWindow))
        XCTAssertTrue(Action.unboundByDefault.contains(.focusDisplay1))
    }
}

final class StashTests: XCTestCase {
    let frame = Rect(x: 0, y: 0, width: 1440, height: 900)
    let visible = Rect(x: 0, y: 25, width: 1440, height: 800)

    func testEdgeChoice() {
        let window = Rect(x: 1000, y: 100, width: 400, height: 500)
        XCTAssertEqual(StashGeometry.edge(for: window, display: frame, sharedEdges: []), .right)
        XCTAssertEqual(StashGeometry.edge(for: window, display: frame, sharedEdges: [.right]), .left)
        XCTAssertNil(StashGeometry.edge(for: window, display: frame, sharedEdges: [.left, .right]))
    }

    func testStashedAndRevealedFrames() {
        let window = Rect(x: 1000, y: 0, width: 400, height: 500)
        let stashed = StashGeometry.stashedFrame(window, edge: .right, frame: frame, visible: visible)
        XCTAssertEqual(stashed, Rect(x: 1430, y: 25, width: 400, height: 500))
        let left = StashGeometry.stashedFrame(window, edge: .left, frame: frame, visible: visible)
        XCTAssertEqual(left.maxX, 10)
        let shown = StashGeometry.revealedFrame(window, edge: .right, visible: visible, gap: 8)
        XCTAssertEqual(shown, Rect(x: 1032, y: 25, width: 400, height: 500))
        let zone = StashGeometry.hotZone(stashed: stashed, edge: .right, frame: frame)
        XCTAssertTrue(zone.contains(x: 1439, y: 300))
        XCTAssertFalse(zone.contains(x: 1439, y: 600))
    }
}

final class SolarTimesTests: XCTestCase {
    private func minutes(_ h: Int, _ m: Int) -> Int { h * 60 + m }

    private func assertNear(_ day: SolarTimes.Day, sunrise: Int, sunset: Int, within tolerance: Int = 6,
                            file: StaticString = #filePath, line: UInt = #line) {
        guard case .normal(let rise, let set) = day else { return XCTFail("\(day)", file: file, line: line) }
        XCTAssertLessThanOrEqual(abs(rise - sunrise), tolerance, "sunrise \(rise / 60):\(rise % 60)", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(set - sunset), tolerance, "sunset \(set / 60):\(set % 60)", file: file, line: line)
    }

    func testLondon() {
        // Midsummer in British Summer Time, midwinter in GMT.
        assertNear(SolarTimes.day(dayOfYear: 172, latitude: 51.51, longitude: -0.13, utcOffsetMinutes: 60),
                   sunrise: minutes(4, 43), sunset: minutes(21, 21))
        assertNear(SolarTimes.day(dayOfYear: 355, latitude: 51.51, longitude: -0.13, utcOffsetMinutes: 0),
                   sunrise: minutes(8, 4), sunset: minutes(15, 53))
    }

    func testNewYorkAndSydney() {
        assertNear(SolarTimes.day(dayOfYear: 172, latitude: 40.71, longitude: -74.01, utcOffsetMinutes: -240),
                   sunrise: minutes(5, 25), sunset: minutes(20, 31))
        // Sydney in its summer (daylight saving, UTC+11).
        assertNear(SolarTimes.day(dayOfYear: 355, latitude: -33.87, longitude: 151.21, utcOffsetMinutes: 660),
                   sunrise: minutes(5, 41), sunset: minutes(20, 5))
    }

    func testPolarDayAndNight() {
        XCTAssertEqual(SolarTimes.day(dayOfYear: 172, latitude: 69.65, longitude: 18.96, utcOffsetMinutes: 120), .alwaysUp)
        XCTAssertEqual(SolarTimes.day(dayOfYear: 355, latitude: 69.65, longitude: 18.96, utcOffsetMinutes: 60), .alwaysDown)
    }

    func testTimeZoneEstimate() throws {
        let london = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let place = ApproximateLocation.coordinates(for: london)
        XCTAssertEqual(place.latitude, 51.51, accuracy: 0.01)
        // An unlisted zone falls back to its offset's longitude.
        let lagos = try XCTUnwrap(TimeZone(identifier: "Africa/Kinshasa"))
        XCTAssertEqual(ApproximateLocation.coordinates(for: lagos).longitude, 15, accuracy: 0.01)
        // A date in London in June gives a summer evening.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = london
        let june = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12)))
        assertNear(SolarTimes.day(on: june, timeZone: london), sunrise: minutes(4, 43), sunset: minutes(21, 21))
    }

    func testSunScheduleLevel() {
        let sun = SolarTimes.Day.normal(sunrise: minutes(7, 0), sunset: minutes(17, 0))
        func level(_ minute: Int) -> Double {
            EveningMode.level(schedule: .sun, manuallyOn: false, strength: 0.8, minute: minute, start: 0, end: 0, sun: sun)
        }
        XCTAssertEqual(level(minutes(12, 0)), 0)
        XCTAssertEqual(level(minutes(17, 20)), 0.4, accuracy: 0.001, "fading in after sunset")
        XCTAssertEqual(level(minutes(23, 0)), 0.8, accuracy: 0.001)
        XCTAssertEqual(level(minutes(6, 40)), 0.4, accuracy: 0.001, "fading out before sunrise")
        XCTAssertEqual(EveningMode.level(schedule: .sun, manuallyOn: false, strength: 0.5, minute: 0, start: 0, end: 0,
                                         sun: .alwaysDown), 0.5)
        XCTAssertEqual(EveningMode.level(schedule: .sun, manuallyOn: false, strength: 0.5, minute: 0, start: 0, end: 0,
                                         sun: .alwaysUp), 0)
    }

    func testRedModeAndBrightness() {
        let red = EveningMode.multipliers(strength: 1, red: true)
        XCTAssertEqual(red.red, 1, accuracy: 0.001)
        XCTAssertEqual(red.green, 0, accuracy: 0.001)
        XCTAssertEqual(red.blue, 0, accuracy: 0.001)
        let warm = EveningMode.multipliers(strength: 0.5), deeper = EveningMode.multipliers(strength: 0.5, red: true)
        XCTAssertLessThan(deeper.green, warm.green)
        let dim = EveningMode.multipliers(strength: 0, brightness: 0.5)
        XCTAssertEqual(dim.red, 0.5, accuracy: 0.001)
        XCTAssertEqual(dim.blue, 0.5, accuracy: 0.001)
        XCTAssertEqual(EveningMode.multipliers(strength: 0, brightness: 0).green, EveningMode.minimumBrightness, accuracy: 0.001,
                       "never fully dark")
    }

    func testPausedApps() {
        XCTAssertTrue(EveningMode.isPaused(frontApp: "com.adobe.Photoshop", exceptions: ["com.adobe.photoshop"]))
        XCTAssertFalse(EveningMode.isPaused(frontApp: "com.apple.Safari", exceptions: ["com.adobe.Photoshop"]))
        XCTAssertFalse(EveningMode.isPaused(frontApp: nil, exceptions: ["com.adobe.Photoshop"]))
    }
}

final class DisplayModeChoiceTests: XCTestCase {
    private func mode(_ w: Int, _ h: Int, scale: Int = 2, hz: Double = 60) -> DisplayModeInfo {
        DisplayModeInfo(width: w, height: h, pixelWidth: w * scale, pixelHeight: h * scale, refreshRate: hz)
    }

    func testOnePerSizeMatchingSharpnessAndRate() {
        let current = mode(1512, 982, hz: 120)
        let modes = [
            mode(1512, 982, hz: 120), mode(1512, 982, hz: 60), mode(1512, 982, scale: 1, hz: 120),
            mode(1800, 1169, hz: 120), mode(1800, 1169, hz: 60), mode(1024, 665, hz: 120), mode(640, 480, hz: 60),
        ]
        let sizes = DisplayModeChoice.sizes(modes, current: current)
        XCTAssertEqual(sizes.map(\.width), [1024, 1512, 1800], "small game modes left out")
        XCTAssertTrue(sizes.allSatisfy { $0.isHiDPI && $0.refreshRate == 120 })
        XCTAssertEqual(DisplayModeChoice.step(from: current, in: modes, moreSpace: true)?.width, 1800)
        XCTAssertEqual(DisplayModeChoice.step(from: current, in: modes, moreSpace: false)?.width, 1024)
        XCTAssertNil(DisplayModeChoice.step(from: mode(1800, 1169), in: modes, moreSpace: true))
        XCTAssertEqual(DisplayModeChoice.refreshRates(modes, current: current).map(\.refreshRate), [120, 60])
    }

    func testTitles() {
        XCTAssertEqual(mode(1920, 1080, scale: 1, hz: 59.94).refreshTitle, "60 Hz")
        XCTAssertEqual(mode(1920, 1080, hz: 0).refreshTitle, "Default rate")
        XCTAssertEqual(mode(1920, 1080).sizeTitle, "1920 × 1080")
        XCTAssertFalse(mode(1920, 1080, scale: 1).isHiDPI)
    }
}
