#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// `Monorail --self-test`: builds every Settings pane and panel, checks every action,
/// theme, language and default, and exits non-zero on the first problem. It needs no
/// permissions, so CI runs it on every build to catch what the compiler can't.
enum SelfTest {
    private static var failures: [String] = []

    private static func check(_ ok: Bool, _ what: String) {
        if !ok { failures.append(what) }
    }

    static func run() -> Int32 {
        _ = NSApplication.shared
        let settings = AppSettings()
        // Settings survive a round trip, and old files without newer keys still load.
        if let data = try? JSONEncoder().encode(settings) {
            check((try? JSONDecoder().decode(AppSettings.self, from: data)) != nil, "settings round trip")
        }
        check((try? JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))) != nil, "empty settings decode")
        // Every action has a name, a title and a URL.
        for action in Action.allCases {
            check(!action.title.isEmpty, "title for \(action.rawValue)")
            check(Action(rawValue: action.rawValue) == action, "round trip for \(action.rawValue)")
            check(URL(string: "monorail://\(action.rawValue)") != nil, "URL for \(action.rawValue)")
        }
        // Themes have their full palettes.
        for theme in Theme.allCases {
            check(WorkspaceColor.palette(theme).count >= 6, "palette for \(theme.rawValue)")
            let backdrop = WorkspaceColor.backdrop(theme)
            check(backdrop.gradient.count == 3 && backdrop.glows.count == 3, "backdrop for \(theme.rawValue)")
        }
        // Each language translates the Settings tabs.
        for (code, _) in Localization.languages where !code.isEmpty && code != "en" {
            Localization.choose(code)
            check(L("Settings…") != "Settings…", "\(code) translates Settings…")
            check(L("Stay Awake") != "Stay Awake", "\(code) translates Stay Awake")
        }
        Localization.choose("en")
        // Every Settings pane builds and lays out.
        let store = SettingsStore()
        let panes: [(String, AnyView)] = [
            ("Smart", AnyView(SmartPane(store: store))),
            ("Devices", AnyView(DevicesPane(store: store))),
            ("Stay Awake", AnyView(StayAwakePane(store: store))),
            ("Settings window", AnyView(SettingsView(store: store, navigation: SettingsNavigation(), stats: UsageStats(),
                                                     isPaused: { false }, setPaused: { _ in }))),
        ]
        for (name, view) in panes {
            let host = NSHostingView(rootView: view.frame(width: 980, height: 680))
            host.layoutSubtreeIfNeeded()
            check(host.fittingSize.width > 0, "\(name) lays out")
        }
        // The help index and settings index answer common questions.
        check(!HelpIndex.answers(for: "how do I keep my mac awake").isEmpty, "help: stay awake")
        check(!SettingsIndex.search("animate").isEmpty, "settings search: animate")
        // Stay Awake's helpers work without a session.
        check(AwakeFormat.clock(90) == "1:30", "awake clock")
        if failures.isEmpty {
            print("Monorail self-test passed: \(Action.allCases.count) actions, \(Theme.allCases.count) themes, \(Localization.languages.count - 1) languages, \(panes.count) panes")
            return 0
        }
        failures.forEach { print("FAILED: \($0)") }
        return 1
    }
}
#endif
