import Foundation

/// What used the battery, day by day: energy (or processor time, on Macs that don't report energy)
/// for each app and agent, kept for 30 days on this Mac.
public struct EnergyLog: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
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

    /// "2026-11-13" → app id → entry.
    public private(set) var days: [String: [String: Entry]] = [:]
    public static let keepDays = 30

    public init() {}

    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public mutating func add(id: String, name: String, isAgent: Bool = false, joules: Double, cpuSeconds: Double,
                             at date: Date = Date(), calendar: Calendar = .current) {
        let day = Self.key(date, calendar: calendar)
        var entry = days[day]?[id] ?? Entry(name: name, isAgent: isAgent)
        entry.name = name
        entry.joules += max(0, joules)
        entry.cpuSeconds += max(0, cpuSeconds)
        days[day, default: [:]][id] = entry
        if days.count > Self.keepDays {
            for old in days.keys.sorted().prefix(days.count - Self.keepDays) { days[old] = nil }
        }
    }

    /// The last `count` days' keys, oldest first (days with nothing recorded included, empty).
    public static func lastDays(_ count: Int, now: Date = Date(), calendar: Calendar = .current) -> [String] {
        (0..<count).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: now).map { key($0, calendar: calendar) }
        }
    }

    /// Totals over some days, biggest first: by energy when recorded, otherwise processor time.
    public func top(over keys: [String], limit: Int = 10) -> [(id: String, entry: Entry)] {
        var sum: [String: Entry] = [:]
        for key in keys {
            for (id, e) in days[key] ?? [:] {
                var t = sum[id] ?? Entry(name: e.name, isAgent: e.isAgent)
                t.joules += e.joules
                t.cpuSeconds += e.cpuSeconds
                sum[id] = t
            }
        }
        let useEnergy = sum.values.contains { $0.joules > 0 }
        func amount(_ e: Entry) -> Double { useEnergy ? e.joules : e.cpuSeconds }
        var rows: [(id: String, entry: Entry)] = []
        for (id, entry) in sum where amount(entry) > 0 { rows.append((id: id, entry: entry)) }
        rows.sort { amount($0.entry) > amount($1.entry) }
        return Array(rows.prefix(limit))
    }

    /// Each day's total, for a bar chart (joules, or processor seconds without energy figures).
    public func dailyTotals(_ keys: [String]) -> [Double] {
        let useEnergy = hasEnergy
        var totals: [Double] = []
        for key in keys {
            var sum = 0.0
            for entry in (days[key] ?? [:]).values { sum += useEnergy ? entry.joules : entry.cpuSeconds }
            totals.append(sum)
        }
        return totals
    }

    public var hasEnergy: Bool {
        for day in days.values { for entry in day.values where entry.joules > 0 { return true } }
        return false
    }
}
