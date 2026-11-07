#if os(Windows)
import MonorailCore
import WinSDK

/// Monorail's shortcuts on Windows: Win+Alt with arrows and a few letters. Windows 11 and Server
/// 2025 keep some of those for themselves (CI found Win+Alt+arrows, W and F taken), so the set
/// falls back to Ctrl+Win+Alt, then Ctrl+Alt, with the same keys. What each action got is printed
/// at start.
enum WindowsKeys {
    struct Binding: Equatable {
        var action: Action
        var modifiers: UInt32
        var key: UInt32
        var label: String { WindowsKeys.label(modifiers: modifiers, key: key) }
    }

    static let alt: UInt32 = 0x0001, control: UInt32 = 0x0002, shift: UInt32 = 0x0004, win: UInt32 = 0x0008
    static let noRepeat: UInt32 = 0x4000

    /// The modifiers tried in turn for each shortcut (Shift is added when the shortcut has it).
    static let modifierChoices: [UInt32] = [win | alt, control | win | alt, control | alt]

    /// Action, key, and whether Shift is part of it.
    static let keymap: [(Action, UInt32, Bool)] = [
        (.focusLeft, 0x25, false), (.focusRight, 0x27, false), (.focusUp, 0x26, false), (.focusDown, 0x28, false),
        (.focusFirst, 0x24, false), (.focusLast, 0x23, false),
        (.moveLeft, 0x25, true), (.moveRight, 0x27, true), (.moveUp, 0x26, true), (.moveDown, 0x28, true),
        (.cycleWidth, 0x57, false), (.cycleWidthBackward, 0x57, true), (.toggleFullWidth, 0x46, false),
        (.consumeIntoLeft, 0xBC, false), (.expel, 0xBE, false),
        // Windows' virtual desktops (see WindowsDesktops): Page Down and Page Up, Shift to take the window along.
        (.nextWorkspace, 0x22, false), (.previousWorkspace, 0x21, false),
        (.moveToNextWorkspace, 0x22, true), (.moveToPreviousWorkspace, 0x21, true),
    ]

    /// The first choice for every action (Win+Alt…).
    static var defaults: [Binding] {
        keymap.map { Binding(action: $0.0, modifiers: modifierChoices[0] | ($0.2 ? shift : 0), key: $0.1) }
    }

    /// The shortcuts that are registered now, by WM_HOTKEY id − 1.
    private(set) static var active: [Binding] = []

    /// Registers a shortcut for every action and returns the actions that got none. All of them
    /// use the same modifiers when one set is entirely free (Win+Alt, else Ctrl+Win+Alt, else
    /// Ctrl+Alt), so they're easy to remember; otherwise each falls back on its own.
    @discardableResult
    static func register() -> [Action] {
        for choice in modifierChoices {
            unregister()
            if keymap.allSatisfy({ tryRegister($0.0, $0.1, choice | ($0.2 ? shift : 0)) }) { return [] }
        }
        unregister()
        var missing: [Action] = []
        for (action, key, withShift) in keymap
        where !modifierChoices.contains(where: { tryRegister(action, key, $0 | (withShift ? shift : 0)) }) {
            missing.append(action)
        }
        return missing
    }

    private static func tryRegister(_ action: Action, _ key: UInt32, _ modifiers: UInt32) -> Bool {
        guard ok(RegisterHotKey(nil, Int32(active.count + 1), UINT(modifiers | noRepeat), UINT(key))) else { return false }
        active.append(Binding(action: action, modifiers: modifiers, key: key))
        return true
    }

    static func unregister() {
        for index in active.indices { _ = UnregisterHotKey(nil, Int32(index + 1)) }
        active = []
    }

    static func binding(for action: Action) -> Binding? { active.first { $0.action == action } }

    /// The action for a WM_HOTKEY id.
    static func action(forHotKey id: Int) -> Action? {
        active.indices.contains(id - 1) ? active[id - 1].action : nil
    }

    static func label(modifiers: UInt32, key: UInt32) -> String {
        var parts: [String] = []
        if modifiers & control != 0 { parts.append("Ctrl") }
        if modifiers & win != 0 { parts.append("Win") }
        if modifiers & alt != 0 { parts.append("Alt") }
        if modifiers & shift != 0 { parts.append("Shift") }
        let names: [UInt32: String] = [0x25: "Left", 0x27: "Right", 0x26: "Up", 0x28: "Down", 0x24: "Home", 0x23: "End", 0xBC: ",", 0xBE: ".", 0x21: "PageUp", 0x22: "PageDown"]
        parts.append(names[key] ?? String(UnicodeScalar(UInt8(key))))
        return parts.joined(separator: "+")
    }

    /// Presses a shortcut through Windows' input system, as a person would (for the UI test).
    static func press(_ binding: Binding) {
        var keys: [UInt8] = []
        if binding.modifiers & control != 0 { keys.append(0x11) }  // VK_CONTROL
        if binding.modifiers & win != 0 { keys.append(0x5B) }  // VK_LWIN
        if binding.modifiers & alt != 0 { keys.append(0x12) }  // VK_MENU
        if binding.modifiers & shift != 0 { keys.append(0x10) }
        keys.append(UInt8(binding.key))
        for key in keys { keybd_event(key, 0, 0, 0) }
        for key in keys.reversed() { keybd_event(key, 0, DWORD(0x0002), 0) }  // KEYEVENTF_KEYUP
    }
}
#endif
