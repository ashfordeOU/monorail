import Foundation
import MonorailCore

/// Settings for the shared engine, read from the same `settings.json` the Mac app writes
/// (docs/PLATFORMS.md: one format on every OS). Unknown and Mac-only keys are kept in the file
/// and ignored here; missing keys take the Mac defaults.
public struct SharedSettings: Equatable {
    public var settings: AppSettings

    public init(_ settings: AppSettings = AppSettings()) { self.settings = settings }

    /// Reads settings from JSON; nil when it isn't valid JSON for the settings.
    public init?(json data: Data) {
        guard let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else { return nil }
        settings = decoded
    }

    /// Reads the file, or the defaults when it's missing or unreadable (the file is left as is).
    public static func load(from url: URL) -> SharedSettings {
        guard let data = try? Data(contentsOf: url), let read = SharedSettings(json: data) else { return SharedSettings() }
        return read
    }

    /// Writes the defaults when there's no file yet, so people have something to edit.
    @discardableResult
    public static func writeDefaultsIfMissing(to url: URL) -> Bool {
        guard !FileManager.default.fileExists(atPath: url.path) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(AppSettings()) else { return false }
        return (try? data.write(to: url)) != nil
    }

    public var layout: LayoutConfig { settings.layout }

    /// Whether app rules keep this window off the strip. A rule matches the app ID (bundle ID on
    /// macOS, executable path or name on Windows) or the app's name, ignoring case; a title rule
    /// matches only windows whose title contains its text.
    public func floats(_ info: WindowInfo) -> Bool {
        settings.appRules.contains { rule in
            guard rule.float, matchesApp(rule, info) else { return false }
            guard rule.isTitleRule, let text = rule.titleContains else { return true }
            return info.title.lowercased().contains(text.trimmingCharacters(in: .whitespaces).lowercased())
        }
    }

    private func matchesApp(_ rule: AppRule, _ info: WindowInfo) -> Bool {
        let id = rule.bundleID.lowercased()
        guard !id.isEmpty else { return false }
        let app = info.appID.lowercased(), name = info.appName.lowercased()
        if app == id || name == id || name == rule.name.lowercased() { return true }
        // Windows: a rule written as "notepad.exe" or "notepad" matches C:\…\notepad.exe.
        let file = app.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? app
        return file == id || file == id + ".exe" || (file.hasSuffix(".exe") && String(file.dropLast(4)) == id)
    }
}
