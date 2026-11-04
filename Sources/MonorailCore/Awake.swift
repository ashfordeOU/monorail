import Foundation

// MARK: - Stay Awake: keep the Mac (and optionally its display) from sleeping

/// How a manual Stay Awake session ends.
public enum AwakeSession: Equatable, Codable, Sendable {
    /// Until you end it.
    case indefinitely
    /// Until a moment in time (a duration or a clock time).
    case until(Date)
    /// While an app (bundle ID) is running.
    case whileApp(String)
    /// While something downloads (incoming network faster than ~50 KB/s).
    case whileDownloading

    /// A short description for the menu bar and notices.
    public func describe(now: Date = Date(), appName: (String) -> String = { $0 }) -> String {
        switch self {
        case .indefinitely: return "until you end it"
        case .until(let date):
            let left = max(Int(date.timeIntervalSince(now).rounded(.up)), 0)
            return "for \(AwakeFormat.remaining(left))"
        case .whileApp(let id): return "while \(appName(id)) is open"
        case .whileDownloading: return "while downloading"
        }
    }
}

/// What can start a Stay Awake session by itself.
public struct AwakeTrigger: Equatable, Hashable, Codable, Sendable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// An app (bundle ID in `value`) is running.
        case app
        /// An app (bundle ID in `value`) is in front.
        case frontApp
        /// An external display is connected (any, or one named `value`).
        case display
        /// On this Wi-Fi network (`value`).
        case wifi
        /// On the power adapter.
        case charging
        /// Between `startMinute` and `endMinute` on `weekdays` (1 = Sunday … 7; empty = every day).
        case schedule
        /// The processors are busier than `threshold` percent.
        case cpu
        /// Something is downloading (incoming network faster than `threshold` KB/s).
        case downloading
        /// An external drive is connected (any, or the volume named `value`).
        case drive

        public var title: String {
            switch self {
            case .app: return "While an app is open"
            case .frontApp: return "While an app is in front"
            case .display: return "While an external display is connected"
            case .wifi: return "On a Wi-Fi network"
            case .charging: return "While charging"
            case .schedule: return "On a schedule"
            case .cpu: return "While the Mac is busy"
            case .downloading: return "While downloading"
            case .drive: return "While a drive is connected"
            }
        }
    }

    public var id: String
    public var kind: Kind
    public var value: String
    public var threshold: Double
    public var startMinute: Int
    public var endMinute: Int
    public var weekdays: [Int]
    public var isEnabled: Bool

    public init(id: String = UUID().uuidString, kind: Kind, value: String = "", threshold: Double = 0,
                startMinute: Int = 9 * 60, endMinute: Int = 17 * 60, weekdays: [Int] = [], isEnabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.value = value
        self.threshold = threshold
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
        self.isEnabled = isEnabled
    }
}

/// What the Mac looks like right now, for deciding whether to stay awake.
public struct AwakeContext: Equatable, Sendable {
    public var now: Date
    public var runningApps: Set<String>
    public var frontApp: String?
    public var externalDisplays: [String]
    public var wifi: String?
    public var charging: Bool
    /// 0–100, nil without a battery.
    public var battery: Int?
    /// 0–100 across all cores.
    public var cpu: Double
    /// Incoming network, KB/s.
    public var downloadRate: Double
    public var mountedVolumes: [String]

    public init(now: Date = Date(), runningApps: Set<String> = [], frontApp: String? = nil, externalDisplays: [String] = [],
                wifi: String? = nil, charging: Bool = true, battery: Int? = nil, cpu: Double = 0, downloadRate: Double = 0,
                mountedVolumes: [String] = []) {
        self.now = now
        self.runningApps = runningApps
        self.frontApp = frontApp
        self.externalDisplays = externalDisplays
        self.wifi = wifi
        self.charging = charging
        self.battery = battery
        self.cpu = cpu
        self.downloadRate = downloadRate
        self.mountedVolumes = mountedVolumes
    }
}

public enum AwakeRules {
    /// Incoming network faster than this counts as downloading (KB/s).
    public static let downloadThreshold = 50.0

    /// Whether a trigger wants the Mac awake now.
    public static func isActive(_ trigger: AwakeTrigger, in context: AwakeContext, calendar: Calendar = .current) -> Bool {
        guard trigger.isEnabled else { return false }
        let value = trigger.value.trimmingCharacters(in: .whitespaces)
        switch trigger.kind {
        case .app: return !value.isEmpty && context.runningApps.contains(value)
        case .frontApp: return !value.isEmpty && context.frontApp == value
        case .display:
            return value.isEmpty ? !context.externalDisplays.isEmpty
                : context.externalDisplays.contains { $0.localizedCaseInsensitiveContains(value) }
        case .wifi: return !value.isEmpty && context.wifi == value
        case .charging: return context.charging
        case .schedule:
            let parts = calendar.dateComponents([.weekday, .hour, .minute], from: context.now)
            if !trigger.weekdays.isEmpty, let weekday = parts.weekday, !trigger.weekdays.contains(weekday) { return false }
            let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            if trigger.startMinute <= trigger.endMinute {
                return minute >= trigger.startMinute && minute < trigger.endMinute
            }
            // Overnight, e.g. 22:00–06:00.
            return minute >= trigger.startMinute || minute < trigger.endMinute
        case .cpu: return context.cpu >= (trigger.threshold > 0 ? trigger.threshold : 50)
        case .downloading: return context.downloadRate >= (trigger.threshold > 0 ? trigger.threshold : downloadThreshold)
        case .drive:
            return value.isEmpty ? !context.mountedVolumes.isEmpty
                : context.mountedVolumes.contains { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }
        }
    }

