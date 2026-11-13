@testable import MonorailCore
import XCTest

final class SuiteRolesTests: XCTestCase {
    func testOneAppAloneLeads() {
        XCTAssertEqual(SuiteRoles.role(isStation: true, monorailRunning: false), .primary)
        XCTAssertEqual(SuiteRoles.role(isStation: false, monorailRunning: true), .primary)
        XCTAssertTrue(SuiteRoles.paused(.primary).isEmpty)
    }

    func testStationRestsWhileMonorailRuns() {
        XCTAssertEqual(SuiteRoles.role(isStation: true, monorailRunning: true), .resting)
        XCTAssertEqual(SuiteRoles.paused(.resting), Set(SuiteRoles.Job.allCases))
        XCTAssertEqual(SuiteRoles.role(isStation: true, monorailRunning: true, stepsBack: false), .primary, "unless you ask it not to")
    }

    func testAwakeHandoff() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(SuiteRoles.handoffMinutes(endsAt: now.addingTimeInterval(61), now: now), 2)
        XCTAssertEqual(SuiteRoles.handoffMinutes(endsAt: now.addingTimeInterval(5), now: now), 1)
        XCTAssertNil(SuiteRoles.handoffMinutes(endsAt: nil, now: now))
    }
}
