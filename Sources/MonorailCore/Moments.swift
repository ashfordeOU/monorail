import Foundation

/// Heat, calls and films: what the Mac is going through right now, and what Monorail suggests.
public enum Heat: Int, Sendable, Comparable, CaseIterable {
    /// macOS's own thermal states, in the same order as `ProcessInfo.ThermalState`.
    case normal = 0, warm, hot, throttling

    public init(thermalState raw: Int) { self = Heat(rawValue: min(max(raw, 0), 3)) ?? .normal }

    public static func < (a: Heat, b: Heat) -> Bool { a.rawValue < b.rawValue }

    public var title: String {
        switch self {
        case .normal: return "Cool"
        case .warm: return "Warm"
        case .hot: return "Hot"
        case .throttling: return "Slowing down to cool"
        }
    }

    /// Hot enough to raise its card to the top of the panel.
    public var needsYou: Bool { self >= .hot }

    /// One line of advice, naming the busiest app when there is one.
    public func advice(busiest: String?, cpuPercent: Double?) -> String {
        let culprit = busiest.map { name in cpuPercent.map { String(format: "%@ is using %.0f%% of the processor", name, $0) } ?? "\(name) is the busiest" }
        switch self {
        case .normal: return "Nothing to do."
        case .warm: return culprit.map { "\($0). Fine for now." } ?? "A little warm. Fine for now."
        case .hot: return (culprit.map { "\($0). " } ?? "") + "Pausing it lets the Mac cool down."
        case .throttling: return (culprit.map { "\($0). " } ?? "") + "macOS is slowing everything to cool off; pausing it helps most."
        }
    }
}

/// A call is on when an app is using the microphone or the camera.
public struct CallState: Equatable, Sendable {
    public var micInUse: Bool
    public var cameraInUse: Bool
    public var micMuted: Bool

    public init(micInUse: Bool = false, cameraInUse: Bool = false, micMuted: Bool = false) {
        self.micInUse = micInUse
        self.cameraInUse = cameraInUse
        self.micMuted = micMuted
    }

    public var isOnCall: Bool { micInUse || cameraInUse }

    public var title: String {
        guard isOnCall else { return "No call" }
        return cameraInUse ? "On a video call" : "On a call"
    }
}

public enum Moments {
    /// "Enough for about a 40-minute call", or a nudge to plug in when the call would outlast the battery.
    /// Video calls draw more, so the estimate is cut by a fifth when the camera is on.
    public static func callBattery(minutesLeft: Int?, video: Bool, typicalCall: Int = 45) -> String? {
        guard let minutesLeft, minutesLeft > 0 else { return nil }
        let usable = video ? minutesLeft * 4 / 5 : minutesLeft
        if usable < typicalCall { return "About \(usable) min of battery for this call. Plug in to be safe." }
        return "Enough battery for about \(BatteryState.duration(usable)) of calling."
    }

    /// "About 1 hr 50 min of film left at this rate."
    public static func movieBattery(minutesLeft: Int?) -> String? {
        guard let minutesLeft, minutesLeft > 0 else { return nil }
        return "About \(BatteryState.duration(minutesLeft)) of watching left at this rate."
    }

    /// The charge-limit nudge: once per charge, when charging reaches the limit you chose.
    public static func shouldNudgeToUnplug(percent: Int, isCharging: Bool, limit: Int, alreadyNudged: Bool) -> Bool {
        isCharging && !alreadyNudged && limit < 100 && percent >= limit
    }

    /// Sleep-timer choices, in minutes; 0 means "when the film ends".
    public static let sleepTimerChoices = [0, 30, 45, 60, 90]

    public static func sleepTimerTitle(_ minutes: Int) -> String {
        minutes == 0 ? "When the film ends" : BatteryState.duration(minutes)
    }
}
