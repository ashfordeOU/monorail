import Foundation

/// The Dashboard's history: a few readings a minute, kept on this Mac. Detail for the last day (one
/// sample a minute), then one every 15 minutes for 30 days, so a month fits in a small file.
public struct SystemHistory: Codable, Equatable, Sendable {
    public struct Sample: Codable, Equatable, Sendable {
        public var at: Date
        public var cpu: Double          // percent of the whole chip
        public var memory: Double       // percent of memory in use
        public var swapGB: Double
        public var downBytes: Double    // bytes a second
        public var upBytes: Double
        public var readBytes: Double    // disk, bytes a second
        public var writeBytes: Double
        public var gpu: Double?         // percent, when the graphics driver says
        public var battery: Int?        // percent

        public init(at: Date, cpu: Double, memory: Double, swapGB: Double = 0, downBytes: Double = 0, upBytes: Double = 0,
                    readBytes: Double = 0, writeBytes: Double = 0, gpu: Double? = nil, battery: Int? = nil) {
            self.at = at; self.cpu = cpu; self.memory = memory; self.swapGB = swapGB
            self.downBytes = downBytes; self.upBytes = upBytes; self.readBytes = readBytes; self.writeBytes = writeBytes
            self.gpu = gpu; self.battery = battery
        }
    }

    public enum Range: String, CaseIterable, Sendable {
        case hours12 = "12h", hours24 = "24h", days7 = "7d", days30 = "30d"
        public var seconds: TimeInterval {
            switch self {
            case .hours12: return 12 * 3600
            case .hours24: return 24 * 3600
            case .days7: return 7 * 86400
            case .days30: return 30 * 86400
            }
        }
    }

    public private(set) var recent: [Sample] = []   // one a minute, last 24 hours
    public private(set) var older: [Sample] = []    // one per 15 minutes, up to 30 days

    public init() {}

    public mutating func add(_ sample: Sample) {
        recent.append(sample)
        let dayAgo = sample.at.addingTimeInterval(-86400)
        // Fold samples older than a day into 15-minute averages, a whole quarter-hour at a time.
        let cutoff = Int(dayAgo.timeIntervalSince1970 / 900)
        let expiring = recent.filter { Int($0.at.timeIntervalSince1970 / 900) < cutoff }
        if !expiring.isEmpty {
            recent.removeAll { Int($0.at.timeIntervalSince1970 / 900) < cutoff }
            var buckets: [Int: [Sample]] = [:]
            for s in expiring { buckets[Int(s.at.timeIntervalSince1970 / 900), default: []].append(s) }
            for key in buckets.keys.sorted() { if let avg = Self.average(buckets[key]!) { older.append(avg) } }
        }
        let monthAgo = sample.at.addingTimeInterval(-30 * 86400)
        older.removeAll { $0.at < monthAgo }
    }

    /// Samples within the range, oldest first.
    public func samples(_ range: Range, now: Date = Date()) -> [Sample] {
        let start = now.addingTimeInterval(-range.seconds)
        return (older + recent).filter { $0.at >= start }
    }

    /// Lowest, average and highest of one reading over a range.
    public static func summary(_ values: [Double]) -> (low: Double, average: Double, high: Double)? {
        guard let low = values.min(), let high = values.max() else { return nil }
        return (low, values.reduce(0, +) / Double(values.count), high)
    }

    static func average(_ group: [Sample]) -> Sample? {
        guard let last = group.last else { return nil }
        let n = Double(group.count)
        func avg(_ key: (Sample) -> Double) -> Double { group.reduce(0) { $0 + key($1) } / n }
        let gpus = group.compactMap(\.gpu)
        return Sample(at: last.at, cpu: avg { $0.cpu }, memory: avg { $0.memory }, swapGB: avg { $0.swapGB },
                      downBytes: avg { $0.downBytes }, upBytes: avg { $0.upBytes }, readBytes: avg { $0.readBytes },
                      writeBytes: avg { $0.writeBytes }, gpu: gpus.isEmpty ? nil : gpus.reduce(0, +) / Double(gpus.count),
                      battery: last.battery)
    }

    /// Totals per day for a rate reading (bytes a second): each sample counts for the time it stands for
    /// (a minute recently, 15 minutes further back). Oldest day first, `days` long, ending today.
    public func dailyTotals(_ value: (Sample) -> Double, days: Int, now: Date = Date(), calendar: Calendar = .current) -> [(day: Date, total: Double)] {
        let today = calendar.startOfDay(for: now)
        var totals: [Date: Double] = [:]
        for s in older { totals[calendar.startOfDay(for: s.at), default: 0] += value(s) * 900 }
        for s in recent { totals[calendar.startOfDay(for: s.at), default: 0] += value(s) * 60 }
        return (0..<days).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            return (day, totals[day] ?? 0)
        }
    }

    /// The average of a reading by weekday (0 = Sunday) and hour, over everything kept: when the Mac is busiest.
    /// Cells with no samples are nil.
    public func weekHours(_ value: (Sample) -> Double, calendar: Calendar = .current) -> [[Double?]] {
        var sums = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        var counts = Array(repeating: Array(repeating: 0, count: 24), count: 7)
        for s in older + recent {
            let c = calendar.dateComponents([.weekday, .hour], from: s.at)
            guard let w = c.weekday, let h = c.hour else { continue }
            sums[w - 1][h] += value(s); counts[w - 1][h] += 1
        }
        return (0..<7).map { w in (0..<24).map { h in counts[w][h] > 0 ? sums[w][h] / Double(counts[w][h]) : nil } }
    }

    /// When a restart would help: up for two weeks, or a week with a lot of swap.
    public static func restartAdvice(uptime: TimeInterval, swapGB: Double) -> String? {
        let days = Int(uptime / 86400)
        if days >= 7, swapGB >= 4 { return "Up \(days) days with \(String(format: "%.1f", swapGB)) GB in swap. A restart clears leaked memory and stuck background tasks." }
        if days >= 14 { return "Up \(days) days. A restart finishes updates and frees memory." }
        return nil
    }
}
