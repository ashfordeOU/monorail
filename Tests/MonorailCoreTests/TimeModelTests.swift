import XCTest
@testable import MonorailCore

final class TimeModelTests: XCTestCase {
    func testFindsJoinLinks() {
        XCTAssertEqual(TimeModel.joinLink(url: nil, location: "https://acme.zoom.us/j/123456789?pwd=abc", notes: nil)?.absoluteString,
                       "https://acme.zoom.us/j/123456789?pwd=abc")
        XCTAssertEqual(TimeModel.joinLink(url: nil, location: "Room 4", notes: "Join: https://meet.google.com/abc-defg-hij.")?.absoluteString,
                       "https://meet.google.com/abc-defg-hij")
        XCTAssertNotNil(TimeModel.joinLink(url: "https://teams.microsoft.com/l/meetup-join/19%3ameeting", location: nil, notes: nil))
        XCTAssertNil(TimeModel.joinLink(url: "https://example.com", location: "Office", notes: "Bring snacks"))
    }

    func testUntil() {
        let now = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(TimeModel.until(now.addingTimeInterval(300), end: now.addingTimeInterval(3600), now: now), "in 5 min")
        XCTAssertEqual(TimeModel.until(now.addingTimeInterval(4800), end: now.addingTimeInterval(9000), now: now), "in 1 hr 20 min")
        XCTAssertEqual(TimeModel.until(now.addingTimeInterval(-60), end: now.addingTimeInterval(60), now: now), "now")
        XCTAssertTrue(TimeModel.isImminent(now.addingTimeInterval(240), end: now.addingTimeInterval(3600), now: now))
        XCTAssertFalse(TimeModel.isImminent(now.addingTimeInterval(900), end: now.addingTimeInterval(3600), now: now))
    }

    func testWorldClocks() {
        XCTAssertEqual(TimeModel.city("America/New_York"), "New York")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(TimeModel.offset(TimeZone(identifier: "Asia/Kolkata")!, from: TimeZone(identifier: "UTC")!, at: date), "+5.5 hr")
        XCTAssertEqual(TimeModel.offset(TimeZone(identifier: "UTC")!, from: TimeZone(identifier: "UTC")!, at: date), "same time")
    }

    func testCountdownAndMonth() {
        XCTAssertEqual(TimeModel.countdown(245), "4:05")
        XCTAssertEqual(TimeModel.countdown(3750), "1:02:30")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // November 2026 starts on a Sunday: six blanks before it in a Monday-first grid.
        let grid = TimeModel.monthGrid(for: Date(timeIntervalSince1970: 1_793_491_200), calendar: calendar)
        XCTAssertEqual(grid.prefix(7).compactMap { $0 }, [1])
        XCTAssertEqual(grid.compactMap { $0 }.count, 30)
    }
}
