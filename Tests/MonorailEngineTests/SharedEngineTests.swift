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

final class SharedEngineQuietTests: XCTestCase {
    func testScreenChangesThatChangeNothingMoveNothing() {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        engine.start()
        system.open(WindowInfo(id: 1, appID: "a", appName: "A", frame: Rect(x: 100, y: 100, width: 800, height: 600)))
        system.open(WindowInfo(id: 2, appID: "b", appName: "B", frame: Rect(x: 100, y: 100, width: 800, height: 600)))
        let batches = system.applied.count
        // macOS reports screen changes it makes itself (Dock, menu bar): nothing to do.
        for _ in 0..<5 { engine.handle(.displaysChanged) }
        XCTAssertEqual(system.applied.count, batches)
        // A real change (the Dock grew) lays out again.
        var laptop = FakeWindowSystem.laptop
        laptop.visibleFrame.height -= 60
        system.displays = [laptop]
        engine.handle(.displaysChanged)
        XCTAssertEqual(system.applied.count, batches + 1)
    }

    func testOnlyWindowsWhosePlaceChangedAreMoved() {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        engine.start()
        for id: WindowID in 1...3 {
            system.open(WindowInfo(id: id, appID: "a\(id)", appName: "A", frame: Rect(x: 100, y: 100, width: 800, height: 600)))
        }
        let batches = system.applied.count
        engine.layout()
        XCTAssertEqual(system.applied.count, batches, "a layout with nothing changed applies nothing")
        system.close(3)
        // Any batch after the close moves only windows that are still there.
        for batch in system.applied.dropFirst(batches) { XCTAssertFalse(batch.keys.contains(3)) }
        XCTAssertNil(engine.lastApplied[3])
    }
}

final class SharedEngineActionTests: XCTestCase {
    private func start(_ count: Int) -> (FakeWindowSystem, SharedEngine) {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        engine.start()
        for id in 1...count {
            system.open(WindowInfo(id: WindowID(id), appID: "a\(id)", appName: "A", frame: Rect(x: 100, y: 100, width: 800, height: 600)))
        }
        return (system, engine)
    }

    private var laptop: String { FakeWindowSystem.laptop.id }

    func testFocusMovesAlongTheStripAndFocusesTheWindow() {
        let (system, engine) = start(3)
        XCTAssertEqual(system.focusedWindow(), 3)
        XCTAssertTrue(engine.perform(.focusLeft))
        XCTAssertEqual(system.focusedWindow(), 2)
        XCTAssertTrue(engine.perform(.focusFirst))
        XCTAssertEqual(system.focusedWindow(), 1)
        XCTAssertFalse(engine.perform(.focusLeft), "nothing further left")
        XCTAssertTrue(engine.perform(.focusLast))
        XCTAssertEqual(system.focusedWindow(), 3)
    }

    func testMovingASlideReordersTheStripAndScreen() {
        let (system, engine) = start(2)
        system.focus(1)
        XCTAssertTrue(engine.perform(.moveRight))
        XCTAssertEqual(engine.strips[laptop]?.allWindows, [2, 1])
        let frames = system.applied.last ?? [:]
        XCTAssertLessThan(frames[2]?.x ?? .infinity, frames[1]?.x ?? 0, "window 2 is now on the left")
    }

    func testWidthsCycleThroughThePresets() {
        let (system, engine) = start(1)
        let before = system.window(1)!.frame.width
        XCTAssertTrue(engine.perform(.cycleWidth))
        XCTAssertNotEqual(system.window(1)!.frame.width, before)
        XCTAssertTrue(engine.perform(.toggleFullWidth))
        XCTAssertEqual(system.window(1)!.frame.width, FakeWindowSystem.laptop.visibleFrame.width - 16, accuracy: 1)
    }

    func testStackingAndUnstacking() {
        let (system, engine) = start(2)
        XCTAssertTrue(engine.perform(.consumeIntoLeft))
        XCTAssertEqual(engine.strips[laptop]?.columns.count, 1)
        let frames = system.applied.last ?? [:]
        XCTAssertNotNil(frames[1])
        XCTAssertTrue(engine.perform(.expel))
        XCTAssertEqual(engine.strips[laptop]?.columns.count, 2)
    }

    func testActionsItDoesNotRunSayNo() {
        let (_, engine) = start(1)
        XCTAssertFalse(engine.perform(.overview))
        XCTAssertFalse(SharedEngine.supportedActions.contains(.overview))
    }
}

final class SharedEngineMinimumWidthTests: XCTestCase {
    func testAnAppThatWontShrinkGetsAWideEnoughSlide() {
        let system = FakeWindowSystem()
        system.minimumWidths["notepad"] = 900
        let engine = SharedEngine(system: system)
        let frame = Rect(x: 100, y: 100, width: 800, height: 600)
        system.open(WindowInfo(id: 1, appID: "notepad", appName: "Notepad", frame: frame))
        system.open(WindowInfo(id: 2, appID: "other", appName: "Other", frame: frame))
        engine.start()
        XCTAssertEqual(engine.minimumWidths["notepad"] ?? 0, 900, accuracy: 0.5)
        // After learning, the engine asks for at least what the app insists on, and the
        // neighbour starts after it: no overlap.
        let a = system.window(1)!.frame, b = system.window(2)!.frame
        XCTAssertGreaterThanOrEqual(engine.lastApplied[1]?.width ?? 0, 899)
        XCTAssertEqual(a.intersection(b).area, 0, "\(a) / \(b)")
    }

    func testStackedTilesMakeRoomForTheirMinimum() {
        let system = FakeWindowSystem()
        system.minimumWidths["notepad"] = 460
        let engine = SharedEngine(system: system)
        let frame = Rect(x: 100, y: 100, width: 800, height: 600)
        system.open(WindowInfo(id: 1, appID: "notepad", appName: "Notepad", frame: frame))
        system.open(WindowInfo(id: 2, appID: "notepad", appName: "Notepad", frame: frame))
        engine.start()
        system.focus(2)
        XCTAssertTrue(engine.perform(.consumeIntoLeft))
        XCTAssertGreaterThanOrEqual(engine.lastApplied[1]?.width ?? 0, 459)
        XCTAssertGreaterThanOrEqual(engine.lastApplied[2]?.width ?? 0, 459)
        let a = system.window(1)!.frame, b = system.window(2)!.frame
        XCTAssertEqual(a.intersection(b).area, 0, "\(a) / \(b)")
    }
}
