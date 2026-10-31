#if os(macOS)
import AppKit
import OSLog
import MonorailCore
import SwiftUI

/// A pomodoro timer in the menu bar: focus, short break, repeat.
final class Pomodoro {
    enum Phase { case focus, rest }

    private(set) var phase: Phase?
    private var endsAt = Date()
    private var timer: Timer?
    var focusMinutes = 25
    var breakMinutes = 5
    /// Called every second with the countdown ("🍅 24:59"), or nil when stopped.
    var onTick: (String?) -> Void = { _ in }
    /// Called when a phase starts: focus (true) or break (false).
    var onPhase: (Bool) -> Void = { _ in }
    /// Called once a minute while focusing.
    var onFocusMinute: () -> Void = {}
    private var lastMinute = -1

    var isRunning: Bool { phase != nil }

    func toggle() {
        isRunning ? stop() : start(.focus)
    }

    func start(_ phase: Phase) {
        self.phase = phase
        let minutes = phase == .focus ? max(focusMinutes, 1) : max(breakMinutes, 1)
        endsAt = Date().addingTimeInterval(Double(minutes) * 60)
        lastMinute = -1
        onPhase(phase == .focus)
        timer?.invalidate()
        timer = Timer.every(1) { [weak self] _ in self?.tick() }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        phase = nil
        onTick(nil)
    }

    private func tick() {
        guard let phase else { return }
        let left = Int(endsAt.timeIntervalSinceNow.rounded(.up))
        if left <= 0 {
            NSSound(named: "Glass")?.play()
            start(phase == .focus ? .rest : .focus)
            return
        }
        if phase == .focus {
            let minute = left / 60
            if minute != lastMinute {
                if lastMinute >= 0 { onFocusMinute() }
                lastMinute = minute
            }
        }
        onTick(String(format: "%@ %d:%02d", phase == .focus ? "●" : "☕", left / 60, left % 60))
    }
}

/// Reminds you to look away and stretch after a stretch of work.
final class BreakReminder {
    private var timer: Timer?
    private var minutes = 0
    var onRemind: () -> Void = {}

    func set(minutes: Int) {
        guard minutes != self.minutes else { return }
        self.minutes = minutes
        timer?.invalidate()
        timer = nil
        guard minutes > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Double(minutes) * 60, repeats: true) { [weak self] _ in
            // Only when you're actually at the Mac.
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
            if idle < 120 { self?.onRemind() }
        }
    }
}

/// A quick flash around the focused window, so you can see where you landed.
final class FocusFlash {
    private var panel: NSPanel?

    /// `frame` is in accessibility coordinates (top-left origin).
    func flash(_ frame: CGRect, color: NSColor) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cocoa = CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
            .insetBy(dx: -6, dy: -6)
        let panel = self.panel ?? Self.makePanel()
        self.panel = panel
        let view = NSView(frame: CGRect(origin: .zero, size: cocoa.size))
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.borderWidth = 6
        view.layer?.borderColor = color.cgColor
        view.layer?.backgroundColor = color.withAlphaComponent(0.12).cgColor
        panel.contentView = view
        panel.setFrame(cocoa, display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.45
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }

    static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        return panel
    }
}

/// Rings that close in on the pointer, to find it on a big screen.
final class PointerLocator {
    private var panel: NSPanel?

    func show(color: NSColor) {
        let mouse = NSEvent.mouseLocation
        let size: CGFloat = 220
        let panel = self.panel ?? FocusFlash.makePanel()
        self.panel = panel
        let view = NSView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.wantsLayer = true
        let ring = CAShapeLayer()
        ring.path = CGPath(ellipseIn: CGRect(x: 10, y: 10, width: size - 20, height: size - 20), transform: nil)
        ring.fillColor = NSColor.clear.cgColor
        ring.strokeColor = color.cgColor
        ring.lineWidth = 6
        ring.frame = view.bounds
        view.layer?.addSublayer(ring)
        panel.contentView = view
        panel.setFrame(CGRect(x: mouse.x - size / 2, y: mouse.y - size / 2, width: size, height: size), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1
        shrink.toValue = 0.12
        shrink.duration = 0.6
        shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)
        ring.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        ring.position = CGPoint(x: size / 2, y: size / 2)
        ring.bounds = view.bounds
        ring.add(shrink, forKey: "shrink")
        ring.transform = CATransform3DMakeScale(0.12, 0.12, 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { panel.orderOut(nil) }
    }
}

/// Rest the pointer in a screen corner to run something.
final class HotCorners {
    private var monitor: Any?
    private var dwell: Timer?
    private var armedCorner: Int?
    private var firedCorner: Int?
    /// Top-left, top-right, bottom-left, bottom-right.
    var corners: [HotCorner] = Array(repeating: .none, count: 4)
    var onTrigger: (HotCorner) -> Void = { _ in }

