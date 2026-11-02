#if os(Windows)
import MonorailCore
import WinSDK

/// Monorail's shortcuts on Windows: Win+Alt with arrows and a few letters, which Windows leaves
/// free (Win+Ctrl switches virtual desktops; Win+Alt+G, R, B, D, T and K belong to Windows).
enum WindowsKeys {
    struct Binding {
        var action: Action
        var modifiers: UInt32
        var key: UInt32
        var label: String
    }

    static let alt: UInt32 = 0x0001, control: UInt32 = 0x0002, shift: UInt32 = 0x0004, win: UInt32 = 0x0008
    static let noRepeat: UInt32 = 0x4000

    static let defaults: [Binding] = [
        Binding(action: .focusLeft, modifiers: win | alt, key: 0x25, label: "Win+Alt+Left"),
        Binding(action: .focusRight, modifiers: win | alt, key: 0x27, label: "Win+Alt+Right"),
        Binding(action: .focusUp, modifiers: win | alt, key: 0x26, label: "Win+Alt+Up"),
        Binding(action: .focusDown, modifiers: win | alt, key: 0x28, label: "Win+Alt+Down"),
        Binding(action: .focusFirst, modifiers: win | alt, key: 0x24, label: "Win+Alt+Home"),
        Binding(action: .focusLast, modifiers: win | alt, key: 0x23, label: "Win+Alt+End"),
        Binding(action: .moveLeft, modifiers: win | alt | shift, key: 0x25, label: "Win+Alt+Shift+Left"),
        Binding(action: .moveRight, modifiers: win | alt | shift, key: 0x27, label: "Win+Alt+Shift+Right"),
        Binding(action: .moveUp, modifiers: win | alt | shift, key: 0x26, label: "Win+Alt+Shift+Up"),
        Binding(action: .moveDown, modifiers: win | alt | shift, key: 0x28, label: "Win+Alt+Shift+Down"),
        Binding(action: .cycleWidth, modifiers: win | alt, key: 0x57, label: "Win+Alt+W"),
        Binding(action: .cycleWidthBackward, modifiers: win | alt | shift, key: 0x57, label: "Win+Alt+Shift+W"),
        Binding(action: .toggleFullWidth, modifiers: win | alt, key: 0x46, label: "Win+Alt+F"),
        Binding(action: .consumeIntoLeft, modifiers: win | alt, key: 0xBC, label: "Win+Alt+,"),
        Binding(action: .expel, modifiers: win | alt, key: 0xBE, label: "Win+Alt+."),
    ]

    /// Registers every shortcut; returns the ones Windows refused (already taken by something else).
    @discardableResult
    static func register(_ bindings: [Binding] = defaults) -> [Binding] {
        var refused: [Binding] = []
        for (index, binding) in bindings.enumerated() {
            if !ok(RegisterHotKey(nil, Int32(index + 1), UINT(binding.modifiers | noRepeat), UINT(binding.key))) {
                refused.append(binding)
            }
        }
        return refused
    }

    static func unregister(_ bindings: [Binding] = defaults) {
        for index in bindings.indices { UnregisterHotKey(nil, Int32(index + 1)) }
    }

    /// The action for a WM_HOTKEY id.
    static func action(forHotKey id: Int, _ bindings: [Binding] = defaults) -> Action? {
        bindings.indices.contains(id - 1) ? bindings[id - 1].action : nil
    }

    /// Presses a shortcut through Windows' input system, as a person would (for the UI test).
    static func press(_ binding: Binding) {
        var keys: [UInt8] = []
        if binding.modifiers & win != 0 { keys.append(0x5B) }  // VK_LWIN
        if binding.modifiers & alt != 0 { keys.append(0x12) }  // VK_MENU
        if binding.modifiers & control != 0 { keys.append(0x11) }
        if binding.modifiers & shift != 0 { keys.append(0x10) }
        keys.append(UInt8(binding.key))
        for key in keys { keybd_event(key, 0, 0, 0) }
        for key in keys.reversed() { keybd_event(key, 0, DWORD(0x0002), 0) }  // KEYEVENTF_KEYUP
    }
}
#endif
