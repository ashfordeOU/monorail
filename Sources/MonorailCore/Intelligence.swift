import Foundation

// MARK: - Natural-language commands

/// What a typed sentence asks for ("slack and mail side by side on 3").
public enum NaturalCommand: Equatable, Sendable {
    /// Put these apps' windows in one slide, optionally on a workspace (0-based).
    case pair(apps: [String], arrangement: Arrangement, workspace: Int?)
    /// Give an app's slide this share of the screen.
    case width(app: String?, share: Double)
    /// Move an app's window (or the focused one) to a workspace (0-based).
    case moveTo(app: String?, workspace: Int)
    /// Show a workspace (0-based).
    case switchTo(workspace: Int)
    /// Open or focus an app.
    case open(app: String)
    case focusMode(Bool)
    /// Any action by its name ("overview", "undo").
    case action(Action)
}

/// Turns plain sentences into commands. Rule-based, on device, instant.
public enum CommandParser {
    private static let numberWords = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
        "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
    ]
    private static let shares: [(String, Double)] = [
        ("full width", 1), ("full screen", 1), ("full", 1), ("whole screen", 1),
        ("three quarters", 0.75), ("3/4", 0.75), ("75%", 0.75),
        ("two thirds", 2.0 / 3.0), ("2/3", 2.0 / 3.0),
        ("half", 0.5), ("1/2", 0.5), ("50%", 0.5),
        ("one third", 1.0 / 3.0), ("a third", 1.0 / 3.0), ("third", 1.0 / 3.0), ("1/3", 1.0 / 3.0),
        ("quarter", 0.25), ("1/4", 0.25), ("25%", 0.25),
    ]
    private static let arrangements: [(String, Arrangement)] = [
        ("side by side", .columns), ("next to each other", .columns), ("beside", .columns), ("columns", .columns),
        ("stacked", .stack), ("on top of each other", .stack), ("above", .stack), ("up and down", .stack),
        ("grid", .grid), ("main left", .mainLeft), ("main on the left", .mainLeft), ("main top", .mainTop),
        ("spiral", .spiral), ("accordion", .accordion),
    ]

    /// Parses `text`; `apps` are the names of running apps, matched loosely.
    public static func parse(_ text: String, apps: [String]) -> NaturalCommand? {
        let lower = " " + text.lowercased()
            .replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces) + " "
        let mentioned = mentionedApps(in: lower, apps: apps)
        let workspace = workspaceNumber(in: lower).map { $0 - 1 }

        if lower.contains(" focus mode") || lower.contains(" focus on ") || lower.hasSuffix(" focus ") {
            if lower.contains(" off") || lower.contains(" stop") || lower.contains(" end") { return .focusMode(false) }
            if lower.contains(" on") || lower.contains(" start") || lower.contains(" focus mode ") { return .focusMode(true) }
        }
        if mentioned.count >= 2 {
            let arrangement = arrangements.first { lower.contains(" " + $0.0) }?.1 ?? .columns
            return .pair(apps: mentioned, arrangement: arrangement, workspace: workspace)
        }
        if let share = shares.first(where: { lower.contains($0.0) })?.1 {
            return .width(app: mentioned.first, share: share)
        }
        if let workspace {
            let moving = [" move ", " send ", " put ", " throw "].contains { lower.contains($0) }
            if moving || mentioned.first != nil { return .moveTo(app: mentioned.first, workspace: workspace) }
            return .switchTo(workspace: workspace)
        }
        if let app = mentioned.first, [" open ", " launch ", " start ", " go to ", " show ", " focus "].contains(where: lower.contains) {
            return .open(app: app)
        }
        // An action by its title or name ("show the overview", "undo").
        let words = lower.trimmingCharacters(in: .whitespaces)
        if let action = Action.allCases.first(where: { action in
            words == action.rawValue || words == action.title.lowercased()
                || words.replacingOccurrences(of: " ", with: "-") == action.rawValue
        }) {
            return .action(action)
        }
        if let action = Action.allCases.first(where: { words.contains($0.title.lowercased()) && $0.title.count > 5 }) {
            return .action(action)
        }
        if let app = mentioned.first { return .open(app: app) }
        return nil
    }

    /// Running apps named in the text, in the order they appear.
    static func mentionedApps(in lower: String, apps: [String]) -> [String] {
        var found: [(String, String.Index)] = []
        for app in apps {
            let name = app.lowercased()
            let short = name.split(separator: " ").first.map(String.init) ?? name
            for candidate in [name, short] where candidate.count >= 3 {
                if let range = lower.range(of: candidate), isWordBoundary(lower, range) {
                    if !found.contains(where: { $0.0 == app }) { found.append((app, range.lowerBound)) }
                    break
                }
            }
        }
        return found.sorted { $0.1 < $1.1 }.map(\.0)
    }

    private static func isWordBoundary(_ text: String, _ range: Range<String.Index>) -> Bool {
        let before = range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
        let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
        func word(_ c: Character?) -> Bool { c.map { $0.isLetter || $0.isNumber } ?? false }
        return !word(before) && !word(after)
    }

    /// "on 3", "to workspace two", "workspace 4", "desktop 2".
    static func workspaceNumber(in lower: String) -> Int? {
        let tokens = lower.split(separator: " ").map(String.init)
        for (i, token) in tokens.enumerated() {
            let value = Int(token) ?? numberWords[token]
            guard let value, (1...9).contains(value) else { continue }
            let previous = i > 0 ? tokens[i - 1] : ""
            if ["on", "to", "workspace", "desktop", "space", "into", "onto"].contains(previous) { return value }
        }
        return nil
    }
}

