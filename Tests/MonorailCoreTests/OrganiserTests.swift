@testable import MonorailCore
import XCTest

final class OrganiserTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private let noon = Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - 1_700_000_000 % 86400 + 12 * 3600 as Int))

    func testReminderBuckets() {
        XCTAssertEqual(Organiser.bucket(due: nil, hasTime: false, now: noon, calendar: calendar), .someday)
        XCTAssertEqual(Organiser.bucket(due: noon.addingTimeInterval(-3600), hasTime: true, now: noon, calendar: calendar), .overdue)
        XCTAssertEqual(Organiser.bucket(due: noon.addingTimeInterval(-3600), hasTime: false, now: noon, calendar: calendar), .today)
        XCTAssertEqual(Organiser.bucket(due: noon.addingTimeInterval(3600), hasTime: true, now: noon, calendar: calendar), .today)
        XCTAssertEqual(Organiser.bucket(due: noon.addingTimeInterval(-2 * 86400), hasTime: false, now: noon, calendar: calendar), .overdue)
        XCTAssertEqual(Organiser.bucket(due: noon.addingTimeInterval(3 * 86400), hasTime: false, now: noon, calendar: calendar), .upcoming)
    }

    func testBusyDays() {
        // 14 Nov 2023 (UTC) is the day after noon's; a two-day event spans 2 days.
        let start = noon.addingTimeInterval(86400), end = start.addingTimeInterval(86400 + 3600)
        let days = Organiser.busyDays([start], ends: [end], month: noon, calendar: calendar)
        let day = calendar.component(.day, from: start)
        XCTAssertEqual(days, [day, day + 1])
    }

    func testNotes() {
        XCTAssertEqual(Organiser.snippet("Shopping\nmilk  eggs\n bread", title: "Shopping"), "milk eggs bread")
        let out = "x-coredata://1\tShopping\t2026-11-13T10:20:00\tShopping milk eggs\nx-coredata://2\t\t\t\n\n"
        let notes = Organiser.parseNotes(out)
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes[0].snippet, "milk eggs")
        XCTAssertNotNil(notes[0].modified)
        XCTAssertEqual(notes[1].title, "New Note")
    }
}
