/// The key that turns on slide mode when tapped on its own.
public enum SlideTrigger: String, Codable, CaseIterable, Sendable {
    case off
    case rightOption
    case rightCommand
    case rightControl
    case rightShift

    /// Virtual key code reported in the key's flags-changed event.
    public var keyCode: UInt16? {
        switch self {
        case .off: return nil
        case .rightOption: return 61
        case .rightCommand: return 54
        case .rightControl: return 62
        case .rightShift: return 60
        }
    }

    /// Device-dependent bit set in the event flags while this exact key is held.
    public var deviceFlag: UInt64 {
        switch self {
        case .off: return 0
        case .rightOption: return 0x40
        case .rightCommand: return 0x10
        case .rightControl: return 0x2000
        case .rightShift: return 0x04
        }
    }

    public var title: String {
        switch self {
        case .off: return "Off"
        case .rightOption: return "Right ⌥ Option"
        case .rightCommand: return "Right ⌘ Command"
        case .rightControl: return "Right ⌃ Control"
        case .rightShift: return "Right ⇧ Shift"
        }
    }
}

/// Slide mode: tap one key, then drive Monorail with single keys, no chords.
public enum SlideMode {
    public enum Result: Equatable, Sendable {
        /// Run the action and stay in slide mode.
        case action(Action)
        /// Leave slide mode and swallow the key.
        case exit
        /// Leave slide mode and let the key reach the app.
        case passThrough
    }

    /// How long slide mode waits for the next key before turning itself off.
    public static let idleTimeout = 4.0
    /// A trigger held longer than this is a normal modifier press, not a tap.
    public static let maximumTapDuration = 0.45

    public static func resolve(keyCode: UInt16, modifiers: Modifiers) -> Result {
        let shift = modifiers.contains(.shift)
        // Chords with other modifiers belong to the app.
        guard modifiers.subtracting(.shift).isEmpty else { return .passThrough }

        switch keyCode {
        case KeyCode.left, KeyCode.h: return .action(shift ? .moveLeft : .focusLeft)
        case KeyCode.right, KeyCode.l: return .action(shift ? .moveRight : .focusRight)
        case KeyCode.up, KeyCode.k: return .action(shift ? .moveUp : .focusUp)
        case KeyCode.down, KeyCode.j: return .action(shift ? .moveDown : .focusDown)
        case KeyCode.home: return .action(.focusFirst)
        case KeyCode.end: return .action(.focusLast)
        case KeyCode.r: return .action(shift ? .cycleWidthBackward : .cycleWidth)
        case KeyCode.f: return .action(shift ? .toggleNativeFullScreen : .toggleFullWidth)
        case KeyCode.c: return .action(.center)
        case KeyCode.minus: return .action(.narrower)
        case KeyCode.equal: return .action(.wider)
        case KeyCode.leftBracket: return .action(shift ? .expelLeft : .consumeIntoLeft)
        case KeyCode.rightBracket: return .action(shift ? .expel : .consumeIntoRight)
        case KeyCode.g: return .action(.cycleLayout)
        case KeyCode.period: return .action(.mainLarger)
        case KeyCode.comma: return .action(.mainSmaller)
        case KeyCode.m: return .action(.makeMain)
        case KeyCode.a: return .action(.regroup)
        case KeyCode.o, KeyCode.tab: return .action(.overview)
        case KeyCode.t: return .action(.toggleFloat)
        case KeyCode.w: return .action(.toggleTabbed)
        case KeyCode.p: return .action(shift ? .pinRight : .pinLeft)
        case KeyCode.d: return .action(.sendToNextDisplay)
        case KeyCode.z: return .action(.undo)
        case KeyCode.escape, KeyCode.returnKey, KeyCode.space: return .exit
        default:
            if let index = KeyCode.digits.firstIndex(of: keyCode) {
                return .action(Action.allCases.first { $0.columnNumber == index + 1 }!)
            }
            return .passThrough
        }
    }

