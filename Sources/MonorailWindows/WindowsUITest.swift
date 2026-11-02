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

        // Everything the engine took over (the runner's desktop has windows of its own too).
        for (display, strip) in engine.strips {
            for id in strip.allWindows {
                let info = system.window(id)
                print("managed on \(display): \(id) \(info?.appName ?? "?") “\(info?.title ?? "")” \(info?.frame ?? Rect(x: 0, y: 0, width: 0, height: 0))")
            }
        }
        let tiled = ours(system, pids).sorted { $0.frame.x < $1.frame.x }
        check(tiled.count == 2 && tiled.allSatisfy { engine.isManaged($0.id) }, "the engine manages both")
        // The backend puts each window exactly where the engine asked (visible bounds, no invisible borders).
        for info in tiled {
            guard let wanted = engine.lastApplied[info.id] else { check(false, "the engine placed \(info.id)"); continue }
            check(info.frame.isClose(to: wanted, tolerance: 3), "window \(info.id) is where the engine put it (\(info.frame) vs \(wanted))")
        }
        if tiled.count == 2 {
            let (a, b) = (tiled[0].frame, tiled[1].frame)
            check(a.maxX <= b.x + 2, "side by side, not overlapping (\(a.maxX) ≤ \(b.x))")
            check(abs(a.width - b.width) < 4, "equal widths (\(Int(a.width)), \(Int(b.width)))")
            check(a.height > work.height * 0.8 && b.height > work.height * 0.8, "full height of the work area")
        }
        // Focusing one scrolls the strip until it's fully on screen.
        if let target = tiled.first {
            system.focus(target.id)
            Win32WindowSystem.pump(for: 1.5)
            let frame = system.window(target.id)?.frame ?? Rect(x: 0, y: 0, width: 0, height: 0)
            let slack = 3.0
            check(frame.x >= work.x - slack && frame.maxX <= work.maxX + slack && frame.y >= work.y - slack && frame.maxY <= work.maxY + slack,
                  "a focused window is fully inside the work area \(work) (\(frame))")
        }

        // Shortcuts: registered with Windows and pressed through its input system, like a person would.
        let refused = WindowsKeys.register()
        check(refused.isEmpty, "every shortcut registers (refused: \(refused.map(\.label)))")
        var pressed: [Action] = []
        Win32WindowSystem.onHotKey = { id in
            guard let action = WindowsKeys.action(forHotKey: id) else { return }
            pressed.append(action)
            engine.perform(action)
        }
        if let display = engine.activeDisplay, let before = engine.strips[display]?.focusedWindow,
            let right = WindowsKeys.defaults.first(where: { $0.action == .focusRight }),
            let left = WindowsKeys.defaults.first(where: { $0.action == .focusLeft })
        {
            WindowsKeys.press(right)
            Win32WindowSystem.pump(for: 1)
            let after = engine.strips[display]?.focusedWindow
            check(pressed.contains(.focusRight), "pressing \(right.label) reaches Monorail")
            check(after != before, "\(right.label) moves focus to the next slide (\(String(describing: before)) → \(String(describing: after)))")
            check(system.focusedWindow() == after, "and Windows focuses that window")
            WindowsKeys.press(left)
            Win32WindowSystem.pump(for: 1)
            check(engine.strips[display]?.focusedWindow == before, "\(left.label) comes back")
        }
        if let target = tiled.last {
            system.focus(target.id)
            Win32WindowSystem.pump(for: 0.5)
            let before = system.window(target.id)?.frame.width ?? 0
            check(engine.perform(.cycleWidth), "cycle width runs")
            Win32WindowSystem.pump(for: 0.8)
            let after = system.window(target.id)?.frame.width ?? 0
            check(abs(after - before) > 20, "and the window really changes width (\(Int(before)) → \(Int(after)))")
        }
        WindowsKeys.unregister()

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
