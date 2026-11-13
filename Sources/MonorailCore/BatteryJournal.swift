import Foundation

/// A long view of the battery: health once a day, every charge, and what it lost while asleep.
/// Small enough to keep for years (one health sample a day, the last 60 charges and 60 nights).
public struct BatteryJournal: Codable, Equatable, Sendable {
    public struct Health: Codable, Equatable, Sendable {
        public var day: Date
        public var capacity: Int
        public var cycles: Int?
        public init(day: Date, capacity: Int, cycles: Int? = nil) {
            self.day = day
            self.capacity = capacity
            self.cycles = cycles
        }
    }

    public struct Charge: Codable, Equatable, Sendable {
        public var start: Date
        public var end: Date
        public var from: Int
        public var to: Int
        public init(start: Date, end: Date, from: Int, to: Int) {
            self.start = start
            self.end = end
            self.from = from
            self.to = to
        }
        public var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
    }

    public struct Night: Codable, Equatable, Sendable {
        public var slept: Date
        public var woke: Date
        public var from: Int
        public var to: Int
        public init(slept: Date, woke: Date, from: Int, to: Int) {
            self.slept = slept
            self.woke = woke
            self.from = from
            self.to = to
        }
        public var hours: Double { woke.timeIntervalSince(slept) / 3600 }
        public var lost: Int { max(from - to, 0) }
        /// Percent an hour; a healthy Mac asleep loses well under 1% an hour.
        public var perHour: Double { hours > 0 ? Double(lost) / hours : 0 }
        public var isHeavy: Bool { hours >= 1 && perHour >= 1.5 }
    }

    public private(set) var health: [Health] = []
    public private(set) var charges: [Charge] = []
    public private(set) var nights: [Night] = []

    public init(health: [Health] = [], charges: [Charge] = [], nights: [Night] = []) {
        self.health = health
        self.charges = charges
        self.nights = nights
    }

    /// One sample a day: a second sample on the same day replaces the first.
    public mutating func record(capacity: Int, cycles: Int?, on date: Date, calendar: Calendar = .current) {
        guard (1...150).contains(capacity) else { return }
        let day = calendar.startOfDay(for: date)
        health.removeAll { $0.day == day }
        health.append(Health(day: day, capacity: capacity, cycles: cycles))
        health.sort { $0.day < $1.day }
        if health.count > 2000 { health.removeFirst(health.count - 2000) }
    }

    public mutating func record(_ charge: Charge) {
        guard charge.to > charge.from, charge.end > charge.start else { return }
        charges.append(charge)
        if charges.count > 60 { charges.removeFirst(charges.count - 60) }
    }

    /// Only sleeps of at least half an hour count; shorter ones say nothing about drain.
    public mutating func record(_ night: Night) {
        guard night.hours >= 0.5 else { return }
        nights.append(night)
        if nights.count > 60 { nights.removeFirst(nights.count - 60) }
    }

    /// Health lost per 30 days, from a straight line through the samples (needs two weeks of them).
    public var lossPerMonth: Double? {
        guard let first = health.first, let last = health.last,
              last.day.timeIntervalSince(first.day) >= 14 * 86400, health.count >= 3 else { return nil }
        let xs = health.map { $0.day.timeIntervalSince(first.day) / 86400 }
        let ys = health.map { Double($0.capacity) }
        let n = Double(xs.count), mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        let sxx = zip(xs, xs).map { ($0 - mx) * ($1 - mx) }.reduce(0, +)
        guard sxx > 0 else { return nil }
        let slope = zip(xs, ys).map { ($0 - mx) * ($1 - my) }.reduce(0, +) / sxx
        return max(-slope * 30, 0)
    }

    /// Roughly how many months until health reaches 80%, when Apple calls for service.
    public var monthsTo80: Int? {
        guard let loss = lossPerMonth, loss > 0.05, let now = health.last?.capacity else { return nil }
        guard now > 80 else { return 0 }
        return Int((Double(now - 80) / loss).rounded())
    }

