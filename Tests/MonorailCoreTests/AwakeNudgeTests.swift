import MonorailCore
import XCTest

final class AwakeNudgeTests: XCTestCase {
    func testNudgesOnlyDuringStayAwakeWithChatAppsKeptAvailableAfterFiftySecondsIdle() {
        XCTAssertFalse(AwakeNudge.isDue(awake: true, keepAvailable: true, idle: 49.9))
        XCTAssertTrue(AwakeNudge.isDue(awake: true, keepAvailable: true, idle: 50))
        XCTAssertTrue(AwakeNudge.isDue(awake: true, keepAvailable: true, idle: 600))
        XCTAssertFalse(AwakeNudge.isDue(awake: false, keepAvailable: true, idle: 600))
        XCTAssertFalse(AwakeNudge.isDue(awake: true, keepAvailable: false, idle: 600))
        XCTAssertTrue(AwakeNudge.isDue(awake: true, keepAvailable: true, idle: 10, limit: 5))
    }

    func testIdleTimeAcrossTheTickCountWrap() {
        XCTAssertEqual(AwakeNudge.idleSeconds(now: 61_000, lastInput: 1_000), 60)
        XCTAssertEqual(AwakeNudge.idleSeconds(now: 4_000, lastInput: UInt32.max - 5_999), 10)
        XCTAssertEqual(AwakeNudge.idleSeconds(now: 5, lastInput: 5), 0)
    }
}
