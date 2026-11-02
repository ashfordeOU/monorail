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
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
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

private extension AXUIElement {
    var pid: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(self, &pid) == .success ? pid : nil
    }
}
#endif
