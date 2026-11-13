import Foundation

/// Today's time: the join link in a meeting, world clocks and timers.
public enum TimeModel {
    /// The video-call link in a meeting's URL, location or notes: Zoom, Google Meet, Teams, Webex,
    /// FaceTime, Whereby or Around. The first one found, in that order of places.
    public static func joinLink(url: String?, location: String?, notes: String?) -> URL? {
        let pattern = #"https?://[^\s<>"']*(zoom\.us/j/|zoom\.us/my/|meet\.google\.com/|teams\.microsoft\.com/l/meetup-join|teams\.live\.com/meet|webex\.com/|facetime\.apple\.com/join|whereby\.com/|around\.co/)[^\s<>"']*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        for text in [url, location, notes].compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range), let r = Range(match.range, in: text) {
                var link = String(text[r])
                while let last = link.last, ".,;)".contains(last) { link.removeLast() }
                return URL(string: link)
            }
        }
        return nil
    }

    /// "in 5 min", "in 1 hr 20 min", "now", "ended".
    public static func until(_ start: Date, end: Date, now: Date) -> String {
        if now >= end { return "ended" }
        if now >= start { return "now" }
        let minutes = Int(ceil(start.timeIntervalSince(now) / 60))
        if minutes < 60 { return "in \(minutes) min" }
        return minutes % 60 == 0 ? "in \(minutes / 60) hr" : "in \(minutes / 60) hr \(minutes % 60) min"
    }

    /// A meeting starting within five minutes (or under way) is worth raising to the top.
    public static func isImminent(_ start: Date, end: Date, now: Date) -> Bool {
        now < end && start.timeIntervalSince(now) <= 300
    }

    /// A world clock's line: "London · 14:05 · −5 hr", with the city from the zone's identifier.
    public static func city(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }

    /// Hours ahead of (+) or behind (−) here: "+5 hr", "−3.5 hr", "same time".
    public static func offset(_ zone: TimeZone, from here: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date) - here.secondsFromGMT(for: date)
        if seconds == 0 { return "same time" }
        let hours = Double(abs(seconds)) / 3600
        let text = hours == hours.rounded() ? String(format: "%.0f", hours) : String(format: "%.1f", hours)
        return "\(seconds > 0 ? "+" : "−")\(text) hr"
    }

    /// Late at night or early in the morning there: worth a gentle hint before messaging someone.
    public static func isNight(in zone: TimeZone, at date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let hour = calendar.component(.hour, from: date)
        return hour < 7 || hour >= 22
    }

    /// A timer's remaining time: "4:05", "1:02:30".
    public static func countdown(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// The days of a month calendar, Monday first: nil for the blanks before the 1st.
    public static func monthGrid(for date: Date, calendar base: Calendar = .current) -> [Int?] {
        var calendar = base
        calendar.firstWeekday = 2
        guard let range = calendar.range(of: .day, in: .month, for: date),
            let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: blanks) + range.map { Optional($0) }
    }
}
