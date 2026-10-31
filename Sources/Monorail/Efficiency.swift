#if os(macOS)
import AppKit

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
#endif
