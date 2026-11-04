#if os(macOS)
import AppKit
import IOKit
import IOKit.pwr_mgt
import MonorailCore
import MonorailEngine
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
            ("Evening Mode", AnyView(EveningPane(store: store))),
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
        // The Mac's WindowSystem (the shared engine's backend) reads displays and windows without
        // failing, even with no Accessibility access (CI has none, so it sees no windows).
        let windowSystem = AXWindowSystem()
        let displayInfos = windowSystem.displays
        check(displayInfos.count == NSScreen.screens.count, "window system: displays")
        check(displayInfos.allSatisfy { $0.visibleFrame.width > 0 && $0.frame.width >= $0.visibleFrame.width }, "window system: display frames")
        _ = windowSystem.windows()
        _ = windowSystem.focusedWindow()
        // The shared engine starts on it (no Accessibility in CI, so no windows to tile).
        let shared = SharedEngine(system: windowSystem, config: settings.layout(for: displayInfos.first?.id ?? ""))
        shared.start()
        check(shared.strips.values.allSatisfy { !$0.isEmpty }, "shared engine: no empty strips")
        windowSystem.start()
        check(windowSystem.isStarted, "window system: events start")
        windowSystem.stop()
        check(!windowSystem.isStarted, "window system: events stop")
        // Stay Awake's helpers work without a session.
        check(AwakeFormat.clock(90) == "1:30", "awake clock")
        if failures.isEmpty {
            print("Monorail self-test passed: \(Action.allCases.count) actions, \(Theme.allCases.count) themes, \(Localization.languages.count - 1) languages, \(panes.count) panes")
            return 0
        }
        failures.forEach { print("FAILED: \($0)") }
        return 1
    }

    /// Measures the idle time, waits about three seconds without input, declares user activity
    /// (as Keep me Available does) and measures again: it should drop. Never fails for a runner
    /// without an input session; it prints the numbers either way.
    static func checkAvailable() -> Int32 {
        let before0 = StayAwake.idleSeconds()
        Thread.sleep(forTimeInterval: 3)
        let before = StayAwake.idleSeconds()
        let declared = StayAwake.declareActivity()
        Thread.sleep(forTimeInterval: 0.5)
        let after = StayAwake.idleSeconds()
        print("Keep me Available check: idle \(before0) s at start; declaring activity \(declared ? "succeeded" : "failed")")
        print("Keep me Available check \(AwakePresence.idleCheckVerdict(before: before, after: after))")
        // Other ways that need no permission, measured the same way (and with IOKit's own idle clock).
        func trial(_ name: String, _ act: () -> Void) {
            Thread.sleep(forTimeInterval: 2)
            let b = StayAwake.idleSeconds(), hb = hidIdleSeconds()
            act()
            Thread.sleep(forTimeInterval: 0.5)
            let a = StayAwake.idleSeconds(), ha = hidIdleSeconds()
            print("Keep me Available trial \(name): event idle \(Int(b)) → \(Int(a)) s; HID idle \(hb.map { String(Int($0)) } ?? "?") → \(ha.map { String(Int($0)) } ?? "?") s")
        }
        trial("warp pointer") {
            if let p = CGEvent(source: nil)?.location {
                CGWarpMouseCursorPosition(CGPoint(x: p.x + 1, y: p.y)); CGWarpMouseCursorPosition(p)
            }
        }
        trial("user-is-active assertion") {
            var id: IOPMAssertionID = 0
            if IOPMAssertionCreateWithName("PreventUserIdleDisplaySleep" as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                           "Monorail check" as CFString, &id) == kIOReturnSuccess {
                IOPMAssertionRelease(id)
            }
            _ = StayAwake.declareActivity()
        }
        trial("posted mouse move (needs Accessibility)") {
            if let p = CGEvent(source: nil)?.location {
                CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: .mouseMoved,
                        mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
            }
        }
        return 0
    }

    /// IOKit's idle time (what some apps read instead of the event clock), in seconds.
    static func hidIdleSeconds() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let value = IORegistryEntryCreateCFProperty(service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber else { return nil }
        return value.doubleValue / 1_000_000_000
    }
}
#endif
