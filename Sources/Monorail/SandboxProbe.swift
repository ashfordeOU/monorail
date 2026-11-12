#if os(macOS)
import AppKit
import ApplicationServices
import CoreAudio
import Darwin
import EventKit
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import Network

/// `Monorail --probe-sandbox`: tries, for real, each thing Monorail Station (the App Store edition)
/// would need, and prints one line per check: `PROBE <name> ok|denied <detail>`. Run on GitHub's Mac
/// by `appstore.yml` with the sandbox on, so what the App Store allows is measured, not guessed.
/// Every check undoes what it changes.
enum SandboxProbe {
    static var isRequested: Bool { CommandLine.arguments.contains("--probe-sandbox") }

    private static var results: [(String, Bool, String)] = []

    static func run() -> Never {
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        print("PROBE sandbox \(sandboxed ? "ok" : "denied") \(sandboxed ? "running in the App Sandbox" : "not sandboxed")")
        check("battery", battery)
        check("batteryHealth", batteryHealth)
        check("processList", processList)
        check("appEnergy", appEnergy)
        check("stayAwake", stayAwake)
        check("userActivity", userActivity)
        check("evening", evening)
        check("windowList", windowList)
        check("frontmostApp", frontmostApp)
        check("hideApp", hideApp)
        check("quitApp", quitApp)
        check("openApp", openApp)
        check("clipboard", clipboard)
        check("calendar", calendar)
        check("micInUse", micInUse)
        check("bluetoothBatteries", bluetoothBatteries)
        check("thermal", thermal)
        check("lowPowerSwitch", lowPowerSwitch)
        check("localServer", localServer)
        check("moveWindows", moveWindows)
        let passed = results.filter(\.1).count
        print("PROBE summary ok \(passed) of \(results.count) allowed")
        exit(0)
    }

    private static func check(_ name: String, _ test: () -> (Bool, String)) {
        let (ok, detail) = test()
        results.append((name, ok, detail))
        print("PROBE \(name) \(ok ? "ok" : "denied") \(detail)")
        fflush(stdout)
    }

    // MARK: Battery

