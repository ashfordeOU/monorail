#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// What the switches need from the rest of the app (set by the app delegate).
enum SwitchContext {
    static var store: SettingsStore?
    static var awakeIsOn: () -> Bool = { false }
    static var awakeSet: (Bool) -> Void = { _ in }
    static var sharingScreen: () -> Bool = { false }
}

/// Flips switches and runs actions; reads each switch's state back from the system.
final class Switchboard: ObservableObject {
    static let shared = Switchboard()

    @Published private(set) var states: [String: Bool] = [:]
    @Published private(set) var activeModes: [String] = []
    @Published var message: String?

    /// What each running mode changed, to put back when it stops.
    private var remembered: [String: [String: Bool]] = [:]
    private var manual: Set<String> = []
    private var timer: Timer?
    private var settings: AppSettings { SwitchContext.store?.settings ?? AppSettings() }

    private static var dndKey = "SwitchDoNotDisturb"

    func start() {
        refresh()
        guard timer == nil else { return }
        timer = Timer.every(15) { [weak self] _ in
            self?.refresh()
            self?.checkTriggers()
        }
        timer?.tolerance = 5
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in self?.checkTriggers() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in self?.checkTriggers() }
    }

    var catalogue: [SwitchDef] {
        var list = SwitchCatalogue.available(appStore: Edition.isAppStore)
        for custom in settings.customSwitches where !Edition.isAppStore || custom.onCommand.isEmpty || !custom.onShortcut.isEmpty {
            list.append(SwitchDef(custom.switchID, custom.title, .custom, custom.symbol, action: custom.isAction, signalbox: true, "Your switch"))
        }
        return list
    }

    // MARK: Reading

    func refresh() {
        var s: [String: Bool] = [:]
        s["darkMode"] = (Self.global("AppleInterfaceStyle") as? String) == "Dark"
        s["evening"] = settings.eveningOn
        s["backdrop"] = Backdrop.shared.isShown
        s["keepAwake"] = SwitchContext.awakeIsOn()
        s["mute"] = SoundControl.shared.muted
        s["doNotDisturb"] = UserDefaults.standard.bool(forKey: Self.dndKey)
        s["lockKeyboard"] = KeyboardLockSwitch.isOn
        if !Edition.isAppStore {
            s["hideDesktopIcons"] = (Self.app("CreateDesktop", "com.apple.finder") as? Bool) == false
            s["hideDock"] = (Self.app("autohide", "com.apple.dock") as? Bool) ?? false
            s["hideMenuBar"] = (Self.global("_HIHideMenuBar") as? Bool) ?? false
            s["showHiddenFiles"] = Self.truthy(Self.app("AppleShowAllFiles", "com.apple.finder"))
            s["showExtensions"] = (Self.global("AppleShowAllExtensions") as? Bool) ?? false
            s["pathBar"] = (Self.app("ShowPathbar", "com.apple.finder") as? Bool) ?? false
            s["statusBar"] = (Self.app("ShowStatusBar", "com.apple.finder") as? Bool) ?? false
            s["foldersFirst"] = (Self.app("_FXSortFoldersFirst", "com.apple.finder") as? Bool) ?? false
            s["trashWarning"] = (Self.app("WarnOnEmptyTrash", "com.apple.finder") as? Bool) ?? true
            s["fastKeyRepeat"] = ((Self.global("KeyRepeat") as? Int) ?? 6) <= 2
        }
        for custom in settings.customSwitches where !custom.isAction {
            s[custom.switchID] = customState(custom)
        }
        if s != states { states = s }
    }

    private static func global(_ key: String) -> Any? { CFPreferencesCopyAppValue(key as CFString, kCFPreferencesAnyApplication) }
    private static func app(_ key: String, _ domain: String) -> Any? { CFPreferencesCopyAppValue(key as CFString, domain as CFString) }
    private static func truthy(_ value: Any?) -> Bool {
        if let b = value as? Bool { return b }
        if let s = value as? String { return ["1", "yes", "true"].contains(s.lowercased()) }
        return false
    }

    // MARK: Changing

    func toggle(_ id: String) {
        if let def = catalogue.first(where: { $0.id == id }), def.isAction { run(id); return }
        set(id, !(states[id] ?? false))
    }

    func set(_ id: String, _ on: Bool) {
        switch id {
        case "darkMode": appleScript("tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
        case "evening": SwitchContext.store?.settings.eveningOn = on
        case "backdrop": on ? Backdrop.shared.show(colour: settings.backdropColour) : Backdrop.shared.hide()
        case "keepAwake": SwitchContext.awakeSet(on)
        case "mute": if SoundControl.shared.muted != on { SoundControl.shared.toggleMute() }
        case "lockKeyboard": on ? KeyboardLockSwitch.start() : KeyboardLockSwitch.stop()
        case "doNotDisturb":
            runShortcut(on ? "Focus On" : "Focus Off")
            UserDefaults.standard.set(on, forKey: Self.dndKey)
        case "hideDesktopIcons": defaults(["write", "com.apple.finder", "CreateDesktop", "-bool", on ? "false" : "true"], restart: "Finder")
        case "hideDock": appleScript("tell application \"System Events\" to set autohide of dock preferences to \(on)")
        case "hideMenuBar": appleScript("tell application \"System Events\" to set autohide menu bar of dock preferences to \(on)")
        case "showHiddenFiles": defaults(["write", "com.apple.finder", "AppleShowAllFiles", "-bool", "\(on)"], restart: "Finder")
        case "showExtensions": defaults(["write", "-g", "AppleShowAllExtensions", "-bool", "\(on)"], restart: "Finder")
        case "pathBar": defaults(["write", "com.apple.finder", "ShowPathbar", "-bool", "\(on)"], restart: "Finder")
        case "statusBar": defaults(["write", "com.apple.finder", "ShowStatusBar", "-bool", "\(on)"], restart: "Finder")
        case "foldersFirst": defaults(["write", "com.apple.finder", "_FXSortFoldersFirst", "-bool", "\(on)"], restart: "Finder")
        case "trashWarning": defaults(["write", "com.apple.finder", "WarnOnEmptyTrash", "-bool", "\(on)"], restart: "Finder")
        case "fastKeyRepeat":
            defaults(["write", "-g", "KeyRepeat", "-int", on ? "2" : "6"], restart: nil)
            defaults(["write", "-g", "InitialKeyRepeat", "-int", on ? "15" : "25"], restart: nil)
            message = "Key repeat changes after you log out and in again."
        default:
            if let custom = settings.customSwitches.first(where: { $0.switchID == id }) { runCustom(custom, on: on) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.refresh() }
    }

    func run(_ id: String) {
        switch id {
        case "emptyTrash": appleScript("tell application \"Finder\" to empty trash")
        case "ejectAll":
            let result = Ejector.ejectAll()
            message = result.done == 0 && result.busy.isEmpty ? "Nothing to eject." : "Ejected \(result.done)." + (result.busy.isEmpty ? "" : " In use: " + result.busy.joined(separator: ", "))
        case "restartFinder": shell("/usr/bin/killall", ["Finder"])
        case "restartDock": shell("/usr/bin/killall", ["Dock"])
        case "flushDNS": appleScript("do shell script \"dscacheutil -flushcache; killall -HUP mDNSResponder\" with administrator privileges")
        case "plainPaste": ClipboardWatch.shared.makeClipboardPlain()
        case "screenSaver": NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
        case "sleepDisplays": shell("/usr/bin/pmset", ["displaysleepnow"])
        default:
            if let custom = settings.customSwitches.first(where: { $0.switchID == id }) { runCustom(custom, on: true) }
        }
    }

    private func defaults(_ args: [String], restart: String?) {
        shell("/usr/bin/defaults", args)
        if let restart { shell("/usr/bin/killall", [restart]) }
    }

    @discardableResult
    private func shell(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        guard !Edition.isAppStore else { return (-1, "") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return (-1, "") }
        process.waitUntilExit()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (process.terminationStatus, out)
    }

    private func appleScript(_ source: String) {
        guard !Edition.isAppStore else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error {
                let text = (error[NSAppleScript.errorMessage] as? String) ?? "macOS said no."
                DispatchQueue.main.async {
                    self.message = text.contains("Not authorised") || text.contains("not allowed")
                        ? "Allow \(Brand.name) to control System Events and Finder in System Settings → Privacy & Security → Automation."
                        : text
                }
            }
            DispatchQueue.main.async { self.refresh() }
        }
    }

    /// A shortcut from the Shortcuts app: run directly in Monorail, through the Shortcuts app in Signalbox.
    func runShortcut(_ name: String) {
        if Edition.isAppStore {
            var parts = URLComponents(string: "shortcuts://run-shortcut")!
            parts.queryItems = [URLQueryItem(name: "name", value: name)]
            if let url = parts.url { NSWorkspace.shared.open(url) }
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.shell("/usr/bin/shortcuts", ["run", name])
                if result.status != 0 {
                    DispatchQueue.main.async { self.message = "Add a shortcut called \"\(name)\" in the Shortcuts app (it can set a Focus), then try again." }
                }
            }
        }
    }

    private func runCustom(_ custom: CustomSwitch, on: Bool) {
        let shortcut = on ? custom.onShortcut : custom.offShortcut
        if !shortcut.isEmpty { runShortcut(shortcut); return }
        let command = on ? custom.onCommand : custom.offCommand
        guard !command.isEmpty, !Edition.isAppStore else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.shell("/bin/zsh", ["-lc", command])
            DispatchQueue.main.async {
                if result.status != 0 { self.message = "\(custom.title) didn't work (exit \(result.status))." }
                self.refresh()
            }
        }
    }

    private func customState(_ custom: CustomSwitch) -> Bool {
        guard !custom.stateCommand.isEmpty, !Edition.isAppStore else { return states[custom.switchID] ?? false }
        let result = shell("/bin/zsh", ["-lc", custom.stateCommand])
        return result.status == 0 && !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Modes

    func isActive(_ mode: Mode) -> Bool { activeModes.contains(mode.id) }

    func toggleMode(_ mode: Mode) {
        if isActive(mode) { stopMode(mode.id); manual.remove(mode.id) } else { startMode(mode); manual.insert(mode.id) }
    }

    func startMode(_ mode: Mode) {
        guard !activeModes.contains(mode.id) else { return }
        refresh()
        let plan = ModePlanner.start(mode, current: states)
        remembered[mode.id] = plan.remember
        for (id, on) in plan.set {
            if SwitchCatalogue.find(id)?.isAction == true { run(id) } else { set(id, on) }
        }
        activeModes.append(mode.id)
    }

    func stopMode(_ id: String) {
        guard let index = activeModes.firstIndex(of: id) else { return }
        activeModes.remove(at: index)
        var stillWanted: [String: Bool] = [:]
        for other in settings.modes where activeModes.contains(other.id) { for (k, v) in other.switches { stillWanted[k] = v } }
        for (switchID, before) in ModePlanner.stop(remembered: remembered[id] ?? [:], stillWanted: stillWanted) { set(switchID, before) }
        remembered[id] = nil
    }

    /// Starts and stops modes whose triggers changed (manual starts are left alone).
    func checkTriggers() {
        let modes = settings.modes
        guard modes.contains(where: { $0.enabled && !$0.triggers.isEmpty }) else { return }
        let now = ModeContext.at(Date())
        let meeting = TodayWatch.shared.meetings.contains { $0.start <= Date() && $0.end > Date() }
        let context = ModeContext(runningApps: Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)),
                                  sharingScreen: SwitchContext.sharingScreen(), displays: NSScreen.screens.map(\.localizedName),
                                  onBattery: PowerWatch.shared.battery.onBattery, weekday: now.weekday, minutes: now.minutes, inMeeting: meeting)
        let wanted = ModePlanner.triggered(modes, context: context)
        for mode in modes where wanted.contains(mode.id) && !activeModes.contains(mode.id) { startMode(mode) }
        for id in activeModes where !wanted.contains(id) && !manual.contains(id) {
            if let mode = modes.first(where: { $0.id == id }), !mode.triggers.isEmpty { stopMode(id) }
        }
    }

    /// When the screen starts or stops being shared.
    func sharingChanged() { checkTriggers() }
}

