import Foundation

/// Meeting Notes: a transcript with who spoke ("You" from the microphone, "Others" from the Mac's
/// sound), the action items in it, a summary, and a Markdown copy. Everything stays on the Mac.
public struct MeetingTranscript: Codable, Equatable, Sendable {
    public struct Line: Codable, Equatable, Sendable {
        public var speaker: String
        /// Seconds from the start of the recording.
        public var at: TimeInterval
        public var text: String

        public init(speaker: String, at: TimeInterval, text: String) {
            self.speaker = speaker
            self.at = at
            self.text = text
        }
    }

    public var id: String
    public var title: String
    public var started: Date
    public var duration: TimeInterval
    public var lines: [Line]
    public var summary: String?
    public var actionItems: [String]

    public init(id: String = UUID().uuidString, title: String, started: Date, duration: TimeInterval = 0, lines: [Line] = [],
                summary: String? = nil, actionItems: [String] = []) {
        self.id = id
        self.title = title
        self.started = started
        self.duration = duration
        self.lines = lines
        self.summary = summary
        self.actionItems = actionItems
    }

    /// Adds a finished phrase, keeping lines in time order and joining a speaker's quick follow-ons.
    public mutating func add(_ line: Line) {
        let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var clean = line
        clean.text = text
        if let index = lines.lastIndex(where: { $0.at <= clean.at }), lines[index].speaker == clean.speaker, clean.at - lines[index].at < 20,
           index == lines.count - 1 {
            lines[index].text += " " + text
            return
        }
        let position = lines.firstIndex { $0.at > clean.at } ?? lines.count
        lines.insert(clean, at: position)
    }

    public var plainText: String {
        var out = ""
        for line in lines { out += "\(line.speaker): \(line.text)\n" }
        return out
    }

    public var wordCount: Int {
        var n = 0
        for line in lines { n += line.text.split(separator: " ").count }
        return n
    }

    /// The notes as Markdown: title, when, summary, action items and the transcript with times.
    public func markdown(calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateStyle = .full
        f.timeStyle = .short
        var md = "# \(title)\n\n\(f.string(from: started)) · \(MeetingNotes.clock(duration))\n\n"
        if let summary, !summary.isEmpty { md += "## Summary\n\n\(summary)\n\n" }
        if !actionItems.isEmpty {
            md += "## Action items\n\n"
            for item in actionItems { md += "- [ ] \(item)\n" }
            md += "\n"
        }
        md += "## Transcript\n\n"
        for line in lines { md += "**\(line.speaker)** \(MeetingNotes.clock(line.at)): \(line.text)\n\n" }
        return md
    }
}

public enum MeetingNotes {
    /// "4:05" or "1:02:03".
    public static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Sentences that sound like someone agreeing to do something, without a model: "I'll send…",
    /// "can you…", "we need to…", "action item…", "by Friday…".
    public static func actionItems(_ transcript: MeetingTranscript, limit: Int = 12) -> [String] {
        let cues = ["i'll ", "i will ", "we'll ", "we will ", "we need to ", "we should ", "can you ", "could you ", "please ", "let's ",
                    "action item", "follow up", "follow-up", "to do", "todo", "next step", "send ", "by monday", "by tuesday", "by wednesday",
                    "by thursday", "by friday", "by tomorrow", "by end of", "deadline", "remind "]
        var found: [String] = []
        for line in transcript.lines {
            for sentence in sentences(line.text) {
                let lower = " " + sentence.lowercased()
                guard sentence.split(separator: " ").count >= 4 else { continue }
                var hit = false
                for cue in cues where lower.contains(" " + cue) { hit = true; break }
                if hit {
                    let item = (line.speaker == "You" ? "" : "\(line.speaker): ") + sentence
                    if !found.contains(item) { found.append(item) }
                }
                if found.count >= limit { return found }
            }
        }
        return found
    }

    static func sentences(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ".!?".contains(ch) {
                let s = current.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { out.append(s) }
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { out.append(rest) }
        return out
    }

    /// The transcript in pieces small enough for the Mac's on-device model (about 4,000 tokens in all,
    /// so roughly 9,000 characters of text each, leaving room for the instructions and the answer).
    public static func chunks(_ transcript: MeetingTranscript, maxCharacters: Int = 9000) -> [String] {
        var pieces: [String] = []
        var current = ""
        for line in transcript.lines {
            let entry = "\(line.speaker): \(line.text)\n"
            if current.count + entry.count > maxCharacters, !current.isEmpty {
                pieces.append(current)
                current = ""
            }
            if entry.count > maxCharacters {
                var rest = Substring(entry)
                while !rest.isEmpty {
                    pieces.append(String(rest.prefix(maxCharacters)))
                    rest = rest.dropFirst(maxCharacters)
                }
            } else {
                current += entry
            }
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }

    /// A safe file name for the notes ("2026-11-13 Design review.md").
    public static func fileName(_ transcript: MeetingTranscript, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: transcript.started)
        let date = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let title = transcript.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return "\(date) \(title).md"
    }
}
