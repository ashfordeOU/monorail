#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// What the Settings panes can ask the running app for (set by AppDelegate).
/// The usage log, for Settings → About.
enum UsageBridge {
    static var log: UsageLog?
}

/// Settings → About → Usage: how Monorail has been used and what it costs, all on this Mac.
struct UsageSection: View {
    @ObservedObject var log: UsageLog
    @State private var refresh = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Usage").font(.headline)
                Text("since \(log.stored.firstLaunch.formatted(date: .abbreviated, time: .omitted)) · kept on this Mac").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.text, forType: .string)
                }
                Button("Reset") { log.reset() }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4), spacing: 10) {
                stat("\(log.stored.launches)", "launches")
                stat(String(format: "%.1f h", log.totalRunning / 3600), "running")
                stat(String(format: "%.2f%%", log.totalCPU / max(log.totalRunning, 1) * 100), "average CPU")
                stat(String(format: "%.0f MB", EnergyReport.residentMegabytes ?? 0), "memory now")
                stat("\(log.stored.windowsManaged)", "windows managed")
                stat("\(log.stored.slideSwitches)", "slide switches")
                stat("\(log.stored.workspaceSwitches)", "workspace switches")
                stat(String(format: "%.1f h", log.totalAwake / 3600), "kept awake")
            }
            if !log.topActions.isEmpty {
                Text("Most used: " + log.topActions.prefix(5).map { "\($0.0) (\($0.1))" }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Text("This session: \(EnergyReport.summary)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
        .id(refresh)
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { refresh = $0 }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

enum SmartBridge {
    static var remoteURL: () -> URL? = { nil }
    static var remoteQR: () -> NSImage? = { nil }
    /// Waits for the next MIDI note and hands it back.
    static var learnMIDINote: (@escaping (Int) -> Void) -> Void = { _ in }
    static var acceptSuggestion: (String) -> Void = { _ in }
}

/// Settings → Smart: what Monorail learns and does for you.
struct SmartPane: View {
    @ObservedObject var store: SettingsStore
    @State private var newPath = ""
    @State private var newPathWorkspace = 0

    var body: some View {
        Form {
            Section {
                Toggle("Stage the window I usually go to next right beside me", isOn: $store.settings.stageNextWindow)
                Toggle("Suggest focus mode when I’m switching a lot", isOn: $store.settings.distractionNudges)
                Toggle("Suggest rules from the fixes I keep making", isOn: $store.settings.ruleSuggestions)
                Toggle("Give new slides a width that suits the app", isOn: $store.settings.contentAwareWidths)
                    .help("About 100 columns for code and terminals, a page for documents, a web page for browsers")
            } header: {
                Text("Learns as you work")
            } footer: {
                Text("Everything is learned and kept on this Mac. In the command palette, type a sentence (“Slack and Mail side by side on 3”) or what you’re about to do (“write the Q3 report”).")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if !store.settings.suggestedRules.isEmpty {
                Section("Suggested rules") {
                    ForEach(store.settings.suggestedRules.sorted(by: { $0.key < $1.key }), id: \.key) { bundle, width in
                        HStack {
                            Text("\(UsageStats.appName(bundle)) at \(Int((width * 100).rounded()))% width")
                            Spacer()
                            Button("Add Rule") { SmartBridge.acceptSuggestion(bundle) }
                            Button("Dismiss") { store.settings.suggestedRules[bundle] = nil }
                        }
                    }
                }
            }
            Section {
                Toggle("Tell me when an AI coding agent is waiting for me", isOn: $store.settings.agentAlerts)
                Toggle("Slide the waiting agent into view", isOn: $store.settings.agentBringIntoView)
                    .disabled(!store.settings.agentAlerts)
            } header: {
                Text("AI agents")
            } footer: {
                Text("Watches terminal windows running Claude Code, Codex, Aider, Gemini and others; when one asks for approval you hear a chime, and the palette offers to take you there.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Elastic focus") {
                    Picker("", selection: $store.settings.layout.elasticFocus) {
                        Text("Off").tag(0.0)
                        Text("Gentle").tag(0.12)
                        Text("Strong").tag(0.25)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 240)
                }
                Toggle("Whole slides only: hide slides that would be cut off at the screen edge", isOn: $store.settings.wholeSlidesOnly)
                Toggle("Hide off-screen slides in the corner (no slivers at the edges)", isOn: $store.settings.parkInCorner)
                Toggle("Dimming follows the pointer", isOn: $store.settings.dimFollowsPointer)
                Toggle("Remember the layout for each set of displays", isOn: $store.settings.displayProfiles)
            } header: {
                Text("The strip")
            } footer: {
                Text("Elastic focus grows the slide you’re in and lets the others give way. Tall slides (a shortcut in Settings → Shortcuts) give each window nearly the full height and scroll up and down.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                ForEach(store.settings.pathRules) { rule in
                    HStack {
                        Image(systemName: "folder")
                        Text(rule.path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text("→ \(store.settings.workspaceName(rule.workspace))").foregroundStyle(.secondary)
                        Button { store.settings.pathRules.removeAll { $0.id == rule.id } } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("~/Clients/Acme", text: $newPath).textFieldStyle(.roundedBorder)
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url { newPath = url.path }
                    }
                    Picker("", selection: $newPathWorkspace) {
                        ForEach(0..<max(store.settings.workspaceCount, 1), id: \.self) { Text(store.settings.workspaceName($0)).tag($0) }
                    }
                    .labelsHidden().frame(width: 150)
                    Button("Add") {
                        store.settings.pathRules.append(PathRule(path: newPath, workspace: newPathWorkspace))
                        newPath = ""
                    }
                    .disabled(newPath.isEmpty)
                }
            } header: {
                Text("Folders to workspaces")
            } footer: {
                Text("Documents opened from these folders go to their workspace (apps that report their document: Pages, Word, Preview, Xcode, TextEdit…).")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hidden during deep work")
                    ForEach(store.settings.deepWorkApps, id: \.self) { bundle in
                        HStack {
                            Text(UsageStats.appName(bundle))
                            Spacer()
                            Button { store.settings.deepWorkApps.removeAll { $0 == bundle } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                        }
                    }
                    AppMenu(title: "Add a running app…") { store.settings.deepWorkApps.append($0) }
                }
                Toggle("Calendar events named Focus or Deep work start deep work", isOn: $store.settings.deepWorkFromCalendar)
                Toggle("On battery, animate at 30 fps and pause live previews", isOn: $store.settings.energySaver)
            } header: {
                Text("Deep work and energy")
            }
            Section {
                ForEach(0..<max(store.settings.workspaceCount, 1), id: \.self) { index in
                    HStack {
                        Text(store.settings.workspaceName(index)).frame(width: 130, alignment: .leading)
                        Picker("", selection: budget(index)) {
                            Text("No budget").tag(Int?.none)
                            ForEach([30, 60, 90, 120, 180, 240], id: \.self) { Text(InsightsPane.duration($0)).tag(Int?.some($0)) }
                        }
                        .labelsHidden().frame(width: 130)
                        TextField("Shortcut to run on arrival", text: shortcut(index)).textFieldStyle(.roundedBorder)
                    }
                }
            } header: {
                Text("Contexts and time budgets")
            } footer: {
                Text("A Shortcut runs each time you arrive: turn on a Focus, switch audio, set your Slack status. A time budget nudges you once a day when it’s used up.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func config(_ index: Int) -> Binding<WorkspaceConfig> {
        Binding(
            get: { store.settings.workspaceConfigs[String(index)] ?? WorkspaceConfig() },
            set: { store.settings.workspaceConfigs[String(index)] = $0 == WorkspaceConfig() ? nil : $0 })
    }

    private func budget(_ index: Int) -> Binding<Int?> {
        Binding(get: { config(index).wrappedValue.budgetMinutes }, set: { value in
            let binding = config(index)
            var changed = binding.wrappedValue
            changed.budgetMinutes = value
            binding.wrappedValue = changed
        })
    }

    private func shortcut(_ index: Int) -> Binding<String> {
        Binding(get: { config(index).wrappedValue.shortcut ?? "" }, set: { value in
            let binding = config(index)
            var changed = binding.wrappedValue
            changed.shortcut = value.isEmpty ? nil : value
            binding.wrappedValue = changed
        })
    }
}

/// Settings → Devices & Sharing: controllers, remote, presenting and privacy.
struct DevicesPane: View {
    @ObservedObject var store: SettingsStore
    @State private var learning: String?

    var body: some View {
        Form {
            Section {
                Picker("Monorail key", selection: $store.settings.monorailKeySource) {
                    ForEach(MonorailKeySource.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("Use it (hold for every shortcut, tap for the palette)", isOn: $store.settings.capsLockKey)
                Toggle("⌃⌥⇧ + drag: left/right switch workspace, up overview, down desktop", isOn: $store.settings.mouseGestures)
                Toggle("Game controller: d-pad slides, shoulders switch workspace, A overview, B undo", isOn: $store.settings.gameController)
                Toggle("Experimental: turn your head towards a display to focus it", isOn: $store.settings.headFocus)
            } header: {
                Text("Keys and controllers")
            }
            Section {
                Toggle("Run actions from a MIDI controller", isOn: $store.settings.midiControl)
                if store.settings.midiControl {
                    ForEach(store.settings.midiMap.sorted(by: { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }), id: \.key) { note, action in
                        HStack {
                            Text("Note \(note)").monospacedDigit().frame(width: 80, alignment: .leading)
                            Text(Action(rawValue: action)?.title ?? action)
                            Spacer()
                            Button { store.settings.midiMap[note] = nil } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                        }
                    }
                    Menu(learning.map { "Press a pad for “\(Action(rawValue: $0)?.title ?? $0)”…" } ?? "Learn a pad for…") {
                        ForEach([Action.focusLeft, .focusRight, .overview, .nextWorkspace, .previousWorkspace, .toggleFullWidth,
                                 .toggleFocusMode, .showDesktop, .undo, .cycleWidth, .commandPalette, .demoZoom], id: \.self) { action in
                            Button(action.title) {
                                learning = action.rawValue
                                SmartBridge.learnMIDINote { note in
                                    store.settings.midiMap[String(note)] = action.rawValue
                                    learning = nil
                                }
                            }
                        }
                    }
                    .fixedSize()
                }
            } header: {
                Text("MIDI")
            } footer: {
                Text("Stream Deck: point its buttons at monorail:// links or the monorail command (see extensions/streamdeck).")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Phone remote on this network", isOn: $store.settings.webRemote)
                if store.settings.webRemote {
                    HStack(alignment: .top, spacing: 16) {
                        if let qr = SmartBridge.remoteQR() {
                            Image(nsImage: qr).interpolation(.none).resizable().frame(width: 120, height: 120)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Scan with your phone’s camera, or open:")
                            Text(SmartBridge.remoteURL()?.absoluteString ?? "Starting…").font(.callout.monospaced()).textSelection(.enabled)
                            Button("New Link") { store.settings.webRemoteToken = "" }
                                .help("Makes a new secret, so old links stop working")
                        }
                    }
                }
            } header: {
                Text("Phone remote")
            } footer: {
                Text("Big buttons for slides, workspaces, the overview and more, from any phone on the same Wi-Fi. The link holds a secret; anyone without it gets nothing.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Hide private apps while I share my screen", isOn: $store.settings.safeScreenShare)
                Toggle("Blur private windows in the overview", isOn: $store.settings.privacyBlur)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Private apps")
                    ForEach(store.settings.privateApps, id: \.self) { bundle in
                        HStack {
                            Text(UsageStats.appName(bundle))
                            Spacer()
                            Button { store.settings.privateApps.removeAll { $0 == bundle } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                        }
                    }
                    AppMenu(title: "Add a running app…") { store.settings.privateApps.append($0) }
                }
                Toggle("Keep a clipboard history for each workspace", isOn: $store.settings.workspaceClipboard)
                    .help("Skips what password managers mark as secret")
            } header: {
                Text("Privacy")
            } footer: {
                Text("Mark any single window private from the command palette. Monorail notices Zoom, Teams, Meet, Webex, Slack and FaceTime screen shares.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Show slides and workspaces around the notch as I move", isOn: $store.settings.notchHUD)
                HStack {
                    Text("Drifting wallpaper")
                    Spacer()
                    Text(store.settings.driftWallpaper.isEmpty ? "Off" : (store.settings.driftWallpaper as NSString).lastPathComponent)
                        .foregroundStyle(.secondary)
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.image]
                        if panel.runModal() == .OK, let url = panel.url { store.settings.driftWallpaper = url.path }
                    }
                    if !store.settings.driftWallpaper.isEmpty { Button("Off") { store.settings.driftWallpaper = "" } }
                }
                Picker("Sounds", selection: $store.settings.soundPack) {
                    ForEach(SoundPack.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Delight")
            }
            Section {
                Toggle("Ask before scripts or AI assistants close windows", isOn: $store.settings.confirmDestructiveAPI)
                Toggle("Keep crash and hang reports on this Mac", isOn: $store.settings.crashReports)
                if !CrashReporter.reports.isEmpty {
                    Button("Show \(CrashReporter.reports.count) Reports") { NSWorkspace.shared.open(CrashReporter.folder) }
                }
                if !ManagedSettings.managedKeys.isEmpty {
                    Text("Managed by your organisation: \(ManagedSettings.managedKeys.joined(separator: ", "))")
                        .font(.callout).foregroundStyle(.secondary)
                }
            } header: {
                Text("Trust")
            } footer: {
                Text("What Monorail can see: window positions and titles (Accessibility), window pictures only for previews you turn on (Screen Recording), your calendar only for meeting and focus events. It stores layouts and settings in ~/Library/Application Support/Monorail. Network: update checks, quirks updates, and anything you turn on here. Hold ⌥ while opening Monorail for safe mode.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// A menu of running apps; picking one hands back its bundle ID.
struct AppMenu: View {
    let title: String
    let pick: (String) -> Void

    var body: some View {
        Menu(title) {
            ForEach(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }, id: \.processIdentifier) { app in
                Button(app.localizedName ?? app.bundleIdentifier!) { pick(app.bundleIdentifier!) }
            }
        }
        .fixedSize()
    }
}
/// Settings → Stay Awake: keep the Mac from sleeping, by hand or by itself.
struct StayAwakePane: View {
    @ObservedObject var store: SettingsStore
    private static let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        Form {
            Section {
                Picker("When turned on, stay awake", selection: $store.settings.awakeDefaultMinutes) {
                    Text("Until I end it").tag(0)
                    ForEach([15, 30, 60, 120, 240, 480], id: \.self) { Text(InsightsPane.duration($0)).tag($0) }
                }
                Toggle("Keep the display on", isOn: $store.settings.awakeKeepDisplayOn)
                Toggle("Allow the screen saver", isOn: $store.settings.awakeAllowScreenSaver)
                    .disabled(!store.settings.awakeKeepDisplayOn)
                Picker("Still lock the screen after", selection: $store.settings.awakeLockAfterMinutes) {
                    Text("Never").tag(0)
                    ForEach([5, 10, 15, 30, 60], id: \.self) { Text("\($0) idle minutes").tag($0) }
                }
                Toggle("Start Stay Awake when Monorail opens", isOn: $store.settings.awakeOnLaunch)
            } header: {
                Text("Stay Awake")
            } footer: {
                Text("Turn it on from the menu bar (Stay Awake), the command palette, a shortcut in Settings → Shortcuts, `monorail awake 60`, or monorail://awake. The menu bar shows ☕ and the time left.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Picker("End it when the battery drops to", selection: $store.settings.awakeBatteryCutoff) {
                    Text("Never").tag(0)
                    ForEach([5, 10, 15, 20, 30, 50], id: \.self) { Text("\($0)%").tag($0) }
                }
                Toggle("Move the pointer now and then, so chat apps don’t show me as away", isOn: $store.settings.awakeMoveCursor)
                if store.settings.awakeMoveCursor {
                    Stepper("Every \(store.settings.awakeMoveCursorMinutes) minutes", value: $store.settings.awakeMoveCursorMinutes, in: 1...30)
                }
                Toggle("Keep external drives from spinning down", isOn: $store.settings.awakeDriveAlive)
                Toggle("Stay awake with the lid closed (asks for your password)", isOn: $store.settings.awakeClosedLid)
                    .help("Keeps a MacBook running when closed, even without an external display. Don't put a running Mac in a bag.")
            } header: {
                Text("While awake")
            }
            Section {
                Toggle("Show a notice when it starts and ends", isOn: $store.settings.awakeNotify)
                Toggle("Play a sound when it starts and ends", isOn: $store.settings.awakeSound)
                Toggle("Show the time left in the menu bar", isOn: $store.settings.awakeShowTime)
            } header: {
                Text("Feedback")
            }
            Section {
                Toggle("Automatic triggers are on", isOn: $store.settings.awakeTriggersOn)
                ForEach($store.settings.awakeTriggers) { $trigger in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Toggle("", isOn: $trigger.isEnabled).labelsHidden()
                            Picker("", selection: $trigger.kind) {
                                ForEach(AwakeTrigger.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            .labelsHidden().frame(width: 260)
                            Spacer()
                            Button { store.settings.awakeTriggers.removeAll { $0.id == trigger.id } } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                        detail($trigger)
                    }
                    .padding(.vertical, 2)
                }
                Menu("Add a Trigger") {
                    ForEach(AwakeTrigger.Kind.allCases, id: \.self) { kind in
                        Button(kind.title) { store.settings.awakeTriggers.append(AwakeTrigger(kind: kind)) }
                    }
                }
                .fixedSize()
            } header: {
                Text("Stay awake by itself")
            } footer: {
                Text("While any trigger applies, your Mac stays awake: a presentation app open, an external display, a download, a busy CPU, your office Wi-Fi, a schedule…")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func detail(_ trigger: Binding<AwakeTrigger>) -> some View {
        switch trigger.wrappedValue.kind {
        case .app, .frontApp:
            HStack {
                Text(trigger.wrappedValue.value.isEmpty ? "No app chosen" : UsageStats.appName(trigger.wrappedValue.value))
                    .foregroundStyle(.secondary)
                AppMenu(title: "Choose…") { trigger.wrappedValue.value = $0 }
            }
        case .display:
            TextField("Any external display, or part of its name", text: trigger.value).textFieldStyle(.roundedBorder)
        case .wifi:
            TextField("Wi-Fi network name", text: trigger.value).textFieldStyle(.roundedBorder)
        case .drive:
            TextField("Any external drive, or its name", text: trigger.value).textFieldStyle(.roundedBorder)
        case .charging:
            EmptyView()
        case .cpu:
            Stepper("Busier than \(Int(trigger.wrappedValue.threshold > 0 ? trigger.wrappedValue.threshold : 50))%",
                    value: Binding(get: { trigger.wrappedValue.threshold > 0 ? trigger.wrappedValue.threshold : 50 },
                                   set: { trigger.wrappedValue.threshold = $0 }), in: 10...95, step: 5)
        case .downloading:
            Stepper("Faster than \(Int(trigger.wrappedValue.threshold > 0 ? trigger.wrappedValue.threshold : 50)) KB/s",
                    value: Binding(get: { trigger.wrappedValue.threshold > 0 ? trigger.wrappedValue.threshold : 50 },
                                   set: { trigger.wrappedValue.threshold = $0 }), in: 10...10000, step: 10)
        case .schedule:
            HStack {
                minutePicker("From", trigger.startMinute)
                minutePicker("to", trigger.endMinute)
                ForEach(1...7, id: \.self) { day in
                    let on = trigger.wrappedValue.weekdays.isEmpty || trigger.wrappedValue.weekdays.contains(day)
                    Button(Self.weekdays[day - 1]) {
                        var days = trigger.wrappedValue.weekdays.isEmpty ? Array(1...7) : trigger.wrappedValue.weekdays
                        if let i = days.firstIndex(of: day) { days.remove(at: i) } else { days.append(day) }
                        trigger.wrappedValue.weekdays = days.count == 7 ? [] : days.sorted()
                    }
                    .buttonStyle(.bordered)
                    .tint(on ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
        }
    }

    private func minutePicker(_ label: String, _ minute: Binding<Int>) -> some View {
        Picker(label, selection: minute) {
            ForEach(Array(stride(from: 0, to: 24 * 60, by: 30)), id: \.self) { m in
                Text(String(format: "%02d:%02d", m / 60, m % 60)).tag(m)
            }
        }
        .frame(width: 130)
    }
}
#endif
