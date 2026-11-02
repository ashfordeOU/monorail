import MonorailCore
import XCTest

final class EveningModeTests: XCTestCase {
    func testZeroChangesNothingAndMoreMeansLessBlue() {
        let none = EveningMode.multipliers(strength: 0)
        XCTAssertEqual(none.red, 1, accuracy: 0.001)
        XCTAssertEqual(none.green, 1, accuracy: 0.001)
        XCTAssertEqual(none.blue, 1, accuracy: 0.001)
        var lastBlue = 1.0, lastGreen = 1.0
        for step in 1...10 {
            let m = EveningMode.multipliers(strength: Double(step) / 10)
            XCTAssertEqual(m.red, 1, accuracy: 0.001, "red stays full")
            XCTAssertLessThan(m.blue, lastBlue)
            XCTAssertLessThanOrEqual(m.green, lastGreen)
            XCTAssertLessThan(m.blue, m.green, "blue drops fastest")
            lastBlue = m.blue
            lastGreen = m.green
        }
        let full = EveningMode.multipliers(strength: 1)
        XCTAssertLessThan(full.blue, 0.3)
        XCTAssertGreaterThan(full.green, 0.4, "still readable at full strength")
        XCTAssertEqual(EveningMode.multipliers(strength: 5).blue, full.blue, accuracy: 0.001, "clamped")
    }

    func testScheduleFadesInAndOutAndRunsPastMidnight() {
        let start = 20 * 60, end = 7 * 60
        XCTAssertEqual(EveningMode.scheduleLevel(minute: 19 * 60, start: start, end: end), 0)
        XCTAssertEqual(EveningMode.scheduleLevel(minute: start + 10, start: start, end: end), 0.5, accuracy: 0.001)
        XCTAssertEqual(EveningMode.scheduleLevel(minute: 23 * 60, start: start, end: end), 1)
        XCTAssertEqual(EveningMode.scheduleLevel(minute: 2 * 60, start: start, end: end), 1)
        XCTAssertEqual(EveningMode.scheduleLevel(minute: end - 5, start: start, end: end), 0.25, accuracy: 0.001)
        XCTAssertEqual(EveningMode.scheduleLevel(minute: 12 * 60, start: start, end: end), 0)
        XCTAssertEqual(EveningMode.scheduleLevel(minute: 600, start: 600, end: 600), 0, "empty schedule")
    }

    func testManualWinsAndOffMeansNormal() {
        XCTAssertEqual(EveningMode.level(schedule: .manual, manuallyOn: false, strength: 0.6, minute: 23 * 60, start: 1200, end: 420), 0)
        XCTAssertEqual(EveningMode.level(schedule: .manual, manuallyOn: true, strength: 0.6, minute: 12 * 60, start: 1200, end: 420), 0.6)
        XCTAssertEqual(EveningMode.level(schedule: .scheduled, manuallyOn: false, strength: 0.6, minute: 23 * 60, start: 1200, end: 420), 0.6)
        XCTAssertEqual(EveningMode.level(schedule: .scheduled, manuallyOn: false, strength: 0.6, minute: 12 * 60, start: 1200, end: 420), 0)
    }

    func testSettingsRoundTrip() throws {
        var settings = AppSettings()
        XCTAssertFalse(settings.eveningOn)
        settings.eveningStrength = 0.8
        settings.eveningSchedule = .scheduled
        let back = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(back.eveningStrength, 0.8)
        XCTAssertEqual(back.eveningSchedule, .scheduled)
    }
}
