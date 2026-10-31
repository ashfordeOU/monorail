#if os(macOS)
import AppKit
import MonorailCore

/// Settings → Basics → Import from another window manager: finds AeroSpace, yabai and
/// Rectangle settings on this Mac and turns them into Monorail shortcuts and rules.
enum Importer {
    static func available() -> [ImportPlan] {
        var plans: [ImportPlan] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        func read(_ paths: [String]) -> String? {
            for path in paths {
                if let text = try? String(contentsOf: home.appendingPathComponent(path), encoding: .utf8) { return text }
            }
            return nil
        }
        if let toml = read([".aerospace.toml", ".config/aerospace/aerospace.toml"]) {
            plans.append(ConfigImport.aeroSpace(toml))
        }
        let yabairc = read([".yabairc", ".config/yabai/yabairc"])
        let skhdrc = read([".skhdrc", ".config/skhd/skhdrc"])
        if yabairc != nil || skhdrc != nil {
            plans.append(ConfigImport.yabai(yabairc: yabairc ?? "", skhdrc: skhdrc ?? ""))
        }
        if let rectangle = UserDefaults.standard.persistentDomain(forName: "com.knollsoft.Rectangle"),
            !rectangle.isEmpty
        {
            plans.append(ConfigImport.rectangle(rectangle))
        }
        return plans.filter { !$0.isEmpty }
    }

    /// Asks which setup to import, then applies it.
    static func run(store: SettingsStore) {
        let plans = available()
        let alert = NSAlert()
        guard !plans.isEmpty else {
            alert.messageText = "No other window manager settings found"
            alert.informativeText = "Monorail looks for AeroSpace (aerospace.toml), yabai and skhd (.yabairc, .skhdrc) and Rectangle. Magnet and Amethyst don't save their settings in a form Monorail can read; set those shortcuts in Settings → Shortcuts."
            alert.runModal()
            return
        }
        alert.messageText = "Import your window manager settings"
        alert.informativeText = plans.map { "\($0.source): \($0.summary)" }.joined(separator: "\n")
            + "\n\nShortcuts replace Monorail's for the same actions. Undo by resetting shortcuts in Settings → Shortcuts."
        for plan in plans { alert.addButton(withTitle: "Import \(plan.source)") }
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let index = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard plans.indices.contains(index) else { return }
        let plan = plans[index]
        store.settings = apply(plan, to: store.settings)
        let done = NSAlert()
        done.messageText = "Imported from \(plan.source)"
        done.informativeText = plan.summary + (plan.skipped.isEmpty ? "" : "\n\nNot imported (no Monorail equivalent):\n" + plan.skipped.prefix(12).joined(separator: "\n"))
        done.runModal()
    }

    static func apply(_ plan: ImportPlan, to old: AppSettings) -> AppSettings {
        var settings = old
        if let gap = plan.gap { settings.layout.gap = gap }
        for (action, shortcut) in plan.bindings {
            // The key moves to its new action.
            for (other, list) in settings.keymap.bindings where list.contains(shortcut) {
                settings.keymap.bindings[other] = list.filter { $0 != shortcut }
            }
            settings.keymap.bindings[action] = [shortcut]
        }
        func rule(for app: String) -> Int {
            let bundle = bundleID(for: app)
            if let index = settings.appRules.firstIndex(where: { $0.bundleID == bundle && !$0.isTitleRule }) { return index }
            settings.appRules.append(AppRule(bundleID: bundle, name: UsageStats.appName(bundle)))
            return settings.appRules.count - 1
        }
        for app in plan.floatApps { settings.appRules[rule(for: app)].float = true }
        for (app, workspace) in plan.workspaceApps { settings.appRules[rule(for: app)].workspace = workspace - 1 }
        return settings
    }

    /// A bundle ID as written, or found from an app name.
    static func bundleID(for app: String) -> String {
        if app.contains("."), !app.contains(" ") { return app }
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName?.caseInsensitiveCompare(app) == .orderedSame }),
            let id = running.bundleIdentifier
        {
            return id
        }
        for folder in ["/Applications", "/System/Applications", "/System/Applications/Utilities", NSHomeDirectory() + "/Applications"] {
            if let id = Bundle(path: "\(folder)/\(app).app")?.bundleIdentifier { return id }
        }
        return app
    }
}
#endif
