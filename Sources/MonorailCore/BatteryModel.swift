import Foundation

/// What the battery is doing now: charge, draw, time left, health. Built from the smart battery's
/// own figures (no estimates of our own except where it says so).
public struct BatteryState: Equatable, Sendable, Codable {
    public var percent: Int
    public var isCharging: Bool
    public var onBattery: Bool
    /// Minutes left as macOS reports it (nil while it's still working it out, or plugged in).
    public var minutesLeft: Int?
    /// Watts the whole Mac draws from the battery right now (nil when plugged in or unknown).
    public var watts: Double?
    /// Watt-hours left in the battery.
    public var remainingWattHours: Double?
    /// Health: full charge today as a share of the design capacity.
    public var capacityPercent: Int?
    public var cycleCount: Int?
    public var lowPowerMode: Bool

    public init(percent: Int, isCharging: Bool, onBattery: Bool, minutesLeft: Int? = nil, watts: Double? = nil,
                remainingWattHours: Double? = nil, capacityPercent: Int? = nil, cycleCount: Int? = nil, lowPowerMode: Bool = false) {
        self.percent = percent
        self.isCharging = isCharging
        self.onBattery = onBattery
        self.minutesLeft = minutesLeft
        self.watts = watts
        self.remainingWattHours = remainingWattHours
        self.capacityPercent = capacityPercent
        self.cycleCount = cycleCount
        self.lowPowerMode = lowPowerMode
    }

    /// Minutes left at the current rate: macOS's figure, or the battery's energy over the draw.
    public var minutesAtCurrentRate: Int? {
        guard onBattery else { return nil }
        if let minutesLeft, minutesLeft > 0 { return minutesLeft }
        guard let wh = remainingWattHours, let w = watts, w > 0.3 else { return nil }
        return Int((wh / w * 60).rounded())
    }

    /// Minutes left if an app drawing `appWatts` stopped: the "if you quit" estimate.
    public func minutesIfSaved(appWatts: Double) -> Int? {
        guard onBattery, let wh = remainingWattHours, let w = watts, w > 0.3 else { return nil }
        let after = max(w - max(appWatts, 0), 0.3)
        return Int((wh / after * 60).rounded())
    }

    /// "5 hr 52 min", "38 min".
    public static func duration(_ minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "—" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }
}

/// One point of battery history.
public struct BatteryPoint: Equatable, Sendable, Codable {
    public var time: Date
    public var percent: Int
    public var charging: Bool
    public init(time: Date, percent: Int, charging: Bool) {
        self.time = time
        self.percent = percent
        self.charging = charging
    }
}

public enum BatteryHistory {
    /// Adds a point, keeping the last `hours` and skipping a point that says nothing new within
    /// `minimumGap` seconds (so the file stays small).
    public static func adding(_ point: BatteryPoint, to points: [BatteryPoint], hours: Double = 24, minimumGap: TimeInterval = 240) -> [BatteryPoint] {
        var list = points.filter { point.time.timeIntervalSince($0.time) <= hours * 3600 && $0.time <= point.time }
        if let last = list.last, point.time.timeIntervalSince(last.time) < minimumGap,
            last.percent == point.percent, last.charging == point.charging {
            return list
        }
        list.append(point)
        return list
    }

    /// Breaks the line where the Mac was asleep or off (more than `gap` seconds with no point).
    public static func segments(_ points: [BatteryPoint], gap: TimeInterval = 1200) -> [[BatteryPoint]] {
        var result: [[BatteryPoint]] = []
        for point in points {
            if let last = result.last?.last, point.time.timeIntervalSince(last.time) <= gap {
                result[result.count - 1].append(point)
            } else {
                result.append([point])
            }
        }
        return result
    }
}

/// AI agents that run as processes on the Mac (often inside a terminal or an editor), by process name.
public enum AgentProcesses {
    /// Process name (lowercased) → the agent's name.
    public static let known: [String: String] = [
        "claude": "Claude Code", "codex": "Codex", "gemini": "Gemini CLI", "aider": "Aider",
        "cursor-agent": "Cursor Agent", "goose": "Goose", "opencode": "OpenCode", "amp": "Amp",
        "ollama": "Ollama", "openclaw": "OpenClaw", "hermes": "Hermes Agent", "copilot": "GitHub Copilot CLI",
        "qwen": "Qwen Code", "crush": "Crush", "llama-server": "llama.cpp", "lms": "LM Studio",
    ]

    /// The agent a process belongs to, from its name or (for scripts run by node or python) its arguments.
    public static func agent(processName: String, arguments: [String] = []) -> String? {
        let name = processName.lowercased()
        if let agent = known[name] { return agent }
        guard ["node", "python", "python3", "bun", "deno"].contains(name) else { return nil }
        for argument in arguments.prefix(4) {
            let base = (argument as NSString).lastPathComponent.lowercased()
            if let agent = known[base] { return agent }
            for (key, agent) in known where argument.lowercased().contains("/\(key)/") || argument.lowercased().contains("@anthropic-ai/claude-code") && key == "claude" {
                return agent
            }
        }
        return nil
    }
}
