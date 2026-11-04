/// The three ways to start (first run, and Settings → Basics): simple, everything, or bringing a
/// setup over from another app. Each also decides how much of Settings shows.
public enum StarterSetup: String, Codable, CaseIterable, Sendable {
    case simple, power, switching

    public var title: String {
        switch self {
        case .simple: return "Simple"
        case .power: return "Power user"
        case .switching: return "Coming from another app"
        }
    }

    public var detail: String {
        switch self {
        case .simple: return "The scrolling strip with sensible defaults, and only the settings most people change."
        case .power: return "Every setting in the sidebar, the workspace indicator and the ‹ › arrows in the menu bar."
        case .switching: return "Brings over your shortcuts, gaps, floating apps and workspaces from AeroSpace, yabai or Rectangle."
        }
    }
}

/// Which Settings sections show in the sidebar. Search always finds every setting.
public enum SettingsVisibility {
    /// The sections shown while "Show all settings" is off.
    public static let essential: [String] = ["basics", "shortcuts", "appearance", "evening", "awake", "about"]

    public static func isShown(_ tab: String, showAll: Bool) -> Bool {
        showAll || essential.contains(tab)
    }
}

extension AppSettings {
    public mutating func apply(_ setup: StarterSetup) {
        switch setup {
        case .simple:
            apply(StartStyle.scrolling)
            showAllSettings = false
        case .power:
            showAllSettings = true
            showNavigationArrows = true
            workspaceHUD = true
        case .switching:
            // The importer sets the rest; switchers usually want everything at hand.
            showAllSettings = true
        }
    }
}

/// The "Pick your extras" checklist in the welcome tour (and the switches in What's New): one line
/// each, bound to real settings. Which start ticked depends on the starter setup.
public enum StarterExtra: String, CaseIterable, Sendable {
    case swipe, windowSwitcher, edgeSnapping, eveningSunset, terminalsTogether, awakeInMenuBar, keepAvailable, agentChime, usageCounts

    public var title: String {
        switch self {
        case .swipe: return "Three-finger swipe moves the strip"
        case .windowSwitcher: return "⌘Tab switcher with window previews"
        case .edgeSnapping: return "Snap windows by dragging to screen edges"
        case .eveningSunset: return "Evening Mode from sunset to sunrise"
        case .terminalsTogether: return "Keep terminals together"
        case .awakeInMenuBar: return "Stay Awake in the menu bar"
        case .keepAvailable: return "Keep Teams and Slack showing you as Available"
        case .agentChime: return "Chime when your AI coding assistant is waiting"
        case .usageCounts: return "Anonymous usage counts"
        }
    }

    /// Whether it's on in `settings`.
    public func isOn(in settings: AppSettings) -> Bool {
        switch self {
        case .swipe: return settings.swipeFingers == .three
        case .windowSwitcher: return settings.windowSwitcherShortcut == .commandTab
        case .edgeSnapping: return settings.edgeSnapping
        case .eveningSunset: return settings.eveningSchedule == .sun
        case .terminalsTogether: return settings.groupTerminals
        case .awakeInMenuBar: return settings.awakeShowTime
        case .keepAvailable: return settings.keepAvailable
        case .agentChime: return settings.agentAlerts
        case .usageCounts: return settings.shareUsageStats
        }
    }

    /// Turns it on or off in `settings`, leaving related choices alone where it can.
    public func set(_ on: Bool, in settings: inout AppSettings) {
        switch self {
        case .swipe:
            if on { settings.swipeFingers = .three } else if settings.swipeFingers == .three { settings.swipeFingers = .off }
        case .windowSwitcher:
            if on { settings.windowSwitcherShortcut = .commandTab } else if settings.windowSwitcherShortcut == .commandTab { settings.windowSwitcherShortcut = .off }
        case .edgeSnapping: settings.edgeSnapping = on
        case .eveningSunset:
            if on { settings.eveningSchedule = .sun } else if settings.eveningSchedule == .sun { settings.eveningSchedule = .manual }
        case .terminalsTogether: settings.groupTerminals = on
        case .awakeInMenuBar: settings.awakeShowTime = on
        case .keepAvailable: settings.keepAvailable = on
        case .agentChime: settings.agentAlerts = on
        case .usageCounts: settings.shareUsageStats = on
        }
    }

    /// Which extras a starter setup ticks. Simple keeps to the gentle ones; the others take most,
    /// but never the ones that take over system gestures and shortcuts (the ⌘Tab switcher and
    /// three-finger swipes) or keep the Mac awake for good (Keep me Available): those stay off unless ticked.
    public static func defaults(for setup: StarterSetup) -> Set<StarterExtra> {
        switch setup {
        case .simple: return [.terminalsTogether, .awakeInMenuBar, .agentChime, .usageCounts]
        case .power, .switching: return Set(allCases).subtracting([.windowSwitcher, .swipe, .keepAvailable])
        }
    }

    /// Extras offered to people updating (What's New): the ones new in this version.
    public static let newInThisVersion: [StarterExtra] = [.windowSwitcher, .edgeSnapping, .eveningSunset]
}

extension AppSettings {
    /// Ticks exactly the extras a starter setup starts with.
    public mutating func applyExtras(for setup: StarterSetup) {
        let on = StarterExtra.defaults(for: setup)
        for extra in StarterExtra.allCases { extra.set(on.contains(extra), in: &self) }
    }
}
