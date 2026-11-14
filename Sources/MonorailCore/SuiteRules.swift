import Foundation

/// Who looks after what when Keeper and Monorail (or Signalbox) are both on the Mac, so nothing runs
/// twice. Agreed with Keeper and approved by the owner (November 2026). Keeper carries the same list in
/// TypeScript; both must give the same answer for the same hellos.
///
/// Each app announces in its hello which areas it has switched on (`owns`), and which owner the person
/// chose for an area (`prefer`, with the time in `preferAt`). The rule list below then says which app
/// rests. Nobody writes a shared table, so there are no races.
public enum SuiteArea: String, CaseIterable, Sendable {
    // Keeper leads.
    case awake, focus, stage, alarms, meetingNotes, menuBarReadings, displayBrightness, storageCleanup, chargeLimit
    case alertDisk = "alerts.disk", alertNetwork = "alerts.network", alertSystem = "alerts.system"
    case alertAI = "alerts.ai", alertMeeting = "alerts.meeting"
    // Monorail leads.
    case snapWindows, clipboard, eveningColours, breaks
    case alertBattery = "alerts.battery", alertAgent = "alerts.agent"
    // The person chooses.
    case island
    // Both keep theirs.
    case launcher

    public enum Owner: Equatable, Sendable { case keeper, monorail, chosen, both }

    public var owner: Owner {
        switch self {
        case .awake, .focus, .stage, .alarms, .meetingNotes, .menuBarReadings, .displayBrightness, .storageCleanup, .chargeLimit,
             .alertDisk, .alertNetwork, .alertSystem, .alertAI, .alertMeeting:
            return .keeper
        case .snapWindows, .clipboard, .eveningColours, .breaks, .alertBattery, .alertAgent:
            return .monorail
        case .island: return .chosen
        case .launcher: return .both
        }
    }

    /// How it reads in a sentence: "Keeper's <title> is on".
    public var title: String {
        switch self {
        case .awake: return "Stay Awake"
        case .focus: return "focus timer"
        case .stage: return "presentation mode"
        case .alarms: return "timer alarms"
        case .meetingNotes: return "meeting notes"
        case .menuBarReadings: return "menu bar readings"
        case .displayBrightness: return "display brightness"
        case .storageCleanup: return "storage clean-up"
        case .chargeLimit: return "charge limit"
        case .alertDisk: return "low-disk alerts"
        case .alertNetwork: return "network alerts"
        case .alertSystem: return "system alerts"
        case .alertAI: return "AI usage alerts"
        case .alertMeeting: return "meeting alerts"
        case .snapWindows: return "window arranging"
        case .clipboard: return "clipboard history"
        case .eveningColours: return "evening warmth"
        case .breaks: return "break reminders"
        case .alertBattery: return "battery alerts"
        case .alertAgent: return "coding agent alerts"
        case .island: return "island"
        case .launcher: return "launcher"
        }
    }

    /// The areas a hello's `owns` object switches on, read from its JSON (top-level flags, and the
    /// nested `alerts` object as "alerts.<kind>").
    public static func announced(in owns: [String: Any]) -> Set<String> {
        var set: Set<String> = []
        for (key, value) in owns {
            if key == "alerts", let alerts = value as? [String: Any] {
                for (kind, on) in alerts where on as? Bool == true { set.insert("alerts.\(kind)") }
            } else if value as? Bool == true {
                set.insert(key)
            }
        }
        return set
    }

    /// The `owns` object for a hello, from the areas that are on.
    public static func ownsObject(_ on: Set<SuiteArea>) -> [String: Any] {
        var owns: [String: Any] = [:]
        var alerts: [String: Any] = [:]
        for area in SuiteArea.allCases {
            if area.rawValue.hasPrefix("alerts.") {
                alerts[String(area.rawValue.dropFirst("alerts.".count))] = on.contains(area)
            } else {
                owns[area.rawValue] = on.contains(area)
            }
        }
        owns["alerts"] = alerts
        return owns
    }
}

public enum SuiteRules {
    public enum App: String, Sendable { case keeper, monorail }

    public enum Verdict: Equatable, Sendable {
        /// This app does it.
        case lead
        /// The other app does it; this one rests.
        case rest
        /// Both have it on and nobody has chosen yet: ask the person (each shows its own meanwhile).
        case ask
    }

    /// A choice the person made: which app, and when (epoch milliseconds).
    public struct Choice: Equatable, Sendable {
        public var app: App
        public var at: Double
        public init(app: App, at: Double) {
            self.app = app
            self.at = at
        }
    }

    /// The newer of two choices (either may be missing). A tie goes to the person's choice in Keeper,
    /// so both apps agree without a coin toss.
    public static func latest(_ a: Choice?, _ b: Choice?) -> Choice? {
        guard let a else { return b }
        guard let b else { return a }
        if a.at != b.at { return a.at > b.at ? a : b }
        return a.app == .keeper ? a : b
    }

    /// What `me` does about `area`. `mineOn`: the area is switched on here. `otherOwns`: the areas the
    /// other app announced (nil when it isn't running). `choice`: the newest choice from either hello.
    public static func verdict(_ area: SuiteArea, me: App, mineOn: Bool, otherOwns: Set<String>?, choice: Choice? = nil) -> Verdict {
        guard mineOn, let otherOwns, otherOwns.contains(area.rawValue) else { return .lead }
        if let choice { return choice.app == me ? .lead : .rest }
        switch area.owner {
        case .keeper: return me == .keeper ? .lead : .rest
        case .monorail: return me == .monorail ? .lead : .rest
        case .both: return .lead
        case .chosen: return .ask
        }
    }
}

/// Something happening in one app that the island owner shows (`state.live` on the suite channel).
public struct SuiteLive: Equatable, Sendable {
    /// sharing, call, recording, timer, batteryLow, aiLimit, charging, awake, mode, download, music, workspace
    public var kind: String
    public var title: String
    public var detail: String
    /// An SF Symbol name.
    public var symbol: String
    /// 0…1 (a timer's progress, a download's share), when it has one.
    public var level: Double?
    /// When it ends (epoch ms), when it has an end.
    public var until: Double?

    public init(kind: String, title: String, detail: String = "", symbol: String, level: Double? = nil, until: Double? = nil) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.level = level
        self.until = until
    }

    public init?(json: [String: Any]) {
        guard let kind = json["kind"] as? String, let title = json["title"] as? String else { return nil }
        self.init(kind: kind, title: title, detail: json["detail"] as? String ?? "", symbol: json["symbol"] as? String ?? "circle.fill",
                  level: (json["level"] as? Double) ?? (json["level"] as? Int).map(Double.init),
                  until: (json["until"] as? Double) ?? (json["until"] as? Int).map(Double.init))
    }

    public var json: [String: Any] {
        ["kind": kind, "title": title, "detail": detail, "symbol": symbol,
         "level": level.map { $0 as Any } ?? NSNull(), "until": until.map { $0 as Any } ?? NSNull()]
    }
}