// MARK: - Intent workspaces

/// Something an intent can open: a template, saved layout, project or app pair.
public struct IntentCandidate: Equatable, Sendable {
    public enum Kind: String, Sendable { case template, layout, project, pair, workspace }
    public var kind: Kind
    public var name: String
    /// Extra words it answers to (its apps, its workspace).
    public var keywords: [String]

    public init(kind: Kind, name: String, keywords: [String] = []) {
        self.kind = kind
        self.name = name
        self.keywords = keywords
    }
}

/// Matches "write the Q3 report" to the best candidate by shared words.
public enum IntentMatcher {
    private static let stopWords: Set<String> = [
        "the", "a", "an", "to", "for", "on", "in", "of", "and", "my", "i", "want", "lets", "let's", "do", "some",
        "work", "start", "open", "get", "time", "with", "please", "now",
    ]
    /// Words that mean the same kind of work.
    private static let synonyms: [String: String] = [
        "code": "dev", "coding": "dev", "program": "dev", "programming": "dev", "develop": "dev", "debug": "dev",
        "write": "writing", "draft": "writing", "report": "writing", "doc": "writing", "docs": "writing", "essay": "writing",
        "design": "design", "figma": "design", "mockup": "design", "sketch": "design",
        "mail": "comms", "email": "comms", "slack": "comms", "chat": "comms", "messages": "comms", "inbox": "comms",
        "meeting": "meeting", "call": "meeting", "zoom": "meeting", "standup": "meeting",
        "research": "research", "read": "research", "reading": "research", "study": "research",
    ]

    public static func words(_ text: String) -> Set<String> {
        let raw = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return Set(raw.filter { !stopWords.contains($0) && $0.count > 1 }.map { synonyms[$0] ?? $0 })
    }

