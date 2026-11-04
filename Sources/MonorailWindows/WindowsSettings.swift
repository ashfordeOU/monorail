#if os(Windows)
import Foundation

/// Where Monorail for Windows keeps its settings: %APPDATA%\Monorail\settings.json, the same
/// format as the Mac app's (so a file copied from a Mac works). Always per user, never next to
/// Monorail.exe, in Program Files or in HKLM, so the portable zip runs from any folder (Downloads,
/// read-only) on a PC where the user isn't an administrator.
enum WindowsSettings {
    static var url: URL {
        let environment = ProcessInfo.processInfo.environment
        let base = (environment["APPDATA"] ?? environment["LOCALAPPDATA"]).flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("AppData\\Roaming")
        return base.appendingPathComponent("Monorail").appendingPathComponent("settings.json")
    }

    static func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
#endif
