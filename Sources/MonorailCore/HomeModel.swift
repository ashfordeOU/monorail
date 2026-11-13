import Foundation

/// The cards on the home page of the menu bar panel.
public enum HomeCard: String, CaseIterable, Sendable, Equatable {
    case notices, heat, call, movie, battery, windows, today, pinned, system, storage, network, agents, controls, tools, layouts
}

/// What the home page knows when it opens: enough to decide what matters most.
public struct HomeSignals: Equatable, Sendable {
    public var onBattery: Bool
    public var percent: Int?
    public var minutesLeft: Int?
    /// Draw now over your usual draw (2 means twice your usual).
    public var drainRatio: Double?
    public var agentsRunning: Int
    public var clashes: Int
    public var updateAvailable: Bool
    public var paused: Bool
    public var heat: Heat
    public var onCall: Bool
    public var movie: Bool
    /// A meeting starts within a few minutes.
    public var meetingSoon: Bool
    /// The startup disk is nearly full.
    public var diskLow: Bool

    public init(onBattery: Bool = false, percent: Int? = nil, minutesLeft: Int? = nil, drainRatio: Double? = nil,
                agentsRunning: Int = 0, clashes: Int = 0, updateAvailable: Bool = false, paused: Bool = false,
                heat: Heat = .normal, onCall: Bool = false, movie: Bool = false, meetingSoon: Bool = false, diskLow: Bool = false) {
        self.diskLow = diskLow
        self.meetingSoon = meetingSoon
        self.heat = heat
        self.onCall = onCall
        self.movie = movie
        self.onBattery = onBattery
        self.percent = percent
        self.minutesLeft = minutesLeft
        self.drainRatio = drainRatio
        self.agentsRunning = agentsRunning
        self.clashes = clashes
        self.updateAvailable = updateAvailable
        self.paused = paused
    }
}

/// The home page, planned: cards in order, the ones raised to the top, and the line above them.
public struct HomeLayout: Equatable, Sendable {
    public enum Tone: String, Sendable { case calm, attention, urgent }

    public var cards: [HomeCard]
    /// Cards that need you: shown first and larger, with their action on them.
    public var raised: [HomeCard]
    public var tone: Tone
    public var title: String
}

/// Decides the home page. Calm, it keeps one fixed order so things are where you left them;
/// when something needs you, that card moves to the top. Like a Smart Stack, without the guessing.
public enum HomePlanner {
    public static let calmOrder: [HomeCard] = [.windows, .today, .pinned, .battery, .system, .storage, .network, .agents, .controls, .tools, .layouts]

    public static func batteryIsLow(_ s: HomeSignals) -> Bool {
        guard s.onBattery else { return false }
        return (s.percent.map { $0 <= 10 } ?? false) || (s.minutesLeft.map { $0 > 0 && $0 < 30 } ?? false)
    }

    /// Not low yet, but worth a look: a quarter left, or under 45 minutes.
    public static func batteryGettingLow(_ s: HomeSignals) -> Bool {
        guard s.onBattery, !batteryIsLow(s) else { return false }
        return (s.percent.map { $0 <= 25 } ?? false) || (s.minutesLeft.map { $0 > 0 && $0 < 45 } ?? false)
    }

    public static func drainingFast(_ s: HomeSignals) -> Bool {
        s.onBattery && (s.drainRatio ?? 0) >= 1.6
    }

    /// The cards you can arrange on Home (the rest come and go by themselves).
    public static let arrangeable: [HomeCard] = calmOrder

    /// Your order for the calm cards: the saved one, with any card it doesn't mention added at the end.
    public static func order(saved: [String]) -> [HomeCard] {
        var list: [HomeCard] = []
        for name in saved { if let card = HomeCard(rawValue: name), arrangeable.contains(card), !list.contains(card) { list.append(card) } }
        for card in arrangeable where !list.contains(card) { list.append(card) }
        return list
    }

