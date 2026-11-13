import Foundation

/// Disk space: how full, what's safe to clear, and when to warn.
public enum Storage {
    public enum Level: String, Sendable { case fine, low, critical }

    /// Under 10% or 20 GB free is low; under 5% or 5 GB is critical.
    public static func level(free: Int64, total: Int64) -> Level {
        guard total > 0 else { return .fine }
        let gb = Double(free) / 1_000_000_000, share = Double(free) / Double(total)
        if gb < 5 || share < 0.05 { return .critical }
        if gb < 20 || share < 0.10 { return .low }
        return .fine
    }

    /// Sizes as Finder shows them (decimal: 1 GB = 1,000,000,000 bytes).
    public static func size(_ bytes: Int64) -> String {
        let b = Double(max(bytes, 0))
        if b >= 1e12 { return String(format: "%.1f TB", b / 1e12) }
        if b >= 1e9 { return String(format: b >= 1e11 ? "%.0f GB" : "%.1f GB", b / 1e9) }
        if b >= 1e6 { return String(format: "%.0f MB", b / 1e6) }
        if b >= 1e3 { return String(format: "%.0f KB", b / 1e3) }
        return "\(Int64(b)) bytes"
    }

    /// Things only you or your tools made, that are rebuilt or redownloaded when needed.
    public struct Cleanup: Equatable, Sendable, Identifiable {
        public var id: String
        public var title: String
        public var detail: String
        /// Paths under the home folder.
        public var paths: [String]
        /// Only items older than this many days (nil: everything inside).
        public var olderThanDays: Int?
        public var symbol: String

        public init(id: String, title: String, detail: String, paths: [String], olderThanDays: Int? = nil, symbol: String) {
            self.id = id
            self.title = title
            self.detail = detail
            self.paths = paths
            self.olderThanDays = olderThanDays
            self.symbol = symbol
        }
    }

    public static let cleanups: [Cleanup] = [
        Cleanup(id: "derivedData", title: "Xcode build files", detail: "DerivedData · rebuilt when needed",
                paths: ["Library/Developer/Xcode/DerivedData"], symbol: "hammer.fill"),
        Cleanup(id: "deviceSupport", title: "Old device support", detail: "Xcode's copies for iOS versions you've connected",
                paths: ["Library/Developer/Xcode/iOS DeviceSupport", "Library/Developer/Xcode/watchOS DeviceSupport"], olderThanDays: 90, symbol: "iphone"),
        Cleanup(id: "simulatorCaches", title: "Simulator caches", detail: "Rebuilt the next time a simulator runs",
                paths: ["Library/Developer/CoreSimulator/Caches"], symbol: "ipad.and.iphone"),
        Cleanup(id: "packageCaches", title: "Package caches", detail: "npm, Yarn, pip and Homebrew downloads",
                paths: [".npm/_cacache", "Library/Caches/Yarn", "Library/Caches/pip", "Library/Caches/Homebrew"], symbol: "shippingbox.fill"),
        Cleanup(id: "appCaches", title: "App caches", detail: "Older than a month; apps make new ones as they need",
                paths: ["Library/Caches"], olderThanDays: 30, symbol: "square.stack.3d.up.fill"),
        Cleanup(id: "downloads", title: "Old downloads", detail: "In Downloads, untouched for 90 days",
                paths: ["Downloads"], olderThanDays: 90, symbol: "arrow.down.circle.fill"),
    ]

    public struct Item: Equatable, Sendable {
        public var path: String
        public var bytes: Int64
        public init(path: String, bytes: Int64) {
            self.path = path
            self.bytes = bytes
        }
    }

    /// The biggest items, at least `minimum` bytes each, largest first.
    public static func largest(_ items: [Item], count: Int = 8, minimum: Int64 = 100_000_000) -> [Item] {
        Array(items.filter { $0.bytes >= minimum }.sorted { $0.bytes > $1.bytes }.prefix(count))
    }

    /// Whether a file counts as old for a clean-up, from its last use or change.
    public static func isOld(lastUsed: Date?, modified: Date?, days: Int?, now: Date = Date()) -> Bool {
        guard let days else { return true }
        let latest = [lastUsed, modified].compactMap { $0 }.max() ?? .distantPast
        return now.timeIntervalSince(latest) >= Double(days) * 86400
    }
}
