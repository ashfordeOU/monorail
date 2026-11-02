import MonorailCore
@testable import MonorailEngine
import XCTest

final class SharedEngineTests: XCTestCase {
    private func window(_ id: WindowID, app: String = "com.example.app", x: Double = 100) -> WindowInfo {
        WindowInfo(id: id, appID: app, appName: app, frame: Rect(x: x, y: 100, width: 800, height: 600))
    }

    private let laptop = FakeWindowSystem.laptop
    private let external = DisplayInfo(id: "external", name: "Studio Display",
                                       frame: Rect(x: 1512, y: 0, width: 2560, height: 1440),
                                       visibleFrame: Rect(x: 1512, y: 25, width: 2560, height: 1415))

    func testTilesEveryWindowSideBySideInOneBatch() {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        system.open(window(1))
        system.open(window(2))
        engine.start()
        XCTAssertEqual(engine.strips[laptop.id]?.allWindows.sorted(), [1, 2])
        let frames = system.applied.last ?? [:]
        XCTAssertEqual(Set(frames.keys), [1, 2])
        // Half width each, side by side, inside the visible area.
        let a = frames[1]!, b = frames[2]!
        XCTAssertEqual(a.width, b.width, accuracy: 1)
        XCTAssertNotEqual(a.x, b.x)
        XCTAssertGreaterThanOrEqual(min(a.y, b.y), laptop.visibleFrame.y)
    }

    func testNewWindowsSlideInAndClosedOnesLeave() {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        engine.start()
        system.open(window(1))
        system.open(window(2))
        system.open(window(3))
        XCTAssertEqual(engine.strips[laptop.id]?.allWindows, [1, 2, 3])
        XCTAssertEqual(engine.strips[laptop.id]?.focusedWindow, 3)
        system.close(2)
        XCTAssertEqual(engine.strips[laptop.id]?.allWindows, [1, 3])
        XCTAssertFalse(engine.isManaged(2))
    }

    func testDialogsAndTinyWindowsAreNotTiled() {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        engine.start()
        system.open(WindowInfo(id: 5, appID: "a", appName: "A", frame: Rect(x: 0, y: 0, width: 400, height: 300), isStandard: false))
        system.open(WindowInfo(id: 6, appID: "a", appName: "A", frame: Rect(x: 0, y: 0, width: 30, height: 30)))
        XCTAssertNil(engine.strips[laptop.id])
        XCTAssertTrue(system.applied.isEmpty)
    }

    func testMinimisedWindowsComeBackWhereTheyWere() {
        let system = FakeWindowSystem(displays: [laptop, external])
        let engine = SharedEngine(system: system)
        engine.start()
        system.open(window(1, x: 2000))
        XCTAssertEqual(engine.displayOf[1], "external")
        system.setMinimized(1, true)
        XCTAssertFalse(engine.isManaged(1))
        system.move(1, to: Rect(x: 50, y: 50, width: 800, height: 600))
        system.setMinimized(1, false)
        XCTAssertEqual(engine.displayOf[1], "external")
    }

    func testFocusScrollsTheStrip() {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        engine.start()
        for id: WindowID in 1...4 { system.open(window(id)) }
        system.focus(1)
        XCTAssertEqual(engine.strips[laptop.id]?.focusedWindow, 1)
        let frame = system.applied.last?[1]
        XCTAssertNotNil(frame)
        XCTAssertGreaterThanOrEqual(frame!.x, laptop.visibleFrame.x)
        XCTAssertLessThanOrEqual(frame!.maxX, laptop.visibleFrame.maxX)
    }

    func testWindowsOnAnUnpluggedDisplayMoveToTheOneLeft() {
        let system = FakeWindowSystem(displays: [laptop, external])
        let engine = SharedEngine(system: system)
        engine.start()
        system.open(window(1, x: 100))
        system.open(window(2, x: 2000))
        XCTAssertEqual(engine.displayOf[2], "external")
        system.displays = [laptop]
        engine.handle(.displaysChanged)
        XCTAssertEqual(engine.displayOf[2], laptop.id)
        XCTAssertEqual(engine.strips[laptop.id]?.allWindows.sorted(), [1, 2])
        XCTAssertNil(engine.strips["external"])
    }

    func testHiddenAppsLeaveAndComeBack() {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        engine.start()
        system.open(window(1, app: "mail"))
        system.open(window(2, app: "notes"))
        engine.handle(.appHidden(appID: "mail"))
        XCTAssertEqual(engine.strips[laptop.id]?.allWindows, [2])
        engine.handle(.appShown(appID: "mail"))
        XCTAssertEqual(Set(engine.strips[laptop.id]?.allWindows ?? []), [1, 2])
    }
}
