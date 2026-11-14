#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// Keeper and Monorail both have an island: the person sees the two side by side and picks one. The
/// other hides while both run (and Monorail's live items go to Keeper's Island if that's the choice).
enum IslandChoice {
    private static var window: NSWindow?

    static func show(choose: @escaping (SuiteRules.App) -> Void) {
        window?.close()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 470), styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.title = "Choose your island"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: IslandChoiceView { app in
            choose(app)
            Self.window?.close()
        })
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct IslandChoiceView: View {
    let choose: (SuiteRules.App) -> Void

    private let keeper = [
        ("music.note", "Music, with album art"),
        ("timer", "Timers"),
        ("calendar", "Your next meeting, with Join"),
        ("bell.badge", "Alerts and live activities"),
        ("tray.and.arrow.down", "A drop shelf"),
        ("paintpalette", "Colourful themes"),
    ]
    private let monorail = [
        ("music.note", "Music, with play, pause and skip"),
        ("video", "Calls, recording and screen sharing"),
        ("bolt", "Battery, charging and Stay Awake"),
        ("arrow.down.circle", "Downloads and AI limits"),
        ("tray.and.arrow.down", "A drop shelf with AirDrop"),
        ("speaker.wave.2", "Volume and brightness, in the island"),
    ]

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Two islands, one notch").font(.system(size: 22, weight: .bold))
                Text("Keeper and \(Brand.name) both have an island. Pick the one you like; the other hides while both are open, so nothing shows twice. You can change this any time in Settings.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 14) {
                column("Keeper's Island", features: keeper, note: "\(Brand.name)'s live items (Stay Awake, downloads, calls) show in it too.", app: .keeper)
                column("\(Brand.name)'s island", features: monorail, note: "Keeper's own island stays hidden while \(Brand.name) runs.", app: .monorail)
            }
        }
        .padding(.horizontal, 26).padding(.top, 34).padding(.bottom, 24)
        .frame(width: 640)
    }

    private func column(_ title: String, features: [(String, String)], note: String, app: SuiteRules.App) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule().fill(.black).frame(width: 120, height: 26)
                .overlay(Image(systemName: app == .keeper ? "sparkles" : "rectangle.split.3x1").font(.system(size: 11)).foregroundStyle(.white))
                .frame(maxWidth: .infinity)
            Text(title).font(.system(size: 15, weight: .semibold))
            ForEach(features.indices, id: \.self) { index in
                Label(features[index].1, systemImage: features[index].0).font(.system(size: 12.5))
            }
            Text(note).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { choose(app) } label: { Text("Use \(title)").frame(maxWidth: .infinity) }
                .controlSize(.large).buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.08)))
    }
}

/// The first time Keeper takes over an area: one note saying what and why, with a way to choose otherwise.
enum SuiteNote {
    static func show(_ areas: Set<SuiteArea>, openSettings: @escaping () -> Void) {
        let names = SuiteArea.allCases.filter { areas.contains($0) }.map(\.title)
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + names.last! : names.first ?? ""
        let alert = NSAlert()
        alert.messageText = "Keeper looks after \(list) now"
        alert.informativeText = "Keeper is open and has these switched on, so \(Brand.name)'s own rest and nothing runs twice. They come back by themselves when Keeper quits."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Use \(Brand.name)'s Instead…")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { openSettings() }
    }
}

/// Settings: who looks after what while Keeper is on the Mac too, with a choice per area.
struct SuiteSharingSection: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject private var role = SuiteRole.shared
    var onChange: () -> Void = {}

    private var areas: [SuiteArea] { SuiteArea.allCases.filter { $0.owner != .both && $0 != .awake && $0 != .focus && $0 != .stage && $0 != .alarms } }

    var body: some View {
        if role.keeper != nil || NSWorkspace.shared.urlForApplication(withBundleIdentifier: Companions.keeper) != nil {
            Section {
                ForEach(areas, id: \.self) { area in
                    HStack {
                        Text(area.title.prefix(1).uppercased() + area.title.dropFirst())
                        Spacer()
                        if role.rests(area) { Text("Keeper").font(.caption).foregroundStyle(.secondary) }
                        Picker("", selection: binding(area)) {
                            Text(agreed(area)).tag("")
                            Text("Keeper").tag("keeper")
                            Text(Brand.name).tag("monorail")
                        }
                        .labelsHidden().frame(width: 170)
                    }
                }
            } header: {
                Text("With Keeper")
            } footer: {
                Text("When Keeper and \(Brand.name) are both open, each of these runs in one of them only. The other's rests, and comes back when the first quits.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func agreed(_ area: SuiteArea) -> String {
        switch area.owner {
        case .keeper: return "Usual (Keeper)"
        case .monorail: return "Usual (\(Brand.name))"
        default: return "Ask me"
        }
    }

    private func binding(_ area: SuiteArea) -> Binding<String> {
        Binding(get: { store.settings.suitePrefer[area.rawValue] ?? "" }, set: { value in
            if value.isEmpty {
                store.settings.suitePrefer[area.rawValue] = nil
                store.settings.suitePreferAt[area.rawValue] = nil
            } else {
                store.settings.suitePrefer[area.rawValue] = value
                store.settings.suitePreferAt[area.rawValue] = Date().timeIntervalSince1970 * 1000
            }
            SuiteRole.shared.evaluateAreas()
            onChange()
        })
    }
}
#endif
