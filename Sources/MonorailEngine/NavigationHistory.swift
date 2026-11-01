/// Back and forward through places you've been, like a browser: going somewhere new clears
/// forward, going back remembers where you were so forward can return. Used for views
/// (⌃⌥⌘[ and ⌃⌥⌘]); `Place` is whatever a platform calls a place on screen.
public struct NavigationHistory<Place> {
    public static var defaultLimit: Int { 50 }

    public private(set) var past: [Place] = []
    public private(set) var future: [Place] = []
    public let limit: Int

    public init(limit: Int = NavigationHistory.defaultLimit) {
        self.limit = max(limit, 1)
    }

    public var canGoBack: Bool { !past.isEmpty }
    public var canGoForward: Bool { !future.isEmpty }

    /// You're leaving `place` for somewhere new (not by back or forward).
    public mutating func leave(_ place: Place) {
        past.append(place)
        if past.count > limit { past.removeFirst(past.count - limit) }
        future.removeAll()
    }

    /// Where back goes from `current`, remembering `current` for forward; nil when there's nothing.
    public mutating func back(from current: Place) -> Place? {
        guard let previous = past.popLast() else { return nil }
        future.append(current)
        return previous
    }

    /// Where forward goes from `current`, remembering `current` for back; nil when there's nothing.
    public mutating func forward(from current: Place) -> Place? {
        guard let next = future.popLast() else { return nil }
        past.append(current)
        if past.count > limit { past.removeFirst(past.count - limit) }
        return next
    }
}
