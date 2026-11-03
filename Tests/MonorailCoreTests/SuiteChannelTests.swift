import Foundation
import MonorailCore
import XCTest

final class SuiteChannelTests: XCTestCase {
    private var container: URL!

    override func setUp() {
        container = FileManager.default.temporaryDirectory.appendingPathComponent("suite-\(UUID().uuidString)")
    }

    override func tearDown() { try? FileManager.default.removeItem(at: container) }

    func testHelloAndStateRoundTripInTheAgreedLayout() {
        let channel = SuiteChannel(container: container)
        channel.writeHello("monorail", ["app": "Monorail", "pid": 42, "state": ["awake": true]])
        XCTAssertEqual(channel.hello(of: "monorail")?["app"] as? String, "Monorail")
        XCTAssertTrue(FileManager.default.fileExists(atPath: container.appendingPathComponent("Library/Application Support/Ashforde/hello/monorail.json").path))
        channel.writeHello("monorail", ["app": "Monorail", "pid": 43])
        XCTAssertEqual(channel.hello(of: "monorail")?["pid"] as? Int, 43, "rewritten in place")
        channel.writeState("monorail", ["paused": false])
        XCTAssertEqual(channel.state(of: "monorail")?["paused"] as? Bool, false)
        XCTAssertNil(channel.hello(of: "keeper"))
    }

    func testRequestsAreTakenOnceAndAnswered() {
        let keeper = SuiteChannel(container: container), monorail = SuiteChannel(container: container)
        let id = keeper.send(to: "monorail", from: "keeper", op: "awake.on", args: ["for": "30m"])
        keeper.send(to: "monorail", from: "keeper", op: "rm -rf", args: [:])
        let requests = monorail.takeRequests(for: "monorail")
        XCTAssertEqual(requests.map(\.op), ["awake.on"], "only allowed operations")
        XCTAssertEqual(requests.first?.args["for"], "30m")
        XCTAssertTrue(monorail.takeRequests(for: "monorail").isEmpty, "taken once")
        monorail.respond(to: requests[0], ok: true, result: ["awake": true])
        XCTAssertEqual(keeper.response(id, for: "keeper")?["ok"] as? Bool, true)
    }

    func testTheAgreedNames() {
        XCTAssertEqual(SuiteChannel.appGroup, "D69G45342Y.group.ashforde.suite")
        XCTAssertEqual(SuiteChannel.doorbell, "com.ashforde.suite.changed")
    }
}
