#if os(macOS)
import AppKit
import MonorailCore

/// Arranges the windows of scriptable apps (Safari, Finder, Terminal…) with Apple Events, for Macs
/// where Accessibility can't be allowed. macOS asks once for each app ("Monorail wants to control
/// Safari"), and a standard user can answer that without an administrator. Only used while
/// Accessibility isn't allowed, and not in the App Store edition (the sandbox doesn't allow it).
final class ScriptableArranger {
    /// Apps brought to the front, most recent first (Monorail itself left out).
    private(set) var recent: [String] = []
    var notice: (String) -> Void = { _ in }
    var gap: () -> Double = { 8 }
    /// One script at a time, on the main thread as Apple recommends for NSAppleScript (a short
    /// async hop keeps the menu responsive while macOS shows its question).
    private let queue = DispatchQueue.main

    static var isAvailable: Bool { !Edition.isAppStore }

    init() {
        if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier { note(id) }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let id = app.bundleIdentifier
            else { return }
            self?.note(id)
        }
    }

    private func note(_ id: String) {
        guard id != Bundle.main.bundleIdentifier else { return }
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)
        if recent.count > 20 { recent.removeLast(recent.count - 20) }
    }

    private var running: [String] {
        recent.filter { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
    }

    /// The app you were last in, when it's one Monorail can arrange this way.
    var frontApp: ScriptableApp? { running.first.flatMap(ScriptableApps.app(for:)) }

    /// The name of the app you were last in, for messages.
    private var frontName: String {
        guard let id = running.first else { return "This app" }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName ?? id
    }

    // MARK: Actions

    func place(_ placement: ScriptPlacement) {
        guard let app = frontApp else {
            notice("\(frontName) can’t be moved without Accessibility · Safari, Chrome, Finder, Terminal and other scriptable apps can")
            return
        }
        let screens = Self.visibleFrames()
        let gap = self.gap()
        queue.async { [weak self] in
            let current = Self.frontBounds(app)
            if let error = current.error {
                DispatchQueue.main.async { self?.report(error, app) }
                return
            }
            guard let screen = ScriptBounds.screen(for: current.rect, among: screens) else { return }
            let frame = ScriptBounds.frame(placement, in: screen, current: current.rect, gap: gap)
            let error = Self.run(ScriptSource.setBounds(app, frame)).error
            DispatchQueue.main.async { if let error { self?.report(error, app) } }
        }
    }

    /// The two apps you used last, side by side: the latest on the left.
    func sideBySide() {
        let pair = ScriptableApps.frontTwo(running)
        guard pair.count == 2 else {
            notice("Side by side needs two scriptable apps open, such as Safari and Notes · switch between them first")
            return
        }
        let screens = Self.visibleFrames()
        let gap = self.gap()
        queue.async { [weak self] in
            let current = Self.frontBounds(pair[0])
            if let error = current.error {
                DispatchQueue.main.async { self?.report(error, pair[0]) }
                return
            }
            guard let screen = ScriptBounds.screen(for: current.rect, among: screens) else { return }
            for (app, placement) in zip(pair, [ScriptPlacement.leftHalf, .rightHalf]) {
                if let error = Self.run(ScriptSource.setBounds(app, ScriptBounds.frame(placement, in: screen, gap: gap))).error {
                    DispatchQueue.main.async { self?.report(error, app) }
                    return
                }
            }
            DispatchQueue.main.async {
                // Both in front: the right one first, then the left.
                for app in pair.reversed() {
                    NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).first?.activate(options: [])
                }
            }
        }
    }

    /// The front app's next (or previous) window.
    func cycleWindows(forward: Bool) {
        guard let app = frontApp else {
            notice("\(frontName) can’t be switched without Accessibility · Safari, Chrome, Finder, Terminal and other scriptable apps can")
            return
        }
        queue.async { [weak self] in
            if let error = Self.run(ScriptSource.cycleWindows(app, forward: forward)).error {
                DispatchQueue.main.async { self?.report(error, app) }
            }
        }
    }

    private func report(_ code: Int, _ app: ScriptableApp) {
        notice(ScriptErrors.message(code, appName: app.name))
    }

    // MARK: Apple Events

    /// Visible frames of every screen, in AppleScript's top-left space.
    private static func visibleFrames() -> [Rect] {
        let screens = NSScreen.screens
        guard let primaryHeight = screens.first?.frame.height else { return [] }
        return screens.map { screen in
            let v = screen.visibleFrame
            return ScriptBounds.topLeft(
                fromCocoa: Rect(x: Double(v.minX), y: Double(v.minY), width: Double(v.width), height: Double(v.height)),
                primaryHeight: Double(primaryHeight))
        }
    }

    private static func frontBounds(_ app: ScriptableApp) -> (rect: Rect?, error: Int?) {
        let result = run(ScriptSource.getBounds(app))
        if let error = result.error { return (nil, error) }
        guard let list = result.descriptor, list.numberOfItems == 4 else { return (nil, nil) }
        let numbers = (1...4).compactMap { index -> Int? in list.atIndex(index).map { item in Int(item.int32Value) } }
        return (ScriptBounds.rect(fromBounds: numbers), nil)
    }

    private static func run(_ source: String) -> (descriptor: NSAppleEventDescriptor?, error: Int?) {
        guard let script = NSAppleScript(source: source) else { return (nil, -1) }
        var info: NSDictionary?
        let result = script.executeAndReturnError(&info)
        if let info {
            return (nil, (info["NSAppleScriptErrorNumber"] as? NSNumber)?.intValue ?? -1)
        }
        return (result, nil)
    }
}
#endif
