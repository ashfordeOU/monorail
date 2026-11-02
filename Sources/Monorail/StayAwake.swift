#if os(macOS)
import AppKit
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import MonorailCore

/// Stay Awake: keeps the Mac (and, if you like, its display) from sleeping, for as
/// long as you say, while an app runs or something downloads, or whenever a trigger
/// says so. Uses the same power assertions as macOS's own `caffeinate`.
final class StayAwake {
    private(set) var session: AwakeSession?
    private(set) var triggeredBy: AwakeTrigger?
    private(set) var startedAt: Date?
    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0
    private var timer: Timer?
    private var activityTimer: Timer?
    private var lastCursorNudge = Date()
    private var lastDriveWrite = Date.distantPast
    private var closedLidOn = false
    private var lidRequestPending = false
    /// The Mac got hot during this session: lid-closed mode stays off until the next one.
    private var hotThisSession = false
    /// The last safety message shown about lid-closed mode, so it's shown once.
    private var lidStopReason: String?
    private var cpuTicks: (busy: UInt64, total: UInt64)?
    private var networkBytes: (bytes: UInt64, at: Date)?
    private var thriftTick = false
    var settings: () -> AppSettings = { AppSettings() }
    /// Safety messages (lid-closed mode stopped because of heat or battery), always shown.
    var onNotice: (String) -> Void = { _ in }
    /// Called when Stay Awake turns on or off, or its session changes.
    var onChange: (_ on: Bool, _ why: String) -> Void = { _, _ in }

    var isOn: Bool { systemAssertion != 0 }

    /// The time left ("0:45") for the menu bar, next to the cup drawn into the icon; nil when there's none to show.
    var menuBarText: String? {
        guard isOn, case .until(let date)? = session, settings().awakeShowTime else { return nil }
        return AwakeFormat.clock(Int(date.timeIntervalSinceNow.rounded(.up)))
    }

    var statusText: String {
        guard isOn else { return "Off" }
        if let session { return "On " + session.describe(appName: UsageStats.appName) }
        if let triggeredBy { return "On · \(triggeredBy.kind.title.lowercased())" }
        return "On"
    }

