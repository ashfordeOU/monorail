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

/// What each app (and AI agent) has used since the Mac was last unplugged: energy and processor
/// time added up from the once-a-minute readings while on battery. Kept across restarts.
public struct ChargeSession: Codable, Equatable, Sendable {
    public struct Total: Codable, Equatable, Sendable {
        public var name: String
        public var isAgent: Bool
        public var joules: Double
        public var cpuSeconds: Double
        public init(name: String, isAgent: Bool = false, joules: Double = 0, cpuSeconds: Double = 0) {
            self.name = name
            self.isAgent = isAgent
            self.joules = joules
            self.cpuSeconds = cpuSeconds
        }
    }

    /// When the Mac was unplugged, and its charge then.
    public var since: Date?
    public var startPercent: Int?
    public var totals: [String: Total] = [:]

    public init(since: Date? = nil, startPercent: Int? = nil) {
        self.since = since
        self.startPercent = startPercent
    }

    /// A fresh session when the Mac comes off power.
    public mutating func start(at date: Date, percent: Int) {
        self = ChargeSession(since: date, startPercent: percent)
    }

    /// Adds one interval's use for an app or agent (negative amounts, from a restart, count as nothing).
    public mutating func add(id: String, name: String, isAgent: Bool = false, joules: Double, cpuSeconds: Double) {
        var total = totals[id] ?? Total(name: name, isAgent: isAgent)
        total.name = name
        total.joules += max(0, joules)
        total.cpuSeconds += max(0, cpuSeconds)
        totals[id] = total
    }

    /// Biggest users first: by energy when the Mac reports it, otherwise by processor time.
    public var ranked: [(id: String, total: Total)] {
        let useEnergy = totals.values.contains { $0.joules > 0 }
        return totals.map { (id: $0.key, total: $0.value) }
            .filter { useEnergy ? $0.total.joules > 0 : $0.total.cpuSeconds > 0 }
            .sorted { useEnergy ? $0.total.joules > $1.total.joules : $0.total.cpuSeconds > $1.total.cpuSeconds }
    }

    /// Battery percentage points this much energy is, for a battery of `wattHours`.
    public static func percentUsed(joules: Double, wattHours: Double?) -> Double? {
        guard let wattHours, wattHours > 0, joules > 0 else { return nil }
        return joules / 3600 / wattHours * 100
    }

    /// "0.4% used", "<0.1% used", or "12 min of processor time" without energy figures.
    public static func usedText(_ total: Total, wattHours: Double?) -> String {
        if let p = percentUsed(joules: total.joules, wattHours: wattHours) {
            return p < 0.1 ? "<0.1% used" : String(format: "%.1f%% used", p)
        }
        let minutes = Int((total.cpuSeconds / 60).rounded())
        return minutes < 1 ? "<1 min of processor time" : "\(minutes) min of processor time"
    }
}

/// The battery panel's cards: which exist, their names, and keeping a saved order valid as cards
/// are added in later versions.
public enum BatteryCards {
    public static let standard = ["numbers", "lowPower", "sinceCharge", "history", "attention", "resting", "apps", "agents", "options"]

    public static func title(_ id: String) -> String {
        switch id {
        case "numbers": return "Battery, time left and draw"
        case "lowPower": return "Low Power Mode"
        case "sinceCharge": return "Since last charge"
        case "history": return "Battery history"
        case "attention": return "Needs your attention"
        case "resting": return "Paused and hidden apps"
        case "apps": return "Apps"
        case "agents": return "AI agents"
        case "options": return "Options"
        default: return id
        }
    }

    /// Unknown cards dropped, duplicates removed, new cards added at their standard place.
    public static func normalised(_ order: [String]) -> [String] {
        var result: [String] = []
        for id in order where standard.contains(id) && !result.contains(id) { result.append(id) }
        for (index, id) in standard.enumerated() where !result.contains(id) {
            let before = standard[..<index].last { result.contains($0) }
            let at = before.flatMap { result.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            result.insert(id, at: at)
        }
        return result
    }

    /// Moves a card one place up (-1) or down (+1).
    public static func moving(_ id: String, by step: Int, in order: [String]) -> [String] {
        guard let index = order.firstIndex(of: id) else { return order }
        let target = index + step
        guard order.indices.contains(target) else { return order }
        var list = order
        list.swapAt(index, target)
        return list
    }
}
