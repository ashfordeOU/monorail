import Foundation

// MARK: - Working without Accessibility
//
// On a Mac where Accessibility can't be allowed (an IT-managed Mac and a standard account),
// Monorail still does everything that doesn't move other apps' windows, and arranges apps that
// can be scripted through Apple Events, which a standard user may allow app by app.

extension Action {
    /// Actions that work without Accessibility: Stay Awake, Evening Mode, the display controls,
    /// Settings and updates. Everything else moves or reads other apps' windows.
    public static let worksWithoutAccessibility: Set<Action> = [
        .toggleAwake, .keepAvailable, .awake30, .awake60, .awake120, .awakeWhileDownloading, .toggleAwakeDisplay,
        .toggleEvening, .displayBrighter, .displayDimmer,
        .displayMoreSpace, .displayLargerText, .displayDefaultResolution,
        .openSettings, .checkForUpdates, .commandPalette, .cheatSheet, .locatePointer, .pomodoro, .restart,
    ]

    public var worksWithoutAccessibility: Bool { Self.worksWithoutAccessibility.contains(self) }
}

/// The menu's status line while Accessibility isn't allowed.
public enum PermissionStatus {
    public static let headline = "Window arranging needs Accessibility — ask IT or an admin"
    public static let useWithout =
        "Without it, Stay Awake, Evening Mode, the display controls and arranging scriptable apps still work."
}

// MARK: - Scriptable apps

/// An app whose windows have an AppleScript `bounds` property, so they can be moved with Apple
/// Events. macOS asks once per app ("Monorail wants to control Safari"), and a standard user may
/// answer: no administrator needed.
public struct ScriptableApp: Equatable, Hashable, Sendable {
    public let bundleID: String
    public let name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

public enum ScriptableApps {
    /// Apps known to move their windows when told `set bounds of front window to {…}`.
    public static let all: [ScriptableApp] = [
        ScriptableApp(bundleID: "com.apple.Safari", name: "Safari"),
        ScriptableApp(bundleID: "com.google.Chrome", name: "Google Chrome"),
        ScriptableApp(bundleID: "com.apple.finder", name: "Finder"),
        ScriptableApp(bundleID: "com.apple.Terminal", name: "Terminal"),
        ScriptableApp(bundleID: "com.apple.Notes", name: "Notes"),
        ScriptableApp(bundleID: "com.apple.mail", name: "Mail"),
        ScriptableApp(bundleID: "com.apple.TextEdit", name: "TextEdit"),
        ScriptableApp(bundleID: "com.apple.iWork.Pages", name: "Pages"),
        ScriptableApp(bundleID: "com.apple.iWork.Numbers", name: "Numbers"),
        ScriptableApp(bundleID: "com.apple.iWork.Keynote", name: "Keynote"),
        ScriptableApp(bundleID: "com.apple.Preview", name: "Preview"),
        ScriptableApp(bundleID: "com.googlecode.iterm2", name: "iTerm2"),
    ]

    /// Bundle identifiers compare without regard to case (macOS treats them that way).
    public static func app(for bundleID: String) -> ScriptableApp? {
        all.first { $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame }
    }

    public static func isScriptable(_ bundleID: String) -> Bool { app(for: bundleID) != nil }

    /// The two most recently used scriptable apps, from bundle IDs most recent first
    /// (duplicates and other apps skipped). Fewer than two when fewer are known.
    public static func frontTwo(_ recentBundleIDs: [String]) -> [ScriptableApp] {
        var result: [ScriptableApp] = []
        for id in recentBundleIDs {
            guard let app = app(for: id), !result.contains(app) else { continue }
            result.append(app)
            if result.count == 2 { break }
        }
        return result
    }
}

/// Where a scriptable app's front window goes.
public enum ScriptPlacement: String, CaseIterable, Sendable {
    case leftHalf = "left-half"
    case rightHalf = "right-half"
    case fill
    case centre

