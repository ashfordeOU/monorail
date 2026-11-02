import MonorailCore
import XCTest

final class ClosedLidTests: XCTestCase {
    private func decide(awake: Bool = true, enabled: Bool = true, onlyOnPower: Bool = true, charging: Bool = true,
                        heat: AwakeHeat = .nominal, hot: Bool = false) -> ClosedLidDecision {
        AwakeRules.closedLid(awake: awake, enabled: enabled, onlyOnPower: onlyOnPower, charging: charging, heat: heat, hotThisSession: hot)
    }

    func testOnOnlyDuringStayAwakeWhenAskedFor() {
        XCTAssertEqual(decide(), .on)
        XCTAssertEqual(decide(awake: false), .off)
        XCTAssertEqual(decide(enabled: false), .off)
    }

    func testHeatStopsIt() {
        XCTAssertEqual(decide(heat: .fair), .on)
        guard case .stopped = decide(heat: .serious) else { return XCTFail("serious heat must stop it") }
        guard case .stopped = decide(heat: .critical) else { return XCTFail("critical heat must stop it") }
    }

    func testOnceHotItStaysOffForTheSessionEvenWhenCool() {
        guard case .stopped = decide(heat: .nominal, hot: true) else { return XCTFail("must stay off once hot") }
        // A new session starts cool again.
        XCTAssertEqual(decide(awake: false, hot: true), .off)
    }

    func testOnBatteryOnlyWhenAllowed() {
        guard case .stopped = decide(charging: false) else { return XCTFail("on battery it must stop") }
        XCTAssertEqual(decide(onlyOnPower: false, charging: false), .on)
        // Heat wins over everything.
        guard case .stopped(let why) = decide(onlyOnPower: false, charging: false, heat: .serious) else { return XCTFail() }
        XCTAssertTrue(why.contains("hot"))
    }

    func testLowPowerModeAndALowBatteryStopIt() {
        guard case .stopped = AwakeRules.closedLid(awake: true, enabled: true, onlyOnPower: true, charging: true,
                                                   heat: .nominal, hotThisSession: false, lowPowerMode: true) else { return XCTFail() }
        XCTAssertEqual(AwakeRules.closedLid(awake: true, enabled: true, onlyOnPower: false, charging: false,
                                            heat: .nominal, hotThisSession: false, battery: 50), .on)
        guard case .stopped = AwakeRules.closedLid(awake: true, enabled: true, onlyOnPower: false, charging: false,
                                                   heat: .nominal, hotThisSession: false, battery: 15) else { return XCTFail() }
        // Plugged in, the battery level doesn't matter.
        XCTAssertEqual(AwakeRules.closedLid(awake: true, enabled: true, onlyOnPower: false, charging: true,
                                            heat: .nominal, hotThisSession: false, battery: 5), .on)
    }

    func testPluggedInOnlyIsTheDefault() {
        XCTAssertTrue(AppSettings().awakeClosedLidOnlyOnPower)
        XCTAssertFalse(AppSettings().awakeClosedLid)
    }
}
