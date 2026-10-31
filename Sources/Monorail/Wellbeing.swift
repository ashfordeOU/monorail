#if os(macOS)
import AppKit
import EventKit
import MetricKit
import MonorailCore
import SwiftUI
import Vision

/// Deep work: distracting apps are hidden and stay hidden until it ends.
final class DeepWork {
    private(set) var isOn = false
    private var endsAt: Date?
    private var observer: NSObjectProtocol?
    private var timer: Timer?
    var apps: () -> [String] = { [] }
    var onChange: (Bool) -> Void = { _ in }
    var onBlocked: (String) -> Void = { _ in }

    func toggle(minutes: Int? = nil) {
        isOn ? stop() : start(minutes: minutes)
    }

    func start(minutes: Int? = nil, until date: Date? = nil) {
        guard !isOn else { return }
        isOn = true
        endsAt = date ?? minutes.map { Date().addingTimeInterval(Double($0) * 60) }
        hideAll()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let id = app.bundleIdentifier, self.apps().contains(id)
            else { return }
            app.hide()
            self.onBlocked(app.localizedName ?? id)
        }
        timer = Timer.every(30) { [weak self] _ in
            guard let self, let endsAt = self.endsAt, Date() >= endsAt else { return }
            self.stop()
        }
        onChange(true)
    }

    func stop() {
        guard isOn else { return }
        isOn = false
        endsAt = nil
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
        timer?.invalidate()
        onChange(false)
    }

    private func hideAll() {
        let blocked = Set(apps())
        for app in NSWorkspace.shared.runningApplications where blocked.contains(app.bundleIdentifier ?? "") { app.hide() }
    }
}

/// Notices when you share your screen (Zoom, Teams, Meet, Webex, Slack, FaceTime,
/// macOS screen sharing) so private windows can step aside.
final class ScreenShareWatch {
    private var timer: Timer?
    private(set) var isSharing = false
    var onChange: (Bool) -> Void = { _ in }

    private static let ownerSignals: [(owner: String, name: String?)] = [
        ("CptHost", nil),                       // Zoom's sharing helper
        ("zoom.us", "zoom share"),
        ("Microsoft Teams", "sharing control bar"),
        ("Webex", "sharing"),
        ("Slack", "screen share"),
        ("FaceTime", "sharing"),
        ("Google Chrome", "is sharing"), ("Arc", "is sharing"), ("Safari", "is sharing"), ("Brave Browser", "is sharing"),
        ("Microsoft Edge", "is sharing"), ("Firefox", "sharing indicator"),
        // Not screencaptureui (⌘⇧5 screenshots) or the Screen Sharing app (viewing another Mac).
    ]

    func setEnabled(_ on: Bool) {
        timer?.invalidate()
        timer = nil
        guard on else {
            if isSharing { isSharing = false; onChange(false) }
            return
        }
        timer = Timer.every(2) { [weak self] _ in self?.check() }
    }

    private func check() {
        guard !Dormancy.shouldSkip() else { return }
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        else { return }
        let sharing = list.contains { info in
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let name = (info[kCGWindowName as String] as? String ?? "").lowercased()
            return Self.ownerSignals.contains { signal in
                owner == signal.owner && (signal.name.map { name.contains($0) } ?? true)
            }
        }
        if sharing != isSharing {
            isSharing = sharing
            onChange(sharing)
        }
    }
}

/// A clipboard history for each workspace: what you copied there stays there.
final class WorkspaceClipboard {
    private var timer: Timer?
    private var lastCount = NSPasteboard.general.changeCount
    private(set) var history: [Int: [String]] = [:]
    var currentWorkspace: () -> Int? = { nil }

    func setEnabled(_ on: Bool) {
        timer?.invalidate()
        timer = nil
        guard on else { return }
        timer = Timer.every(1) { [weak self] _ in self?.poll() }
    }

    private func poll() {
        guard !Dormancy.isDormant else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastCount else { return }
        lastCount = pasteboard.changeCount
        // Skip what password managers mark as concealed or transient.
        let types = pasteboard.types ?? []
        if types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
            || types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        {
            return
        }
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
            text.count < 5000, let workspace = currentWorkspace()
        else { return }
        var items = history[workspace] ?? []
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        history[workspace] = Array(items.prefix(15))
    }

    func items(for workspace: Int) -> [String] { history[workspace] ?? [] }

    /// Puts an item back on the clipboard (without adding it again).
    func use(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastCount = NSPasteboard.general.changeCount
    }
}

/// A picture behind everything that drifts gently as the strip scrolls.
final class WallpaperDrift {
    private var windows: [String: (window: NSWindow, view: NSImageView)] = [:]
    private var image: NSImage?
    private var path = ""

