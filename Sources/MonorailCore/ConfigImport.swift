import Foundation

/// Reads the settings of other window managers so switching to Monorail takes a minute:
/// shortcuts, gaps, which apps float, and which workspace apps open on.
public struct ImportPlan: Equatable, Sendable {
    public var source: String
    public var gap: Double?
    /// Apps to keep off the strip, by bundle ID or app name (as the source wrote them).
    public var floatApps: [String] = []
    /// App (bundle ID or name) → workspace number (1-based).
    public var workspaceApps: [(app: String, workspace: Int)] = []
    public var bindings: [(action: Action, shortcut: Shortcut)] = []
    /// Lines that had no Monorail equivalent, to show people what was left out.
    public var skipped: [String] = []

    public init(source: String) { self.source = source }

    public var isEmpty: Bool { gap == nil && floatApps.isEmpty && workspaceApps.isEmpty && bindings.isEmpty }

    public var summary: String {
        var parts: [String] = []
        if !bindings.isEmpty { parts.append("\(bindings.count) shortcuts") }
        if !floatApps.isEmpty { parts.append("\(floatApps.count) floating apps") }
        if !workspaceApps.isEmpty { parts.append("\(workspaceApps.count) workspace rules") }
        if let gap { parts.append("gaps of \(Int(gap)) points") }
        return parts.isEmpty ? "Nothing to import" : parts.joined(separator: ", ")
    }

    public static func == (a: ImportPlan, b: ImportPlan) -> Bool {
        a.source == b.source && a.gap == b.gap && a.floatApps == b.floatApps
            && a.workspaceApps.map { "\($0.app)=\($0.workspace)" } == b.workspaceApps.map { "\($0.app)=\($0.workspace)" }
            && a.bindings.map { "\($0.action.rawValue)=\($0.shortcut.keyCode)/\($0.shortcut.modifiers.rawValue)" }
                == b.bindings.map { "\($0.action.rawValue)=\($0.shortcut.keyCode)/\($0.shortcut.modifiers.rawValue)" }
    }
}

public enum ConfigImport {
    // MARK: Keys

