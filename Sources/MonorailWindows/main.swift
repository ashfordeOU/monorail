// Monorail for Windows (docs/PLATFORMS.md, Phase 1, alpha): the shared engine on Win32.
//
//   MonorailWindows            run the engine on this desktop (Ctrl-C stops it)
//   MonorailWindows --ci-test  open Notepad windows and check the engine tiles and follows them
//                              (run by CI on GitHub's Windows machines); exits non-zero on failure
//   MonorailWindows --self-check  start far enough to prove this copy runs here (DLLs, displays,
//                              per-user settings), move nothing, exit 0 (CI runs it on the portable zip)
#if os(Windows)
import Foundation
import MonorailCore
import MonorailEngine
import WinSDK

setvbuf(stdout, nil, _IONBF, 0)
// Per-monitor DPI awareness (v2): positions are real pixels on every display, scaled or not.
if !ok(SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT(bitPattern: -4))) { _ = SetProcessDPIAware() }

if CommandLine.arguments.contains("--ci-test") {
    exit(WindowsUITest.run())
}
if CommandLine.arguments.contains("--self-check") {
    exit(WindowsSelfCheck.run())
}

// Settings: the Mac app's settings.json format, in %APPDATA%\Monorail. Edits are picked up live.
let settingsURL = WindowsSettings.url
SharedSettings.writeDefaultsIfMissing(to: settingsURL)
var settingsDate = WindowsSettings.modified(settingsURL)

let system = Win32WindowSystem()
let engine = SharedEngine(system: system)
let initial = SharedSettings.load(from: settingsURL)
engine.config = initial.layout
engine.floats = { initial.floats($0) }
system.start()
engine.start()

// Stay Awake (like Caffeine), kept in the same settings file under "stayAwake".
if !WindowsStayAwake.apply(StayAwakeSettings.load(from: settingsURL)) { print("Windows refused Stay Awake.") }
func changeStayAwake(_ change: (inout StayAwakeSettings) -> Void) {
    var settings = WindowsStayAwake.settings
    change(&settings)
    if !WindowsStayAwake.apply(settings) { print("Windows refused Stay Awake.") }
    if settings.save(to: settingsURL) { settingsDate = WindowsSettings.modified(settingsURL) }
    print(WindowsStayAwake.describe() + (settings.keepChatAvailable ? "" : " (chat apps not kept available)"))
}

WindowsTray.onCommand = { command in
    switch command {
    case .togglePause:
        if engine.isPaused { engine.resume() } else { engine.pause() }
        WindowsTray.isPaused = engine.isPaused
        print(engine.isPaused ? "Paused." : "Resumed.")
    case .openSettings:
        WindowsTray.open(settingsURL.path)
    case .reloadSettings:
        engine.apply(SharedSettings.load(from: settingsURL))
        WindowsStayAwake.apply(StayAwakeSettings.load(from: settingsURL))
        print("Settings reloaded.")
    case .awakeOff:
        changeStayAwake { $0.mode = .off }
    case .awakeHour:
        changeStayAwake { $0.mode = .until(Date().addingTimeInterval(3600)) }
    case .awakeUntilTurnedOff:
        changeStayAwake { $0.mode = .untilTurnedOff }
    case .awakeKeepChatAvailable:
        changeStayAwake { $0.keepChatAvailable.toggle() }
    case .quit:
        _ = SetThreadExecutionState(WindowsStayAwake.continuous)
        WindowsTray.hide()
        WindowsKeys.unregister()
        system.stop()
        exit(0)
    }
}
let hasTray = WindowsTray.show()
if !hasTray { print("No tray icon (the taskbar isn't running); Ctrl-C stops Monorail.") }
let missing = WindowsKeys.register()
Win32WindowSystem.onHotKey = { id in
    if let action = WindowsKeys.action(forHotKey: id) { engine.perform(action) }
}
for action in missing { print("Every shortcut for \(action.title) is taken by another app; it has no key.") }
print("Shortcuts: " + WindowsKeys.active.map { "\($0.label) \($0.action.title.lowercased())" }.joined(separator: " · "))
print("Monorail (Windows alpha) running on \(system.displays.count) display(s) with \(engine.displayOf.count) window(s). Ctrl-C stops it.")
print("Settings: \(settingsURL.path)")
// Opened by double-clicking Monorail.exe (the console window is ours alone, not a terminal's):
// let the console window go, like any tray app; the tray icon's menu quits.
var consoleProcesses = [DWORD](repeating: 0, count: 2)
if hasTray && GetConsoleProcessList(&consoleProcesses, 2) == 1 { _ = FreeConsole() }
while true {
    Win32WindowSystem.pump(for: 1)
    let date = WindowsSettings.modified(settingsURL)
    if date != settingsDate {
        settingsDate = date
        engine.apply(SharedSettings.load(from: settingsURL))
        WindowsStayAwake.apply(StayAwakeSettings.load(from: settingsURL))
        print("Settings changed; applied.")
    }
    if WindowsStayAwake.tick() {
        if WindowsStayAwake.settings.save(to: settingsURL) { settingsDate = WindowsSettings.modified(settingsURL) }
        print("Stay Awake's hour is up; the PC can sleep again.")
    }
}
#else
print("MonorailWindows is the Windows version; on this system, use Monorail.")
#endif
