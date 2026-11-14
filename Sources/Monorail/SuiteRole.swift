#if os(macOS)
import AppKit
import MonorailCore

/// This app's role among Ashforde's apps right now (SuiteRoles decides). Signalbox watches for
/// Monorail starting and quitting; Monorail is always primary.
final class SuiteRole: ObservableObject {
    static let shared = SuiteRole()
    static let monorailID = "org.ashforde.monorail"
    static let stationID = "org.ashforde.monorail.appstore"

    @Published private(set) var role: SuiteRoles.Role = .primary
    /// Monorail: Signalbox is installed and running alongside, resting.
    @Published private(set) var stationAlongside = false

    /// Keeper, while it runs and has said hello (its owns, its choices, its live items).
    @Published private(set) var keeper: PeerHello?
    /// The areas Keeper looks after right now, so Monorail's own rest (SuiteRules).
    @Published private(set) var resting: Set<SuiteArea> = []
    /// Areas both apps have on where nobody has chosen yet (the island): ask the person.
    @Published private(set) var asking: Set<SuiteArea> = []

    var settings: () -> AppSettings = { AppSettings() }
    var onChange: (SuiteRoles.Role) -> Void = { _ in }
    /// The areas resting changed: `fresh` are the ones that just started resting.
    var onAreasChange: (_ fresh: Set<SuiteArea>) -> Void = { _ in }
    private var observers: [NSObjectProtocol] = []

    var isResting: Bool { role == .resting }
    func pauses(_ job: SuiteRoles.Job) -> Bool { SuiteRoles.paused(role).contains(job) }
    /// Keeper looks after this area now.
    func rests(_ area: SuiteArea) -> Bool { resting.contains(area) }
    /// A notification of this kind stays quiet: Signalbox at rest, or Keeper sends these.
    func quiet(_ area: SuiteArea) -> Bool { pauses(.notifications) || rests(area) }

    /// The areas switched on here, as announced in the hello. Signalbox at rest announces none, so
    /// Keeper never steps back for an app that is itself stepping back.
    static func areasOn(_ s: AppSettings, role: SuiteRoles.Role) -> Set<SuiteArea> {
        guard role == .primary else { return [] }
        var on: Set<SuiteArea> = [.alertBattery, .launcher, .storageCleanup, .displayBrightness, .alertDisk, .alertMeeting]
        if !Edition.isAppStore { on.insert(.snapWindows) }
        if s.clipboardHistory { on.insert(.clipboard) }
        if s.eveningOn || s.eveningSchedule != .manual { on.insert(.eveningColours) }
        if s.eyeBreaks || s.postureBreaks || s.waterReminders { on.insert(.breaks) }
        if s.agentAlerts { on.insert(.alertAgent) }
        if s.notchLive { on.insert(.island) }
        if s.meetingNotesOffer { on.insert(.meetingNotes) }
        if !s.menuBarReadings.isEmpty { on.insert(.menuBarReadings) }
        if s.chargeLimit < 100 { on.insert(.chargeLimit) }
        if s.systemAlerts { on.insert(.alertSystem) }
        if s.aiNotifyResets || s.aiNotifyContext || s.aiNotifyIncidents { on.insert(.alertAI) }
        return on
    }

    /// The person's choice for an area made here, if any.
    static func myChoice(_ area: SuiteArea, _ s: AppSettings) -> SuiteRules.Choice? {
        guard let raw = s.suitePrefer[area.rawValue], let app = SuiteRules.App(rawValue: raw) else { return nil }
        return SuiteRules.Choice(app: app, at: s.suitePreferAt[area.rawValue] ?? 0)
    }

    /// The newest choice for an area, from either app.
    func choice(_ area: SuiteArea) -> SuiteRules.Choice? {
        SuiteRules.latest(Self.myChoice(area, settings()), keeper?.choice(for: area))
    }

    /// Keeper said hello (or nil: it quit).
    func setKeeper(_ hello: PeerHello?) {
        if hello != keeper { keeper = hello }
        evaluateAreas()
    }

    func evaluateAreas() {
        let s = settings()
        let on = Self.areasOn(s, role: role)
        var rest: Set<SuiteArea> = []
        var ask: Set<SuiteArea> = []
        for area in SuiteArea.allCases {
            switch SuiteRules.verdict(area, me: .monorail, mineOn: on.contains(area), otherOwns: keeper?.areas, choice: choice(area)) {
            case .rest: rest.insert(area)
            case .ask: ask.insert(area)
            case .lead: break
            }
        }
        if ask != asking { asking = ask }
        guard rest != resting else { return }
        let fresh = rest.subtracting(resting)
        resting = rest
        onAreasChange(fresh)
    }

    static func isRunning(_ bundleID: String) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains { !$0.isTerminated }
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                if Companions.isKeeper(id), note.name == NSWorkspace.didTerminateApplicationNotification {
                    self?.setKeeper(nil)
                    return
                }
                guard id == Self.monorailID || id == Self.stationID else { return }
                // A moment later, so a quitting app has really gone.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.evaluate() }
            })
        }
        evaluate()
    }

    func evaluate() {
        stationAlongside = !Edition.isAppStore && Self.isRunning(Self.stationID)
        let now = SuiteRoles.role(isStation: Edition.isAppStore, monorailRunning: Self.isRunning(Self.monorailID),
                                  stepsBack: settings().stationStepsBack)
        guard now != role else { evaluateAreas(); return }
        role = now
        onChange(now)
        evaluateAreas()
    }
}
#endif
