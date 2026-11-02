import Foundation
import MonorailCore
@testable import MonorailEngine
import XCTest

final class SharedSettingsTests: XCTestCase {
    private func window(_ id: WindowID, app: String, name: String, title: String = "") -> WindowInfo {
        WindowInfo(id: id, appID: app, appName: name, title: title, frame: Rect(x: 100, y: 100, width: 800, height: 600))
    }

    func testReadsTheMacFormatAndKeepsDefaultsForMissingKeys() throws {
        let json = #"{"layout":{"gap":20,"edgeGap":4,"parkSliver":4,"widthPresets":[0.5,1],"defaultWidth":0.75,"centerMode":"never","tabBarHeight":28,"direction":"leftToRight"},"someMacOnlyKey":true}"#
        let read = try XCTUnwrap(SharedSettings(json: Data(json.utf8)))
        XCTAssertEqual(read.layout.gap, 20)
        XCTAssertEqual(read.layout.defaultWidth, 0.75)
        XCTAssertEqual(read.settings.animate, AppSettings().animate)
        XCTAssertNil(SharedSettings(json: Data("not json".utf8)))
    }

    func testMissingFileGivesDefaultsAndDefaultsCanBeWritten() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("monorail-\(UUID().uuidString)").appendingPathComponent("settings.json")
        XCTAssertEqual(SharedSettings.load(from: url), SharedSettings())
        XCTAssertTrue(SharedSettings.writeDefaultsIfMissing(to: url))
        XCTAssertFalse(SharedSettings.writeDefaultsIfMissing(to: url))
        XCTAssertEqual(SharedSettings.load(from: url).layout, LayoutConfig())
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testFloatRulesMatchAppIDsWindowsPathsNamesAndTitles() {
        var settings = AppSettings()
        settings.appRules = [
            AppRule(bundleID: "calc.exe", name: "Calculator", float: true),
            AppRule(bundleID: "com.example.chat", name: "Chat", float: true),
            AppRule(bundleID: "firefox", name: "Firefox", float: true, titleContains: "Picture-in-Picture"),
            AppRule(bundleID: "notepad.exe", name: "Notepad", float: false),
        ]
        let shared = SharedSettings(settings)
        XCTAssertTrue(shared.floats(window(1, app: #"C:\Windows\System32\calc.exe"#, name: "calc")))
        XCTAssertTrue(shared.floats(window(2, app: "com.example.chat", name: "Chat")))
        XCTAssertTrue(shared.floats(window(3, app: #"C:\Program Files\Mozilla Firefox\firefox.exe"#, name: "firefox", title: "Picture-in-Picture")))
        XCTAssertFalse(shared.floats(window(4, app: #"C:\Program Files\Mozilla Firefox\firefox.exe"#, name: "firefox", title: "Inbox")))
        XCTAssertFalse(shared.floats(window(5, app: #"C:\Windows\notepad.exe"#, name: "notepad")))
    }

    func testTheEngineLeavesFloatingWindowsAloneAndAppliesNewSettingsAtOnce() {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        system.open(window(1, app: "notepad.exe", name: "notepad"))
        system.open(window(2, app: "calc.exe", name: "calc"))
        engine.start()
        XCTAssertEqual(engine.strips[FakeWindowSystem.laptop.id]?.allWindows.sorted(), [1, 2])

        var settings = AppSettings()
        settings.appRules = [AppRule(bundleID: "calc.exe", name: "Calculator", float: true)]
        settings.layout.gap = 30
        engine.apply(SharedSettings(settings))
        XCTAssertEqual(engine.strips[FakeWindowSystem.laptop.id]?.allWindows, [1])
        XCTAssertFalse(engine.isManaged(2))
        XCTAssertEqual(engine.config.gap, 30)

        system.open(window(3, app: "calc.exe", name: "calc"))
        XCTAssertFalse(engine.isManaged(3))

        engine.apply(SharedSettings())
        XCTAssertTrue(engine.isManaged(2))
        XCTAssertTrue(engine.isManaged(3))
    }
}

final class SharedEnginePauseTests: XCTestCase {
    func testPausedLeavesWindowsAloneAndResumePicksUpTheDesktop() {
        let system = FakeWindowSystem()
        let engine = SharedEngine(system: system)
        let frame = Rect(x: 100, y: 100, width: 800, height: 600)
        system.open(WindowInfo(id: 1, appID: "a", appName: "A", frame: frame))
        system.open(WindowInfo(id: 2, appID: "a", appName: "A", frame: frame))
        engine.start()
        engine.pause()
        let moves = system.applied.count
        system.open(WindowInfo(id: 3, appID: "a", appName: "A", frame: frame))
        system.close(1)
        XCTAssertFalse(engine.perform(.focusLeft))
        XCTAssertEqual(system.applied.count, moves)
        XCTAssertTrue(engine.isManaged(1))
        engine.resume()
        XCTAssertFalse(engine.isPaused)
        XCTAssertEqual(engine.strips[FakeWindowSystem.laptop.id]?.allWindows.sorted(), [2, 3])
        XCTAssertGreaterThan(system.applied.count, moves)
    }
}
