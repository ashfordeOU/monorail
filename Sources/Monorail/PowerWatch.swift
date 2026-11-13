#if os(macOS)
import AppKit
import Darwin
import IOKit
import IOKit.ps
import MonorailCore

/// Battery and which apps use it. Once a minute on battery (every few seconds while the battery panel
/// is open), it reads the processor time and energy macOS bills to each app and the helper processes
/// it starts, the battery's own figures (charge, draw, time left, health) and AI agents running as
/// processes. Shown as ⚡ on windows and in the battery panel; can pause, hide or quit apps, and keeps
/// a day of battery history. Nothing leaves the Mac.
final class PowerWatch: ObservableObject {
    static let shared = PowerWatch()

    struct AppUse: Identifiable, Equatable {
        var use: PowerUse
        var watts: Double?
        var processes: Int
        var isPaused: Bool
        var id: String { use.bundleID }
    }

    struct AgentUse: Identifiable, Equatable {
        var name: String
        var cpuPercent: Double
        var watts: Double?
        var processes: Int
        var percentPerHour: Double?
        var id: String { name }
    }

    @Published private(set) var battery = BatteryState(percent: 100, isCharging: false, onBattery: false)
    @Published private(set) var apps: [AppUse] = []
    @Published private(set) var agents: [AgentUse] = []
    @Published private(set) var history: [BatteryPoint] = []
    /// Apps Monorail hid to save battery, to show again.
    @Published private(set) var parked: [String] = []
    /// Apps paused (frozen) to save battery: bundle ID → process IDs.
    @Published private(set) var paused: [String: [pid_t]] = [:]
    /// Apps the person chose to keep (no "needs your attention" for them this session).
    @Published var kept: Set<String> = []
    /// What each app and AI agent has used since the Mac was last unplugged.
    @Published private(set) var session = ChargeSession()
    /// What used the battery, day by day, for the last 30 days.
    @Published private(set) var energy = EnergyLog()
    /// The battery's size in watt-hours, to turn energy into battery percentage points.
    var wattHours: Double? { batteryWattHours }

    var onBattery: Bool { battery.onBattery }
    var batteryPercent: Int? { battery.percent }
    var uses: [PowerUse] { apps.map(\.use) }
    /// Apps over the line right now, hungriest first.
    var hungry: [PowerUse] { onBattery ? PowerEstimate.hungry(uses) : [] }
    /// The app to suggest quitting: the hungriest one not kept or paused.
    var attention: AppUse? {
        guard onBattery else { return nil }
        return apps.first { $0.use.isHungry && !kept.contains($0.id) && !$0.isPaused }
    }

    var isEnabled = false {
        didSet { if oldValue != isEnabled { restart() } }
    }
    var parkOnBattery = false
    /// ⚡ on the windows of hungry apps (Settings); the panel works either way.
    var showMarkers = true
    var onNotice: (String) -> Void = { _ in }
    var onChange: () -> Void = {}

