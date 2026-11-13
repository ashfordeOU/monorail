import Foundation

/// The maths behind the System page: CPU load per core from tick counts, memory from page counts,
/// network speed from byte counters. Pure, so it's tested on every platform.
public enum SystemStats {
    /// One core's tick counters (user, system, idle, nice), as the kernel reports them.
    public struct Ticks: Equatable, Sendable {
        public var user: UInt64, system: UInt64, idle: UInt64, nice: UInt64
        public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
            self.user = user; self.system = system; self.idle = idle; self.nice = nice
        }
    }

    /// Each core's load 0–100 between two readings; cores missing from either reading count as idle.
    public static func load(previous: [Ticks], now: [Ticks]) -> [Double] {
        zip(previous, now).map { a, b in
            let busy = Double(b.user &- a.user) + Double(b.system &- a.system) + Double(b.nice &- a.nice)
            let total = busy + Double(b.idle &- a.idle)
            return total > 0 ? min(max(busy / total * 100, 0), 100) : 0
        }
    }

    /// The whole chip's load: the average over its cores.
    public static func average(_ loads: [Double]) -> Double {
        loads.isEmpty ? 0 : loads.reduce(0, +) / Double(loads.count)
    }

    /// Splits cores into performance and efficiency ones. Apple silicon numbers its efficiency cores
    /// first; `performance` comes from the system's own count.
    public static func split(_ loads: [Double], performance: Int) -> (performance: [Double], efficiency: [Double]) {
        let p = max(0, min(performance, loads.count))
        let e = loads.count - p
        return (Array(loads.suffix(p)), Array(loads.prefix(e)))
    }

    /// Memory, in bytes, the way Activity Monitor groups it.
    public struct Memory: Equatable, Sendable {
        public var total: UInt64, app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64
        public var used: UInt64 { app + wired + compressed }
        public var free: UInt64 { total > used + cached ? total - used - cached : 0 }
        /// Share of memory that can't be freed quickly: what pressure follows.
        public var pressure: Double { total == 0 ? 0 : min(Double(wired + compressed + app) / Double(total), 1) }
        public enum Level: String, Sendable { case low, medium, high }
        public var level: Level { pressure < 0.7 ? .low : pressure < 0.9 ? .medium : .high }

        public init(total: UInt64, app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64) {
            self.total = total; self.app = app; self.wired = wired; self.compressed = compressed; self.cached = cached
        }

        /// From page counts (internal pages minus purgeable is app memory, as Activity Monitor shows).
        public static func fromPages(pageSize: UInt64, total: UInt64, internalPages: UInt64, purgeable: UInt64, wired: UInt64,
                                     compressed: UInt64, external: UInt64) -> Memory {
            let app = internalPages > purgeable ? internalPages - purgeable : 0
            return Memory(total: total, app: app * pageSize, wired: wired * pageSize, compressed: compressed * pageSize,
                          cached: (external + purgeable) * pageSize)
        }
    }

    /// Bytes per second between two byte counters taken `seconds` apart (a counter that wrapped or
    /// reset reads as 0, not a huge spike).
    public static func rate(from a: UInt64, to b: UInt64, seconds: Double) -> Double {
        guard seconds > 0, b >= a else { return 0 }
        return Double(b - a) / seconds
    }

    /// "48 MB/s", "312 KB/s", "0 KB/s".
    public static func speed(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1000
        if kb < 1000 { return String(format: "%.0f KB/s", kb) }
        let mb = kb / 1000
        return mb < 100 ? String(format: "%.1f MB/s", mb) : String(format: "%.0f MB/s", mb)
    }

    /// "26.4 GB".
    public static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    /// Megabits per second from a download, for the speed test.
    public static func megabits(bytes: Int, seconds: Double) -> Double {
        seconds > 0 ? Double(bytes) * 8 / seconds / 1_000_000 : 0
    }

    /// "3 days, 4 hr" since the last restart.
    public static func uptime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60), days = minutes / 1440, hours = (minutes % 1440) / 60
        if days > 0 { return "\(days) day\(days == 1 ? "" : "s"), \(hours) hr" }
        return hours > 0 ? "\(hours) hr \(minutes % 60) min" : "\(minutes) min"
    }

    /// A gentle nudge after a long time without a restart.
    public static func suggestsRestart(uptime seconds: TimeInterval) -> Bool { seconds > 14 * 86_400 }
}
