@testable import MonorailCore
import XCTest

final class EnergyLogTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    func testAddsUpByDayAndRanks() {
        var log = EnergyLog()
        log.add(id: "chrome", name: "Chrome", joules: 300, cpuSeconds: 60, at: day, calendar: calendar)
        log.add(id: "chrome", name: "Chrome", joules: 200, cpuSeconds: 40, at: day, calendar: calendar)
        log.add(id: "xcode", name: "Xcode", joules: 900, cpuSeconds: 10, at: day.addingTimeInterval(86400), calendar: calendar)
        log.add(id: "slack", name: "Slack", joules: -5, cpuSeconds: -1, at: day, calendar: calendar)
        let keys = EnergyLog.lastDays(2, now: day.addingTimeInterval(86400), calendar: calendar)
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(log.top(over: keys).map(\.id), ["xcode", "chrome"])
        XCTAssertEqual(log.top(over: [keys[0]]).first?.entry.joules, 500)
        XCTAssertEqual(log.dailyTotals(keys), [500, 900])
        XCTAssertTrue(log.hasEnergy)
    }

    func testKeepsThirtyDays() {
        var log = EnergyLog()
        for i in 0..<40 { log.add(id: "a", name: "A", joules: 1, cpuSeconds: 1, at: day.addingTimeInterval(Double(i) * 86400), calendar: calendar) }
        XCTAssertEqual(log.days.count, EnergyLog.keepDays)
        XCTAssertNil(log.days[EnergyLog.key(day, calendar: calendar)])
    }

    func testProcessorTimeWithoutEnergy() {
        var log = EnergyLog()
        log.add(id: "a", name: "A", joules: 0, cpuSeconds: 30, at: day, calendar: calendar)
        log.add(id: "b", name: "B", joules: 0, cpuSeconds: 90, at: day, calendar: calendar)
        XCTAssertEqual(log.top(over: [EnergyLog.key(day, calendar: calendar)]).map(\.id), ["b", "a"])
        XCTAssertFalse(log.hasEnergy)
    }
}
