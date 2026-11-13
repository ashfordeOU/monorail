import Foundation

/// Switches: one-click system settings and actions, grouped like System Settings, plus modes that
/// turn several on together (by hand or when something happens) and put them back afterwards.

public enum SwitchGroup: String, CaseIterable, Codable, Sendable {
    case screen = "Screen", finder = "Finder", keyboard = "Keyboard", sound = "Sound", system = "System", actions = "Actions", custom = "Your Switches"
}

public struct SwitchDef: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var group: SwitchGroup
    public var symbol: String
    /// An action runs once (Empty Trash); a switch stays on or off.
    public var isAction: Bool
    /// The App Store's sandbox allows it (Signalbox).
    public var inSignalbox: Bool
    public var about: String

    public init(_ id: String, _ title: String, _ group: SwitchGroup, _ symbol: String, action: Bool = false, signalbox: Bool = false, _ about: String) {
        self.id = id
        self.title = title
        self.group = group
        self.symbol = symbol
        self.isAction = action
        self.inSignalbox = signalbox
        self.about = about
    }
}

public enum SwitchCatalogue {
    public static let all: [SwitchDef] = [
        SwitchDef("darkMode", "Dark Mode", .screen, "circle.lefthalf.filled", "Light or dark appearance for the whole Mac."),
        SwitchDef("evening", "Evening Mode", .screen, "sun.haze", signalbox: true, "A warmer screen for the evening."),
        SwitchDef("hideDesktopIcons", "Hide Desktop Icons", .screen, "menubar.dock.rectangle", "A clean desktop for screenshots and sharing."),
        SwitchDef("hideDock", "Hide the Dock", .screen, "dock.rectangle", "The Dock slides in only when you point at it."),
        SwitchDef("hideMenuBar", "Hide the Menu Bar", .screen, "menubar.rectangle", "The menu bar appears only when you point at the top."),
        SwitchDef("backdrop", "Backdrop", .screen, "square.on.square.squareshape.controlhandles", signalbox: true, "A calm colour behind your windows, covering the desktop."),
        SwitchDef("showHiddenFiles", "Show Hidden Files", .finder, "eye", "Show files whose names start with a dot."),
        SwitchDef("showExtensions", "Show File Extensions", .finder, "doc.text", "Show .pdf, .png and the rest on every file."),
        SwitchDef("pathBar", "Path Bar", .finder, "arrow.right.doc.on.clipboard", "Where a folder is, at the bottom of Finder windows."),
        SwitchDef("statusBar", "Status Bar", .finder, "info.circle", "Item count and free space at the bottom of Finder windows."),
        SwitchDef("foldersFirst", "Folders First", .finder, "folder", "Folders above files when sorting by name."),
        SwitchDef("trashWarning", "Ask Before Emptying Trash", .finder, "trash.slash", "Finder asks before it empties the Trash."),
        SwitchDef("fastKeyRepeat", "Fast Key Repeat", .keyboard, "keyboard", "Held keys repeat sooner and faster (after you log out and in)."),
        SwitchDef("lockKeyboard", "Lock the Keyboard", .keyboard, "keyboard.badge.ellipsis", "Ignore every key for a minute while you wipe the keyboard."),
        SwitchDef("mute", "Mute", .sound, "speaker.slash", signalbox: true, "Silence the Mac's sound output."),
        SwitchDef("keepAwake", "Keep Awake", .system, "cup.and.saucer", signalbox: true, "Stop the Mac and its screen from sleeping."),
        SwitchDef("doNotDisturb", "Do Not Disturb", .system, "moon", signalbox: true, "Through two shortcuts you add once: \"Focus On\" and \"Focus Off\"."),
        SwitchDef("emptyTrash", "Empty Trash", .actions, "trash", action: true, "Empties the Trash now."),
        SwitchDef("ejectAll", "Eject All Disks", .actions, "eject", action: true, "Ejects every external drive and disk image."),
        SwitchDef("restartFinder", "Restart Finder", .actions, "arrow.clockwise", action: true, "When Finder misbehaves."),
        SwitchDef("restartDock", "Restart the Dock", .actions, "arrow.clockwise.circle", action: true, "When the Dock or Mission Control misbehave."),
        SwitchDef("flushDNS", "Flush DNS", .actions, "network", action: true, "Clears the address cache when websites won't load (asks for your password)."),
        SwitchDef("plainPaste", "Make Clipboard Plain", .actions, "doc.plaintext", action: true, signalbox: true, "Strips formatting from what you copied."),
        SwitchDef("screenSaver", "Start Screen Saver", .actions, "sparkles.tv", action: true, signalbox: true, "Starts the screen saver now."),
        SwitchDef("sleepDisplays", "Sleep Displays", .actions, "display", action: true, "Turns the screens off now."),
    ]