    /// The average overnight drain, percent an hour, over the last week of nights.
    public var typicalNightDrain: Double? {
        let recent = nights.suffix(7)
        guard !recent.isEmpty else { return nil }
        return recent.map(\.perHour).reduce(0, +) / Double(recent.count)
    }

    /// A plain-text report to keep or send to support.
    public func report(model: String, percent: Int, capacity: Int?, cycles: Int?, now: Date = Date()) -> String {
        let long = DateFormatter(), short = DateFormatter()
        long.dateStyle = .long; long.timeStyle = .short
        short.dateStyle = .medium; short.timeStyle = .short
        var lines = ["Battery report · \(model)", long.string(from: now), ""]
        lines.append("Charge: \(percent)%")
        if let capacity { lines.append("Health: \(capacity)% of its design capacity") }
        if let cycles { lines.append("Charge cycles: \(cycles)") }
        if let loss = lossPerMonth { lines.append(String(format: "Losing about %.1f%% health a month", loss)) }
        if let months = monthsTo80 { lines.append(months == 0 ? "At or below 80%: Apple suggests service" : "About \(months) months until 80%") }
        if let drain = typicalNightDrain { lines.append(String(format: "Overnight drain: %.1f%% an hour (last week)", drain)) }
        if !charges.isEmpty {
            lines.append("")
            lines.append("Recent charges")
            for c in charges.suffix(5).reversed() {
                lines.append("  \(short.string(from: c.start)): \(c.from)% → \(c.to)% in \(c.minutes) min")
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// Batteries in Bluetooth accessories, and when to say one is running low.
public struct AccessoryBattery: Equatable, Sendable, Identifiable {
    public var name: String
    public var percent: Int
    public var id: String { name }
    public init(name: String, percent: Int) {
        self.name = name
        self.percent = percent
    }

    public var symbol: String {
        let n = name.lowercased()
        if n.contains("mouse") { return "magicmouse.fill" }
        if n.contains("trackpad") { return "rectangle.and.hand.point.up.left.fill" }
        if n.contains("keyboard") { return "keyboard.fill" }
        if n.contains("(case)") { return "airpods.chargingcase" }
        if n.contains("airpods") || n.contains("beats") || n.contains("headphone") || n.contains("buds") { return "airpodspro" }
        if n.contains("pencil") { return "pencil" }
        if n.contains("controller") { return "gamecontroller.fill" }
        return "battery.75percent"
    }

    /// Batteries from macOS's Bluetooth report (`system_profiler SPBluetoothDataType -json`): AirPods
    /// and other headphones give left, right and case; mice and keyboards one level. Monorail only
    /// (the App Store's sandbox can't run it).
    public static func fromBluetoothReport(_ json: Data) -> [AccessoryBattery] {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]] else { return [] }
        var found: [AccessoryBattery] = []
        func level(_ value: Any?) -> Int? {
            guard let text = value as? String else { return nil }
            return Int(text.trimmingCharacters(in: CharacterSet.decimalDigits.inverted))
        }
        for section in sections {
            for device in section["device_connected"] as? [[String: Any]] ?? [] {
                for (name, value) in device {
                    guard let info = value as? [String: Any] else { continue }
                    let parts: [(String, String)] = [("device_batteryLevelLeft", "left"), ("device_batteryLevelRight", "right"),
                                                     ("device_batteryLevelCase", "case")]
                    let split = parts.compactMap { key, label in level(info[key]).map { (label, $0) } }
                    if !split.isEmpty {
                        for (label, percent) in split { found.append(AccessoryBattery(name: "\(name) (\(label))", percent: percent)) }
                    } else if let main = level(info["device_batteryLevelMain"]) ?? level(info["device_batteryLevel"]) {
                        found.append(AccessoryBattery(name: name, percent: main))
                    }
                }
            }
        }
        return found.sorted { $0.name < $1.name }
    }

    /// Accessories that just crossed below `threshold` since the last reading (so each warns once).
    public static func newlyLow(_ now: [AccessoryBattery], before: [AccessoryBattery], threshold: Int = 15) -> [AccessoryBattery] {
        now.filter { item in
            item.percent <= threshold && (before.first { $0.name == item.name }.map { $0.percent > threshold } ?? true)
        }
    }
}
