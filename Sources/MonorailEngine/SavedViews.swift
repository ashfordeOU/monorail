import MonorailCore

/// A place to come back to: a workspace on a display, how far along it was, and the window in front.
/// (Saved in Monorail's state file as {"workspace", "scroll", "window"}; keep those names.)
public struct SavedView: Codable, Equatable, Sendable {
    public var workspace: Int
    public var scroll: Double
    public var window: WindowID?

    public init(workspace: Int, scroll: Double, window: WindowID?) {
        self.workspace = workspace
        self.scroll = scroll
        self.window = window
    }
}

/// Nine saved views per display (⌃⌥⌘1…9 on the Mac), keyed by the display's name.
public struct SavedViews: Equatable, Sendable {
    public static let slots = 1...9

    public private(set) var byDisplay: [String: [Int: SavedView]]

    public init(_ byDisplay: [String: [Int: SavedView]] = [:]) {
        self.byDisplay = byDisplay.mapValues { $0.filter { Self.slots.contains($0.key) } }.filter { !$0.value.isEmpty }
    }

    /// Saves `view` as number `n` on `display`; false when `n` isn't 1-9.
    @discardableResult
    public mutating func save(_ view: SavedView, as n: Int, on display: String) -> Bool {
        guard Self.slots.contains(n) else { return false }
        byDisplay[display, default: [:]][n] = view
        return true
    }

    public func view(_ n: Int, on display: String) -> SavedView? {
        byDisplay[display]?[n]
    }

    /// The views saved on `display`, by number.
    public func list(on display: String) -> [(number: Int, view: SavedView)] {
        (byDisplay[display] ?? [:]).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
}
