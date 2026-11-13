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

    var settings: () -> AppSettings = { AppSettings() }
    var onChange: (SuiteRoles.Role) -> Void = { _ in }
    private var observers: [NSObjectProtocol] = []

    var isResting: Bool { role == .resting }
    func pauses(_ job: SuiteRoles.Job) -> Bool { SuiteRoles.paused(role).contains(job) }

    static func isRunning(_ bundleID: String) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains { !$0.isTerminated }
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
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
        guard now != role else { return }
        role = now
        onChange(now)
    }
}
#endif