    private var timer: Timer?
    private var fastTimer: Timer?
    private var historyTimer: Timer?
    private var previous: [String: PowerReading] = [:]
    private var previousAgents: [String: PowerReading] = [:]
    private var previousAt: Date?
    private var lastActive: [String: Date] = [:]
    private var watchingSince = Date()
    private var observers: [NSObjectProtocol] = []
    private let batteryWattHours = PowerWatch.readBatteryWattHours()
    private let ticksToSeconds: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }()
    private static var folder: URL { SettingsStore.directory }
    private static var historyFile: URL { folder.appendingPathComponent("battery-history.json") }
    private static var pausedFile: URL { folder.appendingPathComponent("paused-apps.json") }
    private static var sessionFile: URL { folder.appendingPathComponent("since-charge.json") }

    /// "About 6% of the battery an hour" for a hungry app's windows, or nil.
    func note(for bundleID: String?) -> String? {
        guard isEnabled, showMarkers, onBattery, let bundleID, let app = apps.first(where: { $0.id == bundleID }), app.use.isHungry
        else { return nil }
        return app.use.summary
    }

    func start() {
        guard observers.isEmpty else { return }
        resumeLeftovers()
        history = Self.loadHistory()
        if let data = try? Data(contentsOf: Self.energyFile), let saved = try? JSONDecoder().decode(EnergyLog.self, from: data) { energy = saved }
        if let data = try? Data(contentsOf: Self.sessionFile), let saved = try? JSONDecoder().decode(ChargeSession.self, from: data) {
            session = saved
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let id = app.bundleIdentifier else { return }
            self.lastActive[id] = Date()
            // Opening a paused app wakes it.
            if self.paused[id] != nil { self.resume(id) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.readBattery()
            self?.onChange()
        })
        readBattery()
        recordHistory()
        // On battery with no session yet (first run): count from now.
        if battery.onBattery, session.since == nil { startSession() }
        let timer = Timer.every(300) { [weak self] _ in
            self?.readBattery()
            self?.recordHistory()
        }
        timer.tolerance = 60
        historyTimer = timer
    }

    /// While the battery panel is open: a fresh reading now and every few seconds.
    func setLive(_ live: Bool) {
        fastTimer?.invalidate()
        fastTimer = nil
        guard live, isEnabled else { return }
        if previousAt.map({ Date().timeIntervalSince($0) > 4 }) ?? true { sample(force: true) }
        let timer = Timer.every(5) { [weak self] _ in self?.sample(force: true) }
        timer.tolerance = 1
        fastTimer = timer
    }

    /// A fresh reading when the popover opens, if the last one is more than 15 seconds old.
    func refreshIfStale() {
        guard isEnabled else { return }
        if let at = previousAt, Date().timeIntervalSince(at) < 15 { return }
        sample(force: true)
    }

    // MARK: Acting on apps

    func hide(_ bundleID: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { app.hide() }
    }

    /// Asks the app to quit, as ⌘Q would: it can still ask to save your work.
    func quit(_ bundleID: String) {
        if paused[bundleID] != nil { resume(bundleID) }
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { app.terminate() }
        apps.removeAll { $0.id == bundleID }
        onChange()
    }

    func keep(_ bundleID: String) {
        kept.insert(bundleID)
        onChange()
    }

    /// Whether an app may be paused: not Apple's own apps, not Monorail, not the app in front.
    func canPause(_ bundleID: String) -> Bool {
        !bundleID.hasPrefix("com.apple.") && bundleID != Bundle.main.bundleIdentifier
            && NSWorkspace.shared.frontmostApplication?.bundleIdentifier != bundleID
    }

    /// Freezes the app and its helpers (no processor time, no battery) until it's opened, you plug
    /// in, you resume it, or Monorail quits. Its windows and work stay exactly as they were.
    func pause(_ bundleID: String) {
        guard canPause(bundleID), paused[bundleID] == nil else { return }
        let roots = Set(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).map(\.processIdentifier))
        guard !roots.isEmpty else { return }
        let parents = Self.processTree()
        let tree = parents.keys.filter { Self.owner(of: $0, in: roots, parents: parents) != nil }
        let pids = Array(Set(tree).union(roots))
        for pid in pids { kill(pid, SIGSTOP) }
        paused[bundleID] = pids
        savePaused()
        refreshPausedFlags()
        onNotice("Paused \(Self.appName(bundleID) ?? bundleID) · it wakes when you open it or plug in")
        onChange()
    }

    func resume(_ bundleID: String) {
        guard let pids = paused[bundleID] else { return }
        for pid in pids { kill(pid, SIGCONT) }
        paused[bundleID] = nil
        savePaused()
        refreshPausedFlags()
        onChange()
    }

    func resumeAll() {
        for id in Array(paused.keys) { resume(id) }
    }

    func showParked() {
        for id in parked {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: id) { app.unhide() }
        }
        parked = []
        onChange()
    }

    /// Low Power Mode, from the panel (macOS asks for an administrator password).
    func setLowPowerMode(_ on: Bool) {
        StayAwake.runAsAdministrator("/usr/bin/pmset -a lowpowermode \(on ? 1 : 0)") { [weak self] _ in
            self?.readBattery()
            self?.onChange()
        }
    }

    // MARK: Sampling

    private func restart() {
        timer?.invalidate()
        timer = nil
        guard isEnabled else {
            apps = []
            agents = []
            previous = [:]
            previousAt = nil
            onChange()
            return
        }
        start()
        sample(force: false)
        let timer = Timer.every(60) { [weak self] _ in self?.sample(force: false) }
        timer.tolerance = 15
        self.timer = timer
    }

    private func sample(force: Bool) {
        let wasOnBattery = battery.onBattery
        readBattery()
        if battery.onBattery != wasOnBattery {
            previous = [:]
            previousAgents = [:]
            previousAt = nil
            watchingSince = Date()
            recordHistory()
            if battery.onBattery { startSession() }
            if !battery.onBattery {
                // Back on power: everything paused or hidden to save battery comes back.
                var back: [String] = []
                if !paused.isEmpty { back += paused.keys.compactMap(Self.appName); resumeAll() }
                if !parked.isEmpty { back += parked.compactMap(Self.appName); showParked() }
                if !back.isEmpty { onNotice("Plugged in · \(back.joined(separator: ", ")) back to normal") }
            }
        }
        // On power, only measure while someone is looking.
        guard battery.onBattery || force else {
            apps = []
            agents = []
            onChange()
            return
        }
        let now = Date()
        let reading = readAll()
        if let at = previousAt {
            let seconds = now.timeIntervalSince(at)
            var list: [AppUse] = []
            for (id, entry) in reading.apps {
                guard let before = previous[id] else { continue }
                let use = PowerEstimate.use(bundleID: id, appName: entry.name, before: before, after: entry.reading,
                                            seconds: seconds, batteryWattHours: batteryWattHours)
                let watts = Self.watts(before: before, after: entry.reading, seconds: seconds)
                list.append(AppUse(use: use, watts: watts, processes: entry.processes, isPaused: paused[id] != nil))
            }
            let ranked = PowerEstimate.ranked(list.map(\.use)).map(\.bundleID)
            apps = ranked.compactMap { id in list.first { $0.id == id } }
            agents = reading.agents.compactMap { name, entry in
                guard let before = previousAgents[name] else { return nil }
                let use = PowerEstimate.use(bundleID: name, appName: name, before: before, after: entry.reading,
                                            seconds: seconds, batteryWattHours: batteryWattHours)
                return AgentUse(name: name, cpuPercent: use.cpuPercent, watts: Self.watts(before: before, after: entry.reading, seconds: seconds),
                                processes: entry.processes, percentPerHour: use.percentPerHour)
            }.sorted { ($0.watts ?? $0.cpuPercent / 100) > ($1.watts ?? $1.cpuPercent / 100) }
            // Add this interval to the totals since the last charge.
            if battery.onBattery {
                for (id, entry) in reading.apps {
                    guard let before = previous[id] else { continue }
                    session.add(id: id, name: entry.name, joules: (entry.reading.joules ?? 0) - (before.joules ?? 0),
                                cpuSeconds: entry.reading.cpuSeconds - before.cpuSeconds)
                    energy.add(id: id, name: entry.name, joules: (entry.reading.joules ?? 0) - (before.joules ?? 0),
                               cpuSeconds: entry.reading.cpuSeconds - before.cpuSeconds)
                }
                for (name, entry) in reading.agents {
                    guard let before = previousAgents[name] else { continue }
                    session.add(id: "agent:" + name, name: name, isAgent: true,
                                joules: (entry.reading.joules ?? 0) - (before.joules ?? 0),
                                cpuSeconds: entry.reading.cpuSeconds - before.cpuSeconds)
                    energy.add(id: "agent:" + name, name: name, isAgent: true, joules: (entry.reading.joules ?? 0) - (before.joules ?? 0),
                               cpuSeconds: entry.reading.cpuSeconds - before.cpuSeconds)
                }
                saveSession()
                saveEnergy()
            }
        }
        previous = reading.apps.mapValues(\.reading)
        previousAgents = reading.agents.mapValues(\.reading)
        previousAt = now
        if parkOnBattery, battery.onBattery { parkIdleHogs(now: now) }
        onChange()
    }

    private static func watts(before: PowerReading, after: PowerReading, seconds: Double) -> Double? {
        guard let a = after.joules, let b = before.joules, a > 0, seconds > 0 else { return nil }
        return max(0, a - b) / seconds
    }

    private func refreshPausedFlags() {
        apps = apps.map { var app = $0; app.isPaused = paused[$0.id] != nil; return app }
    }

    private func parkIdleHogs(now: Date) {
        let ids = PowerEstimate.toPark(uses, lastActive: lastActive, watchingSince: watchingSince,
                                       frontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                                       now: now, never: Set(parked).union(kept))
        guard !ids.isEmpty else { return }
        for id in ids { hide(id) }
        parked += ids
        let names = ids.compactMap(Self.appName).joined(separator: ", ")
        onNotice("On battery · hid \(names), using the most power and untouched for an hour. Show them from the battery panel")
    }

    // MARK: Since the last charge

    private func startSession() {
        session.start(at: Date(), percent: battery.percent)
        saveSession()
    }

    private static var energyFile: URL { folder.appendingPathComponent("energy-log.json") }

    private func saveEnergy() {
        if let data = try? JSONEncoder().encode(energy) { try? data.write(to: Self.energyFile, options: .atomic) }
    }

    private func saveSession() {
        if let data = try? JSONEncoder().encode(session) { try? data.write(to: Self.sessionFile, options: .atomic) }
    }

    /// The biggest users since the last charge, with "0.4% used" (or processor time).
    func sinceCharge(limit: Int = 5) -> [(id: String, name: String, isAgent: Bool, used: String)] {
        session.ranked.prefix(limit).map { ($0.id, $0.total.name, $0.total.isAgent, ChargeSession.usedText($0.total, wattHours: batteryWattHours)) }
    }

    // MARK: Battery

    private func readBattery() {
        var state = BatteryState(percent: battery.percent, isCharging: false, onBattery: Power.onBattery,
                                 lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in list {
                guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                    let current = description[kIOPSCurrentCapacityKey] as? Int,
                    let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0
                else { continue }
                state.percent = Int((Double(current) / Double(maximum) * 100).rounded())
                state.isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
                if let minutes = description[kIOPSTimeToEmptyKey] as? Int, minutes > 0 { state.minutesLeft = minutes }
                break
            }
        }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            func number(_ key: String) -> Double? {
                (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.doubleValue
            }
            let voltage = number("Voltage")
            if let voltage, let amps = number("InstantAmperage") ?? number("Amperage"), state.onBattery, amps < 0 {
                state.watts = -amps * voltage / 1_000_000
            }
            if let voltage, let remaining = number("AppleRawCurrentCapacity") {
                state.remainingWattHours = remaining * voltage / 1_000_000
            }
            if let full = number("AppleRawMaxCapacity") ?? number("NominalChargeCapacity"), let design = number("DesignCapacity"), design > 0 {
                state.capacityPercent = min(100, Int((full / design * 100).rounded()))
            }
            state.cycleCount = number("CycleCount").map(Int.init)
        }
        if state != battery { battery = state }
    }

    private func recordHistory() {
        guard Self.hasBattery else { return }
        history = BatteryHistory.adding(BatteryPoint(time: Date(), percent: battery.percent, charging: battery.isCharging || !battery.onBattery), to: history)
        if let data = try? JSONEncoder().encode(history) { try? data.write(to: Self.historyFile, options: .atomic) }
    }

    static var hasBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }
        return !list.isEmpty
    }

    private static func loadHistory() -> [BatteryPoint] {
        guard let data = try? Data(contentsOf: historyFile), let points = try? JSONDecoder().decode([BatteryPoint].self, from: data)
        else { return [] }
        return points
    }

    // MARK: Paused apps survive a crash

    private func savePaused() {
        let pids = paused.values.flatMap { $0 }.map(Int.init)
        if let data = try? JSONEncoder().encode(pids) { try? data.write(to: Self.pausedFile, options: .atomic) }
    }

    /// Wakes anything a previous Monorail paused and didn't get to wake (a crash or force quit).
    private func resumeLeftovers() {
        guard let data = try? Data(contentsOf: Self.pausedFile), let pids = try? JSONDecoder().decode([Int].self, from: data) else { return }
        for pid in pids { kill(pid_t(pid), SIGCONT) }
        try? FileManager.default.removeItem(at: Self.pausedFile)
    }

    // MARK: Reading processes

    private struct Entry { var name: String; var reading: PowerReading; var processes: Int }

    private static func processTree() -> [pid_t: pid_t] {
        var parent: [pid_t: pid_t] = [:]
        let needed = proc_listallpids(nil, 0)
        guard needed > 0 else { return parent }
        var pids = [pid_t](repeating: 0, count: Int(needed) + 64)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        for pid in pids.prefix(Int(max(0, count))) where pid > 1 {
            var info = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.size)
            if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size { parent[pid] = pid_t(info.pbi_ppid) }
        }
        return parent
    }

    private static func owner(of pid: pid_t, in roots: Set<pid_t>, parents: [pid_t: pid_t]) -> pid_t? {
        var current = pid
        for _ in 0..<8 {
            if roots.contains(current) { return current }
            guard let up = parents[current], up > 1 else { return nil }
            current = up
        }
        return nil
    }

    private static func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        return String(cString: buffer)
    }

    /// The first few arguments of a process (for agents started with node or python).
    private static func arguments(_ pid: pid_t) -> [String] {
        var size = 0
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        let bytes = buffer.prefix(size).map { UInt8(bitPattern: $0) }
        let parts = bytes.dropFirst(MemoryLayout<Int32>.size).split(separator: 0, omittingEmptySubsequences: true)
        // The executable path, then the arguments.
        return parts.prefix(5).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Totals per app (its own process plus the helpers it started) and per AI agent.
    private func readAll() -> (apps: [String: Entry], agents: [String: Entry]) {
        let me = getpid()
        var running: [pid_t: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.bundleIdentifier != nil && app.processIdentifier != me {
            running[app.processIdentifier] = app
        }
        let parents = Self.processTree()
        let roots = Set(running.keys)
        var totals: [pid_t: (cpu: Double, joules: Double, count: Int)] = [:]
        var agentTotals: [String: (cpu: Double, joules: Double, count: Int)] = [:]
        for pid in Set(parents.keys).union(roots) {
            let app = Self.owner(of: pid, in: roots, parents: parents)
            let name = Self.processName(pid)
            let scripted = ["node", "python", "python3", "bun", "deno"].contains(name)
            let agent = AgentProcesses.agent(processName: name, arguments: scripted ? Self.arguments(pid) : [])
            guard app != nil || agent != nil, let usage = Self.usage(of: pid) else { continue }
            let cpu = Double(usage.ri_user_time &+ usage.ri_system_time) * ticksToSeconds
            let joules = Double(usage.ri_billed_energy) / 1_000_000_000
            if let app {
                let sum = totals[app] ?? (0, 0, 0)
                totals[app] = (sum.cpu + cpu, sum.joules + joules, sum.count + 1)
            }
            if let agent {
                let sum = agentTotals[agent] ?? (0, 0, 0)
                agentTotals[agent] = (sum.cpu + cpu, sum.joules + joules, sum.count + 1)
            }
        }
        var apps: [String: Entry] = [:]
        for (pid, total) in totals {
            guard let app = running[pid], let id = app.bundleIdentifier else { continue }
            let existing = apps[id]
            apps[id] = Entry(name: app.localizedName ?? id,
                             reading: PowerReading(cpuSeconds: (existing?.reading.cpuSeconds ?? 0) + total.cpu,
                                                   joules: (existing?.reading.joules ?? 0) + total.joules),
                             processes: (existing?.processes ?? 0) + total.count)
        }
        let agents = agentTotals.mapValues { Entry(name: "", reading: PowerReading(cpuSeconds: $0.cpu, joules: $0.joules), processes: $0.count) }
        return (apps, agents)
    }

    private static func usage(of pid: pid_t) -> rusage_info_v4? {
        var info = rusage_info_v4()
        let ok = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) == 0 }
        }
        return ok ? info : nil
    }

    static func appName(_ bundleID: String) -> String? {
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

    /// For the API and MCP: the battery and the top apps.
    func report() -> [String: Any] {
        var out: [String: Any] = ["percent": battery.percent, "charging": battery.isCharging, "onBattery": battery.onBattery,
                                  "lowPowerMode": battery.lowPowerMode]
        if let w = battery.watts { out["watts"] = (w * 100).rounded() / 100 }
        if let m = battery.minutesAtCurrentRate { out["minutesLeft"] = m; out["timeLeft"] = BatteryState.duration(m) }
        if let c = battery.capacityPercent { out["capacityPercent"] = c }
        if let c = battery.cycleCount { out["cycleCount"] = c }
        out["apps"] = apps.prefix(15).map { app -> [String: Any] in
            var row: [String: Any] = ["app": app.use.appName, "bundleID": app.id, "cpuPercent": (app.use.cpuPercent * 10).rounded() / 10,
                                      "processes": app.processes, "paused": app.isPaused]
            if let w = app.watts { row["watts"] = (w * 1000).rounded() / 1000 }
            if let p = app.use.percentPerHour { row["percentPerHour"] = (p * 100).rounded() / 100 }
            return row
        }
        out["agents"] = agents.map { agent -> [String: Any] in
            var row: [String: Any] = ["agent": agent.name, "processes": agent.processes, "cpuPercent": (agent.cpuPercent * 10).rounded() / 10]
            if let w = agent.watts { row["watts"] = (w * 1000).rounded() / 1000 }
            return row
        }
        out["paused"] = paused.keys.sorted()
        if let since = session.since {
            var charge: [String: Any] = ["since": ISO8601DateFormatter().string(from: since)]
            if let p = session.startPercent { charge["startPercent"] = p }
            charge["top"] = sinceCharge(limit: 10).map { ["name": $0.name, "kind": $0.isAgent ? "agent" : "app", "used": $0.used] }
            out["sinceLastCharge"] = charge
        }
        if apps.isEmpty { out["note"] = battery.onBattery ? "Measuring; ask again in a minute" : "Plugged in: per-app figures are measured on battery or while the battery panel is open" }
        return out
    }
}
#endif
