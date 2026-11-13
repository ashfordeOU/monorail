import Foundation

/// What a clip is, so the history can be sorted and filtered by it.
public enum ClipKind: String, Codable, CaseIterable, Sendable {
    case text, link, email, phone, colour, code, number, image, file

    public var title: String {
        switch self {
        case .text: return "Text"
        case .link: return "Links"
        case .email: return "Emails"
        case .phone: return "Phone numbers"
        case .colour: return "Colours"
        case .code: return "Code"
        case .number: return "Numbers"
        case .image: return "Images"
        case .file: return "Files"
        }
    }

    public var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .colour: return "paintpalette"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .number: return "number"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    /// The kind of copied text.
    public static func detect(_ raw: String) -> ClipKind {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .text }
        let oneLine = !text.contains("\n")
        if oneLine, !text.contains(" ") {
            let lower = text.lowercased()
            if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") || lower.hasPrefix("ftp://") { return .link }
            if text.range(of: #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil { return .email }
            if text.range(of: #"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#, options: .regularExpression) != nil { return .colour }
        }
        if oneLine, text.range(of: #"^(rgba?|hsla?)\([^)]*\)$"#, options: [.regularExpression, .caseInsensitive]) != nil { return .colour }
        if oneLine, text.range(of: #"^-?[0-9][0-9,]*(\.[0-9]+)?%?$"#, options: .regularExpression) != nil { return .number }
        if oneLine, text.range(of: #"^\+?[0-9 ()\-.]{7,20}$"#, options: .regularExpression) != nil, text.filter(\.isNumber).count >= 7 { return .phone }
        if looksLikeCode(text) { return .code }
        return .text
    }

    static func looksLikeCode(_ text: String) -> Bool {
        if text.hasPrefix("$ ") || text.hasPrefix("#!/") { return true }
        let markers = ["{\n", "};", "=>", "->", "func ", "def ", "const ", "let ", "var ", "import ", "return ", "</", "/>", "#include", "SELECT ", "fn ", "class ", "() {", "):\n"]
        var hits = 0
        for marker in markers where text.contains(marker) { hits += 1 }
        let lines = text.split(separator: "\n")
        var indented = 0
        for line in lines where line.hasPrefix("    ") || line.hasPrefix("\t") { indented += 1 }
        let symbols = text.filter { "{}[]();=<>".contains($0) }.count
        let dense = Double(symbols) / Double(max(text.count, 1)) > 0.06
        return hits >= 2 || (hits >= 1 && (indented >= 1 || dense)) || (lines.count >= 3 && indented * 2 >= lines.count && dense)
    }
}

/// Copies that look like secrets: kept out of sight until you choose to see them.
public enum SensitiveClip {
    static let patterns: [(String, String)] = [
        (#"-----BEGIN [A-Z ]*PRIVATE KEY-----"#, "Private key"),
        (#"\bsk-ant-[A-Za-z0-9_\-]{20,}"#, "Anthropic key"),
        (#"\bsk-(proj-)?[A-Za-z0-9_\-]{20,}"#, "API key"),
        (#"\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}"#, "GitHub token"),
        (#"\bgithub_pat_[A-Za-z0-9_]{30,}"#, "GitHub token"),
        (#"\bxox[abposr]-[A-Za-z0-9\-]{10,}"#, "Slack token"),
        (#"\bAKIA[0-9A-Z]{16}\b"#, "AWS key"),
        (#"\bAIza[0-9A-Za-z_\-]{35}\b"#, "Google key"),
        (#"\b(sk|rk)_live_[0-9A-Za-z]{20,}"#, "Stripe key"),
        (#"\beyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}"#, "Token"),
        (#"(?i)\b(password|passwd|pwd|secret|api[_-]?key|token)\s*[:=]\s*\S{6,}"#, "Password"),
    ]

    /// What kind of secret this looks like, or nil.
    public static func detect(_ text: String) -> String? {
        guard text.count <= 20_000 else { return nil }
        for (pattern, label) in patterns where text.range(of: pattern, options: .regularExpression) != nil { return label }
        if hasCardNumber(text) { return "Card number" }
        return nil
    }

    /// A 13–19 digit run (spaces or dashes allowed) that passes the Luhn check.
    static func hasCardNumber(_ text: String) -> Bool {
        var start = text.startIndex
        while let range = text.range(of: #"\b[0-9][0-9 \-]{11,22}[0-9]\b"#, options: .regularExpression, range: start..<text.endIndex) {
            let digits = text[range].compactMap { $0.wholeNumberValue }
            if (13...19).contains(digits.count), luhn(digits) { return true }
            start = range.upperBound
        }
        return false
    }

    static func luhn(_ digits: [Int]) -> Bool {
        var sum = 0
        for (i, d) in digits.reversed().enumerated() {
            if i % 2 == 1 { let x = d * 2; sum += x > 9 ? x - 9 : x } else { sum += d }
        }
        return sum % 10 == 0
    }
}

/// Clipboard history, kept small and newest first. Pinned clips stay at the top and are never dropped.
public struct ClipHistory: Codable, Equatable, Sendable {
    public struct Clip: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var text: String
        public var app: String?
        public var copied: Date
        public var pinned: Bool
        public var kind: ClipKind
        /// An image clip's file name in the clip-images folder, and its size in pixels.
        public var image: String?
        public var imageWidth: Int?
        public var imageHeight: Int?
        /// Words read from an image, so it can be searched.
        public var imageText: String?
        /// Copied files' paths.
        public var files: [String]?
        /// Why it's hidden ("API key", "Card number"), when it looks like a secret.
        public var sensitive: String?
        public var tags: [String]
        public var boards: [String]
        public var remindAt: Date?

        public init(id: UUID = UUID(), text: String, app: String? = nil, copied: Date = Date(), pinned: Bool = false, kind: ClipKind? = nil,
                    image: String? = nil, imageWidth: Int? = nil, imageHeight: Int? = nil, files: [String]? = nil, sensitive: String? = nil) {
            self.id = id
            self.text = text
            self.app = app
            self.copied = copied
            self.pinned = pinned
            self.kind = kind ?? (image != nil ? .image : files != nil ? .file : ClipKind.detect(text))
            self.image = image
            self.imageWidth = imageWidth
            self.imageHeight = imageHeight
            self.files = files
            self.sensitive = sensitive
            self.tags = []
            self.boards = []
        }

        enum CodingKeys: String, CodingKey {
            case id, text, app, copied, pinned, kind, image, imageWidth, imageHeight, imageText, files, sensitive, tags, boards, remindAt
        }

        /// Histories saved before kinds, images and boards still open.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            text = try c.decode(String.self, forKey: .text)
            app = try c.decodeIfPresent(String.self, forKey: .app)
            copied = try c.decode(Date.self, forKey: .copied)
            pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
            image = try c.decodeIfPresent(String.self, forKey: .image)
            imageWidth = try c.decodeIfPresent(Int.self, forKey: .imageWidth)
            imageHeight = try c.decodeIfPresent(Int.self, forKey: .imageHeight)
            imageText = try c.decodeIfPresent(String.self, forKey: .imageText)
            files = try c.decodeIfPresent([String].self, forKey: .files)
            sensitive = try c.decodeIfPresent(String.self, forKey: .sensitive)
            tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
            boards = try c.decodeIfPresent([String].self, forKey: .boards) ?? []
            remindAt = try c.decodeIfPresent(Date.self, forKey: .remindAt)
            kind = try c.decodeIfPresent(ClipKind.self, forKey: .kind) ?? (image != nil ? .image : files != nil ? .file : ClipKind.detect(text))
        }

        /// One line for a list: whitespace folded, cut to `limit` characters. Secrets show as dots.
        public func preview(_ limit: Int = 80) -> String {
            if let sensitive { return "\(sensitive) •••••••" }
            if kind == .image { return "Image" + (imageWidth.map { " \($0)×\(imageHeight ?? 0)" } ?? "") }
            let folded = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            return folded.count > limit ? String(folded.prefix(limit - 1)) + "…" : folded
        }

        func matches(_ q: String) -> Bool {
            if kind != .image, text.localizedCaseInsensitiveContains(q) { return true }
            if let imageText, imageText.localizedCaseInsensitiveContains(q) { return true }
            if let app, app.localizedCaseInsensitiveContains(q) { return true }
            for tag in tags where tag.localizedCaseInsensitiveContains(q) { return true }
            for board in boards where board.localizedCaseInsensitiveContains(q) { return true }
            return false
        }
    }

    public private(set) var clips: [Clip] = []
    public var keep: Int
    /// Board names, in the order they were made.
    public var boards: [String] = []

    public init(keep: Int = 50, clips: [Clip] = []) {
        self.keep = keep
        self.clips = clips
    }

    enum CodingKeys: String, CodingKey { case clips, keep, boards }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clips = try c.decodeIfPresent([Clip].self, forKey: .clips) ?? []
        keep = try c.decodeIfPresent(Int.self, forKey: .keep) ?? 50
        boards = try c.decodeIfPresent([String].self, forKey: .boards) ?? []
    }

    /// Adds a copy. The same text again moves to the top instead of repeating; blank text is ignored.
    /// Returns the clips that fell off the end (so their image files can be deleted).
    @discardableResult
    public mutating func add(_ text: String, app: String? = nil, at date: Date = Date(), sensitive: String? = nil) -> [Clip] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 100_000 else { return [] }
        var clip = Clip(text: text, app: app, copied: date, sensitive: sensitive)
        if let index = clips.firstIndex(where: { $0.text == text && $0.image == nil && $0.files == nil }) {
            clip = keepingExtras(clips[index], in: clip)
            clips.remove(at: index)
        }
        clips.insert(clip, at: 0)
        return trim()
    }

    /// Adds an image (already saved as `file`); `digest` spots the same picture copied twice.
    @discardableResult
    public mutating func addImage(file: String, digest: String, width: Int, height: Int, app: String? = nil, at date: Date = Date()) -> [Clip] {
        var dropped: [Clip] = []
        var clip = Clip(text: "", app: app, copied: date, kind: .image, image: file, imageWidth: width, imageHeight: height)
        clip.tags = []
        if let index = clips.firstIndex(where: { $0.image != nil && $0.text == "image:" + digest }) {
            clip = keepingExtras(clips[index], in: clip)
            clip.image = clips[index].image
            clip.imageText = clips[index].imageText
            if clips[index].image != file { dropped.append(Clip(text: "", image: file)) }
            clips.remove(at: index)
        }
        clip.text = "image:" + digest
        clips.insert(clip, at: 0)
        return dropped + trim()
    }

    /// Adds copied files (by path).
    @discardableResult
    public mutating func addFiles(_ paths: [String], app: String? = nil, at date: Date = Date()) -> [Clip] {
        guard !paths.isEmpty else { return [] }
        let text = paths.map { ($0 as NSString).lastPathComponent }.joined(separator: "\n")
        var clip = Clip(text: text, app: app, copied: date, kind: .file, files: paths)
        if let index = clips.firstIndex(where: { $0.files == paths }) {
            clip = keepingExtras(clips[index], in: clip)
            clips.remove(at: index)
        }
        clips.insert(clip, at: 0)
        return trim()
    }

    private func keepingExtras(_ old: Clip, in new: Clip) -> Clip {
        var clip = new
        clip.id = old.id
        clip.pinned = old.pinned
        clip.tags = old.tags
        clip.boards = old.boards
        clip.remindAt = old.remindAt
        return clip
    }

    public mutating func update(_ id: UUID, _ change: (inout Clip) -> Void) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        change(&clips[index])
    }

    public mutating func togglePin(_ id: UUID) { update(id) { $0.pinned.toggle() } }

    public mutating func setTags(_ id: UUID, _ tags: [String]) {
        var clean: [String] = []
        for tag in tags {
            let t = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !t.isEmpty && !clean.contains(t) { clean.append(t) }
        }
        update(id) { $0.tags = clean }
    }

    /// Every tag in use, most used first.
    public var allTags: [String] {
        var counts: [String: Int] = [:]
        for clip in clips { for tag in clip.tags { counts[tag, default: 0] += 1 } }
        return counts.keys.sorted { counts[$0]! != counts[$1]! ? counts[$0]! > counts[$1]! : $0 < $1 }
    }

    /// Makes a board (if new) and puts the clip on it. Clips on a board are kept like pinned ones.
    public mutating func addToBoard(_ id: UUID, board name: String) {
        let board = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !board.isEmpty else { return }
        if !boards.contains(board) { boards.append(board) }
        update(id) { if !$0.boards.contains(board) { $0.boards.append(board) } }
    }

    public mutating func removeFromBoard(_ id: UUID, board: String) { update(id) { $0.boards.removeAll { $0 == board } } }

    public mutating func deleteBoard(_ name: String) {
        boards.removeAll { $0 == name }
        for i in clips.indices { clips[i].boards.removeAll { $0 == name } }
    }

    public mutating func renameBoard(_ old: String, to new: String) {
        let name = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = boards.firstIndex(of: old), !boards.contains(name) else { return }
        boards[index] = name
        for i in clips.indices { clips[i].boards = clips[i].boards.map { $0 == old ? name : $0 } }
    }

    public mutating func remind(_ id: UUID, at date: Date?) { update(id) { $0.remindAt = date } }

    /// Reminders that are due: each clip comes back to the top and its reminder is cleared.
    public mutating func takeDueReminders(now: Date = Date()) -> [Clip] {
        var due: [Clip] = []
        for i in clips.indices {
            if let at = clips[i].remindAt, at <= now {
                clips[i].remindAt = nil
                clips[i].copied = now
                due.append(clips[i])
            }
        }
        if !due.isEmpty { clips.sort { $0.copied > $1.copied } }
        return due
    }

    public mutating func reveal(_ id: UUID) { update(id) { $0.sensitive = nil } }

    public mutating func setImageText(_ id: UUID, _ text: String) { update(id) { $0.imageText = text } }

    @discardableResult
    public mutating func remove(_ id: UUID) -> Clip? {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return nil }
        return clips.remove(at: index)
    }

    /// Clears everything but pinned clips and clips on boards; returns what was cleared.
    @discardableResult
    public mutating func clear() -> [Clip] {
        let gone = clips.filter { !$0.pinned && $0.boards.isEmpty }
        clips.removeAll { !$0.pinned && $0.boards.isEmpty }
        return gone
    }

    /// Pinned first, then newest; filtered by a search, a kind, a board and a tag when given.
    public func shown(matching query: String = "", kind: ClipKind? = nil, board: String? = nil, tag: String? = nil) -> [Clip] {
        let q = query.trimmingCharacters(in: .whitespaces)
        var found: [Clip] = []
        for clip in clips {
            if let kind, clip.kind != kind { continue }
            if let board, !clip.boards.contains(board) { continue }
            if let tag, !clip.tags.contains(tag) { continue }
            if !q.isEmpty && !clip.matches(q) { continue }
            found.append(clip)
        }
        return found.filter(\.pinned) + found.filter { !$0.pinned }
    }

    /// The last ten things copied, newest first, for ⌘⌃1 to ⌘⌃0 (pinned clips keep their place in time).
    public var quick: [Clip] { Array(clips.sorted { $0.copied > $1.copied }.prefix(10)) }

    /// How many clips of each kind.
    public var kindCounts: [ClipKind: Int] {
        var counts: [ClipKind: Int] = [:]
        for clip in clips { counts[clip.kind, default: 0] += 1 }
        return counts
    }

    private mutating func trim() -> [Clip] {
        var unpinned = 0
        var kept: [Clip] = []
        var dropped: [Clip] = []
        for clip in clips {
            if clip.pinned || !clip.boards.isEmpty || clip.remindAt != nil { kept.append(clip); continue }
            unpinned += 1
            if unpinned <= max(keep, 1) { kept.append(clip) } else { dropped.append(clip) }
        }
        clips = kept
        return dropped
    }
}

/// Several images laid out as one picture: justified rows, like a contact sheet.
public enum Moodboard {
    public struct Frame: Equatable, Sendable {
        public var x: Double, y: Double, width: Double, height: Double
    }

    /// Frames for images of the given sizes inside `width`, rows about `rowHeight` tall, `gap` apart.
    public static func layout(sizes: [(width: Double, height: Double)], width: Double, rowHeight: Double = 320, gap: Double = 12) -> (frames: [Frame], height: Double) {
        var frames: [Frame] = []
        var y = gap
        var row: [(index: Int, ratio: Double)] = []
        func place(_ row: [(index: Int, ratio: Double)], last: Bool) {
            let ratios = row.reduce(0) { $0 + $1.ratio }
            let available = width - gap * Double(row.count + 1)
            var height = available / max(ratios, 0.01)
            if last { height = min(height, rowHeight) }
            var x = gap
            for item in row {
                let w = height * item.ratio
                frames.append(Frame(x: x, y: y, width: w, height: height))
                x += w + gap
            }
            y += height + gap
        }
        for (index, size) in sizes.enumerated() {
            let ratio = size.height > 0 ? size.width / size.height : 1
            row.append((index, ratio))
            let ratios = row.reduce(0) { $0 + $1.ratio }
            if (width - gap * Double(row.count + 1)) / ratios <= rowHeight {
                place(row, last: false)
                row = []
            }
        }
        if !row.isEmpty { place(row, last: true) }
        return (frames, y)
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
