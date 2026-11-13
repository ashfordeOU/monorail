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
            let whatsNew = WhatsNewView(version: Bundle.main.shortVersion, section: notes, store: store, offersSwitches: true,
                                        tryAction: { _ in }, close: {})
            if save(AnyView(whatsNew), width: 620, appearance: appearance, to: folder.appendingPathComponent("whats-new-\(name).png")) {
                written += 1
            }
        }
        let extra = renderNewFeatures(into: folder, store: store)
        print("Rendered \(written + extra) screens into \(folder.path)")
        return written == 4 ? 0 : 1
    }

    /// The Dashboard's AI Usage page and the Tools window, with sample accounts and files.
    private static func renderNewFeatures(into folder: URL, store: SettingsStore) -> Int {
        var written = 0
        let accounts = [
            AIAccount(id: "claude", provider: .claude, label: "Claude"),
            AIAccount(id: "codex", provider: .codex, label: "Codex"),
            AIAccount(id: "ollama", provider: .ollama, label: "Ollama"),
            AIAccount(id: "openrouter", provider: .openrouter, label: "OpenRouter"),
            AIAccount(id: "hermes", provider: .hermes, label: "Hermes"),
            AIAccount(id: "lmstudio", provider: .lmstudio, label: "LM Studio"),
        ]
        var settings = store.settings
        settings.aiAccounts = accounts
        settings.aiLiveLimits = true
        store.settings = settings
        DashboardContext.store = store
        AIUsageWatch.shared.store = store
        AIUsageWatch.shared.preview(sampleReports())
        UserDefaults.standard.set(DashboardSection.ai.rawValue, forKey: "DashboardSection")
        let dashboard = VStack(alignment: .leading, spacing: 16) {
            Text("Dashboard").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white)
            SidebarDashboard().environment(\.colorScheme, .dark)
        }
        .padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 12)
        .background(LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.3), Color(red: 0.04, green: 0.06, blue: 0.16)], startPoint: .top, endPoint: .bottom))
        if save(AnyView(dashboard), width: 1240, height: 1320, appearance: .darkAqua, to: folder.appendingPathComponent("ai-usage.png")) { written += 1 }
        let editor = AIAccountEditor(account: AIAccount(provider: .openrouter, label: "OpenRouter"), isNew: true) {}
        if save(AnyView(editor), width: 460, appearance: .aqua, to: folder.appendingPathComponent("ai-add-account.png")) { written += 1 }

        ToolsPreview.on = true
        for (tool, file) in [(ToolKind.screenshotNames, "tools-screenshot-names"), (.qr, "tools-qr"), (.images, "tools-images"), (.password, "tools-password")] {
            UserDefaults.standard.set(tool.rawValue, forKey: "ToolsChoice")
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
                if save(AnyView(ToolsRoot()), width: 920, height: 600, appearance: appearance, to: folder.appendingPathComponent("\(file)-\(name).png")) { written += 1 }
            }
        }
        ToolsPreview.on = false

        // The new Dashboard pages: Switches, Time and Weather (sample weather), in the rail design.
        var shotSettings = store.settings
        shotSettings.worldClocks = ["America/New_York", "Asia/Tokyo", "Europe/Berlin"]
        store.settings = shotSettings
        for (section, file) in [(DashboardSection.switches, "switches"), (.time, "time")] {
            UserDefaults.standard.set(section.rawValue, forKey: "DashboardSection")
            let page = VStack(alignment: .leading, spacing: 16) {
                Text("Dashboard").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white)
                SidebarDashboard().environment(\.colorScheme, .dark)
            }
            .padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 12)
            .background(LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.3), Color(red: 0.04, green: 0.06, blue: 0.16)], startPoint: .top, endPoint: .bottom))
            if save(AnyView(page), width: 1240, height: 980, appearance: .darkAqua, to: folder.appendingPathComponent("\(file).png")) { written += 1 }
        }

        // The menu bar panel as it opens from the icon, at its real size.
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            let popover = SliderPopover()
            popover.store = store
            if let content = popover.contentForScreenshot(), saveView(content, width: 360, appearance: appearance, to: folder.appendingPathComponent("panel-\(name).png")) { written += 1 }
        }

        // The Clipboard window with a few of everything.
        ClipboardWatch.shared.preview(sampleClips())
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            if save(AnyView(ClipboardWindowRoot()), width: 1000, height: 680, appearance: appearance, to: folder.appendingPathComponent("clipboard-\(name).png")) { written += 1 }
        }
        return written
    }

    private static func sampleClips() -> ClipHistory {
        var h = ClipHistory(keep: 100)
        let now = Date()
        try? FileManager.default.createDirectory(at: ClipboardWatch.imagesFolder, withIntermediateDirectories: true)
        func picture(_ name: String, _ colours: [NSColor], _ size: NSSize) {
            let image = NSImage(size: size)
            image.lockFocus()
            NSGradient(colors: colours)?.draw(in: NSRect(origin: .zero, size: size), angle: 35)
            NSColor.white.withAlphaComponent(0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: size.width * 0.3, y: size.height * 0.25, width: size.width * 0.4, height: size.height * 0.5)).fill()
            image.unlockFocus()
            if let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: ClipboardWatch.imagesFolder.appendingPathComponent(name))
            }
        }
        picture("sample-a.png", [.systemPink, .systemOrange], NSSize(width: 800, height: 500))
        picture("sample-b.png", [.systemTeal, .systemBlue], NSSize(width: 600, height: 600))
        let items: [(String, String?, Double)] = [
            ("https://monorail.ashforde.org/docs/clipboard", "Safari", 60),
            ("#FF5A7A", "Figma", 300),
            ("func paste(_ clip: Clip) {\n    board.write(clip)\n}", "Xcode", 900),
            ("Lunch with Sam on Thursday at the Barbican, 1pm", "Messages", 1800),
            ("hello@ashforde.org", "Mail", 4000),
            ("+44 20 7946 0958", "Contacts", 7000),
        ]
        for (text, app, ago) in items.reversed() { h.add(text, app: app, at: now.addingTimeInterval(-ago)) }
        h.add("sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123", app: "Terminal", at: now.addingTimeInterval(-120), sensitive: "Anthropic key")
        h.addImage(file: "sample-b.png", digest: "b", width: 600, height: 600, app: "Preview", at: now.addingTimeInterval(-200))
        h.addImage(file: "sample-a.png", digest: "a", width: 800, height: 500, app: "Safari", at: now.addingTimeInterval(-30))
        h.addFiles(["/Applications/Safari.app", "/System/Applications/Notes.app"], app: "Finder", at: now.addingTimeInterval(-2500))
        if let link = h.clips.first(where: { $0.kind == .link }) { h.addToBoard(link.id, board: "Lisbon trip"); h.setTags(link.id, ["docs"]) }
        if let image = h.clips.first(where: { $0.kind == .image }) { h.addToBoard(image.id, board: "Lisbon trip") }
        if let colour = h.clips.first(where: { $0.kind == .colour }) { h.togglePin(colour.id); h.addToBoard(colour.id, board: "Brand") }
        return h
    }

    private static func sampleReports() -> [String: AIReport] {
        let now = Date()
        func days(_ base: Int, _ spread: Int, cost: Double) -> [String: TokenTotals] {
            var d: [String: TokenTotals] = [:]
            for back in 0..<30 {
                let key = UsageLedger.dayKey(now.addingTimeInterval(Double(-back) * 86400))
                let wobble = (back * 37 % 11) - 5
                let total = max(0, base + wobble * spread / 5 - (back % 7 == 5 || back % 7 == 6 ? base / 2 : 0))
                d[key] = TokenTotals(input: total / 20, output: total / 15, cacheRead: total * 3 / 4, cacheWrite: total / 10, cost: Double(total) / 1_000_000 * cost, requests: total / 9000)
            }
            return d
        }
        func sum(_ d: [String: TokenTotals]) -> TokenTotals { var t = TokenTotals(); for (_, v) in d { t.add(v) }; return t }

        var claude = AIReport(accountID: "claude")
        claude.plan = "Max"
        claude.windows = [UsageWindow(name: "Session", usedPercent: 64, resetsAt: now.addingTimeInterval(2 * 3600 + 900), length: 5 * 3600),
                          UsageWindow(name: "Week", usedPercent: 41, resetsAt: now.addingTimeInterval(3 * 86400 + 4 * 3600), length: 7 * 86400),
                          UsageWindow(name: "Opus week", usedPercent: 78, resetsAt: now.addingTimeInterval(3 * 86400 + 4 * 3600), length: 7 * 86400)]
        claude.daily = days(9_000_000, 4_000_000, cost: 1.1)
        claude.month = sum(claude.daily)
        claude.today = claude.daily[UsageLedger.dayKey(now)] ?? TokenTotals()
        claude.topModel = "claude-opus-5-5"
        claude.contexts = [ContextReading(session: "a", project: "monorail", model: "claude-opus-5-5", used: 612_000, window: 1_000_000, at: now),
                           ContextReading(session: "b", project: "site", model: "claude-sonnet-5-5", used: 148_000, window: 1_000_000, at: now)]

        var codex = AIReport(accountID: "codex")
        codex.plan = "Plus"
        codex.windows = [UsageWindow(name: "Session", usedPercent: 22, resetsAt: now.addingTimeInterval(4 * 3600), length: 5 * 3600),
                         UsageWindow(name: "Week", usedPercent: 57, resetsAt: now.addingTimeInterval(2 * 86400), length: 7 * 86400)]
        codex.daily = days(3_000_000, 2_000_000, cost: 0.9)
        codex.month = sum(codex.daily)
        codex.today = codex.daily[UsageLedger.dayKey(now)] ?? TokenTotals()
        codex.topModel = "gpt-5-codex"
        codex.contexts = [ContextReading(session: "c", project: "windows", model: "gpt-5-codex", used: 231_000, window: 272_000, at: now)]

        var ollama = AIReport(accountID: "ollama")
        ollama.models = [LocalModel(name: "qwen3:30b", loaded: true, sizeBytes: 19_000_000_000, vramBytes: 18_600_000_000, contextLength: 40_960),
                         LocalModel(name: "llama3.3:70b", loaded: false, sizeBytes: 42_000_000_000),
                         LocalModel(name: "gemma3:12b", loaded: false, sizeBytes: 8_100_000_000)]

        var openrouter = AIReport(accountID: "openrouter")
        openrouter.spent = 31.4
        openrouter.limit = 50
        openrouter.balance = 18.6

        var hermes = AIReport(accountID: "hermes")
        hermes.daily = days(800_000, 600_000, cost: 0)
        hermes.month = sum(hermes.daily)
        hermes.today = hermes.daily[UsageLedger.dayKey(now)] ?? TokenTotals()
        hermes.topModel = "hermes-4-405b"

        var lmstudio = AIReport(accountID: "lmstudio")
        lmstudio.models = [LocalModel(name: "openai/gpt-oss-20b", loaded: true, contextLength: 32_768),
                           LocalModel(name: "mistral-small-3.2", loaded: false, contextLength: 131_072)]

        return ["claude": claude, "codex": codex, "ollama": ollama, "openrouter": openrouter, "hermes": hermes, "lmstudio": lmstudio]
    }

    /// An AppKit view at its fitting height, over the window colour of that appearance.
    private static func saveView(_ view: NSView, width: CGFloat, appearance: NSAppearance.Name, to url: URL) -> Bool {
        view.appearance = NSAppearance(named: appearance)
        view.frame = NSRect(x: 0, y: 0, width: width, height: 200)
        view.layoutSubtreeIfNeeded()
        let height = max(view.fittingSize.height, 200)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.backgroundColor = .windowBackgroundColor
        window.contentView = view
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: url)) != nil
    }

    private static func save(_ view: AnyView, width: CGFloat, height: CGFloat? = nil, appearance: NSAppearance.Name, to url: URL) -> Bool {
        let framed: AnyView = height.map { AnyView(view.frame(width: width, height: $0)) } ?? AnyView(view.frame(width: width).fixedSize(horizontal: false, vertical: true))
        let host = NSHostingView(rootView: framed)
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 100)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        host.frame = NSRect(x: 0, y: 0, width: width, height: height ?? max(size.height, 100))
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