    init() {
        // Lid-closed mode never outlives a session. Its watcher puts the normal lid behaviour back
        // when Monorail quits or crashes; only a restart in the middle can leave it on, and then
        // macOS asks for the password once to put it back.
        if FileManager.default.fileExists(atPath: Self.lidFlag.path) {
            if Self.sleepIsDisabled { Self.setClosedLid(false) { _ in } }
            try? FileManager.default.removeItem(at: Self.lidFlag)
        }
        try? FileManager.default.removeItem(at: Self.lidStop)
        timer = Timer.every(15) { [weak self] _ in self?.evaluate() }
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.isOn else { return }
            self.updateClosedLid(awake: true)
        }
    }

    // MARK: Sessions

    /// While Keeper owns staying awake, a session started here goes to Keeper instead
    /// (returns true when it took it). Only starts are handed over, never the end.
    var forwardToPeer: (AwakeSession) -> Bool = { _ in false }

    /// `fromPeer`: Keeper asked for it, so it's never handed back.
    func start(_ session: AwakeSession, fromPeer: Bool = false) {
        if !isOn, !fromPeer, forwardToPeer(session) { return }
        self.session = session
        evaluate(announce: true)
    }

    func start(minutes: Int, fromPeer: Bool = false) {
        start(minutes > 0 ? .until(Date().addingTimeInterval(Double(minutes) * 60)) : .indefinitely, fromPeer: fromPeer)
    }

    /// Ends a manual session (triggers may still keep the Mac awake).
    func end() {
        session = nil
        evaluate(announce: true)
    }

    func toggle() {
        if session != nil || isOn {
            end()
        } else {
            start(minutes: settings().awakeDefaultMinutes)
        }
    }

    /// Re-applies settings (display on or off, closed lid) to a running session.
    func refresh() {
        if isOn { applyAssertions(on: true) }
        evaluate()
    }

    // MARK: Deciding

    private func evaluate(announce: Bool = false) {
        let settings = self.settings()
        // Triggers only (no session running): on low power, check half as often.
        if session == nil, !announce, Dormancy.isThrifty {
            thriftTick.toggle()
            if thriftTick { return }
        }
        // Nothing to watch: no session, nothing on, no triggers. Costs nothing.
        if session == nil, !isOn, !announce, !settings.awakeTriggersOn || settings.awakeTriggers.allSatisfy({ !$0.isEnabled }) {
            return
        }
        let context = currentContext(needsNetwork: needsNetwork(settings), needsCPU: needsCPU(settings))
        var why = ""
        if let session, !AwakeRules.sessionContinues(session, in: context) {
            self.session = nil
            why = "Session ended"
        }
        if AwakeRules.batteryTooLow(context, cutoff: settings.awakeBatteryCutoff), session != nil || isOn {
            session = nil
            applyAssertions(on: false)
            triggeredBy = nil
            onChange(false, "Battery at \(context.battery ?? 0)% · Stay Awake ended so your Mac can sleep")
            return
        }
        let trigger = settings.awakeTriggersOn ? settings.awakeTriggers.first { AwakeRules.isActive($0, in: context) } : nil
        let shouldBeOn = session != nil || trigger != nil
        let changed = shouldBeOn != isOn || trigger?.id != triggeredBy?.id
        triggeredBy = session == nil ? trigger : nil
        if shouldBeOn != isOn { applyAssertions(on: shouldBeOn) }
        if shouldBeOn { keepAlive(settings) }
        updateClosedLid(awake: shouldBeOn)
        if changed || announce {
            if shouldBeOn {
                let reason = session?.describe(appName: UsageStats.appName) ?? trigger.map { $0.kind.title.lowercased() } ?? ""
                onChange(true, "Stay Awake on · \(reason)")
            } else {
                onChange(false, why.isEmpty ? "Stay Awake off · your Mac can sleep again" : "\(why) · your Mac can sleep again")
            }
        }
    }

    private func needsNetwork(_ settings: AppSettings) -> Bool {
        session == .whileDownloading || settings.awakeTriggers.contains { $0.isEnabled && $0.kind == .downloading }
    }

    private func needsCPU(_ settings: AppSettings) -> Bool {
        settings.awakeTriggers.contains { $0.isEnabled && $0.kind == .cpu }
    }

    // MARK: Power assertions

    private func applyAssertions(on: Bool) {
        let settings = self.settings()
        release(&systemAssertion)
        release(&displayAssertion)
        activityTimer?.invalidate()
        activityTimer = nil
        if on {
            startedAt = startedAt ?? Date()
            let reason = "Monorail Stay Awake" as CFString
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &systemAssertion)
            if settings.awakeKeepDisplayOn {
                IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                            IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &displayAssertion)
            }
            // Keep the screen saver away too (unless allowed), and lock after the chosen idle time.
            activityTimer = Timer.every(30) { [weak self] _ in self?.tickActivity() }
        } else {
            startedAt = nil
        }
        updateClosedLid(awake: on)
    }

    private func release(_ id: inout IOPMAssertionID) {
        if id != 0 { IOPMAssertionRelease(id) }
        id = 0
    }

    private func tickActivity() {
        let settings = self.settings()
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        if settings.awakeLockAfterMinutes > 0, idle >= Double(settings.awakeLockAfterMinutes) * 60 {
            Self.lockScreen()
            return
        }
        if settings.awakeKeepDisplayOn, !settings.awakeAllowScreenSaver {
            var id: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Monorail Stay Awake" as CFString, kIOPMUserActiveLocal, &id)
        }
    }

    /// Cursor nudges and drive writes, at their own pace.
    private func keepAlive(_ settings: AppSettings) {
        if settings.awakeMoveCursor,
            Date().timeIntervalSince(lastCursorNudge) >= Double(max(settings.awakeMoveCursorMinutes, 1)) * 60
        {
            lastCursorNudge = Date()
            let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
            if idle > 50 { Self.nudgeCursor() }
        }
        if settings.awakeDriveAlive, Date().timeIntervalSince(lastDriveWrite) >= 240 {
            lastDriveWrite = Date()
            Self.touchDrives()
        }
    }

    /// One point there and back: invisible, but enough for chat apps to see you're around.
    private static func nudgeCursor() {
        guard let location = CGEvent(source: nil)?.location else { return }
        for point in [CGPoint(x: location.x + 1, y: location.y), location] {
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
    }

    /// Writes a tiny hidden file on every external drive so it doesn't spin down.
    private static func touchDrives() {
        for volume in externalVolumes() {
            let file = volume.appendingPathComponent(".monorail-drive-alive")
            try? Data(Date().description.utf8).write(to: file)
        }
    }

    static func externalVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsInternalKey, .volumeIsRootFileSystemKey, .volumeIsReadOnlyKey]
        return (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? [])
            .filter { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                return values?.volumeIsRootFileSystem != true && values?.volumeIsInternal != true && values?.volumeIsReadOnly != true
            }
    }

    /// ⌃⌘Q, the system shortcut for Lock Screen.
    private static func lockScreen() {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: down)
            event?.flags = [.maskCommand, .maskControl]
            event?.post(tap: .cghidEventTap)
        }
    }

    // MARK: Closed lid

    static var lidFlag: URL { SettingsStore.directory.appendingPathComponent(".closed-lid") }
    /// Created to end lid-closed mode: its watcher sees it and puts the normal lid behaviour back.
    static var lidStop: URL { SettingsStore.directory.appendingPathComponent(".closed-lid-stop") }

    /// Turns lid-closed mode on or off as the rules say: only during Stay Awake, only on power
    /// when that's chosen, and off for the rest of the session once the Mac gets hot.
    private func updateClosedLid(awake: Bool) {
        let settings = self.settings()
        let heat = Self.heat
        if !awake {
            hotThisSession = false
            lidStopReason = nil
        } else if heat >= .serious {
            hotThisSession = true
        }
        let decision = AwakeRules.closedLid(awake: awake, enabled: settings.awakeClosedLid,
                                            onlyOnPower: settings.awakeClosedLidOnlyOnPower,
                                            charging: !Power.onBattery, heat: heat, hotThisSession: hotThisSession)
        switch decision {
        case .on:
            lidStopReason = nil
            guard !closedLidOn, !lidRequestPending else { return }
            lidRequestPending = true
            Self.startClosedLid { [weak self] ok in
                guard let self else { return }
                self.lidRequestPending = false
                self.closedLidOn = ok
                // Things may have changed while macOS asked for the password.
                if ok { self.updateClosedLid(awake: self.isOn) }
            }
        case .off, .stopped:
            if case .stopped(let why) = decision, why != lidStopReason {
                lidStopReason = why
                onNotice(why)
            }
            guard closedLidOn else { return }
            closedLidOn = false
            Self.stopClosedLid()
        }
    }

    static var heat: AwakeHeat {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .serious
        }
    }

    /// The lid is closed now.
    static var lidIsClosed: Bool {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        let value = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        return (value as? Bool) ?? false
    }

    /// `pmset disablesleep` is on (shown as SleepDisabled 1 by `pmset -g`).
    static var sleepIsDisabled: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return output.split(separator: "\n").contains { line in
            let parts = line.split(whereSeparator: \.isWhitespace)
            return parts.first == "SleepDisabled" && parts.last == "1"
        }
    }

    /// One password: turns lid-closed mode on and starts a watcher, with the same approval, that
    /// turns it back off when Monorail asks (the stop file), quits or crashes. No second password
    /// is needed to turn it off, which matters with the lid closed and nobody to type it.
    static func startClosedLid(completion: @escaping (Bool) -> Void) {
        try? FileManager.default.removeItem(at: lidStop)
        let pid = ProcessInfo.processInfo.processIdentifier
        let watcher = "while /bin/kill -0 \(pid) 2>/dev/null && [ ! -e \(shellQuoted(lidStop.path)) ]; do /bin/sleep 3; done; "
            + "/usr/bin/pmset -a disablesleep 0"
        let command = "/usr/bin/pmset -a disablesleep 1 && (/usr/bin/nohup /bin/sh -c \(shellQuoted(watcher)) >/dev/null 2>&1 &)"
        runAsAdministrator(command) { ok in
            if ok { FileManager.default.createFile(atPath: lidFlag.path, contents: Data()) }
            completion(ok)
        }
    }

    /// Ends lid-closed mode through the watcher. If the lid is already closed (and no external
    /// display keeps the Mac in clamshell mode), the Mac goes to sleep, as closing it would have done.
    static func stopClosedLid() {
        FileManager.default.createFile(atPath: lidStop.path, contents: Data())
        try? FileManager.default.removeItem(at: lidFlag)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            let external = NSScreen.screens.contains { screen in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) == 0
            }
            guard lidIsClosed, !external else { return }
            let sleep = Process()
            sleep.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            sleep.arguments = ["sleepnow"]
            try? sleep.run()
        }
    }

    /// Puts the normal lid behaviour back directly (after a restart left lid-closed mode on).
    static func setClosedLid(_ on: Bool, completion: @escaping (Bool) -> Void) {
        runAsAdministrator("/usr/bin/pmset -a disablesleep \(on ? 1 : 0)", completion: completion)
    }

    private static func runAsAdministrator(_ command: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let script = "do shell script \"\(escaped)\" with administrator privileges"
            var error: NSDictionary?
            let ok = NSAppleScript(source: script)?.executeAndReturnError(&error) != nil && error == nil
            DispatchQueue.main.async { completion(ok) }
        }
    }

    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: What the Mac is doing

    private func currentContext(needsNetwork: Bool, needsCPU: Bool) -> AwakeContext {
        let apps = NSWorkspace.shared.runningApplications
        let externals = NSScreen.screens.compactMap { screen -> String? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) == 0
            else { return nil }
            return screen.localizedName
        }
        let triggers = settings().awakeTriggers.filter(\.isEnabled)
        return AwakeContext(
            now: Date(),
            runningApps: Set(apps.compactMap(\.bundleIdentifier)),
            frontApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            externalDisplays: externals,
            wifi: triggers.contains { $0.kind == .wifi } ? AutoRules.currentNetwork() : nil,
            charging: !Power.onBattery,
            battery: Self.batteryPercent(),
            cpu: needsCPU ? cpuUsage() : 0,
            downloadRate: needsNetwork ? downloadRate() : 0,
            mountedVolumes: triggers.contains { $0.kind == .drive } ? Self.externalVolumes().map(\.lastPathComponent) : [])
    }

    static func batteryPercent() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                let current = description[kIOPSCurrentCapacityKey] as? Int,
                let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            return current * 100 / max
        }
        return nil
    }

    /// Busy share of all cores since the last call, 0–100.
    private func cpuUsage() -> Double {
        var info: processor_info_array_t?
        var count: mach_msg_type_number_t = 0
        var cpus: natural_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpus, &info, &count) == KERN_SUCCESS,
            let info
        else { return 0 }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(count) * MemoryLayout<integer_t>.stride)) }
        var busy: UInt64 = 0, total: UInt64 = 0
        for cpu in 0..<Int(cpus) {
            let base = cpu * Int(CPU_STATE_MAX)
            let user = UInt64(info[base + Int(CPU_STATE_USER)]), system = UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            let nice = UInt64(info[base + Int(CPU_STATE_NICE)]), idle = UInt64(info[base + Int(CPU_STATE_IDLE)])
            busy += user + system + nice
            total += user + system + nice + idle
        }
        defer { cpuTicks = (busy, total) }
        guard let last = cpuTicks, total > last.total else { return 0 }
        return Double(busy - last.busy) / Double(total - last.total) * 100
    }

    /// Incoming network across interfaces since the last call, KB/s.
    private func downloadRate() -> Double {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return 0 }
        defer { freeifaddrs(pointer) }
        var bytes: UInt64 = 0
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = entry.pointee
            guard interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), let data = interface.ifa_data else { continue }
            let name = String(cString: interface.ifa_name)
            guard !name.hasPrefix("lo") else { continue }
            bytes += UInt64(data.assumingMemoryBound(to: if_data.self).pointee.ifi_ibytes)
        }
        defer { networkBytes = (bytes, Date()) }
        guard let last = networkBytes, bytes >= last.bytes else { return 0 }
        let seconds = max(Date().timeIntervalSince(last.at), 1)
        return Double(bytes - last.bytes) / 1024 / seconds
    }

    /// Ends everything (on quit).
    func shutdown() {
        session = nil
        applyAssertions(on: false)
    }
}
#endif
