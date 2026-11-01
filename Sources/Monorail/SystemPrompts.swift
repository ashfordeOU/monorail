import AppKit
import ApplicationServices
import MonorailCore

/// Permission, password and security prompts from macOS itself ("Monorail would like to…",
/// "… wants to make changes", Gatekeeper's "Are you sure you want to open…", Touch ID) always
/// come to the front, centred on the screen you're using, and stay in front until answered.
/// While one is up, Monorail doesn't move focus to other windows.
final class SystemPrompts {
    /// The processes that draw these prompts.
    static let owners: Set<String> = [
        "UserNotificationCenter", "SecurityAgent", "CoreServicesUIAgent", "universalAccessAuthWarn",
        "coreautha", "CoreLocationAgent", "AuthenticationServicesAgent", "LocalAuthenticationRemoteService",
    ]

    static let bundleIDs: Set<String> = [
        "com.apple.UserNotificationCenter", "com.apple.SecurityAgent", "com.apple.CoreServicesUIAgent",
        "com.apple.universalAccessAuthWarn", "com.apple.coreautha", "com.apple.CoreLocationAgent",
        "com.apple.AuthenticationServicesCore.AuthenticationServicesAgent",
    ]

    /// Whether a prompt is on screen now.
    private(set) var isUp = false
    var isEnabled: () -> Bool = { true }
    /// Called when the first prompt appears and when the last one goes.
    var onChange: (Bool) -> Void = { _ in }

    private var timer: Timer?
    private var placed: Set<Int> = []
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func start() {
        timer?.invalidate()
        timer = Timer.every(1.0) { [weak self] _ in self?.check() }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.check() }
            }
        }
    }

    static func isPromptOwner(pid: pid_t, name: String) -> Bool {
        if owners.contains(name) { return true }
        if let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier { return bundleIDs.contains(id) }
        return false
    }

    private struct Entry {
        let number: Int
        let pid: pid_t
        let layer: Int
        let bounds: CGRect
    }

    func check() {
        guard isEnabled(), !Dormancy.isDormant else { return setUp(false) }
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        else { return }
        // Front to back, as the window server lists them.
        let all: [Entry] = list.compactMap { info in
            guard let number = info[kCGWindowNumber as String] as? Int,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                let layer = info[kCGWindowLayer as String] as? Int,
                let dict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: dict),
                (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.05
            else { return nil }
            return Entry(number: number, pid: pid, layer: layer, bounds: bounds)
        }
        var names: [pid_t: String] = [:]
        for info in list {
            if let pid = info[kCGWindowOwnerPID as String] as? pid_t, let name = info[kCGWindowOwnerName as String] as? String {
                names[pid] = name
            }
        }
        let prompts = all.enumerated().filter { _, entry in
            entry.layer >= 0 && entry.layer < Int(CGWindowLevelForKey(.screenSaverWindow))
                && entry.bounds.width >= 160 && entry.bounds.height >= 80
                && Self.isPromptOwner(pid: entry.pid, name: names[entry.pid] ?? "")
        }
        guard !prompts.isEmpty else {
            placed.removeAll()
            return setUp(false)
        }
        setUp(true)
        for (index, prompt) in prompts {
            if !placed.contains(prompt.number) {
                placed.insert(prompt.number)
                center(prompt)
                bringForward(prompt)
                continue
            }
            // Something else covers it (another app came forward): bring it back on top.
            let covered = all[..<index].contains { other in
                other.pid != prompt.pid && other.pid != self.ownPID && other.layer <= prompt.layer && other.bounds.intersects(prompt.bounds)
                    && other.bounds.width > 40 && other.bounds.height > 40
            }
            if covered { bringForward(prompt) }
        }
    }

    private func setUp(_ up: Bool) {
        guard up != isUp else { return }
        isUp = up
        onChange(up)
    }

    /// The prompt's window through Accessibility, matched by position and size.
    private func element(for prompt: Entry) -> AXUIElement? {
        AXUIElement.application(prompt.pid).windows.first { element in
            guard let frame = element.frame else { return false }
            return abs(frame.minX - prompt.bounds.minX) < 4 && abs(frame.minY - prompt.bounds.minY) < 4
                && abs(frame.width - prompt.bounds.width) < 4
        } ?? AXUIElement.application(prompt.pid).windows.first
    }

    /// Centred on the screen with the pointer (the one you're looking at), a little above the middle like an alert.
    private func center(_ prompt: Entry) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main,
            let primary = NSScreen.screens.first, let window = element(for: prompt)
        else { return }
        // Cocoa (bottom-left) to the window server's top-left coordinates.
        let visible = screen.visibleFrame
        let top = CGRect(x: visible.minX, y: primary.frame.height - visible.maxY, width: visible.width, height: visible.height)
        let size = prompt.bounds.size
        var origin = CGPoint(x: top.midX - size.width / 2, y: top.minY + (top.height - size.height) * 0.4)
        origin.x = min(max(origin.x, top.minX), max(top.maxX - size.width, top.minX))
        origin.y = min(max(origin.y, top.minY), max(top.maxY - size.height, top.minY))
        if abs(origin.x - prompt.bounds.minX) > 2 || abs(origin.y - prompt.bounds.minY) > 2 {
            window.setPosition(origin)
        }
    }

    private func bringForward(_ prompt: Entry) {
        guard prompt.pid != ownPID else { return }
        let app = AXUIElement.application(prompt.pid)
        if let window = element(for: prompt) {
            window.raise()
            window.set(kAXMainAttribute, kCFBooleanTrue)
        }
        app.set(kAXFrontmostAttribute, kCFBooleanTrue)
        NSRunningApplication(processIdentifier: prompt.pid)?.activate(options: [])
    }
}
