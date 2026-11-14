import XCTest
@testable import MonorailCore

final class SuiteRulesTests: XCTestCase {
    func testLeadsAloneOrWhenOtherHasItOff() {
        XCTAssertEqual(SuiteRules.verdict(.alertDisk, me: .monorail, mineOn: true, otherOwns: nil), .lead)
        XCTAssertEqual(SuiteRules.verdict(.alertDisk, me: .monorail, mineOn: true, otherOwns: ["island"]), .lead)
        XCTAssertEqual(SuiteRules.verdict(.alertDisk, me: .monorail, mineOn: false, otherOwns: ["alerts.disk"]), .lead)
    }

    func testAgreedOwners() {
        XCTAssertEqual(SuiteRules.verdict(.alertDisk, me: .monorail, mineOn: true, otherOwns: ["alerts.disk"]), .rest)
        XCTAssertEqual(SuiteRules.verdict(.alertDisk, me: .keeper, mineOn: true, otherOwns: ["alerts.disk"]), .lead)
        XCTAssertEqual(SuiteRules.verdict(.clipboard, me: .monorail, mineOn: true, otherOwns: ["clipboard"]), .lead)
        XCTAssertEqual(SuiteRules.verdict(.clipboard, me: .keeper, mineOn: true, otherOwns: ["clipboard"]), .rest)
        XCTAssertEqual(SuiteRules.verdict(.launcher, me: .monorail, mineOn: true, otherOwns: ["launcher"]), .lead)
        XCTAssertEqual(SuiteRules.verdict(.launcher, me: .keeper, mineOn: true, otherOwns: ["launcher"]), .lead)
    }

    func testIslandAsksUntilChosenThenBothAgree() {
        XCTAssertEqual(SuiteRules.verdict(.island, me: .monorail, mineOn: true, otherOwns: ["island"]), .ask)
        let keeper = SuiteRules.Choice(app: .keeper, at: 10)
        XCTAssertEqual(SuiteRules.verdict(.island, me: .monorail, mineOn: true, otherOwns: ["island"], choice: keeper), .rest)
        XCTAssertEqual(SuiteRules.verdict(.island, me: .keeper, mineOn: true, otherOwns: ["island"], choice: keeper), .lead)
    }

    func testNewestChoiceWinsAndTiesGoToKeeper() {
        let a = SuiteRules.Choice(app: .monorail, at: 20)
        let b = SuiteRules.Choice(app: .keeper, at: 10)
        XCTAssertEqual(SuiteRules.latest(a, b), a)
        XCTAssertEqual(SuiteRules.latest(nil, b), b)
        XCTAssertEqual(SuiteRules.latest(SuiteRules.Choice(app: .monorail, at: 5), SuiteRules.Choice(app: .keeper, at: 5))?.app, .keeper)
        // A choice overrides the agreed owner.
        XCTAssertEqual(SuiteRules.verdict(.alertDisk, me: .monorail, mineOn: true, otherOwns: ["alerts.disk"], choice: a), .lead)
    }

    func testOwnsObjectRoundTrips() {
        let owns = SuiteArea.ownsObject([.island, .clipboard, .alertDisk])
        XCTAssertEqual(owns["island"] as? Bool, true)
        XCTAssertEqual(owns["breaks"] as? Bool, false)
        XCTAssertEqual((owns["alerts"] as? [String: Any])?["disk"] as? Bool, true)
        XCTAssertEqual(SuiteArea.announced(in: owns), ["island", "clipboard", "alerts.disk"])
    }

    func testHelloCarriesAreasChoicesAndLive() {
        let body: [String: Any] = [
            "app": "Keeper", "bundleID": "io.github.ashfordeou.keeper", "pid": 42,
            "owns": ["awake": true, "island": true, "alerts": ["disk": true, "ai": false]],
            "prefer": ["island": "keeper"], "preferAt": ["island": 1234],
            "state": ["live": [["kind": "timer", "title": "4:10", "symbol": "timer", "level": 0.5]]],
        ]
        let hello = PeerHello.decode(body)
        XCTAssertEqual(hello?.areas, ["awake", "island", "alerts.disk"])
        XCTAssertEqual(hello?.owns.awake, true)
        XCTAssertEqual(hello?.choice(for: .island), SuiteRules.Choice(app: .keeper, at: 1234))
        XCTAssertEqual(hello?.live.first?.kind, "timer")
        XCTAssertEqual(hello?.live.first?.level, 0.5)
    }
}
