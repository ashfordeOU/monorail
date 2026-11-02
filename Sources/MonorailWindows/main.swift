// Monorail for Windows (docs/PLATFORMS.md, Phase 1, alpha): the shared engine on Win32.
//
//   MonorailWindows            run the engine on this desktop (Ctrl-C stops it)
//   MonorailWindows --ci-test  open Notepad windows and check the engine tiles and follows them
//                              (run by CI on GitHub's Windows machines); exits non-zero on failure
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

let system = Win32WindowSystem()
let engine = SharedEngine(system: system)
system.start()
engine.start()
let refused = WindowsKeys.register()
Win32WindowSystem.onHotKey = { id in
    if let action = WindowsKeys.action(forHotKey: id) { engine.perform(action) }
}
for binding in refused { print("Shortcut \(binding.label) is taken by another app; \(binding.action.title) has no key.") }
print("Shortcuts: " + WindowsKeys.defaults.map { "\($0.label) \($0.action.title.lowercased())" }.joined(separator: " · "))
print("Monorail (Windows alpha) running on \(system.displays.count) display(s) with \(engine.displayOf.count) window(s). Ctrl-C stops it.")
while true { Win32WindowSystem.pump(for: 1) }
#else
print("MonorailWindows is the Windows version; on this system, use Monorail.")
#endif
