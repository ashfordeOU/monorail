import Foundation

/// How much of the battery each app is using, estimated from the processor time and
/// energy macOS bills to it (and the helper processes it starts).
public struct PowerUse: Equatable, Sendable, Identifiable {
    public let bundleID: String
    public let appName: String
    /// Share of one processor core, averaged over the last sample (100 = one full core).
    public let cpuPercent: Double
    /// Battery percentage points an hour at this rate, when the Mac reports energy (Apple silicon).
    public let percentPerHour: Double?
    public var id: String { bundleID }

    public init(bundleID: String, appName: String, cpuPercent: Double, percentPerHour: Double?) {
        self.bundleID = bundleID
        self.appName = appName
        self.cpuPercent = cpuPercent
        self.percentPerHour = percentPerHour
    }

    /// Drawing noticeably more than an idle app: about 3% of the battery an hour or more,
    /// or (without energy figures) a quarter of a core or more.
    public var isHungry: Bool {
        if let percentPerHour { return percentPerHour >= PowerEstimate.hungryPercentPerHour }
        return cpuPercent >= PowerEstimate.hungryCPUPercent
    }

    /// "About 6% an hour", or "Busy: 40% of a core" without energy figures.
    public var summary: String {
        if let percentPerHour {
            let rounded = percentPerHour >= 10 ? Int(percentPerHour.rounded()) : max(1, Int(percentPerHour.rounded()))
            return "About \(rounded)% of the battery an hour"
        }
        return "Busy: \(Int(cpuPercent.rounded()))% of a core"
    }
}

/// Totals for one app since it started: processor seconds and joules (nil if not reported).
public struct PowerReading: Equatable, Sendable {
    public var cpuSeconds: Double
    public var joules: Double?
    public init(cpuSeconds: Double, joules: Double?) {
        self.cpuSeconds = cpuSeconds
        self.joules = joules
    }
}

public enum PowerEstimate {
    public static let hungryPercentPerHour = 3.0
    public static let hungryCPUPercent = 25.0

    /// Use between two readings `seconds` apart. A reading that went down (the app restarted,
    /// or a helper quit) counts as nothing used rather than a negative amount.
    public static func use(bundleID: String, appName: String, before: PowerReading, after: PowerReading,
                           seconds: Double, batteryWattHours: Double?) -> PowerUse {
        guard seconds > 0 else { return PowerUse(bundleID: bundleID, appName: appName, cpuPercent: 0, percentPerHour: nil) }
        let cpu = max(0, after.cpuSeconds - before.cpuSeconds) / seconds * 100
        var perHour: Double?
        if let a = after.joules, let b = before.joules, a > 0, let capacity = batteryWattHours, capacity > 0 {
            let watts = max(0, a - b) / seconds
            perHour = watts / capacity * 100
        }
        return PowerUse(bundleID: bundleID, appName: appName, cpuPercent: cpu, percentPerHour: perHour)
    }

    /// The hungriest apps first, only those over the threshold.
    public static func hungry(_ uses: [PowerUse]) -> [PowerUse] {
        uses.filter(\.isHungry).sorted { score($0) > score($1) }
    }

    /// Everything, biggest first, for the list in the popover.
    public static func ranked(_ uses: [PowerUse]) -> [PowerUse] {
        uses.sorted { score($0) > score($1) }
    }

    private static func score(_ use: PowerUse) -> Double { use.percentPerHour.map { $0 * 10 } ?? use.cpuPercent }

    /// Hungry apps that haven't been in front for `idleMinutes` and aren't in front now: the ones
    /// "park on battery" hides. Apps never seen in front count from `watchingSince`.
    public static func toPark(_ uses: [PowerUse], lastActive: [String: Date], watchingSince: Date,
                              frontmost: String?, now: Date, idleMinutes: Double = 60, never: Set<String> = []) -> [String] {
        hungry(uses).compactMap { use in
            guard use.bundleID != frontmost, !never.contains(use.bundleID) else { return nil }
            let last = lastActive[use.bundleID] ?? watchingSince
            return now.timeIntervalSince(last) >= idleMinutes * 60 ? use.bundleID : nil
        }
    }

    /// Battery size in watt-hours from the smart battery's figures: capacity in mAh and voltage in mV.
    public static func wattHours(capacityMilliampHours: Double?, voltageMillivolts: Double?) -> Double? {
        guard let capacity = capacityMilliampHours, let voltage = voltageMillivolts,
            capacity > 100, voltage > 1000 else { return nil }
        return capacity * voltage / 1_000_000
    }
}
