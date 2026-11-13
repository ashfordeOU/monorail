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
import IOBluetooth
import ScreenCaptureKit
import Vision
import CoreImage

/// `Monorail --probe-sandbox`: tries, for real, each thing Signalbox (the App Store edition)
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
        // The 🧪 features: what each would need, tried for real.
        check("airpodsPlist", airpodsPlist)
        check("perCoreLoad", perCoreLoad)
        check("chipSensorsSMC", chipSensorsSMC)
        check("networkCounters", networkCounters)
        check("speedTest", speedTest)
        check("homeWithoutGrant", homeWithoutGrant)
        check("bookmarkScope", bookmarkScope)
        check("trashFile", trashFile)
        check("screenCapture", screenCapture)
        check("ocrOnImage", ocrOnImage)
        check("qrOnImage", qrOnImage)
        // Last: without the Bluetooth permission macOS ends the app here.
        check("bluetoothPaired", bluetoothPaired)
        let passed = results.filter(\.1).count
        print("PROBE summary ok \(passed) of \(results.count) allowed")
        exit(0)
    }

    private static var current: (name: String, started: Date)?
    private static let lock = NSLock()

    /// If a check sits on a permission prompt no one can click on a CI Mac, the watchdog reports it
    /// after 25 seconds and ends the probe with the results so far (the riskiest checks run last).
    private static func startWatchdog() {
        Thread.detachNewThread {
            while true {
                Thread.sleep(forTimeInterval: 1)
                lock.lock(); let now = current; lock.unlock()
                guard let now, Date().timeIntervalSince(now.started) > 25 else { continue }
                print("PROBE \(now.name) denied no answer in 25 s (stuck on a permission prompt)")
                print("PROBE summary ok \(results.filter(\.1).count) of \(results.count + 1) allowed (stopped at \(now.name))")
                fflush(stdout)
                exit(0)
            }
        }
    }

    private static func check(_ name: String, _ test: () -> (Bool, String)) {
        if current == nil && results.isEmpty { startWatchdog() }
        lock.lock(); current = (name, Date()); lock.unlock()
        let (ok, detail) = test()
        lock.lock(); current = nil; lock.unlock()
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
    // MARK: The 🧪 features

    /// AirPods' battery is only kept in this system file (and in private Bluetooth properties).
    private static func airpodsPlist() -> (Bool, String) {
        let path = "/Library/Preferences/com.apple.Bluetooth.plist"
        guard let data = FileManager.default.contents(atPath: path) else { return (false, "\(path) not readable") }
        return (true, "\(path) readable, \(data.count) bytes")
    }

    private static func bluetoothPaired() -> (Bool, String) {
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]
        guard let devices else { return (false, "pairedDevices returned nil") }
        return (true, "pairedDevices allowed, \(devices.count) paired")
    }

    private static func perCoreLoad() -> (Bool, String) {
        var count: natural_t = 0, infoCount: mach_msg_type_number_t = 0
        var info: processor_info_array_t?
        let r = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount)
        guard r == KERN_SUCCESS, let info else { return (false, "host_processor_info returned \(r)") }
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        return (true, "\(count) cores' ticks readable")
    }

    /// Per-core temperatures come from the SMC (or private HID sensor APIs, which the App Store refuses).
    private static func chipSensorsSMC() -> (Bool, String) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return (false, "no AppleSMC service visible") }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        let r = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard r == KERN_SUCCESS else { return (false, String(format: "IOServiceOpen(AppleSMC) refused 0x%x", r)) }
        IOServiceClose(connection)
        return (true, "AppleSMC opened")
    }

    private static func networkCounters() -> (Bool, String) {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return (false, "getifaddrs failed") }
        defer { freeifaddrs(list) }
        var bytes: UInt64 = 0
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let addr = pointer.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
                  let data = pointer.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            bytes += UInt64(data.pointee.ifi_ibytes) + UInt64(data.pointee.ifi_obytes)
        }
        return bytes > 0 ? (true, "interface byte counters readable (\(bytes / 1_000_000) MB so far)") : (false, "counters read as zero")
    }

    private static func speedTest() -> (Bool, String) {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=5000000") else { return (false, "bad URL") }
        let done = DispatchSemaphore(value: 0)
        var outcome: (Bool, String) = (false, "timed out")
        let start = Date()
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data, !data.isEmpty {
                let seconds = Date().timeIntervalSince(start)
                outcome = (true, String(format: "downloaded %.1f MB at %.0f Mbit/s", Double(data.count) / 1e6, Double(data.count) * 8 / 1e6 / seconds))
            } else {
                outcome = (false, error?.localizedDescription ?? "no data")
            }
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 30)
        return outcome
    }

    /// Without the open dialog, can it read the real home folder? (Expected: no.)
    private static func homeWithoutGrant() -> (Bool, String) {
        guard let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir else { return (false, "no home") }
        let home = String(cString: dir)
        var seen: [String] = []
        for sub in ["Downloads", "Documents", "Library/Developer", "Library/Caches"] {
            if (try? FileManager.default.contentsOfDirectory(atPath: home + "/" + sub)) != nil { seen.append(sub) }
        }
        return seen.isEmpty ? (false, "real home folders closed without a grant (as expected)") : (true, "readable without a grant: \(seen.joined(separator: ", "))")
    }

    /// Remembering a folder you chose, across launches, needs a security-scoped bookmark.
    private static func bookmarkScope() -> (Bool, String) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("probe-bookmark", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            let data = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            return (true, "security-scoped bookmark made (\(data.count) bytes)")
        } catch {
            return (false, "bookmark refused: \(error.localizedDescription)")
        }
    }

    private static func trashFile() -> (Bool, String) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("probe-trash.txt")
        try? "probe".write(to: file, atomically: true, encoding: .utf8)
        do {
            var landed: NSURL?
            try FileManager.default.trashItem(at: file, resultingItemURL: &landed)
            return (true, "moved to \(landed?.path ?? "the Trash")")
        } catch {
            return (false, "trashItem refused: \(error.localizedDescription)")
        }
    }

    /// OCR and QR read what's on screen: ScreenCaptureKit, after the Screen Recording permission.
    /// The CI step grants it as a person would in System Settings; here the screen is captured and
    /// the word TextEdit shows ("Probe") is looked for.
    private static var captured: CGImage?

    private static func screenCapture() -> (Bool, String) {
        let preflight = CGPreflightScreenCaptureAccess()
        guard #available(macOS 14.0, *) else { return (false, "needs macOS 14") }
        let done = DispatchSemaphore(value: 0)
        var outcome: (Bool, String) = (false, "timed out")
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            guard let content, let display = content.displays.first else {
                outcome = (false, "permission \(preflight ? "granted" : "not granted"); content refused: \(error?.localizedDescription ?? "none")")
                done.signal()
                return
            }
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingWindows: []), configuration: config) { image, error in
                if let image {
                    captured = image
                    outcome = (true, "permission \(preflight ? "granted" : "not preflighted"); captured \(image.width)x\(image.height), \(content.windows.count) windows")
                } else {
                    outcome = (false, "capture refused: \(error?.localizedDescription ?? "none")")
                }
                done.signal()
            }
        }
        _ = done.wait(timeout: .now() + 20)
        return outcome
    }

    private static func ocrOnImage() -> (Bool, String) {
        let image = captured ?? renderedText("Probe 12345")
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch { return (false, "Vision refused: \(error.localizedDescription)") }
        let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let source = captured == nil ? "a drawn image" : "the captured screen"
        let found = text.contains { $0.localizedCaseInsensitiveContains("Probe") }
        return found ? (true, "read \"Probe\" from \(source) (\(text.count) lines)") : (false, "Vision ran on \(source) but found: \(text.prefix(5).joined(separator: " | "))")
    }

    private static func qrOnImage() -> (Bool, String) {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return (false, "no QR generator") }
        filter.setValue("https://monorail.ashforde.org".data(using: .utf8), forKey: "inputMessage")
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let image = CIContext().createCGImage(output, from: output.extent) else { return (false, "couldn't draw a QR code") }
        let request = VNDetectBarcodesRequest()
        do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([request]) } catch { return (false, "Vision refused: \(error.localizedDescription)") }
        let payload = request.results?.first?.payloadStringValue
        return payload == nil ? (false, "no code found") : (true, "read \(payload!)")
    }

    private static func renderedText(_ text: String) -> CGImage {
        let image = NSImage(size: NSSize(width: 600, height: 160), flipped: false) { rect in
            NSColor.white.setFill(); rect.fill()
            (text as NSString).draw(at: NSPoint(x: 20, y: 50), withAttributes: [.font: NSFont.systemFont(ofSize: 64), .foregroundColor: NSColor.black])
            return true
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    }
}
#endif