    /// The best match and its score (0…1), if anything shares a word.
    public static func best(for intent: String, in candidates: [IntentCandidate]) -> (IntentCandidate, Double)? {
        let wanted = words(intent)
        guard !wanted.isEmpty else { return nil }
        var best: (IntentCandidate, Double)?
        for candidate in candidates {
            let have = words(candidate.name).union(candidate.keywords.flatMap { words($0) })
            let shared = wanted.intersection(have).count
            guard shared > 0 else { continue }
            // Names count more than keywords.
            let nameHits = wanted.intersection(words(candidate.name)).count
            let score = (Double(shared) + Double(nameHits) * 0.5) / Double(wanted.count + 1)
            if score > (best?.1 ?? 0) { best = (candidate, min(score, 1)) }
        }
        return best
    }
}

// MARK: - Next-window prediction

/// Learns which app you go to after which, to stage the next window beside you.
public struct SequencePredictor: Codable, Equatable, Sendable {
    /// transitions[from][to] = count.
    public private(set) var transitions: [String: [String: Int]] = [:]
    private var last: String?

    public init() {}

    public mutating func record(_ app: String) {
        if let last, last != app { transitions[last, default: [:]][app, default: 0] += 1 }
        last = app
    }

    /// The likeliest next app after `app` and how sure (share of transitions), once seen enough.
    public func predict(after app: String, minimumSeen: Int = 4) -> (app: String, confidence: Double)? {
        guard let next = transitions[app], let top = next.max(by: { $0.value < $1.value }) else { return nil }
        let total = next.values.reduce(0, +)
        guard total >= minimumSeen else { return nil }
        return (top.key, Double(top.value) / Double(total))
    }

    private enum CodingKeys: String, CodingKey { case transitions }
}

// MARK: - Distraction detection

/// Counts focus switches in a sliding window to spot scattered attention.
public struct SwitchRateMonitor: Sendable {
    public var window: TimeInterval
    public var threshold: Int
    private var times: [Date] = []
    private var lastAlert: Date?

    public init(window: TimeInterval = 300, threshold: Int = 40) {
        self.window = window
        self.threshold = threshold
    }

    /// Records a switch; true when the rate just crossed the threshold (at most every 20 minutes).
    public mutating func record(at date: Date = Date()) -> Bool {
        times.append(date)
        times.removeAll { date.timeIntervalSince($0) > window }
        guard times.count >= threshold else { return false }
        if let lastAlert, date.timeIntervalSince(lastAlert) < 1200 { return false }
        lastAlert = date
        return true
    }

    public var recentCount: Int { times.count }
}

// MARK: - Learning from corrections

/// Notices when you keep giving an app the same width, and suggests a rule.
public struct CorrectionLearner: Codable, Equatable, Sendable {
    /// app → width (rounded to a preset) → times.
    public private(set) var widths: [String: [String: Int]] = [:]
    public private(set) var suggested: Set<String> = []
    public var dismissed: Set<String> = []
    public static let presets: [Double] = [0.25, 1.0 / 3.0, 0.5, 2.0 / 3.0, 0.75, 1]

    public init() {}

    public static func nearestPreset(_ width: Double) -> Double {
        presets.min { abs($0 - width) < abs($1 - width) } ?? width
    }

    /// Records a manual width change; returns a width to suggest as a rule once it has happened 3 times.
    public mutating func record(app: String, width: Double) -> Double? {
        let preset = Self.nearestPreset(width)
        let key = String(format: "%.3f", preset)
        widths[app, default: [:]][key, default: 0] += 1
        guard widths[app]?[key] == 3, !suggested.contains(app), !dismissed.contains(app) else { return nil }
        suggested.insert(app)
        return preset
    }
}

// MARK: - Grouping windows into projects

/// Finds the project a window belongs to from its title ("main.swift — monorail", "Acme · Figma").
public enum ProjectClusterer {
    private static let separators = [" — ", " – ", " - ", " · ", " | ", " • "]
    private static let generic: Set<String> = [
        "untitled", "new tab", "home", "inbox", "settings", "preferences", "welcome", "google chrome", "safari",
        "finder", "terminal", "zsh", "bash", "mail", "slack", "figma", "visual studio code", "xcode", "notion",
    ]

