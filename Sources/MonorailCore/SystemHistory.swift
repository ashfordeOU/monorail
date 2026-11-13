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

    /// When a restart would help: up for two weeks, or a week with a lot of swap.
    public static func restartAdvice(uptime: TimeInterval, swapGB: Double) -> String? {
        let days = Int(uptime / 86400)
        if days >= 7, swapGB >= 4 { return "Up \(days) days with \(String(format: "%.1f", swapGB)) GB in swap. A restart clears leaked memory and stuck background tasks." }
        if days >= 14 { return "Up \(days) days. A restart finishes updates and frees memory." }
        return nil
    }
}