    public static func available(appStore: Bool) -> [SwitchDef] { appStore ? all.filter(\.inSignalbox) : all }

    public static func find(_ id: String) -> SwitchDef? { all.first { $0.id == id } }
}

/// A switch you make from a shell command or a shortcut in the Shortcuts app.
public struct CustomSwitch: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var symbol: String
    /// Shell commands (Monorail only). With no off command it's an action.
    public var onCommand: String
    public var offCommand: String
    /// A command that prints something for on and nothing (or exits non-zero) for off.
    public var stateCommand: String
    /// Shortcuts to run instead (both editions).
    public var onShortcut: String
    public var offShortcut: String

    public init(id: String = UUID().uuidString, title: String, symbol: String = "switch.2", onCommand: String = "", offCommand: String = "",
                stateCommand: String = "", onShortcut: String = "", offShortcut: String = "") {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.onCommand = onCommand
        self.offCommand = offCommand
        self.stateCommand = stateCommand
        self.onShortcut = onShortcut
        self.offShortcut = offShortcut
    }

    public var isAction: Bool { offCommand.isEmpty && offShortcut.isEmpty }
    public var switchID: String { "custom." + id }
}

/// What starts a mode on its own.
public enum ModeTrigger: Codable, Equatable, Hashable, Sendable {
    /// An app is open (by bundle identifier).
    case app(String)
    /// The screen is being shared or recorded.
    case screenShare
    /// A display with this name is connected ("LG UltraFine").
    case display(String)
    case onBattery
    case onPower
    /// Weekdays (1 = Sunday … 7 = Saturday) between two times, in minutes after midnight.
    case schedule(days: [Int], start: Int, end: Int)
    /// A calendar meeting is happening now.
    case inMeeting

    public var title: String {
        switch self {
        case .app(let id): return "When \(id.split(separator: ".").last.map(String.init) ?? id) is open"
        case .screenShare: return "While the screen is shared or recorded"
        case .display(let name): return "When \(name) is connected"
        case .onBattery: return "On battery"
        case .onPower: return "Plugged in"
        case .schedule(let days, let start, let end):
            let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let list = days.count == 7 ? "Every day" : days == [2, 3, 4, 5, 6] ? "Weekdays" : days.sorted().compactMap { (1...7).contains($0) ? names[$0 - 1] : nil }.joined(separator: ", ")
            return "\(list) \(Self.clock(start))–\(Self.clock(end))"
        case .inMeeting: return "During calendar meetings"
        }
    }

    static func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60) }
}

/// What the Mac is doing right now, for deciding which modes should be on.
public struct ModeContext: Equatable, Sendable {
    public var runningApps: Set<String>
    public var sharingScreen: Bool
    public var displays: [String]
    public var onBattery: Bool
    public var weekday: Int
    public var minutes: Int
    public var inMeeting: Bool

    public init(runningApps: Set<String> = [], sharingScreen: Bool = false, displays: [String] = [], onBattery: Bool = false,
                weekday: Int = 2, minutes: Int = 600, inMeeting: Bool = false) {
        self.runningApps = runningApps
        self.sharingScreen = sharingScreen
        self.displays = displays
        self.onBattery = onBattery
        self.weekday = weekday
        self.minutes = minutes
        self.inMeeting = inMeeting
    }