    /// Whether a manual session is still going.
    public static func sessionContinues(_ session: AwakeSession, in context: AwakeContext) -> Bool {
        switch session {
        case .indefinitely: return true
        case .until(let date): return context.now < date
        case .whileApp(let id): return context.runningApps.contains(id)
        case .whileDownloading: return context.downloadRate >= downloadThreshold
        }
    }

    /// The low-battery cut-off: true when the Mac should be allowed to sleep anyway.
    public static func batteryTooLow(_ context: AwakeContext, cutoff: Int) -> Bool {
        guard cutoff > 0, !context.charging, let battery = context.battery else { return false }
        return battery <= cutoff
    }
}

/// How warm the Mac is, as macOS reports it (ProcessInfo.thermalState).
public enum AwakeHeat: Int, Comparable, Sendable {
    case nominal, fair, serious, critical
    public static func < (a: AwakeHeat, b: AwakeHeat) -> Bool { a.rawValue < b.rawValue }
}

/// Whether lid-closed mode should be on, and why not.
public enum ClosedLidDecision: Equatable, Sendable {
    case on
    /// Off because it wasn't asked for, or Stay Awake isn't running.
    case off
    /// Off for safety; the reason is shown to the person.
    case stopped(String)
}

extension AwakeRules {
    /// Lid-closed mode: only during Stay Awake, only on power when that's chosen, and never once
    /// the Mac has got hot during this session (`hotThisSession`): a closed Mac in a bag doesn't
    /// cool down, so it isn't turned back on until the next session.
    public static func closedLid(awake: Bool, enabled: Bool, onlyOnPower: Bool, charging: Bool, heat: AwakeHeat,
                                 hotThisSession: Bool, lowPowerMode: Bool = false, battery: Int? = nil,
                                 batteryFloor: Int = closedLidBatteryFloor) -> ClosedLidDecision {
        guard awake, enabled else { return .off }
        if hotThisSession || heat >= .serious {
            return .stopped("Your Mac is getting hot, so it will sleep when the lid is closed. Stay Awake continues while it's open.")
        }
        if lowPowerMode {
            return .stopped("Low Power Mode is on, so your Mac will sleep when the lid is closed, for the rest of this Stay Awake session.")
        }
        if !charging {
            if onlyOnPower {
                return .stopped("On battery, so your Mac will sleep when the lid is closed, for the rest of this Stay Awake session.")
            }
            if let battery, battery < batteryFloor {
                return .stopped("Battery below \(batteryFloor)%, so your Mac will sleep when the lid is closed, for the rest of this Stay Awake session.")
            }
        }
        return .on
    }

    /// On battery (when allowed), lid-closed mode ends below this charge. Keeper uses the same.
    public static let closedLidBatteryFloor = 20
}

public enum AwakeFormat {
    /// "45 min", "1 h 05", "2 h".
    public static func remaining(_ seconds: Int) -> String {
        let minutes = (seconds + 59) / 60
        if minutes < 60 { return "\(max(minutes, 1)) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : String(format: "%d h %02d", h, m)
    }

    /// "1:05" style countdown for the menu bar.
    public static func clock(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        return s >= 3600 ? String(format: "%d:%02d", s / 3600, (s % 3600) / 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Keeping chat apps showing you as available (Windows)

/// During Stay Awake, chat apps (Teams, Slack) still mark you away after a few minutes without
/// input. Once the PC has been idle this long, the Windows version sends a harmless key press
/// (F15, which no app uses, as Caffeine does); that resets the idle time, so the next one comes
/// after another `idleLimit`. Standard users can do this, no administrator needed.
public enum AwakeNudge {
    /// Idle time before a nudge: under a minute, well inside the shortest away timer (Teams: 5 minutes).
    public static let idleLimit: TimeInterval = 50

    /// Whether to send a nudge now.
    public static func isDue(awake: Bool, keepAvailable: Bool, idle: TimeInterval, limit: TimeInterval = idleLimit) -> Bool {
        awake && keepAvailable && idle >= limit
    }

    /// Idle time from GetTickCount and GetLastInputInfo's tick (milliseconds since start-up, both
    /// wrapping every 49.7 days), right across a wrap.
    public static func idleSeconds(now: UInt32, lastInput: UInt32) -> TimeInterval {
        TimeInterval(now &- lastInput) / 1000
    }
}
