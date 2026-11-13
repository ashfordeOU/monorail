#if os(macOS)
import AppKit
import ServiceManagement
#endif

#if os(macOS)
/// How the app is named wherever people see it.
enum Brand {
    /// The app's own name (its bundle, menus like "Quit Monorail"). The App Store edition is Signalbox.
    #if APPSTORE
    static let name = "Signalbox"
    #else
    static let name = "Monorail"
    #endif
    /// The full window manager, which Signalbox points to.
    static let monorailURL = URL(string: "https://monorail.ashforde.org")!
    /// The maker, with the registered mark.
    static let maker = "by Ashforde®"
    /// The full brand: "Monorail by Ashforde®".
    static let full = "\(name) \(maker)"
}
#endif

#if os(macOS)

/// Monorail's bundle identifiers. Builds up to 1.6 used the old one from the project's first name;
/// the app moves to `org.ashforde.monorail`, and this carries preferences across.
enum BundleIDs {
    static let current = "org.ashforde.monorail"
    static let legacy = "org.ashforde.macslider"
    static let all = [current, legacy]

    /// Reads a preference from this app's domain, then the other identifier's.
    static func bool(_ key: String) -> Bool {
        if UserDefaults.standard.bool(forKey: key) { return true }
        return all.filter { $0 != Bundle.main.bundleIdentifier }.contains { UserDefaults(suiteName: $0)?.bool(forKey: key) == true }
    }

    /// Runs once after the identifier changes: copies the old preferences, closes a copy still
    /// running under the old identifier, and turns launch at login back on if it was on.
    static func migrateIfNeeded() {
        // Remember launch at login under any identifier, so it survives the change.
        let loginKey = "MonorailLaunchAtLogin"
        guard let own = Bundle.main.bundleIdentifier else { return }
        let other = own == current ? legacy : current
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: other) { app.terminate() }
        let defaults = UserDefaults.standard
        let doneKey = "MonorailMigratedFrom." + other
        if !defaults.bool(forKey: doneKey), let old = UserDefaults.standard.persistentDomain(forName: other), !old.isEmpty {
            for (key, value) in old where defaults.object(forKey: key) == nil { defaults.set(value, forKey: key) }
            defaults.set(true, forKey: doneKey)
            if old[loginKey] as? Bool == true, SMAppService.mainApp.status != .enabled {
                try? SMAppService.mainApp.register()
            }
        }
        defaults.set(SMAppService.mainApp.status == .enabled, forKey: loginKey)
    }
}
#endif