    func setEnabled(_ on: Bool) {
        if on, monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in self?.moved() }
        } else if !on, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
            dwell?.invalidate()
        }
    }

    private func moved() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) else { return }
        let f = screen.frame, slack: CGFloat = 3
        let left = mouse.x <= f.minX + slack, right = mouse.x >= f.maxX - slack - 1
        let top = mouse.y >= f.maxY - slack - 1, bottom = mouse.y <= f.minY + slack
        let corner: Int? = top && left ? 0 : top && right ? 1 : bottom && left ? 2 : bottom && right ? 3 : nil
        guard corner != armedCorner else { return }
        armedCorner = corner
        dwell?.invalidate()
        if corner == nil { firedCorner = nil }
        guard let corner, corner != firedCorner, corners.indices.contains(corner), corners[corner] != .none else { return }
        dwell = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self, self.armedCorner == corner else { return }
            self.firedCorner = corner
            self.onTrigger(self.corners[corner])
        }
    }
}

/// Sends events to a URL the user chose (Zapier, Home Assistant, a script server…).
enum Webhook {
    static func post(_ url: String, event: String, payload: [String: Any]) {
        guard let target = URL(string: url), ["http", "https"].contains(target.scheme?.lowercased() ?? "") else { return }
        var request = URLRequest(url: target, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Monorail/\(Bundle.main.shortVersion)", forHTTPHeaderField: "User-Agent")
        var body = payload
        body["event"] = event
        body["time"] = ISO8601DateFormatter().string(from: Date())
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }
}

/// Other apps can drive Monorail with a distributed notification:
/// `org.ashforde.monorail.perform` with the action name as the object.
final class RemoteCommands {
    static let name = Notification.Name("org.ashforde.monorail.perform")
    private var observer: NSObjectProtocol?
    var onPerform: (String) -> Void = { _ in }

    func setEnabled(_ on: Bool) {
        if on, observer == nil {
            observer = DistributedNotificationCenter.default().addObserver(forName: Self.name, object: nil, queue: .main) {
                [weak self] note in
                if let action = note.object as? String { self?.onPerform(action) }
            }
        } else if !on, let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
        }
    }
}

/// Recent log lines from Monorail, for About → Log.
enum LogViewer {
    static func recentLines(limit: Int = 400) -> [String] {
        guard #available(macOS 12, *) else { return ["The log viewer needs macOS 12 or later."] }
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let since = store.position(date: Date().addingTimeInterval(-3600))
            let entries = try store.getEntries(at: since).compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem.hasPrefix("org.ashforde") || $0.subsystem.contains("onorail") }
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return entries.suffix(limit).map { "\(formatter.string(from: $0.date))  \($0.category)  \($0.composedMessage)" }
        } catch {
            return ["Couldn’t read the log: \(error.localizedDescription)"]
        }
    }

    static func show() {
        let text = recentLines().joined(separator: "\n")
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Monorail log · last hour"
        window.isReleasedWhenClosed = false
        let scroll = NSTextView.scrollableTextView()
        if let view = scroll.documentView as? NSTextView {
            view.isEditable = false
            view.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            view.string = text.isEmpty ? "Nothing logged in the last hour." : text
            view.scrollToEndOfDocument(nil)
        }
        window.contentView = scroll
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        LogViewer.window = window
    }

    private static var window: NSWindow?
}
#endif
