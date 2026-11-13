#if os(macOS)
import AppIntents
import AppKit
import MonorailCore

/// What the Shortcuts actions do, wired up by the app delegate when it starts.
enum ShortcutsBridge {
    static var stayAwake: (Int) -> Void = { _ in }
    static var endStayAwake: () -> Void = {}
    static var setEvening: (Bool) -> Void = { _ in }
    static var arrange: (String) -> Bool = { _ in false }
}

/// Shortcuts and Spotlight actions. They run inside the app (which is already in the menu bar), so
/// nothing opens. Station has the same ones except arranging windows.
struct StayAwakeIntent: AppIntent {
    static var title: LocalizedStringResource = "Keep Mac Awake"
    static var description = IntentDescription("Keeps your Mac and its screen awake for a while, or until you turn it off.")
    @Parameter(title: "Minutes", description: "0 keeps it awake until you turn it off.", default: 60, inclusiveRange: (0, 1440))
    var minutes: Int

    static var parameterSummary: some ParameterSummary { Summary("Keep Mac awake for \(\.$minutes) minutes") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        ShortcutsBridge.stayAwake(minutes)
        return .result(dialog: minutes == 0 ? "Your Mac stays awake until you turn it off." : "Your Mac stays awake for \(minutes) minutes.")
    }
}

struct EndStayAwakeIntent: AppIntent {
    static var title: LocalizedStringResource = "Let Mac Sleep"
    static var description = IntentDescription("Ends Stay Awake, so your Mac sleeps as usual.")

    @MainActor func perform() async throws -> some IntentResult {
        ShortcutsBridge.endStayAwake()
        return .result()
    }
}

struct EveningModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Evening Mode"
    static var description = IntentDescription("Turns the warmer evening screen on or off.")
    @Parameter(title: "On", default: true)
    var on: Bool

    static var parameterSummary: some ParameterSummary { Summary("Turn Evening Mode \(\.$on)") }

    @MainActor func perform() async throws -> some IntentResult {
        ShortcutsBridge.setEvening(on)
        return .result()
    }
}

struct FilmModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Film Mode"
    static var description = IntentDescription("Keeps the screen on with true colours and quiet notices, for watching something.")
    @Parameter(title: "On", default: true)
    var on: Bool

    static var parameterSummary: some ParameterSummary { Summary("Turn Film mode \(\.$on)") }

    @MainActor func perform() async throws -> some IntentResult {
        MomentsWatch.shared.setFilm(on)
        return .result()
    }
}

struct FocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Session"
    static var description = IntentDescription("Starts a focus session with your chosen sound.")
    @Parameter(title: "Minutes", default: 25, inclusiveRange: (1, 240))
    var minutes: Int

    static var parameterSummary: some ParameterSummary { Summary("Focus for \(\.$minutes) minutes") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        FocusWatch.shared.start(minutes: minutes)
        return .result(dialog: "Focusing for \(minutes) minutes.")
    }
}

struct BatteryReportIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Battery Report"
    static var description = IntentDescription("Your battery's charge, health, cycles and recent charges, as text.")

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: BatteryLog.shared.report)
    }
}

struct ClipboardPlainIntent: AppIntent {
    static var title: LocalizedStringResource = "Make Clipboard Plain Text"
    static var description = IntentDescription("Removes formatting from what's on the clipboard.")

    @MainActor func perform() async throws -> some IntentResult {
        if let text = NSPasteboard.general.string(forType: .string) { ClipboardWatch.shared.copy(PlainText.clean(text)) }
        return .result()
    }
}

#if !APPSTORE
/// Monorail only: put windows in an arrangement by saying it ("Slack and Mail side by side").
struct ArrangeIntent: AppIntent {
    static var title: LocalizedStringResource = "Arrange Windows"
    static var description = IntentDescription("Arranges your windows from a sentence, like “Slack and Mail side by side”, or a saved layout's name.")
    @Parameter(title: "Arrangement")
    var arrangement: String

    static var parameterSummary: some ParameterSummary { Summary("Arrange \(\.$arrangement)") }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        ShortcutsBridge.arrange(arrangement) ? .result(dialog: "Done.") : .result(dialog: "Monorail couldn't work that out. Try a saved layout's name.")
    }
}

#endif

/// The ready-made phrases for Siri and Spotlight.
struct AshfordeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StayAwakeIntent(), phrases: ["Keep my Mac awake with \(.applicationName)", "\(.applicationName) stay awake"],
                    shortTitle: "Keep Mac Awake", systemImageName: "cup.and.saucer.fill")
        AppShortcut(intent: EndStayAwakeIntent(), phrases: ["Let my Mac sleep with \(.applicationName)"],
                    shortTitle: "Let Mac Sleep", systemImageName: "moon.zzz.fill")
        AppShortcut(intent: EveningModeIntent(), phrases: ["Turn on Evening Mode in \(.applicationName)"],
                    shortTitle: "Evening Mode", systemImageName: "moon.fill")
        AppShortcut(intent: FilmModeIntent(), phrases: ["Start Film mode in \(.applicationName)"],
                    shortTitle: "Film Mode", systemImageName: "film.fill")
        AppShortcut(intent: FocusSessionIntent(), phrases: ["Start a focus session in \(.applicationName)"],
                    shortTitle: "Focus Session", systemImageName: "timer")
        AppShortcut(intent: BatteryReportIntent(), phrases: ["Get my battery report from \(.applicationName)"],
                    shortTitle: "Battery Report", systemImageName: "battery.100.bolt")
    }
}
#endif