    func update(path: String, positions: [(screen: NSScreen, uuid: String, fraction: Double)]) {
        if path != self.path {
            self.path = path
            image = path.isEmpty ? nil : NSImage(contentsOfFile: (path as NSString).expandingTildeInPath)
        }
        guard let image else {
            windows.values.forEach { $0.window.orderOut(nil) }
            windows.removeAll()
            return
        }
        for (screen, uuid, fraction) in positions {
            let entry = windows[uuid] ?? make(for: screen, image: image)
            windows[uuid] = entry
            let frame = screen.frame
            // The picture is 12% wider than the screen and slides across that margin.
            let extra = frame.width * 0.12
            let x = -extra * min(max(fraction, 0), 1)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.6
                entry.view.animator().setFrameOrigin(NSPoint(x: x, y: 0))
            }
        }
    }

    private func make(for screen: NSScreen, image: NSImage) -> (window: NSWindow, view: NSImageView) {
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        let view = NSImageView(frame: NSRect(x: 0, y: 0, width: screen.frame.width * 1.12, height: screen.frame.height))
        view.image = image
        view.imageScaling = .scaleAxesIndependently
        container.addSubview(view)
        window.contentView = container
        window.orderBack(nil)
        return (window, view)
    }
}

/// Slides and workspaces shown around the MacBook notch for a moment as you move.
final class NotchHUD {
    private var panel: NSPanel?
    private var hideTimer: Timer?

