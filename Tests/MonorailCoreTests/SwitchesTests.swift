@testable import MonorailCore
import XCTest

final class SwitchesTests: XCTestCase {
    func testCatalogue() {
        XCTAssertEqual(Set(SwitchCatalogue.all.map(\.id)).count, SwitchCatalogue.all.count)
        XCTAssertTrue(SwitchCatalogue.available(appStore: true).allSatisfy(\.inSignalbox))
        XCTAssertFalse(SwitchCatalogue.available(appStore: true).contains { $0.id == "showHiddenFiles" })
        XCTAssertEqual(SwitchCatalogue.find("emptyTrash")?.isAction, true)
        for mode in Mode.starters { for id in mode.switches.keys { XCTAssertNotNil(SwitchCatalogue.find(id), id) } }
    }

    func testTriggers() {
        let ctx = ModeContext(runningApps: ["us.zoom.xos"], sharingScreen: true, displays: ["LG UltraFine"], onBattery: true, weekday: 3, minutes: 23 * 60)
        XCTAssertTrue(ctx.matches(.app("us.zoom.xos")))
        XCTAssertTrue(ctx.matches(.display("ultrafine")))
        XCTAssertFalse(ctx.matches(.onPower))
        XCTAssertTrue(ctx.matches(.schedule(days: [3], start: 22 * 60, end: 6 * 60)))
        var morning = ctx
        morning.weekday = 4
        morning.minutes = 5 * 60
        XCTAssertTrue(morning.matches(.schedule(days: [3], start: 22 * 60, end: 6 * 60)))
        XCTAssertFalse(morning.matches(.schedule(days: [2, 3, 4, 5, 6], start: 9 * 60, end: 17 * 60)))
        XCTAssertEqual(ModeTrigger.schedule(days: [2, 3, 4, 5, 6], start: 540, end: 1020).title, "Weekdays 09:00–17:00")
        let on = ModePlanner.triggered(Mode.starters, context: ctx)
        XCTAssertEqual(on, ["recording"])
    }

    func testStartAndStopPutThingsBack() {
        let mode = Mode(name: "Rec", switches: ["hideDock": true, "darkMode": true, "emptyTrash": true])
        let plan = ModePlanner.start(mode, current: ["hideDock": false, "darkMode": true])
        XCTAssertEqual(plan.set, ["hideDock": true, "emptyTrash": true])
        XCTAssertEqual(plan.remember, ["hideDock": false])
        XCTAssertEqual(ModePlanner.stop(remembered: plan.remember, stillWanted: [:]), ["hideDock": false])
        XCTAssertEqual(ModePlanner.stop(remembered: plan.remember, stillWanted: ["hideDock": true]), [:])
    }

    func testModesRoundTrip() throws {
        let data = try JSONEncoder().encode(Mode.starters)
        XCTAssertEqual(try JSONDecoder().decode([Mode].self, from: data), Mode.starters)
    }

    func testQuickCalc() {
        XCTAssertEqual(QuickCalc.evaluate("12*4.5"), 54)
        XCTAssertEqual(QuickCalc.evaluate("(3+4)^2"), 49)
        XCTAssertEqual(QuickCalc.evaluate("2^3^2"), 512)
        XCTAssertEqual(QuickCalc.evaluate("15% of 80"), 12)
        XCTAssertEqual(QuickCalc.evaluate("-5 + 2 × 3"), 1)
        XCTAssertEqual(QuickCalc.evaluate("1,200/4"), 300)
        XCTAssertNil(QuickCalc.evaluate("1/0"))
        XCTAssertNil(QuickCalc.evaluate("hello"))
        XCTAssertNil(QuickCalc.evaluate("42"))
        XCTAssertNil(QuickCalc.evaluate("(1+2"))
        XCTAssertEqual(QuickCalc.format(54), "54")
        XCTAssertEqual(QuickCalc.format(1.0 / 3), "0.3333333333")
    }
}

final class NotchActivityTests: XCTestCase {
    func testPickAndCountdown() {
        let list = [NotchActivity(.charging, symbol: "bolt", text: "82%", tint: "green"),
                    NotchActivity(.sharing, symbol: "rectangle.on.rectangle", text: "Sharing", tint: "red"),
                    NotchActivity(.timer, symbol: "timer", text: "24:10", tint: "orange")]
        XCTAssertEqual(NotchActivity.pick(list)?.top.kind, .sharing)
        XCTAssertEqual(NotchActivity.pick(list)?.more, 2)
        XCTAssertNil(NotchActivity.pick([]))
        XCTAssertEqual(NotchActivity.countdown(24 * 60 + 10), "24:10")
        XCTAssertEqual(NotchActivity.countdown(3723), "1:02:03")
    }
}