    /// Key names as other tools write them (lower case) → virtual key code.
    static let keyCodes: [String: UInt16] = {
        var map: [String: UInt16] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
            "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38,
            "k": 40, "n": 45, "m": 46,
            "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
            "equal": 24, "=": 24, "minus": 27, "-": 27, "comma": 43, ",": 43, "period": 47, ".": 47,
            "semicolon": 41, ";": 41, "quote": 39, "'": 39, "slash": 44, "/": 44, "backslash": 42, "\\": 42,
            "leftsquarebracket": 33, "[": 33, "rightsquarebracket": 30, "]": 30, "backtick": 50, "grave": 50, "`": 50,
            "return": 36, "enter": 36, "tab": 48, "space": 49, "backspace": 51, "delete": 51, "esc": 53, "escape": 53,
            "left": 123, "right": 124, "down": 125, "up": 126, "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
        ]
        let f: [UInt16] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        for (i, code) in f.enumerated() { map["f\(i + 1)"] = code }
        return map
    }()

    static func modifiers(_ names: [String]) -> Modifiers? {
        var mods: Modifiers = []
        for name in names {
            switch name.lowercased() {
            case "alt", "option", "opt", "lalt", "ralt": mods.insert(.option)
            case "ctrl", "control", "lctrl", "rctrl": mods.insert(.control)
            case "cmd", "command", "lcmd", "rcmd": mods.insert(.command)
            case "shift", "lshift", "rshift": mods.insert(.shift)
            case "hyper": mods.formUnion([.control, .option, .command, .shift])
            case "meh": mods.formUnion([.control, .option, .shift])
            default: return nil
            }
        }
        return mods
    }

    // MARK: AeroSpace (aerospace.toml)

    /// Reads an AeroSpace `aerospace.toml`.
    public static func aeroSpace(_ raw: String) -> ImportPlan {
        let text = normalisedLines(raw)
        var plan = ImportPlan(source: "AeroSpace")
        var section = ""
        var detectedApp: String?
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = stripComment(String(raw)).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("[[") {
                section = line.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
                detectedApp = nil
                continue
            }
            if line.hasPrefix("[") {
                section = line.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            switch section {
            case "gaps.inner", "gaps":
                if (key == "horizontal" || key == "inner.horizontal"), let n = Double(value) { plan.gap = n }
            case "mode.main.binding":
                let command = unquote(value)
                if let action = aeroSpaceAction(command), let shortcut = aeroSpaceShortcut(key) {
                    plan.bindings.append((action, shortcut))
                } else {
                    plan.skipped.append("\(key) = \(command)")
                }
            case "on-window-detected":
                if key == "if.app-id" { detectedApp = unquote(value) }
                if key == "if.app-name-regex-substring" { detectedApp = unquote(value) }
                if key == "run", let app = detectedApp {
                    let commands = value.trimmingCharacters(in: CharacterSet(charactersIn: "[] ")).split(separator: ",")
                        .map { unquote(String($0)) }
                    for command in commands {
                        if command.contains("layout floating") { plan.floatApps.append(app) }
                        if command.hasPrefix("move-node-to-workspace"), let n = Int(command.split(separator: " ").last ?? ""),
                            (1...9).contains(n)
                        {
                            plan.workspaceApps.append((app, n))
                        }
                    }
                }
            default:
                break
            }
        }
        return plan
    }

    static func aeroSpaceShortcut(_ key: String) -> Shortcut? {
        let parts = key.split(separator: "-").map(String.init)
        guard let last = parts.last, let code = keyCodes[last.lowercased()], let mods = modifiers(Array(parts.dropLast())),
            !mods.isEmpty
        else { return nil }
        return Shortcut(keyCode: code, modifiers: mods)
    }

    static func aeroSpaceAction(_ command: String) -> Action? {
        let words = command.split(separator: " ").map(String.init)
        guard let verb = words.first else { return nil }
        let arg = words.count > 1 ? words[1] : ""
        switch (verb, arg) {
        case ("focus", "left"): return .focusLeft
        case ("focus", "right"): return .focusRight
        case ("focus", "up"): return .focusUp
        case ("focus", "down"): return .focusDown
        case ("move", "left"): return .moveLeft
        case ("move", "right"): return .moveRight
        case ("move", "up"): return .moveUp
        case ("move", "down"): return .moveDown
        case ("fullscreen", _): return .toggleFullWidth
        case ("layout", _) where command.contains("floating"): return .toggleFloat
        case ("layout", _) where command.contains("accordion"): return .layoutAccordion
        case ("layout", _) where command.contains("tiles"): return .cycleLayout
        case ("workspace-back-and-forth", _): return .workspaceBackAndForth
        case ("balance-sizes", _): return .balanceSizes
        case ("resize", _) where command.contains("+"): return .wider
        case ("resize", _) where command.contains("-"): return .narrower
        case ("workspace", _): return Int(arg).flatMap { (1...9).contains($0) ? Action(rawValue: "workspace-\($0)") : nil }
        case ("move-node-to-workspace", _): return Int(arg).flatMap { (1...9).contains($0) ? Action(rawValue: "move-to-workspace-\($0)") : nil }
        case ("move-workspace-to-monitor", _): return .moveWorkspaceToNextDisplay
        case ("focus-monitor", _): return .focusNextDisplay
        default: return nil
        }
    }

    // MARK: yabai + skhd

    /// Reads `.yabairc` (gaps and app rules) and `.skhdrc` (shortcuts that call yabai).
    public static func yabai(yabairc rawYabairc: String, skhdrc rawSkhdrc: String) -> ImportPlan {
        let yabairc = normalisedLines(rawYabairc), skhdrc = normalisedLines(rawSkhdrc)
        var plan = ImportPlan(source: "yabai")
        for raw in yabairc.split(separator: "\n") {
            let line = stripComment(String(raw), marker: "#").trimmingCharacters(in: .whitespaces)
            if line.contains("config window_gap"), let n = Double(line.split(separator: " ").last ?? "") { plan.gap = n }
            guard line.contains("rule --add") else { continue }
            guard let app = argument("app", in: line) else { continue }
            let name = app.trimmingCharacters(in: CharacterSet(charactersIn: "^$"))
            if line.contains("manage=off") { plan.floatApps.append(name) }
            if let space = argument("space", in: line), let n = Int(space), (1...9).contains(n) { plan.workspaceApps.append((name, n)) }
        }
        for raw in skhdrc.split(separator: "\n") {
            let line = stripComment(String(raw), marker: "#").trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let keys = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let command = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard command.contains("yabai -m") else { continue }
            if let action = yabaiAction(command), let shortcut = skhdShortcut(keys) {
                plan.bindings.append((action, shortcut))
            } else {
                plan.skipped.append(line)
            }
        }
        return plan
    }

    static func argument(_ name: String, in line: String) -> String? {
        guard let range = line.range(of: name + "=") else { return nil }
        var rest = line[range.upperBound...]
        if rest.first == "\"" {
            rest = rest.dropFirst()
            return rest.firstIndex(of: "\"").map { String(rest[..<$0]) }
        }
        return rest.split(separator: " ").first.map(String.init)
    }

    static func skhdShortcut(_ keys: String) -> Shortcut? {
        // "alt + shift - h"
        let halves = keys.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard halves.count == 2, let code = keyCodes[halves[1].lowercased()],
            let mods = modifiers(halves[0].split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }), !mods.isEmpty
        else { return nil }
        return Shortcut(keyCode: code, modifiers: mods)
    }

    static func yabaiAction(_ command: String) -> Action? {
        let words = command.split(separator: " ").map(String.init)
        guard let m = words.firstIndex(of: "-m"), words.count > m + 3 else {
            return nil
        }
        let domain = words[m + 1], flag = words[m + 2], value = words[m + 3]
        switch (domain, flag, value) {
        case ("window", "--focus", "west"): return .focusLeft
        case ("window", "--focus", "east"): return .focusRight
        case ("window", "--focus", "north"): return .focusUp
        case ("window", "--focus", "south"): return .focusDown
        case ("window", "--swap", "west"), ("window", "--warp", "west"): return .moveLeft
        case ("window", "--swap", "east"), ("window", "--warp", "east"): return .moveRight
        case ("window", "--swap", "north"), ("window", "--warp", "north"): return .moveUp
        case ("window", "--swap", "south"), ("window", "--warp", "south"): return .moveDown
        case ("window", "--toggle", "zoom-fullscreen"): return .toggleFullWidth
        case ("window", "--toggle", "native-fullscreen"): return .toggleNativeFullScreen
        case ("window", "--toggle", "float"): return .toggleFloat
        case ("space", "--balance", _): return .balanceSizes
        case ("space", "--rotate", _): return .rotateSlide
        case ("space", "--focus", _): return Int(value).flatMap { (1...9).contains($0) ? Action(rawValue: "workspace-\($0)") : nil }
        case ("window", "--space", _): return Int(value).flatMap { (1...9).contains($0) ? Action(rawValue: "move-to-workspace-\($0)") : nil }
        case ("window", "--display", _): return .sendToNextDisplay
        case ("display", "--focus", _): return .focusNextDisplay
        default: return nil
        }
    }

    // MARK: Rectangle

    /// Reads Rectangle's preferences (its defaults domain as a dictionary).
    public static func rectangle(_ defaults: [String: Any]) -> ImportPlan {
        var plan = ImportPlan(source: "Rectangle")
        let map: [String: Action] = [
            "leftHalf": .snapLeftHalf, "rightHalf": .snapRightHalf, "topHalf": .snapTopHalf, "bottomHalf": .snapBottomHalf,
            "maximize": .snapMaximize, "center": .snapCenter, "restore": .snapRestore,
            "firstThird": .snapFirstThird, "centerThird": .snapCenterThird, "lastThird": .snapLastThird,
            "firstTwoThirds": .snapFirstTwoThirds, "lastTwoThirds": .snapLastTwoThirds,
            "topLeft": .snapTopLeft, "topRight": .snapTopRight, "bottomLeft": .snapBottomLeft, "bottomRight": .snapBottomRight,
            "nextDisplay": .sendToNextDisplay,
        ]
        for (key, action) in map.sorted(by: { $0.key < $1.key }) {
            guard let entry = defaults[key] as? [String: Any], let code = entry["keyCode"] as? Int,
                let flags = entry["modifierFlags"] as? Int
            else { continue }
            plan.bindings.append((action, Shortcut(keyCode: UInt16(code), modifiers: appKitModifiers(flags))))
        }
        if let gap = defaults["gapSize"] as? Double, gap > 0 { plan.gap = gap }
        if let gap = defaults["gapSize"] as? Int, gap > 0 { plan.gap = Double(gap) }
        return plan
    }

    /// NSEvent modifier flags → Monorail modifiers.
    public static func appKitModifiers(_ flags: Int) -> Modifiers {
        var mods: Modifiers = []
        if flags & (1 << 17) != 0 { mods.insert(.shift) }
        if flags & (1 << 18) != 0 { mods.insert(.control) }
        if flags & (1 << 19) != 0 { mods.insert(.option) }
        if flags & (1 << 20) != 0 { mods.insert(.command) }
        return mods
    }

    // MARK: Helpers

    /// Windows (\r\n) and old Mac (\r) line endings become \n, so files saved anywhere read the same.
    static func normalisedLines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    static func stripComment(_ line: String, marker: Character = "#") -> String {
        var inQuote: Character?
        for (offset, character) in line.enumerated() {
            if character == "\"" || character == "'" { inQuote = inQuote == character ? nil : (inQuote ?? character) }
            if character == marker, inQuote == nil { return String(line.prefix(offset)) }
        }
        return line
    }

    static func unquote(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
    }
}
