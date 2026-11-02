#if os(Windows)
import Foundation
import MonorailCore
import MonorailEngine
import WinSDK

/// Windows's `WindowSystem` (docs/PLATFORMS.md, Phase 1): top-level windows through Win32 and DWM,
/// in the same coordinates as everywhere else (the virtual screen: origin at the top left of the
/// main display, y down). Frames are the visible bounds DWM reports, without the invisible resize
/// borders Windows 10 and 11 add, so tiles meet edge to edge.
final class Win32WindowSystem: WindowSystem {
    var onEvent: (WindowEvent) -> Void = { _ in }
    private var hook: HWINEVENTHOOK?

    init() {}

    deinit { stop() }

    // MARK: IDs

    /// Window handles are 32-bit values (sign-extended on 64-bit Windows), so they fit a WindowID.
    static func id(_ hwnd: HWND) -> WindowID { WindowID(truncatingIfNeeded: Int(bitPattern: UnsafeMutableRawPointer(hwnd))) }
    static func hwnd(_ id: WindowID) -> HWND? { HWND(bitPattern: Int(Int32(bitPattern: id))) }

    // MARK: Reading

    var displays: [DisplayInfo] {
        Monitors.all().map { monitor in
            DisplayInfo(id: monitor.name, name: monitor.name, frame: monitor.frame, visibleFrame: monitor.work, scale: monitor.scale)
        }
    }

    func windows() -> [WindowInfo] {
        TopLevel.handles().compactMap(Self.info)
    }

    func window(_ id: WindowID) -> WindowInfo? {
        guard let hwnd = Self.hwnd(id), ok(IsWindow(hwnd)) else { return nil }
        return Self.info(hwnd)
    }

    func focusedWindow() -> WindowID? {
        GetForegroundWindow().map(Self.id)
    }

    /// Everything Monorail needs to know about a top-level window.
    static func info(_ hwnd: HWND) -> WindowInfo? {
        guard ok(IsWindowVisible(hwnd)) else { return nil }
        let style = UInt32(truncatingIfNeeded: GetWindowLongPtrW(hwnd, GWL_STYLE))
        let exStyle = UInt32(truncatingIfNeeded: GetWindowLongPtrW(hwnd, GWL_EXSTYLE))
        let className = Text.className(hwnd)
        let title = Text.title(hwnd)
        let (appID, appName) = OwningApp.of(hwnd)
        let frame = visibleFrame(hwnd)
        let hasCaption = style & 0x00C0_0000 == 0x00C0_0000  // WS_CAPTION
        let isTool = exStyle & 0x0000_0080 != 0  // WS_EX_TOOLWINDOW
        let isOwned = GetWindow(hwnd, UINT(4)) != nil  // GW_OWNER: dialogs and pop-ups belong to another window
        let isShell = ["Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd"].contains(className)
        return WindowInfo(
            id: id(hwnd), appID: appID, appName: appName, title: title, frame: frame,
            isStandard: hasCaption && !isTool && !isOwned && !isShell && !isCloaked(hwnd) && !title.isEmpty,
            isMinimized: ok(IsIconic(hwnd)), isFullScreen: false,
            canMove: true, canResize: style & 0x0004_0000 != 0)  // WS_THICKFRAME
    }

    /// Hidden by DWM (another virtual desktop, a suspended Store app): there but not showing.
    private static func isCloaked(_ hwnd: HWND) -> Bool {
        var cloaked: DWORD = 0
        let result = DwmGetWindowAttribute(hwnd, DWORD(14), &cloaked, DWORD(MemoryLayout<DWORD>.size))  // DWMWA_CLOAKED
        return result == 0 && cloaked != 0
    }

    /// The bounds you see (DWMWA_EXTENDED_FRAME_BOUNDS), falling back to the window rectangle.
    static func visibleFrame(_ hwnd: HWND) -> Rect {
        var bounds = RECT()
        if DwmGetWindowAttribute(hwnd, DWORD(9), &bounds, DWORD(MemoryLayout<RECT>.size)) == 0 { return Rect(bounds) }
        var window = RECT()
        GetWindowRect(hwnd, &window)
        return Rect(window)
    }

    // MARK: Acting

