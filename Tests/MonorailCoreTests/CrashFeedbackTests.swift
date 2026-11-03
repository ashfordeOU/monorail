import MonorailCore
import XCTest

final class CrashFeedbackTests: XCTestCase {
    private let ips = #"""
    {"app_name":"Monorail","app_version":"1.7.16","bug_type":"309"}
    {"exception":{"type":"EXC_BAD_ACCESS","signal":"SIGSEGV","subtype":"KERN_INVALID_ADDRESS at 0x0"},
     "termination":{"indicator":"Namespace SIGNAL, Code 11 at /Users/chak/Applications/Monorail.app"},
     "faultingThread":1,
     "usedImages":[{"name":"Monorail","path":"/Users/chak/Applications/Monorail.app/Contents/MacOS/Monorail"},{"name":"AppKit"}],
     "threads":[{"frames":[{"imageIndex":1,"symbol":"-[NSApplication run]"}]},
                {"triggered":true,"frames":[{"imageIndex":0,"symbol":"Engine.layout(animated:)"},{"imageIndex":0,"symbol":"Strip.reveal()"},{"imageIndex":1,"symbol":"_NSEventLoop"}]}]}
    """#

    func testAsksOncePerVersionAndNeverWhenOff() {
        XCTAssertTrue(CrashFeedback.shouldAsk(crashed: true, enabled: true, lastAskedVersion: nil, version: "1.7.16"))
        XCTAssertFalse(CrashFeedback.shouldAsk(crashed: true, enabled: true, lastAskedVersion: "1.7.16", version: "1.7.16"))
        XCTAssertTrue(CrashFeedback.shouldAsk(crashed: true, enabled: true, lastAskedVersion: "1.7.15", version: "1.7.16"))
        XCTAssertFalse(CrashFeedback.shouldAsk(crashed: true, enabled: false, lastAskedVersion: nil, version: "1.7.16"))
        XCTAssertFalse(CrashFeedback.shouldAsk(crashed: false, enabled: true, lastAskedVersion: nil, version: "1.7.16"))
    }

    func testSummaryHasTheCrashedThreadAndNothingPersonal() throws {
        let summary = try XCTUnwrap(CrashFeedback.summary(ips: ips))
        XCTAssertEqual(summary.exception, "EXC_BAD_ACCESS · SIGSEGV · KERN_INVALID_ADDRESS at 0x0")
        XCTAssertEqual(summary.frames, ["Monorail  Engine.layout(animated:)", "Monorail  Strip.reveal()", "AppKit  _NSEventLoop"])
        let body = CrashFeedback.issueBody(version: "1.7.16", macOS: "26.1", summary: summary)
        XCTAssertFalse(body.contains("chak"), body)
        XCTAssertFalse(body.contains("/Users"), body)
        XCTAssertTrue(body.contains("Monorail 1.7.16 · macOS 26.1"))
        XCTAssertTrue(body.contains("Engine.layout(animated:)"))
    }

    func testNoReportStillMakesAnIssue() {
        XCTAssertNil(CrashFeedback.summary(ips: "not a report"))
        XCTAssertTrue(CrashFeedback.issueBody(version: "1", macOS: "26", summary: nil).contains("No crash report"))
    }
}
