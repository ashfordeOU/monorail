import Foundation

/// Clipboard history, kept small and newest first. Pinned clips stay at the top and are never dropped.
public struct ClipHistory: Codable, Equatable, Sendable {
    public struct Clip: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var text: String
        public var app: String?
        public var copied: Date
        public var pinned: Bool

        public init(id: UUID = UUID(), text: String, app: String? = nil, copied: Date = Date(), pinned: Bool = false) {
            self.id = id
            self.text = text
            self.app = app
            self.copied = copied
            self.pinned = pinned
        }

        /// One line for a list: whitespace folded, cut to `limit` characters.
        public func preview(_ limit: Int = 80) -> String {
            let folded = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            return folded.count > limit ? String(folded.prefix(limit - 1)) + "…" : folded
        }
    }

    public private(set) var clips: [Clip] = []
    public var keep: Int

    public init(keep: Int = 50, clips: [Clip] = []) {
        self.keep = keep
        self.clips = clips
    }

    /// Adds a copy. The same text again moves to the top instead of repeating; blank text is ignored.
    public mutating func add(_ text: String, app: String? = nil, at date: Date = Date()) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 100_000 else { return }
        var pinned = false
        if let index = clips.firstIndex(where: { $0.text == text }) {
            pinned = clips[index].pinned
            clips.remove(at: index)
        }
        clips.insert(Clip(text: text, app: app, copied: date, pinned: pinned), at: 0)
        trim()
    }

    public mutating func togglePin(_ id: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].pinned.toggle()
    }

    public mutating func remove(_ id: UUID) { clips.removeAll { $0.id == id } }

    /// Clears everything but the pinned clips.
    public mutating func clear() { clips.removeAll { !$0.pinned } }

    /// Pinned first, then newest; filtered by a search when there is one.
    public func shown(matching query: String = "") -> [Clip] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let found = q.isEmpty ? clips : clips.filter { $0.text.localizedCaseInsensitiveContains(q) }
        return found.filter(\.pinned) + found.filter { !$0.pinned }
    }

    private mutating func trim() {
        var unpinned = 0
        clips = clips.filter { clip in
            if clip.pinned { return true }
            unpinned += 1
            return unpinned <= max(keep, 1)
        }
    }
}

/// Text cleaning for "Paste as plain text" and friends.
public enum PlainText {
    /// Removes trailing spaces on each line, turns non-breaking and zero-width characters into
    /// plain ones and smart quotes into straight ones when `straightQuotes` is set.
    public static func clean(_ text: String, straightQuotes: Bool = false) -> String {
        var out = text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
        if straightQuotes {
            for (a, b) in [("“", "\""), ("”", "\""), ("‘", "'"), ("’", "'")] { out = out.replacingOccurrences(of: a, with: b) }
        }
        return out.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in String(line.reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed()) }
            .joined(separator: "\n")
    }

    /// Words and characters, as a word processor counts them.
    public static func counts(_ text: String) -> (words: Int, characters: Int) {
        (text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count, text.count)
    }
}

/// A colour picked from the screen, written the ways designers and code want it.
public struct PickedColour: Codable, Equatable, Sendable {
    public var red: Double, green: Double, blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    private func byte(_ v: Double) -> Int { Int((v * 255).rounded()) }

    public var hex: String { String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue)) }
    public var rgb: String { "rgb(\(byte(red)), \(byte(green)), \(byte(blue)))" }

    public var hsl: String {
        let maxV = max(red, green, blue), minV = min(red, green, blue), l = (maxV + minV) / 2
        var h = 0.0, s = 0.0
        if maxV != minV {
            let d = maxV - minV
            s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
            switch maxV {
            case red: h = (green - blue) / d + (green < blue ? 6 : 0)
            case green: h = (blue - red) / d + 2
            default: h = (red - green) / d + 4
            }
            h *= 60
        }
        return "hsl(\(Int(h.rounded())), \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
    }

    public var swiftUI: String {
        func f(_ v: Double) -> String { String(format: "%.3f", v) }
        return "Color(red: \(f(red)), green: \(f(green)), blue: \(f(blue)))"
    }

    /// Black or white, whichever reads better on this colour.
    public var prefersDarkText: Bool { 0.2126 * red + 0.7152 * green + 0.0722 * blue > 0.6 }
}