    func apply(_ frames: [WindowID: Rect]) {
        let targets = frames.compactMap { id, frame in Self.hwnd(id).map { ($0, frame) } }
        guard !targets.isEmpty else { return }
        // One batch: the windows move together, without a visible ripple.
        var batch = BeginDeferWindowPos(Int32(targets.count))
        for (hwnd, frame) in targets {
            if ok(IsIconic(hwnd)) || ok(IsZoomed(hwnd)) { ShowWindow(hwnd, SW_RESTORE) }
            let r = Self.outerRect(for: frame, hwnd)
            let flags = UINT(SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER)
            if let current = batch {
                batch = DeferWindowPos(current, hwnd, nil, r.left, r.top, r.right - r.left, r.bottom - r.top, flags)
            }
            if batch == nil {
                // A window that refuses to be batched (another process's elevated window): move it alone.
                SetWindowPos(hwnd, nil, r.left, r.top, r.right - r.left, r.bottom - r.top, flags)
            }
        }
        if let batch { EndDeferWindowPos(batch) }
    }

    /// The window rectangle that makes the visible bounds come out as `frame`
    /// (adds back the invisible borders).
    private static func outerRect(for frame: Rect, _ hwnd: HWND) -> RECT {
        var window = RECT()
        GetWindowRect(hwnd, &window)
        var bounds = RECT()
        let hasBounds = DwmGetWindowAttribute(hwnd, DWORD(9), &bounds, DWORD(MemoryLayout<RECT>.size)) == 0
        let left = hasBounds ? bounds.left - window.left : 0
        let top = hasBounds ? bounds.top - window.top : 0
        let right = hasBounds ? window.right - bounds.right : 0
        let bottom = hasBounds ? window.bottom - bounds.bottom : 0
        let x = Int32(frame.x.rounded()), y = Int32(frame.y.rounded())
        let w = Int32(frame.width.rounded()), h = Int32(frame.height.rounded())
        return RECT(left: x - left, top: y - top, right: x + w + right, bottom: y + h + bottom)
    }

    func focus(_ id: WindowID) {
        guard let hwnd = Self.hwnd(id) else { return }
        if ok(IsIconic(hwnd)) { ShowWindow(hwnd, SW_RESTORE) }
        if ok(SetForegroundWindow(hwnd)) { return }
        // Windows only lets the app that had the last input take the foreground: a tap of Alt
        // counts as input, after which the switch is allowed.
        keybd_event(0x12, 0, 0, 0)
        keybd_event(0x12, 0, DWORD(0x0002), 0)
        SetForegroundWindow(hwnd)
    }

    func setMinimized(_ id: WindowID, _ minimized: Bool) {
        guard let hwnd = Self.hwnd(id) else { return }
        ShowWindow(hwnd, minimized ? SW_MINIMIZE : SW_RESTORE)
    }

    func close(_ id: WindowID) {
        guard let hwnd = Self.hwnd(id) else { return }
        PostMessageW(hwnd, UINT(WM_CLOSE), 0, 0)
    }

    // MARK: Events

    /// Starts reporting window events (SetWinEventHook, out of context: no code runs inside other apps).
    /// Events arrive while the thread pumps messages.
    func start() {
        guard hook == nil else { return }
        EventRouter.current = self
        hook = SetWinEventHook(DWORD(0x0003), DWORD(0x800C), nil, winEventCallback, 0, 0, DWORD(WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS))
    }

    func stop() {
        if let hook { UnhookWinEvent(hook) }
        hook = nil
        if EventRouter.current === self { EventRouter.current = nil }
    }

    fileprivate func handle(event: DWORD, hwnd: HWND, object: LONG, child: LONG) {
        guard object == 0, child == 0 else { return }  // OBJID_WINDOW, CHILDID_SELF: the window itself
        let id = Self.id(hwnd)
        switch event {
        case 0x0003: onEvent(.focused(id))  // EVENT_SYSTEM_FOREGROUND
        case 0x0016: onEvent(.minimized(id))  // EVENT_SYSTEM_MINIMIZESTART
        case 0x0017: onEvent(.restored(id))  // EVENT_SYSTEM_MINIMIZEEND
        case 0x8002: onEvent(.created(id))  // EVENT_OBJECT_SHOW: shown and ready, not just created
        case 0x8001: onEvent(.destroyed(id))  // EVENT_OBJECT_DESTROY
        case 0x800B: onEvent(.moved(id, byUser: GetAsyncKeyState(Int32(VK_LBUTTON)) < 0))  // EVENT_OBJECT_LOCATIONCHANGE
        case 0x800C: onEvent(.titleChanged(id))  // EVENT_OBJECT_NAMECHANGE
        default: break
        }
    }

    /// Called with the id of a registered shortcut when it's pressed (WM_HOTKEY).
    static var onHotKey: (Int) -> Void = { _ in }

