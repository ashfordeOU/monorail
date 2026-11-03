import Foundation

/// The key that opens the hold-and-release window switcher: hold it, press Tab to step through
/// every window, let go to switch. Off by default, because ⌘Tab replaces the macOS app switcher.
public enum SwitcherShortcut: String, Codable, CaseIterable, Sendable {
    case off
    /// ⌘Tab, in place of the macOS app switcher.
    case commandTab
    /// ⌥Tab, leaving ⌘Tab to macOS.
    case optionTab

    /// The modifier held with Tab (nil when off).
    public var modifier: Modifiers? {
        switch self {
        case .off: return nil
        case .commandTab: return .command
        case .optionTab: return .option
        }
    }

    public var title: String {
        switch self {
        case .off: return "Off"
        case .commandTab: return "⌘Tab (replaces the app switcher)"
        case .optionTab: return "⌥Tab"
        }
    }
}

/// What the switcher should do after a key event.
public enum HoldSwitcherEvent: Equatable, Sendable {
    /// Open it, with the next window (or, backwards, the last one) chosen.
    case open(backward: Bool)
    /// Move the choice by this many places (wrapping round).
    case step(Int)
    /// Up or down a row in the grid.
    case row(Int)
    /// Switch to the chosen window and close.
    case commit
    /// Close without switching.
    case cancel
    /// Act on the chosen window and keep the switcher open.
    case closeWindow, minimizeWindow, quitApp
}

/// The hold-and-release switcher's keys: hold the modifier, press Tab (⇧Tab goes back), arrows
/// move, W closes the chosen window, M minimises it, Q quits its app, Esc cancels, and letting go
/// of the modifier switches. Kept free of AppKit so it can be tested anywhere.
public struct HoldSwitcherKeys: Sendable {
    public var shortcut: SwitcherShortcut
    public private(set) var isOpen = false

    public init(shortcut: SwitcherShortcut = .off) {
        self.shortcut = shortcut
    }

    /// A key press. Returns nil when the key isn't the switcher's (it should pass through).
    public mutating func keyDown(_ keyCode: UInt16, modifiers: Modifiers) -> HoldSwitcherEvent? {
        guard let held = shortcut.modifier else { return nil }
        var others = modifiers
        others.remove(.shift)
        if !isOpen {
            guard keyCode == KeyCode.tab, others == held else { return nil }
            isOpen = true
            return .open(backward: modifiers.contains(.shift))
        }
        switch keyCode {
        case KeyCode.tab: return .step(modifiers.contains(.shift) ? -1 : 1)
        case KeyCode.right: return .step(1)
        case KeyCode.left: return .step(-1)
        case KeyCode.down: return .row(1)
        case KeyCode.up: return .row(-1)
        case KeyCode.returnKey, KeyCode.space:
            isOpen = false
            return .commit
        case KeyCode.escape:
            isOpen = false
            return .cancel
        case KeyCode.w: return .closeWindow
        case KeyCode.m: return .minimizeWindow
        case KeyCode.q: return .quitApp
        default:
            // Any other key is swallowed while the switcher is up (so it never types into an app).
            return .step(0)
        }
    }

    /// The modifier keys changed. Letting go of the held modifier switches.
    public mutating func flagsChanged(_ modifiers: Modifiers) -> HoldSwitcherEvent? {
        guard isOpen, let held = shortcut.modifier, !modifiers.contains(held) else { return nil }
        isOpen = false
        return .commit
    }

    /// Closed from elsewhere (a click, or the panel went away).
    public mutating func reset() { isOpen = false }
}

/// Ordering and moving through the switcher's windows.
public enum HoldSwitcher {
    /// Windows most recently used first; windows never focused keep their order after them.
    public static func order(_ ids: [WindowID], recentFirst: [WindowID]) -> [WindowID] {
        let present = Set(ids)
        var seen = Set<WindowID>()
        var result: [WindowID] = []
        for id in recentFirst where present.contains(id) && seen.insert(id).inserted { result.append(id) }
        for id in ids where seen.insert(id).inserted { result.append(id) }
        return result
    }

    /// The window chosen when the switcher opens: the previous one (like ⌘Tab), or going
    /// backwards the least recent one.
    public static func initialSelection(count: Int, backward: Bool) -> Int {
        guard count > 1 else { return 0 }
        return backward ? count - 1 : 1
    }

    /// `selection` moved by `delta`, wrapping round.
    public static func step(_ selection: Int, by delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((selection + delta) % count + count) % count
    }

    /// `selection` moved a row up or down a grid of `columns`, staying put at the top or bottom.
    public static func row(_ selection: Int, by delta: Int, count: Int, columns: Int) -> Int {
        guard count > 0, columns > 0 else { return 0 }
        let target = selection + delta * columns
        return target >= 0 && target < count ? target : selection
    }

    /// How many thumbnails go in a row: a single row for a few windows, at most `maximum`.
    public static func columns(for count: Int, maximum: Int = 6) -> Int {
        guard count > 0 else { return 1 }
        if count <= maximum { return count }
        let rows = Int((Double(count) / Double(maximum)).rounded(.up))
        return Int((Double(count) / Double(rows)).rounded(.up))
    }
}
