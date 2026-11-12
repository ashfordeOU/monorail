#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI
import UserNotifications

/// Caps Lock as the Monorail key. macOS is asked (with hidutil) to send F18
/// for Caps Lock while Monorail runs; holding it then works like ⌃⌥, and a
/// tap on its own opens the command palette. Turned back on quit.
enum CapsLockKey {
    static let f18: UInt16 = 79
    /// The key turned into the Monorail key (Caps Lock unless chosen otherwise).
    static var source = 0x7_0000_0039
    private static let f18Usage = 0x7_0000_006D

    static func set(_ on: Bool) {
        let mapping = on
            ? #"{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":\#(source),"HIDKeyboardModifierMappingDst":\#(f18Usage)}]}"#
            : #"{"UserKeyMapping":[]}"#
        // Only clear the mapping if it's ours, so other remaps survive.
        if !on, let current = run(["property", "--get", "UserKeyMapping"]),
            current.contains("HIDKeyboardModifierMappingSrc"), !current.contains(String(f18Usage))
        {
            return
        }
        _ = run(["property", "--set", mapping])
    }

    @discardableResult
    private static func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}

// MARK: - What's New

/// After an update, a window with that version's part of the changelog.
final class WhatsNew {
    private var window: NSWindow?
    /// Runs an action from a "Try it" button.
    var tryAction: (Action) -> Void = { _ in }
    /// The settings, for switching this version's new features on from the window.
    var store: SettingsStore?

    func show(version: String) {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
            let changelog = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        let notes = Self.section(for: version, in: changelog)
        guard !notes.isEmpty else { return }
        showNotes(notes, version: version)
    }

    /// After an update: the window only for releases with something new to show; small fixes
    /// stay quiet. Either way it's in the menu under What's New.
    func showIfNotable(version: String) {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
            let changelog = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        let notes = Self.section(for: version, in: changelog)
        guard ReleaseNotes.isNotable(notes) else { return }
        showNotes(notes, version: version)
    }

    private func showNotes(_ notes: [String], version: String) {
        guard let store else { return }
        let view = WhatsNewView(version: version, lines: notes, store: store, offersSwitches: true,
                                tryAction: { [weak self] action in
            self?.window?.close()
            self?.tryAction(action)
        }) { [weak self] in self?.window?.close() }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "What’s New in \(Brand.full) \(version)"
        window.keepInFront()
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// The lines between "## [version]" and the next "## [".
    static func section(for version: String, in changelog: String) -> [String] {
        var lines: [String] = []
        var inside = false
        for line in changelog.components(separatedBy: .newlines) {
            if line.hasPrefix("## [") {
                if inside { break }
                inside = line.hasPrefix("## [\(version)]")
                continue
            }
            if inside, !line.trimmingCharacters(in: .whitespaces).isEmpty { lines.append(line) }
        }
        return lines
    }
}

struct WhatsNewView: View {
    let version: String
    let lines: [String]
    @ObservedObject var store: SettingsStore
    let offersSwitches: Bool
    let tryAction: (Action) -> Void
    let close: () -> Void

    /// This version's new features, each off until switched on here.
    private var newSwitches: [StarterExtra] {
        StarterExtra.newInThisVersion.filter { !(Edition.isAppStore && $0 == .windowSwitcher) }
    }

    private func binding(_ item: StarterExtra) -> Binding<Bool> {
        Binding(get: { item.isOn(in: store.settings) }, set: { on in item.set(on, in: &store.settings) })
    }

    /// The features people most often miss, with a button to try each.
    private static let highlights: [(symbol: String, title: String, text: String, action: Action)] = [
        ("sparkles", "Say it", "Type “Slack and Mail side by side on 3” or “write the Q3 report” in the palette.", .commandPalette),
        ("cup.and.saucer.fill", "Stay Awake", "Keep your Mac awake for an hour, while downloading, or by itself.", .awake60),
        ("eye.slash", "Safe screen sharing", "Private windows step aside when you share. Mark one private now.", .markPrivate),
        ("bell.badge", "AI agent alerts", "Run an AI coding assistant in a terminal: hear a chime when it waits for you.", .commandPalette),
    ]