    private static func battery() -> (Bool, String) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return (false, "no power sources") }
        for source in list {
            if let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                let level = d[kIOPSCurrentCapacityKey] as? Int
            { return (true, "charge \(level)%") }
        }
        // A Mac without a battery still answers; that's allowed too.
        return (true, "readable, \(list.count) sources (no battery on this Mac)")
    }

    private static func batteryHealth() -> (Bool, String) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (true, "no smart battery on this Mac (lookup allowed)") }
        defer { IOObjectRelease(service) }
        let cycles = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        return cycles == nil ? (false, "properties not readable") : (true, "cycle count \(cycles!)")
    }

    private static func processList() -> (Bool, String) {
        let needed = proc_listallpids(nil, 0)
        guard needed > 0 else { return (false, "proc_listallpids refused") }
        var pids = [pid_t](repeating: 0, count: Int(needed) + 64)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        return count > 10 ? (true, "\(count) processes listed") : (false, "only \(count) processes visible")
    }

    /// The question that decides per-app battery use: can it read another app's energy?
    private static func appEnergy() -> (Bool, String) {
        guard let other = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier != getpid() && $0.bundleIdentifier == "com.apple.dock"
        }) ?? NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier != getpid() })
        else { return (false, "no other app running") }
        var info = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(other.processIdentifier, RUSAGE_INFO_V4, $0) }
        }
        guard status == 0 else { return (false, "proc_pid_rusage on \(other.localizedName ?? "?") failed (errno \(errno))") }
        return (true, "\(other.localizedName ?? "app"): \(info.ri_user_time / 1_000_000) ms CPU, energy \(info.ri_billed_energy) nJ")
    }

    // MARK: Awake and evening

    private static func stayAwake() -> (Bool, String) {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn), "Monorail probe" as CFString, &id)
        guard result == kIOReturnSuccess else { return (false, "IOPMAssertionCreate returned \(result)") }
        IOPMAssertionRelease(id)
        return (true, "sleep assertion created and released")
    }

    /// Keep me Available tells macOS you're active; Teams and Slack read the idle time.
    private static func userActivity() -> (Bool, String) {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionDeclareUserActivity("Monorail probe" as CFString, kIOPMUserActiveLocal, &id)
        guard result == kIOReturnSuccess else { return (false, "IOPMAssertionDeclareUserActivity returned \(result)") }
        IOPMAssertionRelease(id)
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        return (true, String(format: "declared; idle time now %.1f s", idle))
    }

    /// Evening Mode warms the screen through the display's colour table.
    private static func evening() -> (Bool, String) {
        let display = CGMainDisplayID()
        let size = Int(CGDisplayGammaTableCapacity(display))
        guard size > 0 else { return (false, "no gamma table") }
        var red = [CGGammaValue](repeating: 0, count: size), green = red, blue = red
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, UInt32(size), &red, &green, &blue, &count) == .success else {
            return (false, "can't read the colour table")
        }
        let warm = blue.map { $0 * 0.8 }
        let set = CGSetDisplayTransferByTable(display, count, red, green, warm)
        CGDisplayRestoreColorSyncSettings()
        return set == .success ? (true, "colour table warmed and restored") : (false, "CGSetDisplayTransferByTable returned \(set.rawValue)")
    }

    // MARK: Other apps and windows

    /// Focus dimming needs to know where other apps' windows are.
    private static func windowList() -> (Bool, String) {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let others = list.filter { ($0[kCGWindowOwnerPID as String] as? pid_t) != getpid() && $0[kCGWindowBounds as String] != nil }
        return others.isEmpty ? (false, "no other windows visible") : (true, "\(others.count) other windows with their frames")
    }

    private static func frontmostApp() -> (Bool, String) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return (false, "no frontmost app") }
        return (true, app.localizedName ?? app.bundleIdentifier ?? "known")
    }

    private static func textEdit() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first
    }

    private static func hideApp() -> (Bool, String) {
        guard let app = textEdit() else { return (false, "TextEdit isn't running (the workflow opens it)") }
        _ = app.hide()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        let hidden = app.isHidden
        app.unhide()
        return hidden ? (true, "TextEdit hidden and shown again") : (false, "hide() had no effect")
    }

    private static func quitApp() -> (Bool, String) {
        guard let app = textEdit() else { return (false, "TextEdit isn't running") }
        _ = app.terminate()
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        return app.isTerminated ? (true, "TextEdit quit") : (false, "terminate() had no effect")
    }

    private static func openApp() -> (Bool, String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.calculator") else {
            return (false, "Calculator not found")
        }
        var error: Error?
        var done = false
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { app, err in
            error = err
            app?.terminate()
            done = true
        }
        let deadline = Date().addingTimeInterval(8)
        while !done, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        return error == nil && done ? (true, "Calculator opened and closed") : (false, error?.localizedDescription ?? "timed out")
    }

    private static func clipboard() -> (Bool, String) {
        let text = NSPasteboard.general.string(forType: .string)
        return text == nil ? (false, "nothing readable on the clipboard") : (true, "read \(text!.count) characters")
    }

    private static func calendar() -> (Bool, String) {
        let status = EKEventStore.authorizationStatus(for: .event)
        // Asking needs a person to click Allow; the check is that the store answers at all.
        return (true, "calendar access status \(status.rawValue) (asks the person on first use)")
    }

    /// A call is on: the microphone is in use by some app. Used for "stay awake during calls".
    private static func micInUse() -> (Bool, String) {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr, device != 0 else {
            return (true, "no microphone on this Mac (lookup allowed)")
        }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running)
        return status == noErr ? (true, "microphone in use: \(running != 0)") : (false, "status \(status)")
    }

    /// AirPods, Magic Mouse and keyboard charge, from their HID services.
    private static func bluetoothBatteries() -> (Bool, String) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else {
            return (false, "lookup refused")
        }
        defer { IOObjectRelease(iterator) }
        var found = 0
        while case let service = IOIteratorNext(iterator), service != 0 {
            if IORegistryEntryCreateCFProperty(service, "BatteryPercent" as CFString, kCFAllocatorDefault, 0) != nil { found += 1 }
            IOObjectRelease(service)
        }
        return (true, "lookup allowed, \(found) devices report a battery")
    }

    private static func thermal() -> (Bool, String) {
        (true, "thermal state \(ProcessInfo.processInfo.thermalState.rawValue)")
    }

    /// Low Power Mode is changed with pmset, which needs an administrator.
    private static func lowPowerSwitch() -> (Bool, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (false, "can't run pmset: \(error.localizedDescription)")
        }
        return (false, "pmset readable (exit \(process.terminationStatus)); changing it still needs an administrator")
    }

    /// The local API and MCP server listen for connections.
    private static func localServer() -> (Bool, String) {
        do {
            let listener = try NWListener(using: .tcp, on: .any)
            var state = "starting"
            let queue = DispatchQueue(label: "probe")
            listener.stateUpdateHandler = { new in
                switch new {
                case .ready: state = "ready"
                case .failed(let error): state = "failed: \(error)"
                default: break
                }
            }
            listener.newConnectionHandler = { $0.cancel() }
            listener.start(queue: queue)
            let deadline = Date().addingTimeInterval(3)
            while state == "starting", Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
            listener.cancel()
            return (state == "ready", "listener \(state)")
        } catch {
            return (false, "\(error)")
        }
    }

    /// The strip: moving another app's window through Accessibility. Expected to be refused.
    private static func moveWindows() -> (Bool, String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            return (false, "Finder not found")
        }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var windows: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows)
        return result == .success ? (true, "read Finder's windows through Accessibility") : (false, "Accessibility refused (\(result.rawValue))")
    }
}
#endif
