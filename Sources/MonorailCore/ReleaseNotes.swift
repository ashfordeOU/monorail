import Foundation

/// A release's notes, read from the changelog, made into the few rows an Apple-style
/// "What's New" shows: a title, one short line, and what kind of change it is (for its icon).
public enum ReleaseNotes {
    public enum Kind: String, Sendable, CaseIterable {
        case panel, battery, menuBar, agents, keyboard, windows, privacy, welcome, general
    }

    public struct Highlight: Equatable, Sendable {
        public var title: String
        public var text: String
        public var kind: Kind
    }

    /// The lines of one version's section: between "## [version]" and the next "## [".
    public static func section(_ version: String, in changelog: String) -> [String] {
        var lines: [String] = []
        var inside = false
        for line in changelog.components(separatedBy: .newlines) {
            if line.hasPrefix("## [") {
                if inside { break }
                inside = line.hasPrefix("## [\(version)]")
                continue
            }
            if inside, !line.trimmingCharacters(in: .whitespaces).isEmpty { lines.append(line) }
        }
        return lines
    }

    /// The bullets that start with a bold title ("- **One panel.** Clicking…"), as rows: what was
    /// added or changed first, and fixes only when there's nothing else.
    public static func highlights(_ lines: [String], limit: Int = 4) -> [Highlight] {
        var big: [String] = [], other: [String] = []
        var inBig = true
        for line in lines {
            if line.hasPrefix("### ") { inBig = line.hasPrefix("### Added") || line.hasPrefix("### Changed"); continue }
            if line.hasPrefix("- **") { if inBig { big.append(line) } else { other.append(line) } }
        }
        var result: [Highlight] = []
        for line in big.isEmpty ? other : big {
            let body = line.dropFirst(4)
            guard let close = body.range(of: "**") else { continue }
            var title = String(body[..<close.lowerBound]).trimmingCharacters(in: .whitespaces)
            while let last = title.last, ".:".contains(last) { title.removeLast() }
            let rest = plain(String(body[close.upperBound...]))
            guard !title.isEmpty else { continue }
            result.append(Highlight(title: title, text: firstSentence(rest), kind: kind(of: title + " " + rest)))
            if result.count == limit { break }
        }
        return result
    }

    /// Worth a window after updating: something was added or changed, with at least one titled bullet.
    /// Fixes alone stay quiet.
    public static func isNotable(_ lines: [String]) -> Bool {
        var inBig = false
        for line in lines {
            if line.hasPrefix("### ") { inBig = line.hasPrefix("### Added") || line.hasPrefix("### Changed"); continue }
            if inBig, line.hasPrefix("- **") { return true }
        }
        return false
    }

    static func kind(of text: String) -> Kind {
        let t = text.lowercased()
        let table: [(Kind, [String])] = [
            (.battery, ["battery", "drain", "power", "charge", "watt"]),
            (.panel, ["panel", "home page", "card", "control centre"]),
            (.menuBar, ["menu bar", "icon"]),
            (.agents, ["agent", "assistant", "mcp", "claude", "say it"]),
            (.welcome, ["welcome", "first run", "onboarding", "tour"]),
            (.privacy, ["private", "privacy", "screen shar"]),
            (.keyboard, ["shortcut", "keyboard", "key "]),
            (.windows, ["window", "slide", "strip", "layout", "workspace"]),
        ]
        return table.first { _, words in words.contains { t.contains($0) } }?.0 ?? .general
    }

    /// Without Markdown: no **bold**, `code` or [link](url) marks.
    static func plain(_ text: String) -> String {
        var s = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        if let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\([^)]+\)"#) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// The first sentence, up to about 110 characters.
    static func firstSentence(_ text: String) -> String {
        var sentence = text
        if let end = text.range(of: ". ") { sentence = String(text[..<end.lowerBound]) + "." }
        if sentence.count > 110 {
            let cut = sentence.prefix(107)
            sentence = (cut.range(of: " ", options: .backwards).map { String(cut[..<$0.lowerBound]) } ?? String(cut)) + "…"
        }
        return sentence
    }
}