    func show(slide: Int, slides: Int, workspace: Int, workspaces: Int) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) else { return }
        let height = screen.safeAreaInsets.top
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        let notchWidth = max(right.minX - left.maxX, 180)
        let width = notchWidth + 120
        let view = NSHostingView(rootView: NotchView(slide: slide, slides: slides, workspace: workspace, workspaces: workspaces))
        let panel = self.panel ?? FocusFlash.makePanel()
        self.panel = panel
        panel.level = .statusBar + 1
        panel.contentView = view
        panel.setFrame(NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            guard let panel = self?.panel else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; panel.animator().alphaValue = 0 },
                                                 completionHandler: { panel.orderOut(nil) })
        }
    }

    private struct NotchView: View {
        let slide: Int, slides: Int, workspace: Int, workspaces: Int
        var body: some View {
            HStack {
                HStack(spacing: 3) {
                    ForEach(0..<min(max(workspaces, 1), 9), id: \.self) { i in
                        Circle().fill(i == workspace - 1 ? Color.white : Color.white.opacity(0.3)).frame(width: 5, height: 5)
                    }
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<min(max(slides, 1), 9), id: \.self) { i in
                        Capsule().fill(i == slide - 1 ? Color.white : Color.white.opacity(0.35))
                            .frame(width: 4, height: i == slide - 1 ? 12 : 7)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// Crash and hang reports from macOS, kept on this Mac until you choose to send them.
final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static var folder: URL { SettingsStore.directory.appendingPathComponent("Diagnostics") }
    private var subscribed = false

    func setEnabled(_ on: Bool) {
        if on, !subscribed {
            MXMetricManager.shared.add(self)
            subscribed = true
        } else if !on, subscribed {
            MXMetricManager.shared.remove(self)
            subscribed = false
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        for payload in payloads {
            let name = "diagnostic-\(Int(payload.timeStampEnd.timeIntervalSince1970)).json"
            try? payload.jsonRepresentation().write(to: Self.folder.appendingPathComponent(name))
        }
    }

    static var reports: [URL] {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    }
}

/// Settings an organisation sets through a configuration profile (MDM) win over the user's.
enum ManagedSettings {
    /// Profiles target the app's bundle identifier.
    static var domain: String { Bundle.main.bundleIdentifier ?? "org.ashforde.macslider" }

    private static var defaults: UserDefaults? {
        Bundle.main.bundleIdentifier == domain ? .standard : UserDefaults(suiteName: domain)
    }

    /// The settings with every managed (forced) value applied.
    static func apply(to settings: AppSettings) -> AppSettings {
        guard let defaults else { return settings }
        let forced = defaults.dictionaryRepresentation().filter { defaults.objectIsForced(forKey: $0.key) }
        guard !forced.isEmpty, let data = try? JSONEncoder().encode(settings),
            var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return settings }
        for (key, value) in forced { object[key] = value }
        guard let merged = try? JSONSerialization.data(withJSONObject: object),
            let result = try? JSONDecoder().decode(AppSettings.self, from: merged)
        else { return settings }
        return result
    }

    static var managedKeys: [String] {
        guard let defaults else { return [] }
        return defaults.dictionaryRepresentation().keys.filter { defaults.objectIsForced(forKey: $0) }.sorted()
    }
}

/// Finds a window by the words in it: reads every window's picture on this Mac.
enum WindowTextSearch {
    static func search(_ query: String, in ids: [WindowID], completion: @escaping (WindowID?) -> Void) {
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return completion(nil) }
        WindowThumbnails.capture(ids) { images in
            DispatchQueue.global(qos: .userInitiated).async {
                var best: (WindowID, Int)?
                for (id, image) in images {
                    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .fast
                    try? VNImageRequestHandler(cgImage: cg).perform([request])
                    let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ").lowercased()
                    let hits = words.filter { text.contains($0) }.count
                    if hits > (best?.1 ?? 0) { best = (id, hits) }
                }
                DispatchQueue.main.async { completion(best?.0) }
            }
        }
    }
}

/// A page that shows off your setup: themes, workspaces, rules and shortcuts.
enum SetupExporter {
    static func html(settings: AppSettings, workspaces: [(name: String, apps: [String])]) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        let cards = workspaces.enumerated().map { index, ws in
            "<div class=card><b>\(index + 1) · \(esc(ws.name))</b><p>\(ws.apps.map(esc).joined(separator: " · "))</p></div>"
        }.joined()
        let rules = settings.appRules.map { "<li>\(esc($0.name))\($0.float ? " floats" : "")\($0.width.map { " · width \(Int($0 * 100))%" } ?? "")</li>" }.joined()
        return """
        <!doctype html><html><head><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
        <title>My Monorail setup</title><style>
        body{font-family:-apple-system,system-ui;margin:0;background:#0b1020;color:#eef;padding:40px 20px}
        main{max-width:860px;margin:auto}h1{font-size:34px;margin:0}h2{margin-top:36px;font-size:18px;opacity:.85}
        .sub{opacity:.6}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:12px}
        .card{background:linear-gradient(135deg,#1f2a5a,#3a1f5a);border-radius:16px;padding:16px}
        .card p{opacity:.75;margin:6px 0 0;font-size:14px}code{background:#ffffff1a;padding:2px 6px;border-radius:6px}
        a{color:#9cf}</style></head><body><main>
        <h1>My Monorail setup</h1><p class=sub>Theme: \(esc(settings.theme.title)) · \(settings.workspaceCount) workspaces ·
        made with <a href="https://github.com/ashfordeOU/monorail">Monorail by Ashforde®</a></p>
        <h2>Workspaces</h2><div class=grid>\(cards)</div>
        <h2>App rules</h2><ul>\(rules.isEmpty ? "<li>None</li>" : rules)</ul>
        <h2>Try it</h2><p>Get Monorail, then open the <code>.monorail</code> file shared with this page to use the same layouts.</p>
        </main></body></html>
        """
    }
}

/// Runs a Shortcut by name (for workspace contexts: Focus, audio, status…).
enum ShortcutRunner {
    static func run(_ name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        try? process.run()
    }
}

/// Stage Manager and Monorail both arrange windows; say so once if both are on.
enum StageManagerCheck {
    static var isOn: Bool {
        UserDefaults(suiteName: "com.apple.WindowManager")?.bool(forKey: "GloballyEnabled") ?? false
    }
}

/// Calendar events called "Focus" or "Deep work" start deep work until they end.
final class CalendarFocus {
    private let store = EKEventStore()
    private var timer: Timer?
    var onFocusEvent: (_ until: Date) -> Void = { _ in }
    private var handled: Set<String> = []

    func setEnabled(_ on: Bool) {
        timer?.invalidate()
        timer = nil
        guard on else { return }
        timer = Timer.every(60) { [weak self] _ in self?.check() }
        check()
    }

    private func check() {
        // 3 is "full access" (and the older "authorized").
        guard EKEventStore.authorizationStatus(for: .event).rawValue == 3 else { return }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-60), end: now.addingTimeInterval(60), calendars: nil)
        for event in store.events(matching: predicate) {
            let title = (event.title ?? "").lowercased()
            guard title.contains("focus") || title.contains("deep work"), event.startDate <= now, event.endDate > now,
                let id = event.eventIdentifier, !handled.contains(id)
            else { continue }
            handled.insert(id)
            onFocusEvent(event.endDate)
        }
    }
}

/// Every recent layout change on a line; pick one to go back to just before it.
struct TimelineView: View {
    let changes: [(label: String, date: Date)]
    let undo: (Int) -> Void
    @State private var position = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layout timeline").font(.system(size: 18, weight: .bold, design: .rounded))
            if changes.isEmpty {
                Text("No changes yet. Every move, resize and pairing lands here.").foregroundStyle(.secondary)
            } else {
                Slider(value: $position, in: 0...Double(changes.count), step: 1)
                Text(position == 0 ? "Now" : "Before “\(changes[Int(position) - 1].label)” · \(changes[Int(position) - 1].date.formatted(date: .omitted, time: .shortened))")
                    .font(.callout).foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(changes.enumerated()), id: \.offset) { index, change in
                            HStack {
                                Circle().fill(index < Int(position) ? Color.orange : Color.accentColor).frame(width: 7, height: 7)
                                Text(change.label)
                                Spacer()
                                Text(change.date.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                    }
                }
                .frame(maxHeight: 220)
                HStack {
                    Spacer()
                    Button("Go back") { undo(Int(position)) }.disabled(position == 0).keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
#endif