    public var title: String {
        switch self {
        case .leftHalf: return "Left half"
        case .rightHalf: return "Right half"
        case .fill: return "Fill the screen"
        case .centre: return "Centre"
        }
    }
}

/// The frame maths for arranging with Apple Events.
///
/// AppleScript `bounds` are `{left, top, right, bottom}` in points, measured from the top-left
/// corner of the main display (the one with the menu bar), with y growing downwards. That is the
/// same space as Accessibility frames; AppKit's `NSScreen` frames instead start at the bottom-left
/// of the main display with y growing upwards, so they are flipped first.
public enum ScriptBounds {
    /// An AppKit (bottom-left origin) rectangle in AppleScript's top-left space. `primaryHeight`
    /// is the height of the main display (`NSScreen.screens[0].frame.height`).
    public static func topLeft(fromCocoa rect: Rect, primaryHeight: Double) -> Rect {
        Rect(x: rect.x, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// `{left, top, right, bottom}`, rounded to whole points.
    public static func bounds(of rect: Rect) -> [Int] {
        let left = Int(rect.x.rounded()), top = Int(rect.y.rounded())
        return [left, top, Int(rect.maxX.rounded()), Int(rect.maxY.rounded())]
    }

    /// The rectangle of an AppleScript bounds list; nil unless it has four numbers.
    public static func rect(fromBounds bounds: [Int]) -> Rect? {
        guard bounds.count == 4 else { return nil }
        return Rect(x: Double(bounds[0]), y: Double(bounds[1]),
                    width: Double(bounds[2] - bounds[0]), height: Double(bounds[3] - bounds[1]))
    }

    /// Where a window goes inside a screen's visible frame (top-left space), with `gap` points
    /// around it and between halves. `current` is the window's frame now, for centring.
    public static func frame(_ placement: ScriptPlacement, in visible: Rect, current: Rect? = nil, gap: Double = 0) -> Rect {
        let inner = Rect(x: visible.x + gap, y: visible.y + gap,
                         width: max(visible.width - 2 * gap, 1), height: max(visible.height - 2 * gap, 1))
        let half = max((inner.width - gap) / 2, 1)
        switch placement {
        case .leftHalf:
            return Rect(x: inner.x, y: inner.y, width: half, height: inner.height)
        case .rightHalf:
            return Rect(x: inner.maxX - half, y: inner.y, width: half, height: inner.height)
        case .fill:
            return inner
        case .centre:
            // Keeps the window's size (no larger than the screen); a window of unknown size gets two thirds.
            let width = min(current?.width ?? inner.width * 2 / 3, inner.width)
            let height = min(current?.height ?? inner.height * 2 / 3, inner.height)
            return Rect(x: inner.x + (inner.width - width) / 2, y: inner.y + (inner.height - height) / 2,
                        width: width, height: height)
        }
    }

    /// The screen (visible frames, top-left space) a window is on: the one holding its centre,
    /// else the one it overlaps most, else the first.
    public static func screen(for window: Rect?, among screens: [Rect]) -> Rect? {
        guard let window else { return screens.first }
        let centre = (x: window.x + window.width / 2, y: window.y + window.height / 2)
        if let holding = screens.first(where: {
            centre.x >= $0.x && centre.x < $0.maxX && centre.y >= $0.y && centre.y < $0.maxY
        }) {
            return holding
        }
        func overlap(_ s: Rect) -> Double {
            max(0, min(s.maxX, window.maxX) - max(s.x, window.x)) * max(0, min(s.maxY, window.maxY) - max(s.y, window.y))
        }
        return screens.max { overlap($0) < overlap($1) } ?? screens.first
    }
}

/// The AppleScript Monorail sends. Only allowlisted bundle identifiers are ever put into a script.
public enum ScriptSource {
    public static func setBounds(_ app: ScriptableApp, _ rect: Rect) -> String {
        let b = ScriptBounds.bounds(of: rect)
        return "tell application id \"\(app.bundleID)\" to set bounds of front window to {\(b[0]), \(b[1]), \(b[2]), \(b[3])}"
    }

    public static func getBounds(_ app: ScriptableApp) -> String {
        "tell application id \"\(app.bundleID)\" to get bounds of front window"
    }

    /// Brings the app's next window to the front (the front one goes to the back), or its previous one.
    public static func cycleWindows(_ app: ScriptableApp, forward: Bool) -> String {
        let change = forward
            ? "set index of front window to (count of windows)"
            : "set index of last window to 1"
        return "tell application id \"\(app.bundleID)\"\nif (count of windows) > 1 then \(change)\nend tell"
    }
}

// MARK: - Staying "Available" in chat apps

/// When Stay Awake tells macOS someone is at the Mac, so chat apps such as Teams and Slack keep
/// showing you as available. They read the system's idle time; declaring user activity resets it
/// and needs no permission. Moving the pointer (posting an event) needs Accessibility.
public enum AwakePresence {
    /// Declare activity only once the Mac has been idle this long (seconds)…
    public static let idleThreshold: Double = 50
    /// …and at most this often (seconds).
    public static let declareInterval: Double = 55

    /// Whether to declare user activity now.
    public static func shouldDeclareActivity(awake: Bool, keepAvailable: Bool, moveCursor: Bool,
                                             idleSeconds: Double, sinceLastDeclare: Double) -> Bool {
        awake && (keepAvailable || moveCursor) && idleSeconds > idleThreshold && sinceLastDeclare >= declareInterval
    }

    /// Whether to nudge the pointer now: only with Accessibility, as before.
    public static func shouldNudgeCursor(awake: Bool, moveCursor: Bool, canPostEvents: Bool, everyMinutes: Int,
                                         idleSeconds: Double, sinceLastNudge: Double) -> Bool {
        awake && moveCursor && canPostEvents && idleSeconds > idleThreshold
            && sinceLastNudge >= Double(max(everyMinutes, 1)) * 60
    }

    /// The outcome of the "does declaring activity reset the idle time?" check (`--self-check-available`).
    public static func idleCheckVerdict(before: Double, after: Double) -> String {
        let numbers = String(format: "idle %.1f s before, %.1f s after declaring activity", before, after)
        if before < 1 { return "inconclusive: the Mac wasn't idle (\(numbers)); no input session?" }
        return after < before ? "passed: \(numbers)" : "did not drop: \(numbers)"
    }
}

/// Plain words for what went wrong when an app was asked to move a window.
public enum ScriptErrors {
    /// errAEEventNotPermitted: the person said no to "Monorail wants to control…", or hasn't been asked yet.
    public static let notPermitted = -1743
    /// errAEEventWouldRequireUserConsent: macOS would need to ask, but can't right now.
    public static let needsConsent = -1744
    /// procNotFound / connectionInvalid: the app isn't running.
    public static let notRunning = [-600, -609]
    /// errAENoSuchObject: no such window (the app has none open).
    public static let noWindow = -1728

    public static func message(_ code: Int, appName: String) -> String {
        if code == notPermitted || code == needsConsent {
            return "Monorail isn’t allowed to control \(appName) · allow it in System Settings → Privacy & Security → Automation"
        }
        if code == noWindow { return "\(appName) has no window to arrange" }
        if notRunning.contains(code) { return "\(appName) isn’t open" }
        return "\(appName) didn’t move its window (error \(code))"
    }

    /// Privacy & Security → Automation, where the answers to "Monorail wants to control…" live.
    public static let automationSettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
}
