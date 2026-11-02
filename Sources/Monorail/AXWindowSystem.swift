#if os(macOS)
import AppKit
import ApplicationServices
import MonorailCore
import MonorailEngine

/// The Mac's `WindowSystem` (docs/PLATFORMS.md, Phase 0): the shared engine's view of macOS windows,
/// through the Accessibility API, in the same coordinates as the rest of Monorail (points, origin at
/// the top left of the main display, y down). Windows (Win32/DWM) and Linux get their own.
///
/// Today's engine still talks to Accessibility directly; this backend is how the shared engine will
/// drive the Mac as the move continues, and the self-test exercises it on every build.
final class AXWindowSystem: WindowSystem {
    var onEvent: (WindowEvent) -> Void = { _ in }
    private var elements: [WindowID: AXUIElement] = [:]
    private var observers: [NSObjectProtocol] = []
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        func appID(_ note: Notification) -> String? {
            (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
        }
        observers.append(workspace.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let id = appID(note) { self?.onEvent(.appHidden(appID: id)) }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let id = appID(note) { self?.onEvent(.appShown(appID: id)) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                                                queue: .main) { [weak self] _ in
            self?.onEvent(.displaysChanged)
        })
    }

    deinit {
        stop()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: Window events

    /// Follow title changes too (off by default: terminals and browsers retitle constantly).
    var followTitles = false
    private var axObservers: [pid_t: AXObserver] = [:]
    private var appObservers: [NSObjectProtocol] = []
    private(set) var isStarted = false

    private static let appNotifications = [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification]
    private static let windowNotifications = [
        kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
        kAXWindowMovedNotification, kAXWindowResizedNotification,
    ]

    /// Starts reporting window events for every app, and for apps that launch later.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            observe(app.processIdentifier)
        }
        let center = NSWorkspace.shared.notificationCenter
        appObservers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            // Apps answer Accessibility a moment after they launch.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.observe(app.processIdentifier) }
        })
        appObservers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.unobserve(app.processIdentifier)
        })
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        for pid in Array(axObservers.keys) { unobserve(pid) }
        for observer in appObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        appObservers.removeAll()
    }

    private var refcon: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }

    private func observe(_ pid: pid_t) {
        guard axObservers[pid] == nil, pid != ownPID else { return }
        var created: AXObserver?
        guard AXObserverCreate(pid, axWindowSystemCallback, &created) == .success, let observer = created else { return }
        let app = AXUIElement.application(pid)
        var ok = false
        for name in Self.appNotifications {
            let error = AXObserverAddNotification(observer, app, name as CFString, refcon)
            ok = ok || error == .success || error == .notificationAlreadyRegistered
        }
        guard ok else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        axObservers[pid] = observer
        for window in app.windows { observeWindow(window, observer: observer) }
    }

    private func observeWindow(_ element: AXUIElement, observer: AXObserver) {
        for name in Self.windowNotifications {
            AXObserverAddNotification(observer, element, name as CFString, refcon)
        }
        if followTitles { AXObserverAddNotification(observer, element, kAXTitleChangedNotification as CFString, refcon) }
        if let id = element.windowID { elements[WindowID(id)] = element }
    }

    private func unobserve(_ pid: pid_t) {
        guard let observer = axObservers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        let gone = elements.filter { $0.value.pid == pid }.map(\.key)
        for id in gone {
            elements[id] = nil
            onEvent(.destroyed(id))
        }
    }

    /// The ID of a window element, also once it's gone (when Accessibility can no longer say).
    private func id(of element: AXUIElement) -> WindowID? {
        if let id = element.windowID { return WindowID(id) }
        return elements.first { CFEqual($0.value, element) }?.key
    }

    fileprivate func handle(_ notification: String, element: AXUIElement) {
        switch notification {
        case kAXWindowCreatedNotification:
            guard let pid = element.pid, let observer = axObservers[pid], let id = id(of: element) else { return }
            observeWindow(element, observer: observer)
            onEvent(.created(id))
        case kAXFocusedWindowChangedNotification:
            let window = element.role == kAXWindowRole ? element : element.focusedWindow
            if let window, let id = id(of: window) { onEvent(.focused(id)) }
        case kAXUIElementDestroyedNotification:
            guard let id = id(of: element) else { return }
            elements[id] = nil
            onEvent(.destroyed(id))
        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            if let id = id(of: element) { onEvent(.moved(id, byUser: NSEvent.pressedMouseButtons != 0)) }
        case kAXWindowMiniaturizedNotification:
            if let id = id(of: element) { onEvent(.minimized(id)) }
        case kAXWindowDeminiaturizedNotification:
            if let id = id(of: element) { onEvent(.restored(id)) }
        case kAXTitleChangedNotification:
            if let id = id(of: element) { onEvent(.titleChanged(id)) }
        default:
            break
        }
    }

    // MARK: Reading

    var displays: [DisplayInfo] {
        Display.all().map { display in
            let scale = NSScreen.screens.first { screen in
                (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.id
            }?.backingScaleFactor ?? 2
            return DisplayInfo(id: display.uuid, name: display.name, frame: Rect(display.frame),
                               visibleFrame: Rect(display.visibleFrame), scale: Double(scale))
        }
    }

    func windows() -> [WindowInfo] {
        var found: [WindowID: AXUIElement] = [:]
        var result: [WindowInfo] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != ownPID {
            for element in AXUIElement.application(app.processIdentifier).windows {
                guard let info = Self.info(element, app: app) else { continue }
                found[info.id] = element
                result.append(info)
            }
        }
        elements = found
        return result
    }

    func window(_ id: WindowID) -> WindowInfo? {
        if let element = elements[id], let pid = element.pid, let app = NSRunningApplication(processIdentifier: pid),
            let info = Self.info(element, app: app)
        {
            return info
        }
        return windows().first { $0.id == id }
    }

    func focusedWindow() -> WindowID? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AXUIElement.application(app.processIdentifier).focusedWindow?.windowID.map { WindowID($0) }
    }

    private static func info(_ element: AXUIElement, app: NSRunningApplication) -> WindowInfo? {
        guard element.role == kAXWindowRole, let id = element.windowID, let frame = element.frame else { return nil }
        let hasButtons = element.element(kAXCloseButtonAttribute) != nil && element.element(kAXMinimizeButtonAttribute) != nil
        return WindowInfo(
            id: WindowID(id), appID: app.bundleIdentifier ?? app.executableURL?.path ?? "pid-\(app.processIdentifier)",
            appName: app.localizedName ?? "", title: element.title ?? "", frame: Rect(frame),
            isStandard: element.subrole == kAXStandardWindowSubrole as String && hasButtons,
            isMinimized: element.isMinimized, isFullScreen: element.isFullScreen,
            canMove: element.isSettable(kAXPositionAttribute), canResize: !element.hasFixedSize)
    }

    // MARK: Acting

    func apply(_ frames: [WindowID: Rect]) {
        for (id, frame) in frames {
            guard let element = elements[id] ?? lookUp(id) else { continue }
            element.setFrame(CGRect(frame))
        }
    }

    func focus(_ id: WindowID) {
        guard let element = elements[id] ?? lookUp(id), let pid = element.pid else { return }
        element.set(kAXMainAttribute, kCFBooleanTrue)
        element.raise()
        AXUIElement.application(pid).set(kAXFrontmostAttribute, kCFBooleanTrue)
        NSRunningApplication(processIdentifier: pid)?.activate(options: [])
    }

    func setMinimized(_ id: WindowID, _ minimized: Bool) {
        (elements[id] ?? lookUp(id))?.set(kAXMinimizedAttribute, minimized ? kCFBooleanTrue : kCFBooleanFalse)
    }

    func close(_ id: WindowID) {
        guard let button = (elements[id] ?? lookUp(id))?.element(kAXCloseButtonAttribute) else { return }
        AXUIElementPerformAction(button, kAXPressAction as CFString)
    }

    private func lookUp(_ id: WindowID) -> AXUIElement? {
        _ = windows()
        return elements[id]
    }
}

private func axWindowSystemCallback(
    _ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    Unmanaged<AXWindowSystem>.fromOpaque(refcon).takeUnretainedValue().handle(notification as String, element: element)
}

private extension AXUIElement {
    var pid: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(self, &pid) == .success ? pid : nil
    }
}
#endif
