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
