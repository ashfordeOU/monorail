#if os(macOS)
import AppKit
import Darwin
import IOKit
import IOKit.ps
import MonorailCore

/// Which apps are using the most battery, measured once a minute and only while on battery.
/// Counts each app's own process and the helper processes it starts, from the processor time and
/// energy macOS bills to them. Shown as ⚡ on windows, in the popover, and used to hide (never quit)
/// hungry apps left alone for an hour when "park on battery" is on.
final class PowerWatch: ObservableObject {
    static let shared = PowerWatch()

    @Published private(set) var onBattery = false
    @Published private(set) var batteryPercent: Int?
    /// Every measured app, biggest first (only while on battery).
    @Published private(set) var uses: [PowerUse] = []
    /// Apps Monorail hid to save battery, to show again.
    @Published private(set) var parked: [String] = []

    var isEnabled = false {
        didSet { if oldValue != isEnabled { restart() } }
    }
    var parkOnBattery = false
    var onNotice: (String) -> Void = { _ in }
    var onChange: () -> Void = {}

    private var timer: Timer?
    private var previous: [String: PowerReading] = [:]
    private var previousAt: Date?
    private var lastActive: [String: Date] = [:]
    private var watchingSince = Date()
    private var activationObserver: NSObjectProtocol?
    private let batteryWattHours = PowerWatch.readBatteryWattHours()
    private let ticksToSeconds: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }()

    /// Apps over the line right now, hungriest first.
    var hungry: [PowerUse] { onBattery ? PowerEstimate.hungry(uses) : [] }

    /// "About 6% of the battery an hour" for a hungry app's windows, or nil.
    func note(for bundleID: String?) -> String? {
        guard isEnabled, onBattery, let bundleID, let use = uses.first(where: { $0.bundleID == bundleID }), use.isHungry
        else { return nil }
        return use.summary
    }

    func start() {
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            if let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier {
                self?.lastActive[id] = Date()
            }
        }
    }

    /// A fresh reading when the popover opens, if the last one is more than 15 seconds old.
    func refreshIfStale() {
        guard isEnabled else { return }
        if let at = previousAt, Date().timeIntervalSince(at) < 15 { return }
        sample()
    }

    func hide(_ bundleID: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { app.hide() }
    }

    /// Asks the app to quit, as ⌘Q would: it can still ask to save your work.
    func quit(_ bundleID: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { app.terminate() }
        uses.removeAll { $0.bundleID == bundleID }
        onChange()
    }

    func showParked() {
        for id in parked {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: id) { app.unhide() }
        }
        parked = []
        onChange()
    }

    private func restart() {
        timer?.invalidate()
        timer = nil
        guard isEnabled else {
            uses = []
            previous = [:]
            previousAt = nil
            onChange()
            return
        }
        start()
        sample()
        let timer = Timer.every(60) { [weak self] _ in self?.sample() }
        timer.tolerance = 15
        self.timer = timer
    }

    private func sample() {
        let battery = Power.onBattery
        batteryPercent = Self.readBatteryPercent()
        if battery != onBattery {
            onBattery = battery
            previous = [:]
            previousAt = nil
            watchingSince = Date()
            if !battery {
                uses = []
                // Back on power: the apps hidden to save battery come back.
                if !parked.isEmpty {
                    let names = parked.compactMap(Self.appName).joined(separator: ", ")
                    showParked()
                    onNotice("Plugged in · showing \(names) again")
                }
            }
        }
        guard battery else {
            onChange()
            return
        }
        let now = Date()
        let readings = readAll()
        if let at = previousAt {
            let seconds = now.timeIntervalSince(at)
            uses = PowerEstimate.ranked(readings.compactMap { id, entry in
                guard let before = previous[id] else { return nil }
                return PowerEstimate.use(bundleID: id, appName: entry.name, before: before, after: entry.reading,
                                         seconds: seconds, batteryWattHours: batteryWattHours)
            })
        }
        previous = readings.mapValues(\.reading)
        previousAt = now
        if parkOnBattery { parkIdleHogs(now: now) }
        onChange()
    }

    private func parkIdleHogs(now: Date) {
        let ids = PowerEstimate.toPark(uses, lastActive: lastActive, watchingSince: watchingSince,
                                       frontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                                       now: now, never: Set(parked))
        guard !ids.isEmpty else { return }
        for id in ids { hide(id) }
        parked += ids
        let names = ids.compactMap(Self.appName).joined(separator: ", ")
        onNotice("On battery · hid \(names), using the most power and untouched for an hour. Show them from ⚡ in the popover")
    }

    // MARK: Reading

    /// Totals per app (its own process plus the helpers it started).
    private func readAll() -> [String: (name: String, reading: PowerReading)] {
        let me = getpid()
        var apps: [pid_t: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.bundleIdentifier != nil && app.processIdentifier != me {
            apps[app.processIdentifier] = app
        }
        guard !apps.isEmpty else { return [:] }

        var parent: [pid_t: pid_t] = [:]
        let needed = proc_listallpids(nil, 0)
        if needed > 0 {
            var pids = [pid_t](repeating: 0, count: Int(needed) + 64)
            let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
            for pid in pids.prefix(Int(max(0, count))) where pid > 1 {
                var info = proc_bsdinfo()
                let size = Int32(MemoryLayout<proc_bsdinfo>.size)
                if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size { parent[pid] = pid_t(info.pbi_ppid) }
            }
        }
        func owner(of pid: pid_t) -> pid_t? {
            var current = pid
            for _ in 0..<8 {
                if apps[current] != nil { return current }
                guard let up = parent[current], up > 1 else { return nil }
                current = up
            }
            return nil
        }

        var totals: [pid_t: (cpu: Double, joules: Double)] = [:]
        for pid in Set(parent.keys).union(apps.keys) {
            guard let app = owner(of: pid), let usage = Self.usage(of: pid) else { continue }
            let cpu = Double(usage.ri_user_time &+ usage.ri_system_time) * ticksToSeconds
            let joules = Double(usage.ri_billed_energy) / 1_000_000_000
            let sum = totals[app] ?? (0, 0)
            totals[app] = (sum.cpu + cpu, sum.joules + joules)
        }
        var result: [String: (name: String, reading: PowerReading)] = [:]
        for (pid, total) in totals {
            guard let app = apps[pid], let id = app.bundleIdentifier else { continue }
            let existing = result[id]?.reading ?? PowerReading(cpuSeconds: 0, joules: 0)
            result[id] = (app.localizedName ?? id,
                          PowerReading(cpuSeconds: existing.cpuSeconds + total.cpu,
                                       joules: (existing.joules ?? 0) + total.joules))
        }
        return result
    }

    private static func usage(of pid: pid_t) -> rusage_info_v4? {
        var info = rusage_info_v4()
        let ok = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) == 0 }
        }
        return ok ? info : nil
    }

    private static func appName(_ bundleID: String) -> String? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.localizedName ?? bundleID
    }

    private static func readBatteryWattHours() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func number(_ key: String) -> Double? {
            (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.doubleValue
        }
        let capacity = number("AppleRawMaxCapacity") ?? number("DesignCapacity")
        return PowerEstimate.wattHours(capacityMilliampHours: capacity, voltageMillivolts: number("Voltage"))
    }

    private static func readBatteryPercent() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                let current = description[kIOPSCurrentCapacityKey] as? Int,
                let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            return Int((Double(current) / Double(max) * 100).rounded())
        }
        return nil
    }
}
#endif
