import XCTest
@testable import MonorailCore

final class HomeModelTests: XCTestCase {
    func testCalmKeepsTheFixedOrder() {
        let plan = HomePlanner.plan(HomeSignals(onBattery: true, percent: 64, minutesLeft: 352, drainRatio: 1.1))
        XCTAssertEqual(plan.cards, [.windows, .today, .pinned, .battery, .system, .storage, .network, .controls, .tools, .layouts])
        XCTAssertEqual(plan.raised, [])
        XCTAssertEqual(plan.tone, .calm)
        XCTAssertEqual(plan.title, "All calm")
    }

    func testAgentsShowOnlyWhileRunning() {
        XCTAssertTrue(HomePlanner.plan(HomeSignals(agentsRunning: 1)).cards.contains(.agents))
        XCTAssertFalse(HomePlanner.plan(HomeSignals()).cards.contains(.agents))
    }

    func testFastDrainRaisesBattery() {
        let plan = HomePlanner.plan(HomeSignals(onBattery: true, percent: 38, minutesLeft: 92, drainRatio: 4))
        XCTAssertEqual(plan.cards.first, .battery)
        XCTAssertEqual(plan.raised, [.battery])
        XCTAssertEqual(plan.tone, .attention)
        XCTAssertEqual(plan.title, "Draining fast")
    }

    func testFastDrainPluggedInIsCalm() {
        XCTAssertEqual(HomePlanner.plan(HomeSignals(onBattery: false, drainRatio: 4)).raised, [])
    }

    func testLowBatteryIsUrgent() {
        let plan = HomePlanner.plan(HomeSignals(onBattery: true, percent: 8, minutesLeft: 25))
        XCTAssertEqual(plan.tone, .urgent)
        XCTAssertEqual(plan.title, "Battery low")
    }

    func testSeveralThingsAreCounted() {
        let plan = HomePlanner.plan(HomeSignals(onBattery: true, percent: 50, drainRatio: 2, clashes: 2, updateAvailable: true))
        XCTAssertEqual(plan.raised, [.battery, .notices])
        XCTAssertEqual(Array(plan.cards.prefix(2)), [.battery, .notices])
        XCTAssertEqual(plan.title, "Three things need you")
    }

    func testRingsAtYourUsualDraw() {
        let b = BatteryState(percent: 64, isCharging: false, onBattery: true, watts: 5.2)
        let r = BatteryRings.make(b, usualWatts: 5.2)
        XCTAssertEqual(r.charge, 0.64, accuracy: 0.001)
        XCTAssertEqual(r.time, 0.64, accuracy: 0.001)
        XCTAssertEqual(r.drain, 0.5, accuracy: 0.001)
        XCTAssertEqual(r.drainTone, .good)
    }

    func testRingsAtFourTimesYourUsual() {
        let b = BatteryState(percent: 40, isCharging: false, onBattery: true, watts: 20)
        let r = BatteryRings.make(b, usualWatts: 5)
        XCTAssertEqual(r.time, 0.1, accuracy: 0.001)
        XCTAssertEqual(r.drain, 1)
        XCTAssertEqual(r.drainTone, .high)
        XCTAssertEqual(r.drainRatio ?? 0, 4, accuracy: 0.001)
    }

    func testRingsPluggedIn() {
        let r = BatteryRings.make(BatteryState(percent: 80, isCharging: true, onBattery: false), usualWatts: 5)
        XCTAssertEqual(r.time, 0.8, accuracy: 0.001)
        XCTAssertEqual(r.drain, 0)
        XCTAssertNil(r.drainRatio)
    }

    func testUsualDrainFromHistory() {
        let start = Date(timeIntervalSince1970: 0)
        // 10 points an hour for an hour, then a charge, then a long gap that doesn't count.
        var points = (0...6).map { i in BatteryPoint(time: start.addingTimeInterval(Double(i) * 600), percent: 90 - Int((Double(i) * 10 / 6).rounded()), charging: false) }
        points.append(BatteryPoint(time: start.addingTimeInterval(4200), percent: 81, charging: true))
        points.append(BatteryPoint(time: start.addingTimeInterval(20000), percent: 60, charging: false))
        let rate = DrainBaseline.percentPerHour(points)
        XCTAssertEqual(rate ?? 0, 10, accuracy: 0.01)
        XCTAssertEqual(DrainBaseline.watts(percentPerHour: rate, wattHours: 52) ?? 0, 5.2, accuracy: 0.01)
    }

    func testNoBaselineFromTooLittle() {
        let start = Date(timeIntervalSince1970: 0)
        let points = [BatteryPoint(time: start, percent: 50, charging: false), BatteryPoint(time: start.addingTimeInterval(600), percent: 48, charging: false)]
        XCTAssertNil(DrainBaseline.percentPerHour(points))
    }

    func testAMeetingAboutToStartComesFirstCalmly() {
        let plan = HomePlanner.plan(HomeSignals(meetingSoon: true))
        XCTAssertEqual(plan.cards.first, .today)
        XCTAssertEqual(plan.tone, .calm)
        XCTAssertEqual(plan.title, "Meeting soon")
        XCTAssertEqual(HomePlanner.plan(HomeSignals(onCall: true, meetingSoon: true)).cards.first, .call)
    }

    func testAFullDiskMovesStorageUp() {
        let plan = HomePlanner.plan(HomeSignals(diskLow: true))
        XCTAssertEqual(plan.cards.first, .storage)
        XCTAssertEqual(plan.title, "Disk almost full")
        XCTAssertEqual(plan.tone, .attention)
    }

    func testBatteryGettingLowIsNotCalm() {
        let plan = HomePlanner.plan(HomeSignals(onBattery: true, percent: 24, minutesLeft: 35))
        XCTAssertEqual(plan.cards.first, .battery)
        XCTAssertEqual(plan.tone, .attention)
        XCTAssertEqual(plan.title, "Battery at 24%")
        XCTAssertEqual(HomePlanner.plan(HomeSignals(onBattery: true, percent: 60, minutesLeft: 200)).tone, .calm)
        XCTAssertEqual(HomePlanner.plan(HomeSignals(onBattery: false, percent: 20)).tone, .calm, "plugged in is fine")
    }
}
