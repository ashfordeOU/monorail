@testable import MonorailCore
import XCTest

final class FocusLogTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private let noon = Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - 1_700_000_000 % 86400 + 12 * 3600 as Int))

    func testStreakCountsFinishedDaysInARow() {
        var log = FocusLog()
        for back in 0..<3 { log.record(.init(start: noon.addingTimeInterval(Double(-back) * 86400), minutes: 25, finished: true)) }
        log.record(.init(start: noon.addingTimeInterval(-5 * 86400), minutes: 25, finished: true))
        XCTAssertEqual(log.streak(now: noon, calendar: calendar), 3)
        // Before today's first session, yesterday's streak still stands.
        XCTAssertEqual(log.streak(now: noon.addingTimeInterval(86400), calendar: calendar), 3)
        XCTAssertEqual(log.streak(now: noon.addingTimeInterval(2 * 86400), calendar: calendar), 0)
    }

    func testWeekAndReview() {
        var log = FocusLog()
        log.record(.init(start: noon, minutes: 50, finished: true))
        log.record(.init(start: noon.addingTimeInterval(3600), minutes: 20, finished: false))
        log.record(.init(start: noon, minutes: 0, finished: false))
        XCTAssertEqual(log.sessions.count, 2)
        XCTAssertEqual(log.week(now: noon, calendar: calendar).last, 70)
        XCTAssertEqual(log.review(now: noon, calendar: calendar), "1 h 10 min of focus in 2 sessions (1 finished).")
        XCTAssertEqual(FocusLog().review(now: noon, calendar: calendar), "No focus sessions today yet.")
    }

    func testBestHour() {
        var log = FocusLog()
        for i in 0..<4 { log.record(.init(start: noon.addingTimeInterval(Double(i) * 86400 - 3 * 3600), minutes: 50, finished: true)) }
        log.record(.init(start: noon, minutes: 25, finished: true))
        XCTAssertEqual(log.bestHour(calendar: calendar), 9)
        XCTAssertNil(FocusLog().bestHour())
    }

    func testEyeBreaks() {
        XCTAssertTrue(EyeBreaks.isDue(activeSeconds: 1201, idleSeconds: 3))
        XCTAssertFalse(EyeBreaks.isDue(activeSeconds: 600, idleSeconds: 3))
        XCTAssertFalse(EyeBreaks.isDue(activeSeconds: 1300, idleSeconds: 120))
    }
}