    /// The cheat sheet shown while slide mode is on.
    public static let hints: [(keys: String, label: String)] = [
        ("← →", "slide"),
        ("⇧ ← →", "move window"),
        ("↑ ↓", "stack"),
        ("R", "width"),
        ("F", "fill"),
        ("C", "centre"),
        ("G", "layout"),
        ("O", "overview"),
        ("1–9", "jump"),
        ("esc", "done"),
    ]
}

/// Vim mode: a persistent normal mode with counts ("3l"), "gg", "G", "dd" and friends.
public struct VimMachine: Sendable {
    public enum Result: Equatable, Sendable {
        /// Run these actions (a count repeats one).
        case actions([Action])
        /// Waiting for the rest of a command ("3", "g", "d").
        case pending
        /// Leave vim mode.
        case exit
        /// Not for vim mode: let the app have it.
        case passThrough
    }

    public private(set) var count = 0
    private var prefix: UInt16?

    public init() {}

    public var pendingText: String {
        (count > 0 ? String(count) : "") + (prefix == KeyCode.g ? "g" : prefix == KeyCode.d ? "d" : "")
    }

    public mutating func handle(keyCode: UInt16, modifiers: Modifiers) -> Result {
        let shift = modifiers.contains(.shift)
        if modifiers.contains(.command) || modifiers.contains(.option) { return reset(.passThrough) }
        if modifiers == [.control] {
            return keyCode == KeyCode.r ? reset(.actions([.redo])) : reset(.passThrough)
        }
        // Counts.
        if !shift, let digit = KeyCode.digits.firstIndex(of: keyCode) {
            count = min(count * 10 + digit + 1, 99)
            return .pending
        }
        if keyCode == KeyCode.zero, !shift {
            if count > 0 {
                count = min(count * 10, 99)
                return .pending
            }
            return reset(.actions([.focusFirst]))
        }
        // Two-key commands.
        if let first = prefix {
            prefix = nil
            if first == KeyCode.g, keyCode == KeyCode.g, !shift { return reset(.actions([.focusFirst])) }
            if first == KeyCode.d, keyCode == KeyCode.d, !shift { return reset(.actions(repeated(.closeSlide))) }
            return reset(.pending)
        }
        switch keyCode {
        case KeyCode.h, KeyCode.left: return reset(.actions(repeated(shift ? .moveLeft : .focusLeft)))
        case KeyCode.l, KeyCode.right: return reset(.actions(repeated(shift ? .moveRight : .focusRight)))
        case KeyCode.j, KeyCode.down: return reset(.actions(repeated(shift ? .moveDown : .focusDown)))
        case KeyCode.k, KeyCode.up: return reset(.actions(repeated(shift ? .moveUp : .focusUp)))
        case KeyCode.g:
            if shift { return reset(.actions([.focusLast])) }
            prefix = KeyCode.g
            return .pending
        case KeyCode.d:
            prefix = KeyCode.d
            return .pending
        case KeyCode.digits[3] where shift: return reset(.actions([.focusLast]))  // $
        case KeyCode.w: return reset(.actions(repeated(.nextWorkspace)))
        case KeyCode.b: return reset(.actions(repeated(.previousWorkspace)))
        case KeyCode.u: return reset(.actions(repeated(.undo)))
        case KeyCode.slash: return reset(.actions([.commandPalette]))
        case KeyCode.o: return reset(.actions([.overview]))
        case KeyCode.f: return reset(.actions([.toggleFullWidth]))
        case KeyCode.r: return reset(.actions([shift ? .cycleWidthBackward : .cycleWidth]))
        case KeyCode.c: return reset(.actions([.center]))
        case KeyCode.m: return reset(.actions([.makeMain]))
        case KeyCode.t: return reset(.actions([.toggleFloat]))
        case KeyCode.z: return reset(.actions([.zoomTile]))
        case KeyCode.minus: return reset(.actions(repeated(.narrower)))
        case KeyCode.equal: return reset(.actions(repeated(.wider)))
        case KeyCode.i, KeyCode.escape: return reset(.exit)
        default: return reset(.pending)  // normal mode swallows other keys
        }
    }

    private func repeated(_ action: Action) -> [Action] {
        Array(repeating: action, count: max(count, 1))
    }

    private mutating func reset(_ result: Result) -> Result {
        count = 0
        prefix = nil
        return result
    }
}
