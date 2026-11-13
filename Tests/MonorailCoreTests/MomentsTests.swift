import XCTest
@testable import MonorailCore

final class MomentsTests: XCTestCase {
    func testHeatFromThermalState() {
        XCTAssertEqual(Heat(thermalState: 0), .normal)
        XCTAssertEqual(Heat(thermalState: 3), .throttling)
        XCTAssertEqual(Heat(thermalState: 9), .throttling)
        XCTAssertFalse(Heat.warm.needsYou)
        XCTAssertTrue(Heat.hot.needsYou)
    }

    func testHeatAdviceNamesTheBusiestApp() {
        XCTAssertEqual(Heat.hot.advice(busiest: "Xcode", cpuPercent: 240), "Xcode is using 240% of the processor. Pausing it lets the Mac cool down.")
        XCTAssertEqual(Heat.warm.advice(busiest: nil, cpuPercent: nil), "A little warm. Fine for now.")
    }

    func testCallState() {
        XCTAssertFalse(CallState().isOnCall)
        XCTAssertEqual(CallState(micInUse: true).title, "On a call")
        XCTAssertEqual(CallState(micInUse: true, cameraInUse: true).title, "On a video call")
    }

    func testCallBattery() {
        XCTAssertEqual(Moments.callBattery(minutesLeft: 40, video: true), "About 32 min of battery for this call. Plug in to be safe.")
        XCTAssertEqual(Moments.callBattery(minutesLeft: 180, video: false), "Enough battery for about 3 hr of calling.")
        XCTAssertNil(Moments.callBattery(minutesLeft: nil, video: false))
    }

    func testUnplugNudgeOncePerCharge() {
        XCTAssertTrue(Moments.shouldNudgeToUnplug(percent: 80, isCharging: true, limit: 80, alreadyNudged: false))
        XCTAssertFalse(Moments.shouldNudgeToUnplug(percent: 80, isCharging: true, limit: 80, alreadyNudged: true))
        XCTAssertFalse(Moments.shouldNudgeToUnplug(percent: 79, isCharging: true, limit: 80, alreadyNudged: false))
        XCTAssertFalse(Moments.shouldNudgeToUnplug(percent: 100, isCharging: true, limit: 100, alreadyNudged: false))
    }

    func testPlannerRaisesHeatAndCalls() {
        let hot = HomePlanner.plan(HomeSignals(heat: .hot))
        XCTAssertEqual(hot.cards.first, .heat)
        XCTAssertEqual(hot.title, "Running hot")
        let call = HomePlanner.plan(HomeSignals(onCall: true))
        XCTAssertEqual(call.cards.first, .call)
        XCTAssertEqual(call.title, "On a call")
        XCTAssertEqual(call.tone, .calm)
        XCTAssertFalse(HomePlanner.plan(HomeSignals()).cards.contains(.heat))
    }
}
