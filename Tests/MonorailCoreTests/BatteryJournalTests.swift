@testable import MonorailCore
import XCTest

final class BatteryJournalTests: XCTestCase {
    private let day: TimeInterval = 86400
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    func testOneHealthSampleADay() {
        var j = BatteryJournal()
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        j.record(capacity: 95, cycles: 100, on: d, calendar: calendar)
        j.record(capacity: 94, cycles: 101, on: d.addingTimeInterval(60), calendar: calendar)
        XCTAssertEqual(j.health.count, 1)
        XCTAssertEqual(j.health[0].capacity, 94)
        j.record(capacity: 0, cycles: nil, on: d, calendar: calendar)
        XCTAssertEqual(j.health.count, 1)
    }

    func testHealthTrendAndMonthsTo80() {
        var j = BatteryJournal()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        // 1% every 15 days: 2% a month.
        for i in 0..<5 { j.record(capacity: 90 - i, cycles: nil, on: start.addingTimeInterval(Double(i) * 15 * day), calendar: calendar) }
        XCTAssertEqual(j.lossPerMonth ?? 0, 2, accuracy: 0.01)
        XCTAssertEqual(j.monthsTo80, 3) // 86 now, 6 points at 2 a month
        XCTAssertNil(BatteryJournal().lossPerMonth)
    }

    func testNightsAndCharges() {
        var j = BatteryJournal()
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        j.record(BatteryJournal.Night(slept: t, woke: t.addingTimeInterval(8 * 3600), from: 80, to: 76))
        j.record(BatteryJournal.Night(slept: t, woke: t.addingTimeInterval(600), from: 80, to: 79)) // too short
        XCTAssertEqual(j.nights.count, 1)
        XCTAssertEqual(j.typicalNightDrain ?? 0, 0.5, accuracy: 0.001)
        XCTAssertFalse(j.nights[0].isHeavy)
        XCTAssertTrue(BatteryJournal.Night(slept: t, woke: t.addingTimeInterval(4 * 3600), from: 80, to: 70).isHeavy)
        j.record(BatteryJournal.Charge(start: t, end: t.addingTimeInterval(3600), from: 20, to: 90))
        j.record(BatteryJournal.Charge(start: t, end: t, from: 20, to: 90))
        XCTAssertEqual(j.charges.count, 1)
        XCTAssertEqual(j.charges[0].minutes, 60)
        let report = j.report(model: "MacBook Pro", percent: 64, capacity: 91, cycles: 212, now: t)
        XCTAssertTrue(report.contains("Health: 91%"))
        XCTAssertTrue(report.contains("20% → 90% in 60 min"))
    }

    func testAccessoriesWarnOnceWhenLow() {
        let before = [AccessoryBattery(name: "Magic Mouse", percent: 20)]
        let now = [AccessoryBattery(name: "Magic Mouse", percent: 14), AccessoryBattery(name: "AirPods Pro", percent: 50)]
        XCTAssertEqual(AccessoryBattery.newlyLow(now, before: before).map(\.name), ["Magic Mouse"])
        XCTAssertTrue(AccessoryBattery.newlyLow(now, before: now).isEmpty)
        XCTAssertEqual(now[0].symbol, "magicmouse.fill")
        XCTAssertEqual(now[1].symbol, "airpodspro")
    }
}
