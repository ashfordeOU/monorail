#if os(macOS)
import AppKit
import MonorailCore
import MonorailEngine

/// `Monorail --shared-engine`: runs only the platform-free engine (MonorailEngine.SharedEngine) on
/// this Mac, through AXWindowSystem, with no menu bar item, settings or extras. It's how the core
/// the Windows and Linux versions share is tried on real windows before it ever replaces today's
/// engine. Quit the normal Monorail first; stop this one with Ctrl-C. Prints what it does.
enum SharedEngineRunner {
    static var isRequested: Bool { CommandLine.arguments.contains("--shared-engine") }

    static func run() -> Never {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        guard Accessibility.isTrusted(prompt: true) else {
            print("Monorail needs Accessibility access: System Settings → Privacy & Security → Accessibility.")
            exit(1)
        }
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })
        {
            print("Quit the running Monorail first: two window managers would fight over the same windows.")
            exit(1)
        }
        let system = AXWindowSystem()
        let engine = SharedEngine(system: system, config: AppSettings().layout(for: system.displays.first?.id ?? ""))
        system.start()
        engine.start()
        // Log what happens, then hand each event to the engine.
        system.onEvent = { [weak engine] event in
            print("event:", event)
            engine?.handle(event)
            if let engine {
                let counts = engine.strips.map { "\($0.key.prefix(8)): \($0.value.allWindows.count)" }.sorted()
                print("strips:", counts.joined(separator: ", "))
            }
        }
        print("Shared engine running on \(system.displays.count) display(s) with \(engine.displayOf.count) window(s). Ctrl-C stops it.")
        signal(SIGINT) { _ in
            print("\nStopped. Windows stay where they are; start Monorail to arrange them again.")
            exit(0)
        }
        NSApp.run()
        exit(0)
    }
}
#endif