    /// Delivers waiting messages (and so window events and shortcuts) for up to `seconds`.
    static func pump(for seconds: Double) {
        let end = Date().addingTimeInterval(seconds)
        var message = MSG()
        repeat {
            while ok(PeekMessageW(&message, nil, 0, 0, UINT(PM_REMOVE))) {
                if message.message == UINT(0x0312) { onHotKey(Int(message.wParam)) }  // WM_HOTKEY
                TranslateMessage(&message)
                DispatchMessageW(&message)
            }
            Sleep(15)
        } while Date() < end
    }
}

private enum EventRouter {
    static var current: Win32WindowSystem?
}

private func winEventCallback(_ hook: HWINEVENTHOOK?, _ event: DWORD, _ hwnd: HWND?, _ object: LONG, _ child: LONG,
                              _ thread: DWORD, _ time: DWORD) {
    guard let hwnd else { return }
    EventRouter.current?.handle(event: event, hwnd: hwnd, object: object, child: child)
}

// MARK: - Helpers

/// Win32's BOOL, however this Swift imports it (Bool, WindowsBool or a plain integer).
@inline(__always) func ok(_ value: WindowsBool) -> Bool { value.boolValue }
@inline(__always) func ok(_ value: Int32) -> Bool { value != 0 }
@inline(__always) func ok(_ value: Bool) -> Bool { value }

extension Rect {
    init(_ r: RECT) {
        self.init(x: Double(r.left), y: Double(r.top), width: Double(r.right - r.left), height: Double(r.bottom - r.top))
    }
}

enum TopLevel {
    private static var found: [HWND] = []

    /// Every top-level window, front to back.
    static func handles() -> [HWND] {
        found = []
        EnumWindows({ hwnd, _ in
            if let hwnd { TopLevel.found.append(hwnd) }
            return true
        }, 0)
        return found
    }
}

enum Text {
    static func title(_ hwnd: HWND) -> String {
        let length = GetWindowTextLengthW(hwnd)
        guard length > 0 else { return "" }
        var buffer = [WCHAR](repeating: 0, count: Int(length) + 1)
        GetWindowTextW(hwnd, &buffer, Int32(buffer.count))
        return String(decodingCString: buffer, as: UTF16.self)
    }

    static func className(_ hwnd: HWND) -> String {
        var buffer = [WCHAR](repeating: 0, count: 256)
        GetClassNameW(hwnd, &buffer, Int32(buffer.count))
        return String(decodingCString: buffer, as: UTF16.self)
    }
}

enum OwningApp {
    /// The app a window belongs to: its executable's path (the app ID) and file name.
    static func of(_ hwnd: HWND) -> (id: String, name: String) {
        var pid: DWORD = 0
        GetWindowThreadProcessId(hwnd, &pid)
        guard let process = OpenProcess(DWORD(0x1000), false, pid) else { return ("pid-\(pid)", "") }  // PROCESS_QUERY_LIMITED_INFORMATION
        defer { CloseHandle(process) }
        var buffer = [WCHAR](repeating: 0, count: 1024)
        var size = DWORD(buffer.count)
        guard ok(QueryFullProcessImageNameW(process, 0, &buffer, &size)) else { return ("pid-\(pid)", "") }
        let path = String(decodingCString: buffer, as: UTF16.self)
        let name = path.split(separator: "\\").last.map(String.init) ?? path
        return (path.lowercased(), name.hasSuffix(".exe") ? String(name.dropLast(4)) : name)
    }
}

enum Monitors {
    struct Monitor {
        var name: String
        var frame: Rect
        var work: Rect
        var scale: Double
    }

    private static var found: [Monitor] = []

    /// Every display, left to right. (Scale is 1 until the app is per-monitor DPI aware.)
    static func all() -> [Monitor] {
        found = []
        EnumDisplayMonitors(nil, nil, { monitor, _, _, _ in
            guard let monitor else { return true }
            var info = MONITORINFO()
            info.cbSize = DWORD(MemoryLayout<MONITORINFO>.size)
            guard ok(GetMonitorInfoW(monitor, &info)) else { return true }
            let primary = info.dwFlags & DWORD(1) != 0  // MONITORINFOF_PRIMARY
            let frame = Rect(info.rcMonitor)
            let name = primary ? "primary" : "display-\(Int(frame.x))x\(Int(frame.y))"
            Monitors.found.append(Monitor(name: name, frame: frame, work: Rect(info.rcWork), scale: 1))
            return true
        }, 0)
        return found.sorted { $0.frame.x < $1.frame.x }
    }
}
#endif
