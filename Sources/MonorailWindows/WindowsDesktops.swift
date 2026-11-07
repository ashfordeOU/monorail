#if os(Windows)
import MonorailCore
import MonorailEngine
import WinSDK

/// Windows' own virtual desktops as Monorail's workspaces: next and previous desktop, and taking the
/// focused window along. Windows has no public way for one app to switch desktops or move another
/// app's window to one, so Monorail does what a person would: it presses Windows' own Ctrl+Win+Left
/// or Right, and to take a window along it hides the window, switches, and shows it again (a window
/// that's shown again belongs to the desktop you're on). Nothing undocumented is used.
enum WindowsDesktops {
    static let actions: Set<Action> = [.nextWorkspace, .previousWorkspace, .moveToNextWorkspace, .moveToPreviousWorkspace]

    /// Runs a desktop action; false for any other action.
    @discardableResult
    static func perform(_ action: Action) -> Bool {
        switch action {
        case .nextWorkspace: switchDesktop(right: true)
        case .previousWorkspace: switchDesktop(right: false)
        case .moveToNextWorkspace: carry(right: true)
        case .moveToPreviousWorkspace: carry(right: false)
        default: return false
        }
        return true
    }

    /// Ctrl+Win+Right or Left, as if pressed on the keyboard.
    static func switchDesktop(right: Bool) {
        releaseHeldModifiers()
        let keys: [UInt8] = [0x11, 0x5B, right ? 0x27 : 0x25]  // VK_CONTROL, VK_LWIN, arrow
        for key in keys { keybd_event(key, 0, extended(key), 0) }
        for key in keys.reversed() { keybd_event(key, 0, extended(key) | DWORD(0x0002), 0) }  // KEYEVENTF_KEYUP
    }

    /// Takes the focused window to the next or previous desktop and keeps it focused there.
    static func carry(right: Bool) {
        guard let hwnd = GetForegroundWindow(), Win32WindowSystem.info(hwnd)?.isTileable == true else {
            switchDesktop(right: right)
            return
        }
        _ = ShowWindow(hwnd, SW_HIDE)
        switchDesktop(right: right)
        // Let Windows finish switching before the window is shown on the new desktop.
        Win32WindowSystem.pump(for: 0.4)
        _ = ShowWindow(hwnd, SW_SHOW)
        _ = SetForegroundWindow(hwnd)
    }

    /// The arrows are extended keys; Ctrl and Win aren't.
    private static func extended(_ key: UInt8) -> DWORD { key == 0x25 || key == 0x27 ? DWORD(0x0001) : 0 }  // KEYEVENTF_EXTENDEDKEY

    /// Monorail's own shortcut may still be held (Win+Alt+PageDown): let go of Alt and Shift first,
    /// or Windows would see Ctrl+Win+Alt+Right. A key nothing uses goes first, so letting go of Alt
    /// doesn't open an app's menu bar.
    private static func releaseHeldModifiers() {
        let held = ([0x12, 0x10, 0x5C] as [UInt8]).filter { GetAsyncKeyState(Int32($0)) < 0 }  // Alt, Shift, right Win
        guard !held.isEmpty else { return }
        keybd_event(0xE8, 0, 0, 0)
        keybd_event(0xE8, 0, DWORD(0x0002), 0)
        for key in held { keybd_event(key, 0, DWORD(0x0002), 0) }
    }
}
#endif