    public static func at(_ date: Date, calendar: Calendar = .current) -> (weekday: Int, minutes: Int) {
        let c = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        return (c.weekday ?? 1, (c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    public func matches(_ trigger: ModeTrigger) -> Bool {
        switch trigger {
        case .app(let id): return runningApps.contains(id)
        case .screenShare: return sharingScreen
        case .display(let name): return displays.contains { $0.localizedCaseInsensitiveContains(name) }
        case .onBattery: return onBattery
        case .onPower: return !onBattery
        case .inMeeting: return inMeeting
        case .schedule(let days, let start, let end):
            if start <= end { return days.contains(weekday) && minutes >= start && minutes < end }
            // Overnight (22:00–06:00): the evening belongs to `days`, the morning to the day after.
            let yesterday = weekday == 1 ? 7 : weekday - 1
            return (days.contains(weekday) && minutes >= start) || (days.contains(yesterday) && minutes < end)
        }
    }
}

/// A group of switches for one job: Recording, Call, Presentation, Deep Work, or your own.
public struct Mode: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var symbol: String
    /// Switch id → on or off while the mode runs (actions run once when it starts).
    public var switches: [String: Bool]
    /// Starts by itself when any of these is true (and stops when none is).
    public var triggers: [ModeTrigger]
    public var enabled: Bool

    public init(id: String = UUID().uuidString, name: String, symbol: String = "square.stack.3d.up", switches: [String: Bool] = [:],
                triggers: [ModeTrigger] = [], enabled: Bool = true) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.switches = switches
        self.triggers = triggers
        self.enabled = enabled
    }

    public static let starters: [Mode] = [
        Mode(id: "recording", name: "Recording", symbol: "record.circle",
             switches: ["hideDesktopIcons": true, "hideDock": true, "backdrop": true, "doNotDisturb": true],
             triggers: [.screenShare]),
        Mode(id: "call", name: "Call", symbol: "phone", switches: ["doNotDisturb": true, "keepAwake": true], triggers: [.inMeeting]),
        Mode(id: "presentation", name: "Presentation", symbol: "play.rectangle",
             switches: ["hideDesktopIcons": true, "hideDock": true, "hideMenuBar": true, "doNotDisturb": true, "keepAwake": true]),
        Mode(id: "deepWork", name: "Deep Work", symbol: "brain.head.profile", switches: ["doNotDisturb": true, "mute": true]),
    ]
}

extension Mode {
    /// The starter modes, with their automatic starts off until you turn them on.
    public static var defaultSet: [Mode] {
        var list = starters
        for i in list.indices { list[i].enabled = false }
        return list
    }
}

public enum ModePlanner {
    /// Modes whose triggers say they should be on now.
    public static func triggered(_ modes: [Mode], context: ModeContext) -> Set<String> {
        var on: Set<String> = []
        for mode in modes where mode.enabled && !mode.triggers.isEmpty {
            if mode.triggers.contains(where: context.matches) { on.insert(mode.id) }
        }
        return on
    }

    /// What to set when a mode starts: each switch's target, and what it was before (to put back).
    public static func start(_ mode: Mode, current: [String: Bool]) -> (set: [String: Bool], remember: [String: Bool]) {
        var set: [String: Bool] = [:]
        var remember: [String: Bool] = [:]
        for (id, target) in mode.switches {
            if SwitchCatalogue.find(id)?.isAction == true { set[id] = true; continue }
            let now = current[id] ?? false
            if now != target {
                set[id] = target
                remember[id] = now
            }
        }
        return (set, remember)
    }

    /// What to put back when a mode stops, leaving alone anything another running mode still wants.
    public static func stop(remembered: [String: Bool], stillWanted: [String: Bool]) -> [String: Bool] {
        var restore: [String: Bool] = [:]
        for (id, before) in remembered where stillWanted[id] == nil { restore[id] = before }
        return restore
    }
}

/// Sums typed into the palette ("12*4.5", "(3+4)^2", "15% of 80"): numbers, + − × ÷, ^, brackets and %.
public enum QuickCalc {
    public static func evaluate(_ input: String) -> Double? {
        var text = input.lowercased().replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: "")
        if text.hasPrefix("=") { text.removeFirst() }
        // "15%of80" → 15/100*80
        if let range = text.range(of: "%of") {
            text = "(" + text[..<range.lowerBound] + ")/100*(" + text[range.upperBound...] + ")"
        }
        guard !text.isEmpty, text.contains(where: { "+-*/^%(".contains($0) }), text.allSatisfy({ "0123456789.+-*/^%()".contains($0) }) else { return nil }
        var parser = Parser(chars: Array(text))
        guard let value = parser.expression(), parser.index == parser.chars.count, value.isFinite else { return nil }
        return value
    }

    public static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        let s = String(format: "%.10g", value)
        return s
    }

    struct Parser {
        let chars: [Character]
        var index = 0

        mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while index < chars.count, chars[index] == "+" || chars[index] == "-" {
                let op = chars[index]
                index += 1
                guard let rhs = term() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func term() -> Double? {
            guard var value = power() else { return nil }
            while index < chars.count, chars[index] == "*" || chars[index] == "/" {
                let op = chars[index]
                index += 1
                guard let rhs = power() else { return nil }
                if op == "/" && rhs == 0 { return nil }
                value = op == "*" ? value * rhs : value / rhs
            }
            return value
        }

        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if index < chars.count, chars[index] == "^" {
                index += 1
                guard let exponent = power() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        mutating func unary() -> Double? {
            if index < chars.count, chars[index] == "-" {
                index += 1
                return unary().map { -$0 }
            }
            if index < chars.count, chars[index] == "+" { index += 1 }
            guard var value = primary() else { return nil }
            while index < chars.count, chars[index] == "%" {
                index += 1
                value /= 100
            }
            return value
        }

        mutating func primary() -> Double? {
            guard index < chars.count else { return nil }
            if chars[index] == "(" {
                index += 1
                guard let value = expression(), index < chars.count, chars[index] == ")" else { return nil }
                index += 1
                return value
            }
            var digits = ""
            while index < chars.count, chars[index].isNumber || chars[index] == "." {
                digits.append(chars[index])
                index += 1
            }
            return Double(digits)
        }
    }
}