    public static func plan(_ s: HomeSignals, order: [HomeCard] = calmOrder, hidden: Set<HomeCard> = []) -> HomeLayout {
        var raised: [HomeCard] = []
        var reasons: [String] = []
        // A call or a film comes first: it's what you're doing right now. Calm, not a warning.
        if s.onCall { raised.append(.call) } else if s.meetingSoon { raised.append(.today) } else if s.movie { raised.append(.movie) }
        if s.heat.needsYou {
            raised.append(.heat)
            reasons.append(s.heat == .throttling ? "Slowing down to cool" : "Running hot")
        }
        if batteryIsLow(s) {
            raised.append(.battery)
            reasons.append("Battery low")
        } else if batteryGettingLow(s) {
            raised.append(.battery)
            reasons.append(s.percent.map { "Battery at \($0)%" } ?? "Battery getting low")
        } else if drainingFast(s) {
            raised.append(.battery)
            reasons.append("Draining fast")
        }
        if s.diskLow {
            raised.append(.storage)
            reasons.append("Disk almost full")
        }
        if s.updateAvailable { reasons.append("Update ready") }
        if s.clashes > 0 { reasons.append(s.clashes == 1 ? "A shortcut clash" : "\(s.clashes) shortcut clashes") }
        if s.paused { reasons.append("Tiling paused") }
        if s.updateAvailable || s.clashes > 0 || s.paused { raised.append(.notices) }

        // Raised cards always show; your hidden cards stay hidden while calm.
        var cards = raised + order.filter { !raised.contains($0) && !hidden.contains($0) }
        if s.agentsRunning == 0 { cards.removeAll { $0 == .agents } }
        for card in [HomeCard.notices, .heat, .call, .movie] where !raised.contains(card) { cards.removeAll { $0 == card } }

        let tone: HomeLayout.Tone = batteryIsLow(s) ? .urgent : reasons.isEmpty ? .calm : .attention
        let title: String
        switch reasons.count {
        case 0 where s.onCall: title = "On a call"
        case 0 where s.meetingSoon: title = "Meeting soon"
        case 0 where s.movie: title = "Movie mode"
        case 0: title = "All calm"
        case 1: title = reasons[0]
        default: title = "\(count(reasons.count)) things need you"
        }
        return HomeLayout(cards: cards, raised: raised, tone: tone, title: title)
    }

    static func count(_ n: Int) -> String {
        ["Two", "Three", "Four", "Five"].indices.contains(n - 2) ? ["Two", "Three", "Four", "Five"][n - 2] : "\(n)"
    }
}

/// The three battery rings, each 0…1: charge, time left against your usual, and drain against your usual.
public struct BatteryRings: Equatable, Sendable {
    public enum Tone: String, Sendable { case good, ok, high }

    public var charge: Double
    public var time: Double
    public var drain: Double
    /// Draw now over your usual, when both are known.
    public var drainRatio: Double?

    public var drainTone: Tone {
        guard let r = drainRatio else { return .good }
        return r >= 1.6 ? .high : r > 1.05 ? .ok : .good
    }

    public init(charge: Double, time: Double, drain: Double, drainRatio: Double?) {
        self.charge = charge
        self.time = time
        self.drain = drain
        self.drainRatio = drainRatio
    }

    /// - Parameter usualWatts: your usual draw on battery (see `DrainBaseline`).
    public static func make(_ b: BatteryState, usualWatts: Double?) -> BatteryRings {
        let charge = clamp(Double(b.percent) / 100)
        let ratio: Double? = {
            guard b.onBattery, let w = b.watts, let u = usualWatts, u > 0.3 else { return nil }
            return w / u
        }()
        // Time left at this rate, as a share of a full battery at your usual rate: the same as the
        // charge ring when you draw your usual, a quarter of it at four times your usual.
        let time: Double = {
            guard b.onBattery, let ratio, ratio > 0 else { return charge }
            return clamp(charge / ratio)
        }()
        let drain: Double = {
            guard b.onBattery, let w = b.watts else { return 0 }
            if let u = usualWatts, u > 0.3 { return clamp(w / (u * 2)) }
            return clamp(w / 20)
        }()
        return BatteryRings(charge: charge, time: time, drain: drain, drainRatio: ratio)
    }

    static func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
}

/// Your usual draw, learnt from the battery history: how fast the percentage falls while on battery.
public enum DrainBaseline {
    /// Percentage points an hour, from stretches on battery; nil until there's half an hour of them.
    public static func percentPerHour(_ points: [BatteryPoint], maximumGap: TimeInterval = 1200) -> Double? {
        var drop = 0.0, seconds = 0.0
        for (a, b) in zip(points, points.dropFirst()) where !a.charging && !b.charging {
            let gap = b.time.timeIntervalSince(a.time)
            guard gap > 0, gap <= maximumGap, b.percent <= a.percent else { continue }
            drop += Double(a.percent - b.percent)
            seconds += gap
        }
        guard seconds >= 1800, drop > 0 else { return nil }
        return drop / (seconds / 3600)
    }

    /// Watts, given the battery's size.
    public static func watts(percentPerHour: Double?, wattHours: Double?) -> Double? {
        guard let p = percentPerHour, let wh = wattHours, wh > 0 else { return nil }
        return p / 100 * wh
    }
}
