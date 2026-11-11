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

/// How long since a person last touched the keyboard, mouse or trackpad. Monorail's own
/// pointer nudges (Keep me Available) reset the system's idle time, so they're left out here:
/// otherwise Monorail would think someone is always at the Mac and never rest.
enum UserIdle {
    /// When Monorail last nudged the pointer, and when the person last did something before that.
    private static var lastNudge: CFTimeInterval = 0
    private static var lastRealInput: CFTimeInterval = 0

    private static func systemIdle() -> Double {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// Call just before posting a pointer nudge.
    static func noteNudge() {
        let now = CACurrentMediaTime()
        let lastInput = now - systemIdle()
        // If the newest input was itself a nudge, the person's last input is still the one before.
        if lastNudge == 0 || abs(lastInput - lastNudge) > 1.5 { lastRealInput = lastInput }
        lastNudge = now
    }

    static var seconds: Double {
        let idle = systemIdle()
        let now = CACurrentMediaTime()
        if lastNudge > 0, abs((now - idle) - lastNudge) <= 1.5 { return now - lastRealInput }
        return idle
    }

    /// Nobody has touched the Mac for a minute.
    static var isAway: Bool { seconds >= 60 }
}

/// A poller that runs every round while someone is at the Mac, and one round in `every`
/// while nobody is (or while the Mac is asleep, never).
struct RestingPoller {
    let every: Int
    private var tick = 0
    init(every: Int) { self.every = max(every, 1) }

    mutating func shouldSkip() -> Bool {
        if Dormancy.shouldSkip() { return true }
        tick &+= 1
        return UserIdle.isAway && tick % every != 0
    }
}

/// How much Monorail has cost since launch, for Settings → About.
enum EnergyReport {
    /// When this Monorail process started (from the system, not when this was first read).
    static let launched: Date = {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else { return Date() }
        let start = info.kp_proc.p_un.__p_starttime
        let date = Date(timeIntervalSince1970: Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000)
        return date.timeIntervalSince1970 > 0 ? date : Date()
    }()

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
/// A 30-second measurement of Monorail's own CPU, wake-ups and energy, from macOS's
/// per-process counters (the same ones Activity Monitor uses). Settings → About → Check Energy.
enum EnergyCheck {
    struct Sample {
        var cpu: Double       // seconds
        var wakeups: UInt64
        var energy: UInt64    // nanojoules
        var at: Date
    }

    static func sample() -> Sample? {
        var info = rusage_info_v4()
        let ok = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0) }
        }
        guard ok == 0 else { return nil }
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let ticks = Double(info.ri_user_time + info.ri_system_time)
        let seconds = ticks * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
        return Sample(cpu: seconds, wakeups: info.ri_pkg_idle_wkups + info.ri_interrupt_wkups,
                      energy: info.ri_billed_energy, at: Date())
    }

    /// Measures for `seconds`, then reports CPU %, wake-ups a second and average power.
    static func run(seconds: Double = 30, completion: @escaping (String) -> Void) {
        guard let start = sample() else { return completion("Couldn’t read the energy counters") }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            guard let end = sample() else { return completion("Couldn’t read the energy counters") }
            let elapsed = max(end.at.timeIntervalSince(start.at), 1)
            let cpu = (end.cpu - start.cpu) / elapsed * 100
            let wakeups = Double(end.wakeups &- start.wakeups) / elapsed
            let milliwatts = Double(end.energy &- start.energy) / elapsed / 1_000_000
            let verdict = cpu < 0.5 && wakeups < 3 ? "Excellent" : cpu < 2 && wakeups < 10 ? "Good" : "Higher than it should be"
            completion(String(format: "%@: %.2f%% CPU · %.1f wake-ups a second · %.1f mW over %.0f s", verdict, cpu, wakeups, milliwatts, elapsed))
        }
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
    }

    private var lastPlace: (workspace: Int, column: Int)?

    /// Counts moves however they happen (keys, slider, swipes, clicks, the overview).
    func noteFocus(workspace: Int, column: Int) {
        defer { lastPlace = (workspace, column) }
        guard let last = lastPlace else { return }
        if last.workspace != workspace { stored.workspaceSwitches += 1 }
        else if last.column != column { stored.slideSwitches += 1 }
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
