import MonorailCore

/// Where windows go back to: the place a hidden, minimised or closed window had, and each app's
/// most recent place, for when the app opens a window again (a Dock click after closing it, or a
/// relaunch). `Place` is whatever a platform calls a spot on a strip.
public struct ReturnMemory<Place> {
    private var byWindow: [WindowID: Place] = [:]
    private var byApp: [String: Place] = [:]

    public init() {}

    /// `window` (of `app`) is leaving `place`.
    public mutating func remember(_ window: WindowID, app: String, at place: Place) {
        byWindow[window] = place
        byApp[app] = place
    }

    /// Where a returning window belongs, used up once found. A window's own place comes first; the
    /// app's place only when none of the app's windows are there already (`appIsAt`), so a
    /// genuinely new second window opens normally.
    public mutating func recall(_ window: WindowID, app: String, appIsAt: (Place) -> Bool) -> Place? {
        if let place = byWindow.removeValue(forKey: window) { return place }
        guard let place = byApp[app], !appIsAt(place) else { return nil }
        byApp[app] = nil
        return place
    }

    public func remembers(_ window: WindowID) -> Bool { byWindow[window] != nil }

    public mutating func forget(_ window: WindowID) { byWindow[window] = nil }

    public mutating func forgetAll() {
        byWindow.removeAll()
        byApp.removeAll()
    }
}
