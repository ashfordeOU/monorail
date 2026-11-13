import Foundation

/// Who does what when more than one of Ashforde's apps is on the Mac. One app alone does all it's
/// designed for. With Monorail running, Station steps back: Monorail is the superset, so it leads,
/// and Station stops the jobs that would clash (two apps writing the screen's colours) or double up
/// (two clipboard watchers, two "unplug now" notifications). When Monorail quits, Station takes over
/// again by itself. (Keeper's own handover for Stay Awake is separate: see PeerHello.)
public enum SuiteRoles {
    public enum Role: String, Sendable {
        /// Does everything it's designed for.
        case primary
        /// Another app leads; this one rests (and may hide its menu bar icon).
        case resting
    }

    /// The jobs a resting app pauses.
    public enum Job: String, CaseIterable, Sendable {
        case eveningColours, clipboardWatch, notifications, eyeBreaks, callAssertions, stayAwake
    }

    public static func role(isStation: Bool, monorailRunning: Bool, stepsBack: Bool = true) -> Role {
        isStation && monorailRunning && stepsBack ? .resting : .primary
    }

    /// What a resting app pauses: everything that would clash or double up. Glances (battery,
    /// system, calendar) stay readable in its panel, since reading twice harms nothing.
    public static func paused(_ role: Role) -> Set<Job> {
        role == .resting ? Set(Job.allCases) : []
    }

    /// A Stay Awake session handed from Station to Monorail as it steps back: the minutes left
    /// (rounded up), or nil for "until turned off".
    public static func handoffMinutes(endsAt: Date?, now: Date = Date()) -> Int? {
        guard let endsAt else { return nil }
        return max(Int((endsAt.timeIntervalSince(now) / 60).rounded(.up)), 1)
    }
}
