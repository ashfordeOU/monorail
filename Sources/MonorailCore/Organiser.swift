import Foundation

/// Sorting for the Calendar, Reminders and Notes page: pure, so it's tested on Linux too.
public enum Organiser {
    public enum Bucket: String, CaseIterable, Sendable {
        case overdue, today, upcoming, someday
        public var title: String {
            switch self {
            case .overdue: return "Overdue"
            case .today: return "Today"
            case .upcoming: return "Coming Up"
            case .someday: return "No Date"
            }
        }
    }

    /// Where a reminder goes, by its due date. A due date earlier today with no time counts as today.
    public static func bucket(due: Date?, hasTime: Bool, now: Date = Date(), calendar: Calendar = .current) -> Bucket {
        guard let due else { return .someday }
        if calendar.isDate(due, inSameDayAs: now) { return hasTime && due < now ? .overdue : .today }
        return due < now ? .overdue : .upcoming
    }

    /// Days of a month that have something on, for the dots under the dates.
    public static func busyDays(_ starts: [Date], ends: [Date], month: Date, calendar: Calendar = .current) -> Set<Int> {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return [] }
        var days = Set<Int>()
        for (start, end) in zip(starts, ends) {
            for day in range {
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: first),
                      let next = calendar.date(byAdding: .day, value: 1, to: date) else { continue }
                if start < next && end > date { days.insert(day) }
            }
        }
        return days
    }

    /// A short line for a note's preview: the first words after the title, whitespace folded.
    public static func snippet(_ body: String, title: String, limit: Int = 90) -> String {
        var text = body.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if text.hasPrefix(title) { text = String(text.dropFirst(title.count)).trimmingCharacters(in: .whitespaces) }
        return text.count > limit ? String(text.prefix(limit - 1)) + "…" : text
    }

    /// Lines from the Notes script: id, title, ISO date and snippet, separated by tabs.
    public struct NoteLine: Equatable, Sendable {
        public var id: String
        public var title: String
        public var modified: Date?
        public var snippet: String
    }

    public static func parseNotes(_ output: String) -> [NoteLine] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2, !parts[0].isEmpty else { return nil }
            let date = parts.count > 2 ? iso.date(from: parts[2]) : nil
            let title = parts[1].isEmpty ? "New Note" : parts[1]
            return NoteLine(id: parts[0], title: title, modified: date, snippet: parts.count > 3 ? snippet(parts[3], title: title) : "")
        }
    }
}
