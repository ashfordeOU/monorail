#if os(macOS)
import AppKit
import MonorailCore

/// Anonymous usage counts, at most once a day, so Ashforde knows how many Macs run Monorail,
/// which kinds of Mac, and which features people use. On by default; turn off in
/// Settings → Devices & Sharing → Trust, or `defaults write org.ashforde.monorail MonorailNoUsageCounts -bool YES`.
///
/// Never sent: window titles, app names, file names, typed or spoken text, screen contents, the
/// serial number or the Apple ID. The install ID is random and stays on this Mac (it isn't synced).
final class Telemetry {
    /// Where the endpoint is published, so the server can move without a new release.
    static let endpointFile = "https://raw.githubusercontent.com/ashfordeOU/monorail/main/server/endpoint.txt"
    private static let lastSentKey = "MonorailUsageCountsLastSent"
    private static let optOutKey = "MonorailNoUsageCounts"

    var settings: () -> AppSettings = { AppSettings() }
    var usage: () -> UsageLog.Stored? = { nil }
    private var timer: Timer?

    static var idURL: URL { SettingsStore.directory.appendingPathComponent("install-id") }

    /// A random ID for this install, made the first time it's needed.
    static var installID: String {
        if let id = try? String(contentsOf: idURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
            !id.isEmpty
        {
            return id
        }
        let id = UUID().uuidString.lowercased()
        try? FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
        try? id.write(to: idURL, atomically: true, encoding: .utf8)
        return id
    }

    var isAllowed: Bool {
        let s = settings()
        return s.shareUsageStats && s.usageNoticeShown && !BundleIDs.bool(Self.optOutKey)
    }

    func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self] in self?.sendIfDue() }
        timer = Timer.every(6 * 3600) { [weak self] _ in self?.sendIfDue() }
    }

    func sendIfDue() {
        guard isAllowed else { return }
        let last = UserDefaults.standard.double(forKey: Self.lastSentKey)
        guard Date().timeIntervalSince1970 - last > 20 * 3600 else { return }
        let body = payload()
        Self.endpoint { url in
            guard let url, let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = data
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Monorail/\(Bundle.main.shortVersion)", forHTTPHeaderField: "User-Agent")
            URLSession.shared.dataTask(with: request) { _, response, _ in
                guard (response as? HTTPURLResponse)?.statusCode ?? 0 < 300 else { return }
                DispatchQueue.main.async {
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastSentKey)
                }
            }.resume()
        }
    }

    /// Reads the endpoint from the repository (cached for a week); nothing is sent until it exists.
    private static func endpoint(_ done: @escaping (URL?) -> Void) {
        let defaults = UserDefaults.standard
        if let cached = defaults.string(forKey: "MonorailUsageEndpoint"),
            Date().timeIntervalSince1970 - defaults.double(forKey: "MonorailUsageEndpointAt") < 7 * 86400
        {
            return done(URL(string: cached).flatMap { $0.scheme == "https" ? $0 : nil })
        }
        guard let file = URL(string: endpointFile) else { return done(nil) }
        URLSession.shared.dataTask(with: file) { data, response, _ in
            var text = ""
            if (response as? HTTPURLResponse)?.statusCode == 200, let data {
                text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            DispatchQueue.main.async {
                defaults.set(text, forKey: "MonorailUsageEndpoint")
                defaults.set(Date().timeIntervalSince1970, forKey: "MonorailUsageEndpointAt")
                done(URL(string: text).flatMap { $0.scheme == "https" ? $0 : nil })
            }
        }.resume()
    }

    /// Exactly what gets sent. Shown to people under “What's sent…”.
    func payload() -> [String: Any] {
        let info = ProcessInfo.processInfo
        let os = info.operatingSystemVersion
        let memory = Double(info.physicalMemory) / 1_073_741_824
        let s = settings()
        var body: [String: Any] = [
            "id": Self.installID,
            "version": Bundle.main.shortVersion,
            "macos": "\(os.majorVersion).\(os.minorVersion)",
            "model": Self.sysctl("hw.model") ?? "unknown",
            "chip": Self.chip,
            "arch": Self.isAppleSilicon ? "arm64" : "x86_64",
            "cores": info.activeProcessorCount,
            "memory_gb": Self.bucket(memory, [8, 16, 24, 32, 48, 64, 96, 128]),
            "displays": NSScreen.screens.count,
            "language": String((Locale.preferredLanguages.first ?? "en").prefix(2)),
            "source": Self.installSource,
            "channel": s.betaUpdates ? "beta" : "stable",
            "features": Self.changedFeatures(s),
        ]
        if let usage = usage() {
            body["launches"] = usage.launches
            body["days_installed"] = max(0, Int(Date().timeIntervalSince(usage.firstLaunch) / 86400))
            body["windows_managed"] = Self.bucket(Double(usage.windowsManaged), [0, 10, 100, 1000, 10_000, 100_000])
            body["actions"] = Dictionary(uniqueKeysWithValues: usage.actions.sorted { $0.value > $1.value }.prefix(25).map { ($0.key, $0.value) })
        }
        return body
    }

    var payloadText: String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload(), options: [.prettyPrinted, .sortedKeys]) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Names of on/off settings that differ from the defaults. Names only, never other values.
    static func changedFeatures(_ settings: AppSettings) -> [String] {
        let defaults = Dictionary(uniqueKeysWithValues: Mirror(reflecting: AppSettings()).children.compactMap { child -> (String, Bool)? in
            guard let label = child.label, let value = child.value as? Bool else { return nil }
            return (label, value)
        })
        let skip: Set<String> = ["hasCompletedOnboarding", "usageNoticeShown", "shareUsageStats", "compactMenuBarApplied"]
        return Mirror(reflecting: settings).children.compactMap { child in
            guard let label = child.label, !skip.contains(label), let value = child.value as? Bool,
                let original = defaults[label], value != original
            else { return nil }
            return value ? label : "-" + label
        }.sorted()
    }

    static func bucket(_ value: Double, _ edges: [Double]) -> String {
        for edge in edges where value <= edge { return "≤\(Int(edge))" }
        return ">\(Int(edges.last ?? 0))"
    }

    static func sysctl(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        return String(cString: bytes)
    }

    static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }

    /// "Apple M2 Pro", or "Intel" for Intel Macs (their exact CPU isn't needed).
    static var chip: String {
        let brand = sysctl("machdep.cpu.brand_string") ?? ""
        return brand.hasPrefix("Apple") ? brand : "Intel"
    }

    static var installSource: String {
        let path = Bundle.main.bundlePath
        if path.contains("/dist/") || path.contains("/.build/") { return "source" }
        for root in ["/opt/homebrew/Caskroom/monorail", "/usr/local/Caskroom/monorail"]
        where FileManager.default.fileExists(atPath: root) {
            return "homebrew"
        }
        return path.hasPrefix("/Applications") ? "download" : "other"
    }

    /// The one-time notice. Returns after the person answers.
    static func showNotice(store: SettingsStore, showSent: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Help improve Monorail"
        alert.informativeText = """
            Once a day, Monorail sends anonymous counts: its version, your macOS version and Mac model, \
            the number of displays, and which features are on. It never sends window titles, app names, \
            files or anything you type, and there's no account.

            You can change this any time in Settings → Devices & Sharing → Trust.
            """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Turn Off")
        alert.addButton(withTitle: "What's Sent…")
        NSApp.activate(ignoringOtherApps: true)
        let answer = alert.runModal()
        var settings = store.settings
        settings.usageNoticeShown = true
        if answer == .alertSecondButtonReturn { settings.shareUsageStats = false }
        store.settings = settings
        if answer == .alertThirdButtonReturn { showSent() }
    }
}
#endif
