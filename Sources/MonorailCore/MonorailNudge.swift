import Foundation

/// When Signalbox suggests Monorail, and what it says. Only at a moment Monorail would help (lots
/// of windows, or lots of switching between apps), never in the first two days, at most once a
/// week, and never again after it's been dismissed three times.
public enum MonorailNudge {
    public struct Signals: Equatable, Sendable {
        public var windowsOnScreen: Int
        public var appSwitchesLastHour: Int
        public var daysSinceInstall: Int
        public var daysSinceShown: Int?
        public var dismissals: Int
        public var monorailInstalled: Bool

        public init(windowsOnScreen: Int = 0, appSwitchesLastHour: Int = 0, daysSinceInstall: Int = 0,
                    daysSinceShown: Int? = nil, dismissals: Int = 0, monorailInstalled: Bool = false) {
            self.windowsOnScreen = windowsOnScreen
            self.appSwitchesLastHour = appSwitchesLastHour
            self.daysSinceInstall = daysSinceInstall
            self.daysSinceShown = daysSinceShown
            self.dismissals = dismissals
            self.monorailInstalled = monorailInstalled
        }
    }

    public enum Reason: Equatable, Sendable {
        case manyWindows(Int)
        case manySwitches(Int)

        public var headline: String {
            switch self {
            case .manyWindows(let n): return "\(n) windows open"
            case .manySwitches(let n): return "\(n) app switches this hour"
            }
        }

        public var pitch: String {
            switch self {
            case .manyWindows: return "Monorail lines them up on one strip, so nothing hides behind anything else."
            case .manySwitches: return "Monorail keeps the apps you're using side by side, a swipe apart."
            }
        }
    }

    public static let windowThreshold = 8
    public static let switchThreshold = 40

    public static func reason(_ s: Signals) -> Reason? {
        guard !s.monorailInstalled, s.dismissals < 3, s.daysSinceInstall >= 2 else { return nil }
        if let shown = s.daysSinceShown, shown < 7 { return nil }
        if s.windowsOnScreen >= windowThreshold { return .manyWindows(s.windowsOnScreen) }
        if s.appSwitchesLastHour >= switchThreshold { return .manySwitches(s.appSwitchesLastHour) }
        return nil
    }
}

/// Release notes for both apps: Signalbox's update window shows what's new in Signalbox, and a section
/// for what's new in Monorail. A bullet ending in `<!-- monorail -->` is Monorail's alone, and one
/// ending in `<!-- station -->` is Signalbox's alone; the rest belong to both. (The markers are
/// invisible on the site.)
public enum EditionNotes {
    public enum Edition: Sendable { case monorail, station }

    static func belongs(_ line: String, to edition: Edition) -> Bool {
        let onlyMonorail = line.contains("<!-- monorail -->"), onlyStation = line.contains("<!-- station -->")
        switch edition {
        case .monorail: return !onlyStation
        case .station: return !onlyMonorail
        }
    }

    /// The section's lines for one edition (headings kept, other edition's bullets dropped).
    public static func lines(_ section: [String], for edition: Edition) -> [String] {
        section.filter { $0.hasPrefix("#") || belongs($0, to: edition) }.map(strip)
    }

    /// Only the bullets marked as Monorail's: what Signalbox people are missing.
    public static func monorailOnly(_ section: [String]) -> [String] {
        section.filter { $0.hasPrefix("#") || $0.contains("<!-- monorail -->") }.map(strip)
    }

    static func strip(_ line: String) -> String {
        line.replacingOccurrences(of: "<!-- monorail -->", with: "").replacingOccurrences(of: "<!-- station -->", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