    /// The likely project word or phrase in a title, or nil.
    public static func project(in title: String, appName: String) -> String? {
        var parts = [title]
        for separator in separators {
            parts = parts.flatMap { $0.components(separatedBy: separator) }
        }
        let app = appName.lowercased()
        let candidates = parts.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { part in
                let lower = part.lowercased()
                return part.count >= 2 && part.count <= 40 && lower != app && !generic.contains(lower)
                    && !lower.contains(".") && !lower.hasPrefix("~") && !lower.hasPrefix("/")
            }
        // Editors and browsers put the project last; documents put it first.
        return candidates.count > 1 ? candidates.last : candidates.first
    }

    /// Windows (id, app, title) grouped by project, keeping only groups seen in 2+ windows.
    public static func groups<ID: Hashable>(_ windows: [(id: ID, app: String, title: String)]) -> [String: [ID]] {
        var groups: [String: [ID]] = [:]
        var display: [String: String] = [:]
        for window in windows {
            guard let project = project(in: window.title, appName: window.app) else { continue }
            let key = project.lowercased()
            display[key] = display[key] ?? project
            groups[key, default: []].append(window.id)
        }
        return Dictionary(uniqueKeysWithValues: groups.filter { $0.value.count >= 2 }.map { (display[$0.key]!, $0.value) })
    }
}

// MARK: - Content-aware widths

/// A width that suits what an app shows: about 100 columns of code, a page of text, a web page.
public enum ContentWidths {
    public enum Kind: String, Sendable { case code, terminal, document, browser, chat, media, design }

    private static let kinds: [String: Kind] = [
        "com.apple.dt.Xcode": .code, "com.microsoft.VSCode": .code, "com.todesktop.230313mzl4w4u92": .code,
        "dev.zed.Zed": .code, "com.jetbrains.intellij": .code, "com.sublimetext.4": .code, "com.panic.Nova": .code,
        "com.apple.Terminal": .terminal, "com.googlecode.iterm2": .terminal, "com.github.wez.wezterm": .terminal,
        "net.kovidgoyal.kitty": .terminal, "com.mitchellh.ghostty": .terminal, "dev.warp.Warp-Stable": .terminal,
        "org.alacritty": .terminal, "io.alacritty": .terminal, "co.zeit.hyper": .terminal, "com.raphaelamorim.rio": .terminal,
        "com.apple.iWork.Pages": .document, "com.microsoft.Word": .document, "com.apple.TextEdit": .document,
        "md.obsidian": .document, "notion.id": .document, "com.apple.Preview": .document, "com.apple.Notes": .document,
        "com.apple.Safari": .browser, "com.google.Chrome": .browser, "org.mozilla.firefox": .browser,
        "company.thebrowser.Browser": .browser, "com.brave.Browser": .browser, "com.microsoft.edgemac": .browser,
        "com.tinyspeck.slackmacgap": .chat, "com.apple.MobileSMS": .chat, "com.hnc.Discord": .chat,
        "ru.keepcoder.Telegram": .chat, "net.whatsapp.WhatsApp": .chat, "com.apple.mail": .chat,
        "com.apple.Music": .media, "com.spotify.client": .media, "com.apple.TV": .media,
        "com.figma.Desktop": .design, "com.bohemiancoding.sketch3": .design, "com.adobe.Photoshop": .design,
    ]

    public static func kind(of bundleID: String?) -> Kind? { bundleID.flatMap { kinds[$0] } }

    /// The share of a display of this width (points) that suits the app, or nil to keep the default.
    public static func share(for bundleID: String?, displayWidth: Double) -> Double? {
        guard let kind = kind(of: bundleID), displayWidth > 0 else { return nil }
        let points: Double
        switch kind {
        case .code: points = 980        // ~100 columns plus a sidebar
        case .terminal: points = 760    // ~100 columns
        case .document: points = 860    // a page with margins
        case .browser: points = 1180    // most sites' layout width
        case .chat: points = 620
        case .media: points = 560
        case .design: return 1
        }
        let share = points / displayWidth
        return CorrectionLearner.nearestPreset(min(max(share, 0.25), 1))
    }
}

