#if os(macOS)
import MonorailCore
import SwiftUI

/// Which build this is. The Mac App Store edition (built with `APPSTORE=1 scripts/build-app.sh`)
/// runs in Apple's sandbox, so it leaves out what the sandbox doesn't allow: the self-updater (the
/// App Store updates it), the Caps Lock key, the local API and MCP server, JavaScript scripts,
/// the phone remote, and saving browser tabs in snapshots.
enum Edition {
    #if APPSTORE
    static let isAppStore = true
    #else
    static let isAppStore = false
    #endif

    static var name: String { isAppStore ? "App Store edition" : "Direct download" }

    /// Turns off what this edition can't do, whatever the settings file says.
    static func restrict(_ settings: AppSettings) -> AppSettings {
        guard isAppStore else { return settings }
        var s = settings
        s.capsLockKey = false
        s.localAPI = false
        s.scripts = false
        s.webRemote = false
        s.restoreBrowserTabs = false
        s.checkForUpdates = false
        s.installUpdatesAutomatically = false
        s.betaUpdates = false
        return s
    }
}

extension View {
    /// Leaves a control out of the App Store edition.
    @ViewBuilder func hiddenInAppStore() -> some View {
        if Edition.isAppStore { EmptyView() } else { self }
    }
}
#endif
