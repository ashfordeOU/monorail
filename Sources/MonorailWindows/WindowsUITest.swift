#if os(Windows)
import Foundation
import MonorailCore
import MonorailEngine
import WinSDK

/// The Windows end-to-end check, run by CI on GitHub's Windows runners (which have a real desktop):
/// real Notepad windows, the real Win32 backend and the shared engine. Writes what it saw to
/// windows-ui-test.json and returns 0 when every check passes.
enum WindowsUITest {
    private static var failures: [String] = []
    private static var log: [String] = []

    private static func check(_ ok: Bool, _ what: String) {
        log.append("\(ok ? "ok  " : "FAIL") \(what)")
        print(ok ? "ok   \(what)" : "FAIL \(what)")
        if !ok { failures.append(what) }
    }

    private static func notepad() -> Foundation.Process? {
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\notepad.exe")
        do { try process.run() } catch { print("could not start Notepad: \(error)"); return nil }
        return process
    }

    /// The tileable windows of the Notepads we started.
    private static func ours(_ system: Win32WindowSystem, _ pids: Set<Int32>) -> [WindowInfo] {
        system.windows().filter { info in
            guard info.isTileable, let hwnd = Win32WindowSystem.hwnd(info.id) else { return false }
            var pid: DWORD = 0
            GetWindowThreadProcessId(hwnd, &pid)
            return pids.contains(Int32(bitPattern: pid))
        }
    }

    private static func waitFor(_ count: Int, _ system: Win32WindowSystem, _ pids: Set<Int32>, seconds: Double = 10) -> [WindowInfo] {
        let end = Date().addingTimeInterval(seconds)
        var found = ours(system, pids)
        while found.count < count, Date() < end {
            Win32WindowSystem.pump(for: 0.25)
            found = ours(system, pids)
        }
        return found
    }

    static func run() -> Int32 {
        let system = Win32WindowSystem()
        let displays = system.displays
        print("displays: \(displays.map { "\($0.id) \(Int($0.frame.width))x\(Int($0.frame.height)) work \($0.visibleFrame)" })")
        check(!displays.isEmpty, "Win32 reports at least one display")
        guard let display = displays.first else { return finish([]) }
        let work = display.visibleFrame

        var processes: [Foundation.Process] = []
        for _ in 0..<2 { if let p = notepad() { processes.append(p) } }
        var pids = Set(processes.map(\.processIdentifier))
        let first = waitFor(2, system, pids)
        check(first.count == 2, "two Notepad windows are seen as tileable (saw \(first.count))")

        let engine = SharedEngine(system: system)
        system.start()
        engine.start()
        Win32WindowSystem.pump(for: 1.5)

        let tiled = ours(system, pids).sorted { $0.frame.x < $1.frame.x }
        for info in tiled { print("window \(info.id) \(info.appName) \(info.frame)") }
        check(tiled.allSatisfy { engine.isManaged($0.id) }, "the engine manages both")
        if tiled.count == 2 {
            let (a, b) = (tiled[0].frame, tiled[1].frame)
            let slack = 12.0
            check([a, b].allSatisfy { $0.x >= work.x - slack && $0.maxX <= work.maxX + slack && $0.y >= work.y - slack && $0.maxY <= work.maxY + slack },
                  "both sit inside the work area \(work)")
            check(a.maxX <= b.x + slack, "side by side, not overlapping (\(a.maxX) ≤ \(b.x))")
            check(abs(a.width - b.width) < 24, "equal widths (\(Int(a.width)), \(Int(b.width)))")
            check(a.height > work.height * 0.8 && b.height > work.height * 0.8, "full height of the work area")
        }

        // A new window arrives through SetWinEventHook and joins the strip.
        if let p = notepad() { processes.append(p); pids.insert(p.processIdentifier) }
        _ = waitFor(3, system, pids)
        Win32WindowSystem.pump(for: 1.5)
        let afterOpen = ours(system, pids)
        check(afterOpen.count == 3 && afterOpen.allSatisfy { engine.isManaged($0.id) },
              "a newly opened window is adopted from its event (\(afterOpen.filter { engine.isManaged($0.id) }.count) of \(afterOpen.count))")

        // Closing one: the engine lets it go.
        if let victim = afterOpen.first {
            system.close(victim.id)
            Win32WindowSystem.pump(for: 2)
            check(!engine.isManaged(victim.id), "a closed window leaves the strip")
            check(engine.strips.values.reduce(0) { $0 + $1.allWindows.count } >= 2, "the others stay tiled")
        }

        system.stop()
        for p in processes where p.isRunning { p.terminate() }
        return finish(tiled)
    }

    private static func finish(_ tiled: [WindowInfo]) -> Int32 {
        let summary: [String: Any] = [
            "passed": failures.isEmpty,
            "failures": failures,
            "log": log,
            "windows": tiled.map { ["id": Int($0.id), "app": $0.appName, "frame": [$0.frame.x, $0.frame.y, $0.frame.width, $0.frame.height]] },
        ]
        if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
            FileManager.default.createFile(atPath: "windows-ui-test.json", contents: data)
        }
        print(failures.isEmpty ? "Windows UI test passed." : "Windows UI test FAILED: \(failures.joined(separator: "; "))")
        return failures.isEmpty ? 0 : 1
    }
}
#endif
