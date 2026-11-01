import MonorailCore

/// The windows you've been on, in the order you focused them (most recent last), without repeats.
/// Used for "back to the last window", quick launch, and picking where focus goes when a window closes.
public struct FocusHistory: Equatable, Sendable {
    public static let defaultLimit = 30

    public private(set) var ids: [WindowID] = []
    public let limit: Int

    public init(limit: Int = FocusHistory.defaultLimit) {
        self.limit = max(limit, 1)
    }

    /// The window focused most recently.
    public var last: WindowID? { ids.last }

    /// The window focused before the most recent one.
    public var previous: WindowID? { ids.dropLast().last }

    /// Most recent first.
    public var recentFirst: [WindowID] { ids.reversed() }

    /// Notes that `id` was focused. Returns false when it already was the most recent.
    @discardableResult
    public mutating func record(_ id: WindowID) -> Bool {
        guard ids.last != id else { return false }
        ids.removeAll { $0 == id }
        ids.append(id)
        if ids.count > limit { ids.removeFirst(ids.count - limit) }
        return true
    }

    /// Forgets a window (it closed).
    public mutating func remove(_ id: WindowID) {
        ids.removeAll { $0 == id }
    }

    /// The most recent window, other than `current`, that `isAlive` still accepts.
    public func back(from current: WindowID?, isAlive: (WindowID) -> Bool) -> WindowID? {
        recentFirst.first { $0 != current && isAlive($0) }
    }

    /// The most recent window matching `predicate`.
    public func mostRecent(where predicate: (WindowID) -> Bool) -> WindowID? {
        recentFirst.first(where: predicate)
    }
}
