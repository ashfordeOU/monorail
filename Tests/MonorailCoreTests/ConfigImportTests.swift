import XCTest
@testable import MonorailCore

final class ConfigImportTests: XCTestCase {
    func testAeroSpace() {
        let toml = """
            # my config
            [gaps]
            inner.horizontal = 12
            [mode.main.binding]
            alt-h = 'focus left'
            alt-shift-l = "move right"
            alt-3 = 'workspace 3'
            alt-shift-2 = 'move-node-to-workspace 2'
            alt-f = 'fullscreen'
            alt-x = 'exec-and-forget open -a Terminal'

            [[on-window-detected]]
            if.app-id = 'com.apple.finder'
            run = 'layout floating'

            [[on-window-detected]]
            if.app-id = "com.tinyspeck.slackmacgap"
            run = ['move-node-to-workspace 4']
            """
        let plan = ConfigImport.aeroSpace(toml)
        XCTAssertEqual(plan.gap, 12)
        XCTAssertEqual(plan.floatApps, ["com.apple.finder"])
        XCTAssertEqual(plan.workspaceApps.map(\.app), ["com.tinyspeck.slackmacgap"])
        XCTAssertEqual(plan.workspaceApps.map(\.workspace), [4])
        let actions = plan.bindings.map(\.action)
        XCTAssertEqual(actions, [.focusLeft, .moveRight, Action(rawValue: "workspace-3")!, Action(rawValue: "move-to-workspace-2")!, .toggleFullWidth])
        XCTAssertEqual(plan.bindings[0].shortcut, Shortcut(keyCode: KeyCode.h, modifiers: [.option]))
        XCTAssertEqual(plan.bindings[1].shortcut, Shortcut(keyCode: KeyCode.l, modifiers: [.option, .shift]))
        XCTAssertEqual(plan.skipped.count, 1)
    }

    func testYabaiAndSkhd() {
        let yabairc = """
            yabai -m config window_gap 8
            yabai -m rule --add app="^System Settings$" manage=off
            yabai -m rule --add app="Slack" space=3
            """
        let skhd = """
            # focus
            alt - h : yabai -m window --focus west
            shift + alt - l : yabai -m window --swap east
            alt - 2 : yabai -m space --focus 2
            alt - t : yabai -m window --toggle float
            alt - return : open -a Terminal
            """
        let plan = ConfigImport.yabai(yabairc: yabairc, skhdrc: skhd)
        XCTAssertEqual(plan.gap, 8)
        XCTAssertEqual(plan.floatApps, ["System Settings"])
        XCTAssertEqual(plan.workspaceApps.first?.workspace, 3)
        XCTAssertEqual(plan.bindings.map(\.action), [.focusLeft, .moveRight, Action(rawValue: "workspace-2")!, .toggleFloat])
        XCTAssertEqual(plan.bindings[1].shortcut.modifiers, [.option, .shift])
        XCTAssertTrue(plan.summary.contains("4 shortcuts"))
    }

    func testRectangle() {
        let defaults: [String: Any] = [
            "leftHalf": ["keyCode": 123, "modifierFlags": (1 << 18) | (1 << 19)],
            "maximize": ["keyCode": 36, "modifierFlags": (1 << 18) | (1 << 19)],
            "gapSize": 6.0,
        ]
        let plan = ConfigImport.rectangle(defaults)
        XCTAssertEqual(plan.gap, 6)
        XCTAssertEqual(Set(plan.bindings.map(\.action)), [.snapLeftHalf, .snapMaximize])
        XCTAssertEqual(plan.bindings.first { $0.action == .snapLeftHalf }?.shortcut.modifiers, [.control, .option])
    }
}
