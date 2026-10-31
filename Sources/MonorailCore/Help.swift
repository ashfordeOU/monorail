import Foundation

/// Answers to "how do I…" questions typed in the command palette (Ask Monorail).
public enum HelpIndex {
    public enum Target: Equatable, Sendable {
        case action(Action)
        /// A Settings tab by its id (general, layout, input, appearance, apps, smart, devices, awake, automation, insights, shortcuts, about).
        case settings(String)
    }

    public struct Answer: Equatable, Sendable {
        public var question: String
        public var answer: String
        public var target: Target
        public var keywords: [String]
    }

    public static let all: [Answer] = [
        .init(question: "Keep my Mac awake", answer: "Stay Awake in the menu bar: for a while, while an app is open, or by itself with triggers.", target: .settings("awake"), keywords: ["awake", "sleep", "caffeinate", "amphetamine", "display", "lid"]),
        .init(question: "See all my windows", answer: "⌃⌥O opens the overview of every workspace and slide.", target: .action(.overview), keywords: ["overview", "see", "all", "windows", "expose", "mission"]),
        .init(question: "Find a window", answer: "⌃⌥/ then type its name, or use the window switcher.", target: .action(.windowSwitcher), keywords: ["find", "search", "window", "switch"]),
        .init(question: "Put two apps side by side", answer: "Type “Safari and Notes side by side” in the palette, or drag one window onto another in the overview.", target: .action(.commandPalette), keywords: ["side", "pair", "two", "together", "split"]),
        .init(question: "Make a window wider or narrower", answer: "⌃⌥R cycles widths; ⌃⌥- and ⌃⌥= narrower and wider; or type “Safari two thirds”.", target: .action(.cycleWidth), keywords: ["wider", "narrower", "width", "size", "resize", "bigger", "smaller"]),
        .init(question: "Fill the screen with one window", answer: "⌃⌥F makes the slide full width.", target: .action(.toggleFullWidth), keywords: ["full", "fill", "maximise", "maximize", "screen"]),
        .init(question: "Stop windows from moving", answer: "⌃⌥Q pauses tiling; every window comes back on screen.", target: .action(.togglePause), keywords: ["stop", "pause", "disable", "off", "moving"]),
        .init(question: "Turn off animations", answer: "Animate Windows in the menu bar menu: off moves windows instantly.", target: .action(.toggleAnimations), keywords: ["animation", "animate", "motion", "instant", "fast"]),
        .init(question: "Make an app float", answer: "⌃⌥T floats the window; a rule in Settings → Apps floats the app every time.", target: .settings("apps"), keywords: ["float", "floating", "tile", "exclude", "ignore"]),
        .init(question: "Change the shortcuts", answer: "Settings → Shortcuts: click a shortcut to change it.", target: .settings("shortcuts"), keywords: ["shortcut", "key", "keyboard", "hotkey", "bind"]),
        .init(question: "Use more workspaces", answer: "⌃⌥1–9 switches workspace; add ⇧ to take the window along. Set how many in Settings → General.", target: .settings("general"), keywords: ["workspace", "desktop", "space", "virtual"]),
        .init(question: "Hide private windows when sharing", answer: "Safe screen sharing hides private apps while you share; choose them in Devices & Sharing.", target: .settings("devices"), keywords: ["private", "share", "sharing", "zoom", "meet", "teams", "hide"]),
        .init(question: "Focus on one thing", answer: "⌃⌥B focus mode dims the rest; deep work also hides distracting apps.", target: .action(.toggleFocusMode), keywords: ["focus", "distraction", "dim", "concentrate", "deep"]),
        .init(question: "Change the colours", answer: "Settings → Appearance: 27 themes, including Seasons.", target: .settings("appearance"), keywords: ["theme", "colour", "color", "look", "dark"]),
        .init(question: "Hide the slider bar", answer: "Settings → Appearance → Show the slider bar.", target: .settings("appearance"), keywords: ["slider", "bar", "bottom", "hide"]),
        .init(question: "Undo a change", answer: "⌃⌥Z undoes the last layout change; the layout timeline goes further back.", target: .action(.undo), keywords: ["undo", "back", "revert", "mistake"]),
        .init(question: "Save a layout", answer: "Saved Layouts in the menu bar menu, or a session snapshot that brings back apps too.", target: .action(.takeSnapshot), keywords: ["save", "layout", "snapshot", "restore"]),
        .init(question: "Get alerts from AI agents", answer: "Monorail chimes when Claude Code, Codex and others wait for approval (Settings → Smart).", target: .settings("smart"), keywords: ["agent", "claude", "codex", "ai", "approval"]),
        .init(question: "Control it from my phone", answer: "Turn on the phone remote in Devices & Sharing and scan the QR code.", target: .settings("devices"), keywords: ["phone", "remote", "iphone", "qr"]),
        .init(question: "Use it with the mouse", answer: "Scroll over the menu bar or slider bar, use mouse buttons 4 and 5, or drag the slider.", target: .settings("input"), keywords: ["mouse", "scroll", "wheel", "trackpad", "swipe"]),
        .init(question: "Report a problem", answer: "Settings → Devices & Sharing → Report a Problem…", target: .settings("devices"), keywords: ["bug", "problem", "crash", "report", "broken"]),
        .init(question: "See how much energy it uses", answer: "Settings → About → Usage, and Check Energy.", target: .settings("about"), keywords: ["energy", "battery", "cpu", "performance", "usage", "memory"]),
        .init(question: "Fit every window on screen", answer: "The fit chip on a workspace in the overview, or ⌃⌥ fit mode, shares the screen between slides.", target: .action(.toggleFitMode), keywords: ["fit", "tile", "grid", "all on screen"]),
        .init(question: "Present or record", answer: "Presentation mode, share one slide, demo zoom, keystrokes and presenter notes are all in the palette.", target: .action(.shareSlide), keywords: ["present", "presentation", "record", "demo", "webinar"]),
        .init(question: "Automate it", answer: "monorail:// links, the monorail command, the local API, MCP and scripts (Settings → Automation).", target: .settings("automation"), keywords: ["automate", "script", "api", "shortcuts", "cli", "url"]),
    ]

    /// The best answers for a question, best first.
    public static func answers(for question: String, limit: Int = 3) -> [Answer] {
        let words = question.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            .filter { !["how", "do", "i", "can", "my", "the", "a", "to", "what", "is", "it", "make", "use", "in"].contains($0) }
        guard !words.isEmpty else { return [] }
        let scored = all.map { answer -> (Answer, Int) in
            let haystack = (answer.keywords + answer.question.lowercased().split(separator: " ").map(String.init))
            let score = words.reduce(0) { total, word in
                total + (haystack.contains(word) ? 3 : haystack.contains { $0.hasPrefix(word) || word.hasPrefix($0) && $0.count > 3 } ? 1 : 0)
            }
            return (answer, score)
        }
        return scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    /// True when the text reads like a question rather than a command.
    public static func isQuestion(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        return lower.hasSuffix("?") || ["how ", "how do", "how can", "where ", "what ", "why ", "can i", "help"].contains { lower.hasPrefix($0) }
    }
}
