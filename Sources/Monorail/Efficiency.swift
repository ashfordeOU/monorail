#if os(macOS)
import AppKit
import MonorailCore

extension Timer {
    /// A repeating timer that lets macOS group its wake-ups with others (saves energy):
    /// timers of a second or more may fire up to a fifth of their interval late.
    @discardableResult
    static func every(_ interval: TimeInterval, _ block: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: block)
        if interval >= 1 { timer.tolerance = interval * 0.2 }
        return timer
    }
}

/// When Monorail can rest: the screen is asleep, locked or showing the screen saver
/// (pollers skip their work), or energy is short (pollers run half as often).
enum Dormancy {
    static var isDormant = false
    /// On battery with the energy saver on, or in Low Power Mode.
    static var isThrifty = false
    private static var tick = 0

    /// True when a poller should skip this round.
    static func shouldSkip() -> Bool {
        if isDormant { return true }
        guard isThrifty else { return false }
        tick &+= 1
        return tick % 2 == 0
    }
}

/// How much Monorail has cost since launch, for Settings → About.
enum EnergyReport {
    static let launched = Date()

    static var cpuSeconds: Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ t: timeval) -> Double { Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }

    static var summary: String {
        let uptime = max(Date().timeIntervalSince(launched), 1)
        let cpu = cpuSeconds
        let percent = cpu / uptime * 100
        let hours = uptime / 3600
        let memory = residentMegabytes.map { String(format: " · %.0f MB in memory", $0) } ?? ""
        return String(format: "%.1f s of CPU in %.1f h (%.2f%% on average)", cpu, hours, percent) + memory
    }

    static var residentMegabytes: Double? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : nil
    }
}
/// Monorail's own usage, kept on this Mac (Settings → About → Usage): how long it runs,
/// what it costs, and which actions you use. Counts only: no window titles or app names.
final class UsageLog: ObservableObject {
    struct Stored: Codable {
        var firstLaunch = Date()
        var launches = 0
        var runningSeconds: Double = 0
        var cpuSeconds: Double = 0
        var actions: [String: Int] = [:]
        var windowsManaged = 0
        var workspaceSwitches = 0
        var slideSwitches = 0
        var awakeSeconds: Double = 0
        var versions: [String] = []
        var lastVersion = ""
    }

    static var url: URL { SettingsStore.directory.appendingPathComponent("usage.json") }
    @Published private(set) var stored = Stored()
    private let sessionStart = Date()
    private var savedRunning: Double = 0
    private var savedCPU: Double = 0
    private var awakeSince: Date?
    private var timer: Timer?

    init() {
        if let data = try? Data(contentsOf: Self.url), let old = try? JSONDecoder().decode(Stored.self, from: data) {
            stored = old
        }
        savedRunning = stored.runningSeconds
        savedCPU = stored.cpuSeconds
        stored.launches += 1
        let version = Bundle.main.shortVersion
        if stored.lastVersion != version {
            stored.versions.append(version)
            stored.lastVersion = version
        }
        timer = Timer.every(300) { [weak self] _ in self?.save() }
    }

    func action(_ action: Action) {
        stored.actions[action.rawValue, default: 0] += 1
        if action.workspaceNumber != nil || action == .nextWorkspace || action == .previousWorkspace { stored.workspaceSwitches += 1 }
        if [.focusLeft, .focusRight].contains(action) || action.columnNumber != nil { stored.slideSwitches += 1 }
    }

    func windowManaged() { stored.windowsManaged += 1 }

    func awake(_ on: Bool) {
        if on, awakeSince == nil { awakeSince = Date() }
        if !on, let since = awakeSince {
            stored.awakeSeconds += Date().timeIntervalSince(since)
            awakeSince = nil
        }
    }

    /// Totals including this session.
    var totalRunning: Double { savedRunning + Date().timeIntervalSince(sessionStart) }
    var totalCPU: Double { savedCPU + EnergyReport.cpuSeconds }
    var totalAwake: Double { stored.awakeSeconds + (awakeSince.map { Date().timeIntervalSince($0) } ?? 0) }

    var topActions: [(String, Int)] {
        stored.actions.sorted { $0.value > $1.value }.prefix(8).map { (Action(rawValue: $0.key)?.title ?? $0.key, $0.value) }
    }

    func save() {
        stored.runningSeconds = totalRunning
        stored.cpuSeconds = totalCPU
        try? FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(stored) { try? data.write(to: Self.url, options: .atomic) }
        objectWillChange.send()
    }

    func reset() {
        stored = Stored()
        savedRunning = 0
        savedCPU = -EnergyReport.cpuSeconds
        save()
    }

    /// The usage as plain text, to copy into a bug report.
    var text: String {
        func hours(_ s: Double) -> String { String(format: "%.1f h", s / 3600) }
        var lines = [
            "Monorail usage since \(DateFormatter.localizedString(from: stored.firstLaunch, dateStyle: .medium, timeStyle: .none))",
            "Launches: \(stored.launches) · running \(hours(totalRunning)) · CPU \(String(format: "%.0f s", totalCPU)) (\(String(format: "%.2f%%", totalCPU / max(totalRunning, 1) * 100)) on average)",
            "Windows managed: \(stored.windowsManaged) · slide switches: \(stored.slideSwitches) · workspace switches: \(stored.workspaceSwitches)",
            "Stay Awake: \(hours(totalAwake)) · versions: \(stored.versions.joined(separator: ", "))",
            "This session: \(EnergyReport.summary)",
            "Most used:",
        ]
        lines += topActions.map { "  \($0.0): \($0.1)" }
        return lines.joined(separator: "\n")
    }
}
#endif
