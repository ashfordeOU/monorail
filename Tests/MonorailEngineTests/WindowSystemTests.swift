import MonorailCore
import XCTest
@testable import MonorailEngine

final class WindowSystemTests: XCTestCase {
    func testFakeReportsEventsAndAppliesBatches() {
        let system = FakeWindowSystem()
        var events: [WindowEvent] = []
        system.onEvent = { events.append($0) }
        system.open(WindowInfo(id: 1, appID: "com.apple.Safari", appName: "Safari", frame: Rect(x: 100, y: 100, width: 800, height: 600)))
        system.open(WindowInfo(id: 2, appID: "com.apple.Notes", appName: "Notes", frame: Rect(x: 200, y: 150, width: 600, height: 500)))
        XCTAssertEqual(events, [.created(1), .focused(1), .created(2), .focused(2)])
        XCTAssertEqual(system.focusedWindow(), 2)

        system.apply([1: Rect(x: 8, y: 41, width: 744, height: 933), 2: Rect(x: 760, y: 41, width: 744, height: 933)])
        XCTAssertEqual(system.applied.count, 1)
        XCTAssertEqual(system.window(2)?.frame, Rect(x: 760, y: 41, width: 744, height: 933))

        system.close(2)
        XCTAssertEqual(events.last, .destroyed(2))
        XCTAssertEqual(system.focusedWindow(), 1)
        XCTAssertEqual(system.windows().map(\.id), [1])
    }

    func testWhatGetsTiled() {
        let frame = Rect(x: 0, y: 0, width: 800, height: 600)
        XCTAssertTrue(WindowInfo(id: 1, appID: "a", appName: "A", frame: frame).isTileable)
        XCTAssertFalse(WindowInfo(id: 2, appID: "a", appName: "A", frame: frame, isStandard: false).isTileable)
        XCTAssertFalse(WindowInfo(id: 3, appID: "a", appName: "A", frame: frame, isFullScreen: true).isTileable)
        XCTAssertFalse(WindowInfo(id: 4, appID: "a", appName: "A", frame: Rect(x: 0, y: 0, width: 40, height: 40)).isTileable)
    }
}
