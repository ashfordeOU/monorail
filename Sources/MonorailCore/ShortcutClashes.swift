/// Keyboard shortcuts macOS itself uses (System Settings → Keyboard → Keyboard Shortcuts),
/// read from `com.apple.symbolichotkeys`, and which Monorail shortcuts clash with them.
public enum SystemShortcuts {
    public struct Entry: Equatable, Sendable {
        public let id: Int
        public let name: String
        public let shortcut: Shortcut
        public init(id: Int, name: String, shortcut: Shortcut) {
            self.id = id
            self.name = name
            self.shortcut = shortcut
        }
    }

    /// Names of the macOS shortcuts people meet most; others are "a macOS shortcut".
    public static func name(for id: Int) -> String {
        if (118...126).contains(id) { return "Switch to Desktop \(id - 117)" }
        switch id {
        case 7: return "Move focus to the menu bar"
        case 8: return "Move focus to the Dock"
        case 9: return "Move focus to the active or next window"
        case 10: return "Move focus to the window toolbar"
        case 11: return "Move focus to the floating window"
        case 27: return "Move focus to next window"
        case 28: return "Save picture of screen as a file"
        case 29: return "Copy picture of screen"
        case 30: return "Save picture of selected area as a file"
        case 31: return "Copy picture of selected area"
        case 32: return "Mission Control"
        case 33: return "Application windows"
        case 36: return "Show Desktop"
        case 52: return "Turn Dock hiding on or off"
        case 57: return "Move focus to status menus"
        case 60: return "Select the previous input source"
        case 61: return "Select next source in Input menu"
        case 64: return "Show Spotlight search"
        case 65: return "Show Finder search window"
        case 79: return "Move left a space"
        case 81: return "Move right a space"
        case 98: return "Show Help menu"
        case 160: return "Show Launchpad"
        case 162: return "Show Accessibility controls"
        case 163: return "Show Notification Centre"
        case 175: return "Turn Do Not Disturb on or off"
        case 184: return "Screenshot and recording options"
        case 190: return "Quick Note"
        case 222: return "Turn Stage Manager on or off"
        default: return "a macOS shortcut"
        }
    }

    /// Cocoa modifier flags (as macOS stores them) to Monorail's.
    public static func modifiers(fromCocoa flags: Int) -> Modifiers {
        var m: Modifiers = []
        if flags & 0x20000 != 0 { m.insert(.shift) }
        if flags & 0x40000 != 0 { m.insert(.control) }
        if flags & 0x80000 != 0 { m.insert(.option) }
        if flags & 0x100000 != 0 { m.insert(.command) }
        return m
    }

    /// The turned-on shortcuts in an `AppleSymbolicHotKeys` dictionary.
    public static func parse(_ hotkeys: [String: Any]) -> [Entry] {
        var entries: [Entry] = []
        for (key, raw) in hotkeys {
            guard let id = Int(key), let item = raw as? [String: Any] else { continue }
            let enabled = (item["enabled"] as? Bool) ?? ((item["enabled"] as? Int).map { $0 != 0 } ?? false)
            guard enabled, let value = item["value"] as? [String: Any],
                let parameters = value["parameters"] as? [Int], parameters.count >= 3
            else { continue }
            let keyCode = parameters[1]
            guard keyCode >= 0, keyCode < 0xFFFF else { continue }
            let modifiers = Self.modifiers(fromCocoa: parameters[2])
            guard !modifiers.isEmpty else { continue }
            entries.append(Entry(id: id, name: name(for: id), shortcut: Shortcut(keyCode: UInt16(keyCode), modifiers: modifiers)))
        }
        return entries.sorted { $0.id < $1.id }
    }
}

/// A Monorail shortcut that something else on the Mac also uses.
public struct ShortcutClash: Equatable, Sendable, Identifiable {
    public let action: Action
    public let shortcut: Shortcut
    /// What else uses it.
    public let usedBy: String
    /// A free combination to use instead, if there is one.
    public let suggestion: Shortcut?
    public var id: String { "\(action.rawValue)|\(shortcut.keyCode)|\(shortcut.modifiers.rawValue)" }
}

extension Keymap {
    /// Monorail shortcuts that macOS also uses, or that two Monorail actions share.
    public func clashes(with system: [SystemShortcuts.Entry]) -> [ShortcutClash] {
        var bySystem: [Shortcut: String] = [:]
        for entry in system where bySystem[entry.shortcut] == nil { bySystem[entry.shortcut] = entry.name }
        var owners: [Shortcut: Action] = [:]
        var result: [ShortcutClash] = []
        for action in bindings.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            for shortcut in bindings[action] ?? [] {
                if let name = bySystem[shortcut] {
                    result.append(ShortcutClash(action: action, shortcut: shortcut, usedBy: "macOS: \(name)",
                                                suggestion: freeAlternative(for: shortcut, avoiding: system)))
                } else if let other = owners[shortcut], other != action {
                    result.append(ShortcutClash(action: action, shortcut: shortcut, usedBy: "Monorail: \(other.title)",
                                                suggestion: freeAlternative(for: shortcut, avoiding: system)))
                }
                if owners[shortcut] == nil { owners[shortcut] = action }
            }
        }
        return result
    }

    /// The same key with other modifiers, used by neither Monorail nor macOS.
    public func freeAlternative(for shortcut: Shortcut, avoiding system: [SystemShortcuts.Entry]) -> Shortcut? {
        let taken = Set(system.map(\.shortcut)).union(bindings.values.flatMap { $0 })
        var candidates: [Modifiers] = [shortcut.modifiers.union(.shift)]
        for prefix in Keymap.prefixes {
            candidates.append(shortcut.modifiers.contains(.shift) ? prefix.union(.shift) : prefix)
            candidates.append(prefix.union(.shift))
        }
        candidates.append([.control, .option, .command])
        for modifiers in candidates where modifiers != shortcut.modifiers {
            let candidate = Shortcut(keyCode: shortcut.keyCode, modifiers: modifiers)
            if !taken.contains(candidate) { return candidate }
        }
        return nil
    }
}
