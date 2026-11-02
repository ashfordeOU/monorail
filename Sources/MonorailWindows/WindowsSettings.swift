#if os(Windows)
import Foundation

/// Where Monorail for Windows keeps its settings: %APPDATA%\Monorail\settings.json, the same
/// format as the Mac app's (so a file copied from a Mac works).
enum WindowsSettings {
    static var url: URL {
        let base = ProcessInfo.processInfo.environment["APPDATA"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("AppData\\Roaming")
        return base.appendingPathComponent("Monorail").appendingPathComponent("settings.json")
    }

    static func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
#endif
