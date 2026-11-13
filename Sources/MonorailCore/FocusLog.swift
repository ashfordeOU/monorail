import Foundation

/// Focus sessions: what you did, your streak and a short daily review. Kept on this Mac.
public struct FocusLog: Codable, Equatable, Sendable {
    public struct Session: Codable, Equatable, Sendable {
        public var start: Date
        public var minutes: Int
        public var finished: Bool
        public init(start: Date, minutes: Int, finished: Bool) {
            self.start = start
            self.minutes = minutes
            self.finished = finished
        }
    }

    public private(set) var sessions: [Session] = []

    public init(sessions: [Session] = []) { self.sessions = sessions }

    /// Sessions shorter than a minute aren't kept; a year of them at most.
    public mutating func record(_ session: Session) {
        guard session.minutes >= 1 else { return }
        sessions.append(session)
        if sessions.count > 3000 { sessions.removeFirst(sessions.count - 3000) }
    }

    public func minutes(on day: Date, calendar: Calendar = .current) -> Int {
        sessions.filter { calendar.isDate($0.start, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
    }

    /// Days in a row, ending today (or yesterday, so the streak isn't lost before you start today),
    /// with at least one finished session.
    public func streak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(sessions.filter(\.finished).map { calendar.startOfDay(for: $0.start) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Minutes for each of the last seven days, oldest first.
    public func week(now: Date = Date(), calendar: Calendar = .current) -> [Int] {
        (0..<7).reversed().map { back in
            minutes(on: calendar.date(byAdding: .day, value: -back, to: now) ?? now, calendar: calendar)
        }
    }

    /// The hour of day you focus best, from finished sessions (needs five).
    public func bestHour(calendar: Calendar = .current) -> Int? {
        let finished = sessions.filter(\.finished)
        guard finished.count >= 5 else { return nil }
        var byHour: [Int: Int] = [:]
        for s in finished { byHour[calendar.component(.hour, from: s.start), default: 0] += s.minutes }
        return byHour.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }?.key
    }

    /// One line for the end of the day.
    public func review(now: Date = Date(), calendar: Calendar = .current) -> String {
        let today = sessions.filter { calendar.isDate($0.start, inSameDayAs: now) }
        guard !today.isEmpty else { return "No focus sessions today yet." }
        let total = today.reduce(0) { $0 + $1.minutes }
        let done = today.filter(\.finished).count
        let hours = total >= 60 ? "\(total / 60) h \(total % 60) min" : "\(total) min"
        var line = "\(hours) of focus in \(today.count) session\(today.count == 1 ? "" : "s")"
        if done < today.count { line += " (\(done) finished)" }
        let streak = streak(now: now, calendar: calendar)
        if streak > 1 { line += " · \(streak)-day streak" }
        return line + "."
    }
}

/// The 20-20-20 rule: after 20 minutes of looking at the screen, look 20 feet away for 20 seconds.
public enum EyeBreaks {
    /// Whether a break is due, given how long you've been at the screen since the last one.
    /// Being idle for `restSeconds` counts as a break by itself.
    public static func isDue(activeSeconds: TimeInterval, idleSeconds: TimeInterval,
                             every interval: TimeInterval = 20 * 60, restSeconds: TimeInterval = 60) -> Bool {
        idleSeconds < restSeconds && activeSeconds >= interval
    }
}