/// Lock the Keyboard as a switch: on for a minute at most.
enum KeyboardLockSwitch {
    private(set) static var isOn = false
    private static var timer: Timer?

    static func start() {
        guard KeyboardLock.start() else { Switchboard.shared.message = "Locking the keyboard needs Accessibility."; return }
        isOn = true
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { _ in stop() }
    }

    static func stop() {
        KeyboardLock.stop()
        timer?.invalidate()
        timer = nil
        isOn = false
        Switchboard.shared.refresh()
    }
}

enum Ejector {
    static func ejectAll() -> (done: Int, busy: [String]) {
        var done = 0, busy: [String] = []
        let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey, .volumeNameKey]
        for url in FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? [] {
            guard url.path != "/", let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.volumeIsEjectable == true || v.volumeIsRemovable == true || v.volumeIsInternal == false else { continue }
            do { try NSWorkspace.shared.unmountAndEjectDevice(at: url); done += 1 } catch { busy.append(v.volumeName ?? url.lastPathComponent) }
        }
        return (done, busy)
    }
}

/// A calm colour behind every window, covering the desktop and its icons, on every display.
final class Backdrop {
    static let shared = Backdrop()
    private var windows: [NSWindow] = []
    var isShown: Bool { !windows.isEmpty }

    func show(colour hex: String) {
        hide()
        let colour = NSColor(hex: hex) ?? NSColor(red: 0.12, green: 0.13, blue: 0.21, alpha: 1)
        for screen in NSScreen.screens {
            let w = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            w.ignoresMouseEvents = true
            w.isReleasedWhenClosed = false
            w.backgroundColor = colour
            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            windows.append(w)
        }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }
}