// MARK: - File-path rules

/// "Anything from ~/Clients/Acme goes to workspace 3."
public struct PathRule: Equatable, Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var path: String
    /// 0-based workspace.
    public var workspace: Int

    public init(id: String = UUID().uuidString, path: String, workspace: Int) {
        self.id = id
        self.path = path
        self.workspace = workspace
    }

    /// The workspace for a document path (the longest matching folder wins).
    public static func workspace(for document: String, rules: [PathRule], home: String = NSHomeDirectory()) -> Int? {
        func expand(_ p: String) -> String {
            var path = p.hasPrefix("~") ? home + p.dropFirst() : p
            if path.hasPrefix("file://") { path = URL(string: path)?.path ?? path }
            return path.hasSuffix("/") ? path : path + "/"
        }
        let target = expand(document.removingPercentEncoding ?? document)
        return rules.filter { !$0.path.isEmpty && target.hasPrefix(expand($0.path)) }
            .max { expand($0.path).count < expand($1.path).count }?.workspace
    }
}

// MARK: - Display profiles

/// A stable name for the set of connected displays ("desk", "café", "projector").
public enum DisplayProfile {
    public static func key(for displayUUIDs: [String]) -> String {
        displayUUIDs.sorted().joined(separator: "+")
    }
}

// MARK: - Flow score and time budgets

/// A 0–100 score for a day: focused time up, interruptions down.
public enum FlowScore {
    public static func score(focusMinutes: Int, activeMinutes: Int, switches: Int) -> Int {
        guard activeMinutes > 0 else { return 0 }
        let focus = min(Double(focusMinutes) / Double(activeMinutes), 1)
        let switchesPerHour = Double(switches) / (Double(activeMinutes) / 60)
        let calm = max(0, 1 - switchesPerHour / 120)
        return Int(((focus * 0.6 + calm * 0.4) * 100).rounded())
    }

    public static func label(_ score: Int) -> String {
        switch score {
        case 80...: return "Deep flow"
        case 60..<80: return "Focused"
        case 40..<60: return "Mixed"
        default: return "Scattered"
        }
    }
}

/// How long a workspace may be used each day before a nudge.
public enum TimeBudget {
    /// Nil until over budget; then the minutes over.
    public static func over(used: Int, budget: Int) -> Int? {
        budget > 0 && used >= budget ? used - budget : nil
    }
}

// MARK: - Agent windows

/// Spots terminal windows of AI coding agents and when they need you.
public enum AgentWatch {
    private static let agentMarkers = ["claude", "codex", "aider", "gemini", "cursor-agent", "copilot", "goose", "opencode", "amp"]
    private static let waitingMarkers = ["✳", "needs approval", "waiting for", "permission", "approve", "(y/n)", "[y/n]", "❓", "input required"]
    private static let doneMarkers = ["✓ done", "completed", "finished", "✔"]

    public enum State: String, Sendable { case working, waiting, done }

    public static func isAgent(title: String) -> Bool {
        let lower = title.lowercased()
        return agentMarkers.contains { lower.contains($0) }
    }

    public static func state(title: String) -> State? {
        guard isAgent(title: title) else { return nil }
        let lower = title.lowercased()
        if waitingMarkers.contains(where: { lower.contains($0) }) { return .waiting }
        if doneMarkers.contains(where: { lower.contains($0) }) { return .done }
        return .working
    }
}

// MARK: - App quirks

