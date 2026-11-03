#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// `Monorail --render-screens <folder>`: draws the welcome tour and the What's New window to PNG
/// files, light and dark, so a new version's first-run screens can be checked before release (CI).
enum ScreenRender {
    static func run(into folder: URL) -> Int32 {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = SettingsStore()
        var notes: [String] = []
        if let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
            let changelog = try? String(contentsOf: url, encoding: .utf8)
        {
            notes = WhatsNew.section(for: Bundle.main.shortVersion, in: changelog)
            if notes.isEmpty { notes = WhatsNew.section(for: "Unreleased", in: changelog) }
        }
        var written = 0
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            let welcome = WelcomeView(store: store, practice: PracticeTracker()) {}
            if save(AnyView(welcome), width: 640, appearance: appearance, to: folder.appendingPathComponent("welcome-\(name).png")) {
                written += 1
            }
            let whatsNew = WhatsNewView(version: Bundle.main.shortVersion, lines: notes, store: store, offersSwitches: true,
                                        tryAction: { _ in }, close: {})
            if save(AnyView(whatsNew), width: 560, appearance: appearance, to: folder.appendingPathComponent("whats-new-\(name).png")) {
                written += 1
            }
        }
        print("Rendered \(written) screens into \(folder.path)")
        return written == 4 ? 0 : 1
    }

    private static func save(_ view: AnyView, width: CGFloat, appearance: NSAppearance.Name, to url: URL) -> Bool {
        let host = NSHostingView(rootView: view.frame(width: width).fixedSize(horizontal: false, vertical: true))
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 100)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        host.frame = NSRect(x: 0, y: 0, width: width, height: max(size.height, 100))
        host.layoutSubtreeIfNeeded()
        // Draw over the window background colour of that appearance.
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.backgroundColor = .windowBackgroundColor
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: url)) != nil
    }
}
#endif