// MARK: - The Switches page (Dashboard)

struct SwitchesSection: View {
    @ObservedObject private var board = Switchboard.shared
    @State private var editingMode: Mode?
    @State private var editingSwitch: CustomSwitch?

    var body: some View {
        let store = DashboardContext.store
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Switches").font(.system(size: 22, weight: .bold))
                    Text("System settings and quick actions in one click, and modes that set several at once").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { editingSwitch = CustomSwitch(title: "") } label: { Label("New Switch", systemImage: "plus") }
            }
            if let message = board.message {
                HStack {
                    Image(systemName: "info.circle").foregroundStyle(Color(nsColor: .systemOrange))
                    Text(message).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("OK") { board.message = nil }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.07)))
            }
            if let store { modes(store) }
            ForEach(SwitchGroup.allCases, id: \.self) { group in
                let items = board.catalogue.filter { $0.group == group }
                if !items.isEmpty {
                    DashCard(title: group.rawValue) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 10)], spacing: 10) {
                            ForEach(items) { item in tile(item, store: store) }
                        }
                    }
                }
            }
            if let store {
                DashCard(title: "Island") {
                    Toggle("The island: what's happening at the top of the screen (beside the notch, or a pill on Macs without one), with a shelf for files", isOn: Binding(
                        get: { store.settings.notchLive }, set: { store.settings.notchLive = $0 }))
                    Toggle("Show the volume in the island as it changes", isOn: Binding(
                        get: { store.settings.volumeHUD }, set: { store.settings.volumeHUD = $0 }))
                        .disabled(!store.settings.notchLive)
                    if NSScreen.screens.contains(where: { $0.safeAreaInsets.top > 0 }) {
                        Toggle("Push the pointer into the notch to open the clipboard", isOn: Binding(
                            get: { store.settings.clipboardNotch }, set: { store.settings.clipboardNotch = $0 }))
                    }
                    Text("Nothing shows while nothing's happening. Rest the pointer on it to open it; drag files to it to keep them. The Island toggle on Home turns it on and off.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .font(.system(size: 12.5))
            }
            if Edition.isAppStore {
                Text("Monorail, the free download, adds Finder, Dock, menu bar, keyboard and Trash switches, which the App Store's sandbox doesn't allow.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
        }
        .sectionScroll()
        .onAppear { board.start() }
        .sheet(item: $editingMode) { mode in
            if let store { ModeEditor(mode: mode, store: store) { editingMode = nil } }
        }
        .sheet(item: $editingSwitch) { custom in
            if let store { CustomSwitchEditor(custom: custom, store: store) { editingSwitch = nil } }
        }
    }

    private func modes(_ store: SettingsStore) -> some View {
        DashCard(title: "Modes", trailing: "Start one by hand, or let it start by itself") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                ForEach(store.settings.modes) { mode in
                    let active = board.isActive(mode)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: mode.symbol).font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(active ? Color.white : Color(nsColor: .systemOrange))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(active ? Color(nsColor: .systemOrange) : Color.white.opacity(0.08)))
                            Text(mode.name).font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Button(active ? "Stop" : "Start") { board.toggleMode(mode) }.controlSize(.small)
                        }
                        Text(mode.switches.keys.sorted().compactMap { SwitchCatalogue.find($0)?.title }.joined(separator: " · "))
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                        HStack {
                            Text(mode.triggers.isEmpty ? "By hand" : (mode.enabled ? "Auto: " : "Auto off: ") + mode.triggers.map(\.title).joined(separator: ", "))
                                .font(.system(size: 11)).foregroundStyle(mode.enabled && !mode.triggers.isEmpty ? Color(nsColor: .systemGreen) : .secondary).lineLimit(1)
                            Spacer()
                            Button("Edit") { editingMode = mode }.buttonStyle(.link).font(.system(size: 11))
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(active ? Color(nsColor: .systemOrange).opacity(0.15) : Color.white.opacity(0.05)))
                }
                Button { editingMode = Mode(name: "New Mode") } label: {
                    Label("New Mode", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 70)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4])))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tile(_ item: SwitchDef, store: SettingsStore?) -> some View {
        let on = board.states[item.id] ?? false
        return Button { board.toggle(item.id) } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(on ? Color.white : Color.primary.opacity(0.8))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(on ? Color(nsColor: .systemOrange) : Color.white.opacity(0.08)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(.system(size: 12.5, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
                    Text(item.isAction ? "Run" : (on ? "On" : "Off")).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(on ? 0.1 : 0.04)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.about)
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(Text(item.isAction ? "" : (on ? "On" : "Off")))
        .contextMenu {
            if item.group == .custom, let store, let custom = store.settings.customSwitches.first(where: { $0.switchID == item.id }) {
                Button("Edit…") { editingSwitch = custom }
                Button("Delete") { store.settings.customSwitches.removeAll { $0.id == custom.id } }
            }
        }
    }
}

/// Make or change a mode: which switches, and what starts it.
struct ModeEditor: View {
    @State var mode: Mode
    @ObservedObject var store: SettingsStore
    let close: () -> Void
    @State private var app = ""
    @State private var display = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode.name.isEmpty ? "New Mode" : mode.name).font(.system(size: 17, weight: .bold))
            Form {
                TextField("Name", text: $mode.name)
                Section("While it's on") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Switchboard.shared.catalogue) { item in
                                Toggle(item.isAction ? "\(item.title) (once, when it starts)" : item.title, isOn: Binding(
                                    get: { mode.switches[item.id] == true },
                                    set: { mode.switches[item.id] = $0 ? true : nil }))
                            }
                        }
                    }
                    .frame(height: 200)
                }
                Section("Start by itself") {
                    Toggle("Start and stop by itself", isOn: $mode.enabled)
                    ForEach(Array(mode.triggers.enumerated()), id: \.offset) { index, trigger in
                        HStack {
                            Text(trigger.title)
                            Spacer()
                            Button("Remove") { mode.triggers.remove(at: index) }.buttonStyle(.link)
                        }
                    }
                    Menu("Add a Trigger") {
                        Button("While the screen is shared or recorded") { add(.screenShare) }
                        Button("During calendar meetings") { add(.inMeeting) }
                        Button("On battery") { add(.onBattery) }
                        Button("Plugged in") { add(.onPower) }
                        Button("Weekdays 9:00–17:00") { add(.schedule(days: [2, 3, 4, 5, 6], start: 540, end: 1020)) }
                        Button("Every evening 21:00–07:00") { add(.schedule(days: [1, 2, 3, 4, 5, 6, 7], start: 1260, end: 420)) }
                        Divider()
                        Button("When an App Is Open…") {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.application]
                            panel.directoryURL = URL(fileURLWithPath: "/Applications")
                            if panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier { add(.app(id)) }
                        }
                        Menu("When a Display Is Connected") {
                            ForEach(NSScreen.screens, id: \.localizedName) { screen in Button(screen.localizedName) { add(.display(screen.localizedName)) } }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                if store.settings.modes.contains(where: { $0.id == mode.id }) {
                    Button("Delete", role: .destructive) {
                        Switchboard.shared.stopMode(mode.id)
                        store.settings.modes.removeAll { $0.id == mode.id }
                        close()
                    }
                }
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button("Save") {
                    if let i = store.settings.modes.firstIndex(where: { $0.id == mode.id }) { store.settings.modes[i] = mode } else { store.settings.modes.append(mode) }
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(mode.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480, height: 600)
    }

    private func add(_ trigger: ModeTrigger) {
        if !mode.triggers.contains(trigger) { mode.triggers.append(trigger) }
        mode.enabled = true
    }
}

/// Make a switch from shell commands (Monorail) or shortcuts (both).
struct CustomSwitchEditor: View {
    @State var custom: CustomSwitch
    @ObservedObject var store: SettingsStore
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(custom.title.isEmpty ? "New Switch" : custom.title).font(.system(size: 17, weight: .bold))
            Form {
                TextField("Name", text: $custom.title, prompt: Text("Wi-Fi, VPN, Bluetooth…"))
                TextField("Symbol", text: $custom.symbol, prompt: Text("switch.2"))
                Section("Shortcuts (from the Shortcuts app)") {
                    TextField("Turn on with", text: $custom.onShortcut, prompt: Text("Shortcut name"))
                    TextField("Turn off with", text: $custom.offShortcut, prompt: Text("Leave empty for a one-off action"))
                }
                if !Edition.isAppStore {
                    Section("Or shell commands") {
                        TextField("On", text: $custom.onCommand, prompt: Text("networksetup -setairportpower en0 on"))
                        TextField("Off", text: $custom.offCommand, prompt: Text("networksetup -setairportpower en0 off"))
                        TextField("Is it on?", text: $custom.stateCommand, prompt: Text("Prints something when it's on"))
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button("Save") {
                    if let i = store.settings.customSwitches.firstIndex(where: { $0.id == custom.id }) { store.settings.customSwitches[i] = custom } else { store.settings.customSwitches.append(custom) }
                    Switchboard.shared.refresh()
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(custom.title.trimmingCharacters(in: .whitespaces).isEmpty || (custom.onShortcut.isEmpty && custom.onCommand.isEmpty))
            }
        }
        .padding(20)
        .frame(width: 480, height: 470)
    }
}
#endif