    /// Apple's "What's New": a big title, a few rows with coloured icons rising in one by one,
    /// the rest folded away, and one blue button.
    var body: some View {
        let rows = ReleaseNotes.highlights(lines, limit: 4)
        VStack(spacing: 0) {
            Text("What’s New in \(Brand.name)").font(.system(size: 28, weight: .bold)).multilineTextAlignment(.center)
            Text("Version \(version)").font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 3).padding(.bottom, 24)
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    FeatureRow(symbol: ReleaseStyle.symbol(row.kind), tint: ReleaseStyle.tint(row.kind), title: row.title, text: row.text,
                               delay: Double(index) * 0.08)
                }
            }
            if offersSwitches, !newSwitches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Try the new features").font(.system(size: 13, weight: .semibold))
                    ForEach(newSwitches, id: \.self) { item in
                        Toggle(item.title, isOn: binding(item)).toggleStyle(.checkbox)
                    }
                    Text("They stay off unless you tick them. Change them any time in Settings.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                .padding(.top, 18)
            }
            DisclosureGroup("All changes in \(version)") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            if line.hasPrefix("### ") {
                                Text(line.dropFirst(4)).font(.system(size: 12, weight: .semibold)).padding(.top, 4)
                            } else {
                                let text = line.hasPrefix("- ") ? String(line.dropFirst(2)) : line
                                Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
                                    .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 160)
            }
            .font(.system(size: 12))
            .padding(.top, 18)
            Button(action: close) { Text("Continue").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 22)
            Link("Full changelog", destination: URL(string: "https://monorail.ashforde.org/changelog/")!)
                .font(.system(size: 11)).padding(.top, 10)
        }
        .padding(.horizontal, 44).padding(.top, 40).padding(.bottom, 20)
        .frame(width: 500)
    }
}

// MARK: - Weekly summary

/// Monday mornings: a notification with last week's switches, top workspace and top pair.
final class WeeklySummary {
    var stats: UsageStats?
    var workspaceTitle: (Int) -> String = { _ in "" }
    var isEnabled: () -> Bool = { false }
    private var timer: Timer?
    private static let sentKey = "weeklySummarySent"

    func start() {
        timer = Timer.every(1800) { [weak self] _ in self?.check() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in self?.check() }
    }

    private func check() {
        guard isEnabled(), let stats else { return }
        let calendar = Calendar.current
        let now = Date()
        guard calendar.component(.weekday, from: now) == 2, calendar.component(.hour, from: now) >= 9 else { return }
        let week = "\(calendar.component(.yearForWeekOfYear, from: now))-\(calendar.component(.weekOfYear, from: now))"
        guard UserDefaults.standard.string(forKey: Self.sentKey) != week else { return }
        let days = stats.lastDays(8).dropLast()
        let switches = days.reduce(0) { $0 + $1.day.switches }
        guard switches > 0 else { return }
        let time = stats.time(days: 7)
        var body = "\(switches) slide switches"
        if let top = time.workspaces.first { body += " · most time in \(top.0) (\(InsightsPane.duration(top.1)))" }
        if let pair = stats.topPairs(1).first {
            body += " · \(pair.apps.map(UsageStats.appName).joined(separator: " + ")) together most"
        }
        let content = UNMutableNotificationContent()
        content.title = "Your week with Monorail"
        content.body = body
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            center.add(UNNotificationRequest(identifier: "weekly-\(week)", content: content, trigger: nil))
            DispatchQueue.main.async { UserDefaults.standard.set(week, forKey: Self.sentKey) }
        }
    }
}
extension NSWindow {
    /// For Monorail's own messages (welcome, What's New, permissions): stays in front of other
    /// windows, never joins a tab group, and follows you to the Space you're on.
    func keepInFront() {
        level = .floating
        tabbingMode = .disallowed
        collectionBehavior.insert([.moveToActiveSpace, .fullScreenAuxiliary])
        collectionBehavior.remove(.canJoinAllSpaces)
        hidesOnDeactivate = false
    }
}
#endif