/// What Monorail knows about apps that bend the rules, built in and updated
/// from the repository's quirks.json.
public enum Quirks {
    /// Apps that keep part of a window on screen when parked at the edge (often Electron).
    public static var edgeShy: Set<String> = [
        "com.tinyspeck.slackmacgap", "com.hnc.Discord", "com.microsoft.teams2", "notion.id", "com.spotify.client",
        "com.anthropic.claudefordesktop", "com.openai.chat", "md.obsidian", "com.figma.Desktop", "com.linear",
        "com.todesktop.230313mzl4w4u92", "com.microsoft.VSCode", "net.whatsapp.WhatsApp", "com.electron.",
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "app.zen-browser.zen", "com.google.Chrome",
    ]

    /// The shape of quirks.json.
    public struct File: Codable, Equatable, Sendable {
        public var edgeShy: [String]
        public var float: [String]?
        public init(edgeShy: [String], float: [String]? = nil) {
            self.edgeShy = edgeShy
            self.float = float
        }
    }

    /// Merges a downloaded quirks file; returns how many new apps it taught.
    @discardableResult
    public static func merge(_ data: Data) -> Int {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return 0 }
        let before = edgeShy.count
        edgeShy.formUnion(file.edgeShy)
        return edgeShy.count - before
    }
}

// MARK: - Template gallery

/// Ready-made workspaces to start from (Settings → Apps → Templates → Gallery).
public enum TemplateGallery {
    public static let all: [WorkspaceTemplate] = [
        WorkspaceTemplate(name: "Web development", items: [
            .init(bundleID: "com.microsoft.VSCode"), .init(bundleID: "com.googlecode.iterm2"),
            .init(bundleID: "com.google.Chrome", open: "http://localhost:3000"),
        ], arrangement: .mainLeft),
        WorkspaceTemplate(name: "iOS development", items: [
            .init(bundleID: "com.apple.dt.Xcode"), .init(bundleID: "com.apple.iphonesimulator"), .init(bundleID: "com.apple.Terminal"),
        ], arrangement: .mainLeft),
        WorkspaceTemplate(name: "Design review", items: [
            .init(bundleID: "com.figma.Desktop"), .init(bundleID: "com.apple.Safari"), .init(bundleID: "com.tinyspeck.slackmacgap"),
        ], arrangement: .mainLeft),
        WorkspaceTemplate(name: "Writing", items: [
            .init(bundleID: "com.apple.iWork.Pages"), .init(bundleID: "com.apple.Safari"),
        ], arrangement: .columns),
        WorkspaceTemplate(name: "Research", items: [
            .init(bundleID: "com.apple.Safari"), .init(bundleID: "md.obsidian"), .init(bundleID: "com.apple.Preview"),
        ], arrangement: .columns),
        WorkspaceTemplate(name: "Trading desk", items: [
            .init(bundleID: "com.google.Chrome", open: "https://www.tradingview.com"),
            .init(bundleID: "com.apple.stocks"), .init(bundleID: "com.apple.Notes"),
        ], arrangement: .grid),
        WorkspaceTemplate(name: "Video editing", items: [
            .init(bundleID: "com.apple.FinalCut"), .init(bundleID: "com.apple.finder"),
        ], arrangement: .mainTop),
        WorkspaceTemplate(name: "Communications", items: [
            .init(bundleID: "com.apple.mail"), .init(bundleID: "com.tinyspeck.slackmacgap"), .init(bundleID: "com.apple.iCal"),
        ], arrangement: .columns),
        WorkspaceTemplate(name: "Data science", items: [
            .init(bundleID: "com.microsoft.VSCode"), .init(bundleID: "com.google.Chrome", open: "http://localhost:8888"),
            .init(bundleID: "com.googlecode.iterm2"),
        ], arrangement: .mainLeft),
        WorkspaceTemplate(name: "Support desk", items: [
            .init(bundleID: "com.google.Chrome"), .init(bundleID: "com.tinyspeck.slackmacgap"), .init(bundleID: "com.apple.Notes"),
        ], arrangement: .mainLeft),
    ]
}
