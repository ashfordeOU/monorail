import XCTest
@testable import MonorailCore

final class ShortcutClashTests: XCTestCase {
    private func hotkey(_ keyCode: Int, _ flags: Int, enabled: Bool = true) -> [String: Any] {
        ["enabled": enabled, "value": ["parameters": [65535, keyCode, flags], "type": "standard"]]
    }

    func testParsesTurnedOnShortcutsOnly() {
        let parsed = SystemShortcuts.parse([
            "79": hotkey(123, 0x40000),             // ⌃← Move left a space
            "81": hotkey(124, 0x40000, enabled: false),
            "64": hotkey(49, 0x100000),             // ⌘Space
            "999": hotkey(65535, 0x100000),         // no key
        ])
        XCTAssertEqual(parsed.map(\.id), [64, 79])
        XCTAssertEqual(parsed[1].shortcut, Shortcut(keyCode: KeyCode.left, modifiers: .control))
        XCTAssertEqual(parsed[1].name, "Move left a space")
        XCTAssertEqual(SystemShortcuts.name(for: 120), "Switch to Desktop 3")
    }

    func testFindsClashWithMacOSAndSuggestsAFreeKey() {
        let taken = Shortcut(keyCode: KeyCode.left, modifiers: [.control, .option])
        var keymap = Keymap(bindings: [:])
        keymap.bindings[.focusLeft] = [taken]
        let system = [SystemShortcuts.Entry(id: 79, name: "Move left a space", shortcut: taken)]
        let clashes = keymap.clashes(with: system)
        XCTAssertEqual(clashes.count, 1)
        XCTAssertEqual(clashes[0].usedBy, "macOS: Move left a space")
        let suggestion = try! XCTUnwrap(clashes[0].suggestion)
        XCTAssertNotEqual(suggestion, taken)
        XCTAssertEqual(suggestion.keyCode, KeyCode.left)
    }

    func testDefaultKeymapHasNoClashesWithItself() {
        XCTAssertTrue(Keymap.default.clashes(with: []).isEmpty)
    }
}

final class ReservedEdgesTests: XCTestCase {
    func testInsetsEachEdge() {
        let area = Rect(x: 0, y: 25, width: 1440, height: 875)
        let inset = ReservedEdges(top: 30, bottom: 10, left: 50, right: 0).inset(area)
        XCTAssertEqual(inset, Rect(x: 50, y: 55, width: 1390, height: 835))
        XCTAssertEqual(ReservedEdges().inset(area), area)
    }

    func testNeverSmallerThanAUsableArea() {
        let inset = ReservedEdges(top: 900, left: 2000).inset(Rect(x: 0, y: 0, width: 1000, height: 800))
        XCTAssertEqual(inset.width, 200)
        XCTAssertEqual(inset.height, 200)
    }

    func testOldSettingsDecodeWithDefaults() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(settings.pauseForStageManager)
        XCTAssertTrue(settings.portraitStacks)
        XCTAssertFalse(settings.restoreHidesOthers)
        XCTAssertEqual(settings.appAppearance, .system)
        XCTAssertTrue(settings.reservedEdges.isEmpty)
    }
}

final class PortraitTests: XCTestCase {
    func testPortraitTurnsSideBySideIntoStacked() {
        XCTAssertEqual(Arrangement.columns.forPortrait, .stack)
        XCTAssertEqual(Arrangement.mainLeft.forPortrait, .mainTop)
        XCTAssertEqual(Arrangement.grid.forPortrait, .grid)
    }
}
