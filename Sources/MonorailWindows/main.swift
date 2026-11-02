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
_ = SetProcessDPIAware()

if CommandLine.arguments.contains("--ci-test") {
    exit(WindowsUITest.run())
}

let system = Win32WindowSystem()
let engine = SharedEngine(system: system)
system.start()
engine.start()
print("Monorail (Windows alpha) running on \(system.displays.count) display(s) with \(engine.displayOf.count) window(s). Ctrl-C stops it.")
while true { Win32WindowSystem.pump(for: 1) }
#else
print("MonorailWindows is the Windows version; on this system, use Monorail.")
#endif
