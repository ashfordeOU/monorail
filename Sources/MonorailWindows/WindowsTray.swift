#if os(Windows)
import Foundation
import WinSDK

/// Monorail's icon in the notification area (the tray), with its menu: pause and resume, open
/// the settings file, reload it, quit. Clicking the icon (either button) opens the menu.
enum WindowsTray {
    enum Command: Int {
        case togglePause = 1, openSettings, reloadSettings, quit
    }

    /// Called with the menu item chosen.
    static var onCommand: (Command) -> Void = { _ in }
    /// Whether the menu says Pause or Resume.
    static var isPaused = false

    private static var window: HWND?
    private static let iconID: UINT = 1
    private static let callbackMessage = UINT(WM_APP) + 1

    /// Adds the icon; false when Windows refused it (no taskbar, or Explorer isn't running).
    @discardableResult
    static func show(tip: String = "Monorail (Windows alpha)") -> Bool {
        if window == nil { window = makeWindow() }
        guard let window else { return false }
        var data = iconData(window)
        data.uFlags = UINT(NIF_MESSAGE | NIF_ICON | NIF_TIP)
        data.uCallbackMessage = callbackMessage
        // The standard application icon until the alpha has its own.
        data.hIcon = LoadIconW(nil, UnsafePointer<WCHAR>(bitPattern: 32512))
        withUnsafeMutableBytes(of: &data.szTip) { raw in
            let units = Array(tip.utf16.prefix(raw.count / 2 - 1)) + [0]
            raw.copyBytes(from: units.withUnsafeBytes { Array($0) })
        }
        return ok(Shell_NotifyIconW(DWORD(NIM_ADD), &data))
    }

    static func hide() {
        guard let window else { return }
        var data = iconData(window)
        _ = Shell_NotifyIconW(DWORD(NIM_DELETE), &data)
    }

    /// Opens a file (the settings) in the app Windows uses for it, Notepad when there's none.
    static func open(_ path: String) {
        let result = path.withCString(encodedAs: UTF16.self) { file in
            "open".withCString(encodedAs: UTF16.self) { verb in
                Int(bitPattern: ShellExecuteW(nil, verb, file, nil, nil, Int32(SW_SHOWNORMAL)))
            }
        }
        if result <= 32 {
            let process = Foundation.Process()
            process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\notepad.exe")
            process.arguments = [path]
            try? process.run()
        }
    }

    // MARK: Private

    private static func iconData(_ window: HWND) -> NOTIFYICONDATAW {
        var data = NOTIFYICONDATAW()
        data.cbSize = DWORD(MemoryLayout<NOTIFYICONDATAW>.size)
        data.hWnd = window
        data.uID = iconID
        return data
    }

    private static func makeWindow() -> HWND? {
        let instance = GetModuleHandleW(nil)
        return "MonorailTray".withCString(encodedAs: UTF16.self) { name -> HWND? in
            var wc = WNDCLASSEXW()
            wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
            wc.lpfnWndProc = trayProc
            wc.hInstance = instance
            wc.lpszClassName = name
            _ = RegisterClassExW(&wc)
            // A message-only window: it receives the icon's clicks and is never shown.
            return CreateWindowExW(0, name, name, 0, 0, 0, 0, 0, HWND(bitPattern: -3), nil, instance, nil)
        }
    }

    fileprivate static func showMenu(_ window: HWND) {
        guard let menu = CreatePopupMenu() else { return }
        defer { _ = DestroyMenu(menu) }
        let items: [(Command, String)] = [
            (.togglePause, isPaused ? "Resume Monorail" : "Pause Monorail"),
            (.openSettings, "Open Settings File"),
            (.reloadSettings, "Reload Settings"),
            (.quit, "Quit Monorail"),
        ]
        for (command, title) in items {
            if command == .quit { _ = AppendMenuW(menu, UINT(MF_SEPARATOR), 0, nil) }
            _ = title.withCString(encodedAs: UTF16.self) { AppendMenuW(menu, UINT(MF_STRING), UINT_PTR(command.rawValue), $0) }
        }
        var point = POINT()
        _ = GetCursorPos(&point)
        // Windows closes the menu on a click elsewhere only when its window is in front.
        _ = SetForegroundWindow(window)
        // The chosen item arrives as WM_COMMAND (handled in trayProc).
        _ = TrackPopupMenu(menu, UINT(TPM_RIGHTBUTTON), point.x, point.y, 0, window, nil)
        _ = PostMessageW(window, UINT(WM_NULL), 0, 0)
    }

    fileprivate static func chose(_ id: Int) {
        if let command = Command(rawValue: id) { onCommand(command) }
    }

    fileprivate static var callback: UINT { callbackMessage }
}

private func trayProc(_ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT {
    if message == WindowsTray.callback, let hwnd {
        let event = UINT(truncatingIfNeeded: lParam & 0xFFFF)
        if event == UINT(WM_LBUTTONUP) || event == UINT(WM_RBUTTONUP) { WindowsTray.showMenu(hwnd) }
        return 0
    }
    if message == UINT(WM_COMMAND) {
        WindowsTray.chose(Int(wParam & 0xFFFF))
        return 0
    }
    return DefWindowProcW(hwnd, message, wParam, lParam)
}
#endif
