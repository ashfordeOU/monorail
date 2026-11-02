#if os(macOS)
import AppKit
import Combine
import MonorailCore
import SwiftUI
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case basics, general, layout, input, appearance, evening, apps, smart, devices, awake, automation, insights, shortcuts, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .basics: return L("Basics")
        case .general: return L("General")
        case .layout: return L("Layout")
        case .input: return L("Motion & Input")
        case .appearance: return L("Appearance")
        case .evening: return L("Evening Mode")
        case .apps: return L("Apps")
        case .smart: return L("Smart")
        case .devices: return L("Devices & Sharing")
        case .awake: return L("Stay Awake")
        case .automation: return L("Automation")
        case .insights: return L("Insights")
        case .shortcuts: return L("Shortcuts")
        case .about: return L("About")
        }
    }

    var symbol: String {
        switch self {
        case .basics: return "star"
        case .general: return "gearshape"
        case .layout: return "rectangle.split.3x1"
        case .input: return "hand.draw"
        case .appearance: return "paintbrush"
        case .evening: return "moon"
        case .apps: return "square.grid.2x2"
        case .smart: return "sparkles"
        case .devices: return "dot.radiowaves.left.and.right"
        case .awake: return "cup.and.saucer"
        case .automation: return "clock.arrow.2.circlepath"
        case .insights: return "chart.bar"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsTab = .basics
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var stats: UsageStats
    let isPaused: () -> Bool
    let setPaused: (Bool) -> Void
    @State private var query = ""

    /// The sidebar's groups, most-used first.
    static let groups: [(String, [SettingsTab])] = [
        (L("Essentials"), [.basics, .general, .layout, .shortcuts]),
        (L("Make it yours"), [.appearance, .evening, .input, .apps]),
        (L("Power"), [.smart, .automation, .devices, .awake]),
        (L("Monorail"), [.insights, .about]),
    ]

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 210)
                .background(.regularMaterial)
            Divider()
            Group {
                if query.isEmpty { pane(navigation.tab) } else { searchResults }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // A comfortable size where it fits; the window shrinks to smaller screens and can be resized.
        .frame(minWidth: 640, idealWidth: 980, maxWidth: .infinity, minHeight: 440, idealHeight: 700, maxHeight: .infinity)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search settings", text: $query).textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
            .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Self.groups, id: \.0) { group in
                        Text(group.0.uppercased())
                            .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 2)
                        ForEach(group.1) { tab in sidebarRow(tab) }
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 12)
            }
        }
    }

    private func sidebarRow(_ tab: SettingsTab) -> some View {
        let selected = navigation.tab == tab && query.isEmpty
        return Button {
            navigation.tab = tab
            query = ""
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.symbol)
                    .frame(width: 18)
                    .foregroundStyle(selected ? Color.white : Color.accentColor)
                Text(tab.title).foregroundStyle(selected ? Color.white : Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Color.accentColor : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pane(_ tab: SettingsTab) -> some View {
        switch tab {
        case .basics: BasicsPane(store: store, navigation: navigation)
        case .general: GeneralPane(store: store, isPaused: isPaused, setPaused: setPaused)
        case .layout: LayoutPane(store: store)
        case .input: InputPane(store: store)
        case .appearance: AppearancePane(store: store)
        case .apps: AppsPane(store: store)
        case .smart: SmartPane(store: store)
        case .devices: DevicesPane(store: store)
        case .awake: StayAwakePane(store: store)
        case .evening: EveningPane(store: store)
        case .automation: AutomationPane(store: store)
        case .insights: InsightsPane(store: store, stats: stats)
        case .shortcuts: ShortcutsPane(store: store)
        case .about: AboutPane()
        }
    }

    private var searchResults: some View {
        let results = SettingsIndex.search(query)
        return List {
            if results.isEmpty {
                Text("No settings match “\(query)”. Try the command palette (⌃⌥/) for actions.").foregroundStyle(.secondary)
            }
            ForEach(Array(results.enumerated()), id: \.offset) { _, entry in
                Button {
                    if let tab = SettingsTab(rawValue: entry.tab) { navigation.tab = tab }
                    query = ""
                } label: {
                    HStack {
                        Text(entry.label).lineLimit(2)
                        Spacer()
                        if let tab = SettingsTab(rawValue: entry.tab) {
                            Label(tab.title, systemImage: tab.symbol).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Basics

/// The settings most people change, on one page. Everything else is in the other panes.
private struct BasicsPane: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var navigation: SettingsNavigation
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section {
                LabeledContent("Start from a style") {
                    HStack {
                        ForEach(StartStyle.allCases, id: \.self) { style in
                            Button(style.title) { store.settings.apply(style) }.help(style.detail)
                        }
                    }
                }
                Toggle("Open Monorail when I log in", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { LoginItem.setEnabled($0) }
                LabeledContent("Coming from another app?") {
                    Button("Import Settings…") { Importer.run(store: store) }
                        .help("Brings over shortcuts, gaps, floating apps and workspace rules from AeroSpace, yabai and skhd, or Rectangle")
                }
            } header: {
                Text("Getting set up")
            }
            Section {
                Toggle("Every slide fits on screen (fit mode)", isOn: $store.settings.fitByDefault)
                Toggle("Windows of the same app share a slide", isOn: $store.settings.groupByApp)
                LabeledSlider(title: "Gap between windows", value: $store.settings.layout.gap, range: 0...40)
                Toggle("Animate windows", isOn: $store.settings.animate)
            } header: {
                Text("Windows")
            }
            Section {
                Toggle("Show the slider bar", isOn: Binding(
                    get: { store.settings.sliderBar != .off },
                    set: { store.settings.sliderBar = $0 ? .whileMoving : .off }))
                Toggle("Outline the focused window", isOn: $store.settings.focusBorder)
                Picker("Theme", selection: $store.settings.theme) {
                    ForEach(Theme.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Look")
            }
            Section {
                Toggle("Use Caps Lock as the Monorail key", isOn: $store.settings.capsLockKey).hiddenInAppStore()
                    .help("Hold Caps Lock instead of ⌃⌥; tap it for the command palette")
                LabeledContent("Shortcuts") {
                    Button("Change Shortcuts…") { navigation.tab = .shortcuts }
                }
            } header: {
                Text("Keys")
            }
            Section {
                Toggle("Share anonymous usage counts", isOn: $store.settings.shareUsageStats)
                Toggle("Check for updates automatically", isOn: $store.settings.checkForUpdates).hiddenInAppStore()
            } header: {
                Text("Privacy and updates")
            } footer: {
                Text("These are the settings most people change. Everything else is in the sidebar, or type in the search field to find any option.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }
}

// MARK: - General

private struct GeneralPane: View {
    @ObservedObject var store: SettingsStore
    let isPaused: () -> Bool
    let setPaused: (Bool) -> Void
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var paused = false
    @State private var checks: [SetupCheck] = []

    var body: some View {
        Form {
            Section {
                LabeledContent("Style") {
                    HStack {
                        ForEach(StartStyle.allCases, id: \.self) { style in
                            Button(style.title) { store.settings.apply(style) }
                                .help(style.detail)
                        }
                    }
                }
                Toggle("Every slide fits on screen in every workspace (fit mode)", isOn: $store.settings.fitByDefault)
                    .help("Turn it on or off for one workspace from the overview or the menu bar")
                Toggle("Workspaces without a name take their apps’ names", isOn: $store.settings.autoNameWorkspaces)
                Toggle("Use Caps Lock as the Monorail key (hold it instead of ⌃⌥; tap for the palette)", isOn: $store.settings.capsLockKey).hiddenInAppStore()
                    .help("Caps Lock goes back to normal when you quit Monorail or turn this off")
                Toggle("A summary of your week on Monday mornings", isOn: $store.settings.weeklySummary)
                Picker("Language", selection: $store.settings.language) {
                    ForEach(Localization.languages, id: \.code) { Text($0.name).tag($0.code) }
                }
                .help("Menus, Settings tabs and the welcome tour. Reopen Settings after changing it.")
                Toggle("Launch Monorail at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { LoginItem.setEnabled($0) }
                Toggle("Pause tiling", isOn: $paused)
                    .onChange(of: paused) { setPaused($0) }
                Toggle("Show column position in the menu bar", isOn: $store.settings.showColumnIndicator)
                Toggle("List windows right in the menu (instead of a Windows submenu)", isOn: $store.settings.menuWindowsInline)
                Picker("Menu bar shows", selection: $store.settings.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(!store.settings.showColumnIndicator)
                Toggle("Show the workspace’s name when switching", isOn: $store.settings.workspaceHUD)
                Toggle("Quiet mode: no pop-up notices", isOn: $store.settings.quietMode)
                Toggle("VoiceOver announces slide and workspace changes", isOn: $store.settings.announceChanges)
                Toggle("VoiceOver also says which window got focus", isOn: $store.settings.announceWindows)
                    .disabled(!store.settings.announceChanges)
                Toggle("Keep a “Last session” snapshot on quit and sleep", isOn: $store.settings.autoSnapshot)
                Toggle("Show the focused app’s name in the menu bar too", isOn: $store.settings.menuBarShowsApp)
                    .disabled(!store.settings.showColumnIndicator)
                Toggle("Clicking the menu bar icon shows the slider (right-click for the menu)", isOn: $store.settings.iconOpensSlider)
                Stepper(value: $store.settings.workspaceCount, in: 1...9) {
                    Text("Workspaces per display: \(store.settings.workspaceCount)")
                }
                ForEach(0..<store.settings.workspaceCount, id: \.self) { index in
                    LabeledContent {
                        HStack {
                            TextField("Workspace \(index + 1)", text: workspaceName(index))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                            WallpaperButton(store: store, index: index)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(WorkspaceColor.color(index)).frame(width: 9, height: 9)
                            Text("Name of workspace \(index + 1)")
                        }
                    }
                }
                Toggle("Only show workspaces in use, plus one empty one", isOn: $store.settings.dynamicWorkspaces)
                Toggle("Red dots on windows whose apps have a badge in the Dock", isOn: $store.settings.attentionMarkers)
                Toggle("Check for updates automatically", isOn: $store.settings.checkForUpdates).hiddenInAppStore()
                Toggle("Install updates automatically", isOn: $store.settings.installUpdatesAutomatically).hiddenInAppStore()
                    .disabled(!store.settings.checkForUpdates)
                Toggle("Get beta versions too (early, may have rough edges)", isOn: $store.settings.betaUpdates).hiddenInAppStore()
                    .disabled(!store.settings.checkForUpdates)
                Picker("New windows open", selection: $store.settings.newWindowPosition) {
                    Text("Next to the focused window").tag(Strip.InsertPosition.afterFocused)
                    Text("At the end of the strip").tag(Strip.InsertPosition.end)
                    Text("At the start of the strip").tag(Strip.InsertPosition.start)
                }
            }
            ProfilesSection(store: store)
            SyncSection(store: store)
            RestoreSection(store: store)
            BackupsSection(store: store)
            Section {
                ForEach(checks) { check in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: check.state == .ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(check.state == .ok ? Color.green : Color.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title).fontWeight(.medium)
                            Text(check.detail).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if let url = check.fixURL {
                            Button("Open…") { NSWorkspace.shared.open(url) }
                        }
                    }
                }
                Button("Check again") { refresh() }
            } header: {
                Text("Mac setup")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            paused = isPaused()
            launchAtLogin = LoginItem.isEnabled
            refresh()
        }
    }

    private func refresh() { checks = SetupCheck.run(settings: store.settings) }

    private func workspaceName(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                store.settings.workspaceNames.indices.contains(index) ? store.settings.workspaceNames[index] : ""
            },
            set: { store.settings.setWorkspaceName($0, at: index) }
        )
    }
}

// MARK: - Layout

private let widthChoices: [(String, Double)] = [
    ("¼", 0.25), ("⅓", 1.0 / 3.0), ("½", 0.5), ("⅔", 2.0 / 3.0), ("¾", 0.75), ("Full", 1.0),
]

private struct LayoutPane: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Strip direction", selection: $store.settings.layout.direction) {
                    ForEach(StripDirection.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("Keep windows in place when an app resizes or moves them itself", isOn: $store.settings.keepWindowsInPlace)
                Toggle("Keep every window and dialog on screen", isOn: $store.settings.keepEverythingOnScreen)
                    .help("Floating windows and dialogs that end up off screen (a display unplugged, a size saved on a bigger screen) come back into view.")
                Toggle("Keep macOS permission and password prompts in front, centred", isOn: $store.settings.systemPromptsInFront)
                    .help("Prompts like “… would like to access…” or “… wants to make changes” come to the front of every window, centred on your screen, and focus stays on them until you answer.")
                Toggle("Drag a window onto another to dock it beside (edges) or tab them together (middle)", isOn: $store.settings.dragToDock)
                    .help("Works with any apps, in any slide or from floating. Undo puts it back.")
                Toggle("Drag the gap between two windows to resize both", isOn: $store.settings.gapHandles)
                Toggle("After resizing a window in a slide, offer to rearrange it", isOn: $store.settings.resizeAssist)
                Toggle("Group windows into slides by app", isOn: $store.settings.groupByApp)
                Toggle("Pair lone windows of different apps as they open", isOn: $store.settings.pairLoneWindowsOnOpen)
                    .disabled(!store.settings.groupByApp)
                Stepper(value: $store.settings.tilesPerSlide, in: 1...Column.maximumWindows) {
                    Text("Windows per slide: \(store.settings.tilesPerSlide)")
                }
                .disabled(!store.settings.groupByApp)
                Toggle("Drag a window to the top of the screen to pick a snap layout", isOn: $store.settings.snapPicker)
                Picker("Slide layout", selection: $store.settings.slideArrangement) {
                    ForEach(Arrangement.standard, id: \.self) { arrangement in
                        Label(arrangement.title, systemImage: arrangement.symbol).tag(arrangement)
                    }
                }
            } header: {
                Text("Slides")
            } footer: {
                Text("Windows of the same app share a full-screen slide. Lone windows of different apps pair up when you regroup, or as they open if you turn that on. Windows that come back — unhidden, unminimised, reopened from the Dock or after a relaunch — return to exactly where they were. Terminals get four tiles per slide — change tiles and layout per app under Apps. ⌃⌥A regroups everything; ⌃⌥G cycles a slide through Grid, Columns, Main + side, Main + bottom and Rows; ⌃⌥. and ⌃⌥, resize the main window; ⌃⌥M makes a window the main one. Right to left mirrors the whole strip.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            CustomLayoutsSection(store: store)
            Section("Spacing") {
                LabeledSlider(title: "Gap between windows", value: $store.settings.layout.gap, range: 0...40)
                LabeledSlider(title: "Gap at screen edges", value: $store.settings.layout.edgeGap, range: 0...40)
                Toggle("Smart gaps: none around a lone window, wider on big displays", isOn: $store.settings.smartGaps)
            }
            Section("Comfort") {
                Toggle("Open each app’s windows at the width you last gave it", isOn: $store.settings.rememberWidths)
                Toggle("Open new windows next to their app’s other windows", isOn: $store.settings.openNextToSameApp)
                Toggle("Open new windows in the focused slide", isOn: $store.settings.openIntoFocusedSlide)
                Toggle("Floating windows go back where you last put them", isOn: $store.settings.rememberFloatingPositions)
                Picker("A lone window", selection: $store.settings.centerLoneWindow) {
                    Text("Fills its slide").tag(0.0)
                    ForEach([0.5, 0.6, 0.7, 0.8], id: \.self) { Text("Sits centred at \(Int($0 * 100))%").tag($0) }
                }
                Picker("The focused one of two windows", selection: $store.settings.autoGrowFocus) {
                    Text("Stays the same size").tag(0.0)
                    ForEach([0.55, 0.6, 0.65, 0.7], id: \.self) { Text("Grows to \(Int($0 * 100))%").tag($0) }
                }
            }
            ProjectsSection(store: store)
            WholeSlideAppsSection()
            DisplaysSection(store: store)
            Section("Widths") {
                Picker("New window width", selection: $store.settings.layout.defaultWidth) {
                    ForEach(widthChoices, id: \.1) { Text($0.0).tag($0.1) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("“Cycle width” steps through")
                    HStack {
                        ForEach(widthChoices, id: \.1) { choice in
                            Toggle(choice.0, isOn: presetBinding(choice.1)).toggleStyle(.button)
                        }
                    }
                }
            }
            Section("Scrolling") {
                Picker("Centre the focused window", selection: $store.settings.layout.centerMode) {
                    Text("Never — scroll just enough").tag(CenterMode.never)
                    Text("When it would be off-screen").tag(CenterMode.onOverflow)
                    Text("Always").tag(CenterMode.always)
                }
            }
            Section("Windows") {
                Toggle("Keep each window’s own height", isOn: $store.settings.keepHeights)
                LabeledSlider(title: "Tab bar height", value: $store.settings.layout.tabBarHeight, range: 20...44)
            }
        }
        .formStyle(.grouped)
    }

    private func presetBinding(_ value: Double) -> Binding<Bool> {
        Binding(
            get: { store.settings.layout.widthPresets.contains { abs($0 - value) < 0.001 } },
            set: { on in
                var presets = store.settings.layout.widthPresets.filter { abs($0 - value) >= 0.001 }
                if on { presets.append(value) }
                if presets.isEmpty { return }
                store.settings.layout.widthPresets = presets.sorted()
            }
        )
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range, step: 1).frame(width: 200)
                Text("\(Int(value)) pt").monospacedDigit().frame(width: 44, alignment: .trailing)
            }
        }
    }
}

// MARK: - Motion & input

private struct InputPane: View {
    @ObservedObject var store: SettingsStore
    static let scrollModifiers: [Modifiers] = [[.option], [.command], [.control], [.control, .option]]

    var body: some View {
        Form {
            Section("Animation") {
                Toggle("Animate windows", isOn: $store.settings.animate)
                    .help("Off: windows move instantly. Everything else works exactly the same, and it uses less energy.")
                Toggle("Skip animations with Reduce Motion or Low Power Mode", isOn: $store.settings.followReduceMotion)
                    .disabled(!store.settings.animate)
                Toggle("Skip animations on battery", isOn: $store.settings.skipAnimationsOnBattery)
                    .disabled(!store.settings.animate)
                Toggle("A soft click as the strip lands on a slide", isOn: $store.settings.slideSound)
                    .disabled(!store.settings.animate)
                LabeledContent("Speed") {
                    Picker("", selection: $store.settings.animationDuration) {
                        Text("Fast").tag(0.12)
                        Text("Normal").tag(0.2)
                        Text("Relaxed").tag(0.3)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                }
                .disabled(!store.settings.animate)
                Picker("Motion", selection: $store.settings.animationCurve) {
                    ForEach(AnimationCurve.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(!store.settings.animate)
                Picker("Frame rate", selection: $store.settings.animationFPS) {
                    Text("30 fps (saves energy)").tag(30)
                    Text("60 fps").tag(60)
                    Text("120 fps (ProMotion)").tag(120)
                }
                .disabled(!store.settings.animate)
                Picker("Click sound", selection: $store.settings.clickSound) {
                    ForEach(["Tink", "Pop", "Morse", "Bottle", "Frog", "Purr", "Submarine"], id: \.self) { Text($0).tag($0) }
                }
                .disabled(!store.settings.slideSound)
            }
            Section {
                Picker("Slide mode key", selection: $store.settings.slideTrigger) {
                    ForEach(SlideTrigger.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Slide mode")
            } footer: {
                Text("Tap this key on its own, then use plain keys: ← → to slide, ⇧← ⇧→ to move a window, R width, F fill, C centre, 1–9 jump. Esc, Return or a few idle seconds end it. You can also scroll the strip while it’s on.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle(isOn: $store.settings.modifierSwipe) {
                    HStack {
                        Text("Scroll the strip while holding")
                        Picker("", selection: $store.settings.scrollModifier) {
                            ForEach(Self.scrollModifiers, id: \.rawValue) { Text($0.symbols).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                Toggle("Scroll the strip when the pointer is over the menu bar", isOn: $store.settings.scrollOverMenuBar)
                Toggle("Show ‹ › buttons in the menu bar", isOn: $store.settings.showNavigationArrows)
                Picker("Swipe without any keys", selection: $store.settings.swipeFingers) {
                    Text("Off").tag(SwipeFingers.off)
                    Text("Three fingers").tag(SwipeFingers.three)
                    Text("Four fingers").tag(SwipeFingers.four)
                }
                LabeledContent("Sensitivity") {
                    Slider(value: $store.settings.swipeSensitivity, in: 0.25...3).frame(width: 240)
                }
                Toggle("Reverse scroll direction", isOn: $store.settings.invertSwipe)
            } header: {
                Text("Mouse & trackpad scrolling")
            } footer: {
                Text("With a mouse, each notch of the wheel moves one window. On a trackpad the strip follows your fingers and settles on the nearest window. If macOS uses the same finger count to switch Spaces, change it in System Settings → Trackpad → More Gestures.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Hot edges: rest the pointer on the left or right screen edge to slide", isOn: $store.settings.hotEdges)
                Toggle("Hold ⌥ and pinch on the trackpad for the overview", isOn: $store.settings.pinchForOverview)
                Toggle("Tap with three fingers for the overview", isOn: $store.settings.threeFingerTapOverview)
                Toggle("Swipe up and down to switch workspace (with the swipe fingers above)", isOn: $store.settings.verticalWorkspaceSwipes)
                    .disabled(store.settings.swipeFingers == .off)
                    .help("Turn off Mission Control and App Exposé swipes for those fingers in System Settings → Trackpad")
                Toggle("⌥ + pinch zooms out on the strip (otherwise it opens the overview)", isOn: $store.settings.pinchZoomsStrip)
                    .help("If macOS uses a three-finger tap for Look Up, change that in System Settings → Trackpad")
                Toggle("Hold ⌥ over a slide in the slider to peek at it", isOn: $store.settings.peekWithOption)
                Toggle("Hold ⌃⌥ and drag anywhere in a window to move it (right-drag to resize)", isOn: $store.settings.modifierDrag)
                Toggle("Swipe with two fingers on a title bar to move, widen or minimise", isOn: $store.settings.titleBarSwipes)
                    .help("Left and right move the window's slide, up toggles full width, down minimises")
                Toggle("Show the size while resizing", isOn: $store.settings.resizeHUD)
                Toggle("Haptic tap as the strip lands on a slide (Force Touch trackpads)", isOn: $store.settings.hapticFeedback)
            } header: {
                Text("Gestures & screen edges")
            }
            Section {
                Toggle("Mouse buttons 4 and 5 (back and forward) step through slides", isOn: $store.settings.mouseButtonsStep)
                Toggle("⌥ + middle-click zooms the window under the pointer", isOn: $store.settings.middleClickZoom)
                Toggle("⌃⌥ + scroll over a window makes its slide narrower or wider", isOn: $store.settings.scrollResizes)
                Toggle("⇧ + scroll over the menu bar or slider switches workspace", isOn: $store.settings.shiftScrollSwitchesWorkspace)
            } header: {
                Text("Mouse")
            }
            Section {
                ForEach(0..<4, id: \.self) { index in
                    Picker(["Top-left corner", "Top-right corner", "Bottom-left corner", "Bottom-right corner"][index],
                           selection: hotCorner(index)) {
                        ForEach(HotCorner.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
            } header: {
                Text("Hot corners")
            } footer: {
                Text("Rest the pointer in a corner for a moment. If macOS has its own hot corner there, turn it off in System Settings → Desktop & Dock → Hot Corners.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Focus") {
                Toggle("Focus follows mouse", isOn: $store.settings.focusFollowsMouse)
                if store.settings.focusFollowsMouse {
                    LabeledContent("Wait before focusing") {
                        HStack {
                            Slider(value: $store.settings.focusFollowsMouseDelay, in: 0.05...1).frame(width: 200)
                            Text(String(format: "%.2f s", store.settings.focusFollowsMouseDelay)).monospacedDigit()
                        }
                    }
                }
                Toggle("Hold ⌃⌥ for a moment to see every shortcut", isOn: $store.settings.cheatSheetOnHold)
                Toggle("Mouse follows focus", isOn: $store.settings.mouseFollowsFocus)
            }
        }
        .formStyle(.grouped)
    }

    private func hotCorner(_ index: Int) -> Binding<HotCorner> {
        Binding(
            get: { store.settings.hotCorners.indices.contains(index) ? store.settings.hotCorners[index] : .none },
            set: { value in
                while store.settings.hotCorners.count < 4 { store.settings.hotCorners.append(.none) }
                store.settings.hotCorners[index] = value
            })
    }
}

// MARK: - Appearance

private struct AppearancePane: View {
    @ObservedObject var store: SettingsStore

    private var sliderBarOn: Binding<Bool> {
        Binding(
            get: { store.settings.sliderBar != .off },
            set: { store.settings.sliderBar = $0 ? .always : .off })
    }

    var body: some View {
        Form {
            Section {
                Toggle("Show the slider bar", isOn: sliderBarOn)
                if store.settings.sliderBar != .off {
                    Picker("Show it", selection: $store.settings.sliderBar) {
                        Text("Always (windows leave room for it)").tag(SliderBarMode.always)
                        Text("Only while sliding").tag(SliderBarMode.whileMoving)
                    }
                    Picker("Position", selection: $store.settings.sliderBarEdge) {
                        Text("Bottom of the screen").tag(SliderBarEdge.bottom)
                        Text("Top of the screen").tag(SliderBarEdge.top)
                    }
                    Toggle("Step aside for full-screen apps and videos", isOn: $store.settings.sliderBarStepsAside)
                        .help("Hides while any app fills the screen, and while a playing video is underneath it, like a player's controls")
                    Toggle("Window titles on the slides", isOn: $store.settings.sliderTitles)
                    Toggle("Compact", isOn: $store.settings.compactSlider)
                    LabeledContent("Opacity") {
                        Slider(value: $store.settings.sliderOpacity, in: 0.3...1).frame(width: 240)
                    }
                    Picker("Size", selection: $store.settings.sliderScale) {
                        Text("Small").tag(0.8)
                        Text("Normal").tag(1.0)
                        Text("Large").tag(1.25)
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Slider bar")
            } footer: {
                Text("A mini-map of every slide in the workspace: drag it to slide your windows along, click a slide to jump to it. Turn it off to use just the menu bar icon; windows then fill the screen right down to the Dock.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Theme") {
                ThemeGrid(title: "Classic", themes: Theme.classic, selection: $store.settings.theme)
                ThemeGrid(title: "Seasonal", themes: Theme.seasonal, selection: $store.settings.theme)
                ThemeGrid(title: "Unique", themes: Theme.unique, selection: $store.settings.theme)
            }
            Section {
                Picker("Lasts", selection: $store.settings.focusMinutes) {
                    Text("Until I turn it off").tag(0)
                    ForEach([15, 25, 45, 60, 90], id: \.self) { Text("\($0) minutes").tag($0) }
                }
                LabeledContent("Dim everything else") {
                    Slider(value: $store.settings.focusDim, in: 0.2...0.9).frame(width: 240)
                }
            } header: {
                Text("Focus mode")
            } footer: {
                Text("⌃⌥B dims every window except the slide you’re in, so the rest of the strip fades away. It ends by itself after the time you choose.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Focus border") {
                Toggle("Outline the focused window", isOn: $store.settings.focusBorder)
                ColorPicker("Colour", selection: borderColor, supportsOpacity: false)
                    .disabled(!store.settings.focusBorder)
                Toggle("Fade into a second colour", isOn: $store.settings.focusBorderGradient)
                    .disabled(!store.settings.focusBorder)
                if store.settings.focusBorderGradient {
                    ColorPicker("Second colour", selection: borderColor2, supportsOpacity: false)
                        .disabled(!store.settings.focusBorder)
                }
                LabeledContent("Width") {
                    Stepper(value: $store.settings.focusBorderWidth, in: 1...10, step: 1) {
                        Text("\(Int(store.settings.focusBorderWidth)) pt").monospacedDigit()
                    }
                }
                .disabled(!store.settings.focusBorder)
                Toggle("Glow", isOn: $store.settings.focusGlow).disabled(!store.settings.focusBorder)
                Toggle("Take the colour of the app’s icon", isOn: $store.settings.borderFromAppIcon)
                    .disabled(!store.settings.focusBorder)
                Toggle("Flash the focused window when focus moves", isOn: $store.settings.focusFlash)
            }
            Section("Overview, menu bar and notices") {
                Toggle("Plain overview backdrop (no colours or glows)", isOn: $store.settings.plainOverview)
                    .help("Also used when Reduce Transparency is on")
                Toggle("App icons in the overview instead of live previews", isOn: $store.settings.overviewIconsOnly)
                Toggle("Show the focused window’s title in the menu bar", isOn: $store.settings.menuBarShowsTitle)
                Picker("Notices appear", selection: $store.settings.noticePosition) {
                    ForEach(NoticePosition.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                LabeledContent("Notices stay for") {
                    HStack {
                        Slider(value: $store.settings.noticeDuration, in: 1...6).frame(width: 200)
                        Text(String(format: "%.1f s", store.settings.noticeDuration)).monospacedDigit()
                    }
                }
            }
            Section("Inactive windows") {
                Toggle("Dim windows that don’t have focus", isOn: $store.settings.dimInactive)
                LabeledContent("Amount") {
                    Slider(value: $store.settings.dimAmount, in: 0.05...0.6).frame(width: 240)
                }
                .disabled(!store.settings.dimInactive)
            }
        }
        .formStyle(.grouped)
    }

    private var borderColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: store.settings.focusBorderColor) ?? .controlAccentColor) },
            set: { store.settings.focusBorderColor = NSColor($0).hexString }
        )
    }

    private var borderColor2: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: store.settings.focusBorderColor2) ?? .systemPink) },
            set: { store.settings.focusBorderColor2 = NSColor($0).hexString }
        )
    }
}

// MARK: - Apps

private struct AppsPane: View {
    @ObservedObject var store: SettingsStore

    private var allRunningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func titleBinding(_ rule: Binding<AppRule>) -> Binding<String> {
        Binding(get: { rule.wrappedValue.titleContains ?? "" }, set: { rule.wrappedValue.titleContains = $0 })
    }

    private var runningApps: [NSRunningApplication] {
        let known = Set(store.settings.appRules.map(\.bundleID))
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && !known.contains($0.bundleIdentifier!) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        Form {
            Section {
                ForEach($store.settings.appRules) { $rule in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(rule.name).fontWeight(.medium)
                            if rule.ruleID != nil || rule.isTitleRule {
                                TextField("Only windows whose title contains…", text: titleBinding($rule))
                                    .textFieldStyle(.roundedBorder).frame(width: 220)
                            } else {
                                Text(rule.bundleID).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                store.settings.appRules.removeAll { $0.id == rule.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                        HStack(spacing: 16) {
                            Toggle("Float", isOn: $rule.float)
                            Toggle("Own slide", isOn: Binding(
                                get: { rule.ownSlide ?? false }, set: { rule.ownSlide = $0 ? true : nil }))
                                .disabled(rule.float)
                            Picker("Width", selection: $rule.width) {
                                Text("Default").tag(Double?.none)
                                ForEach(widthChoices, id: \.1) { Text($0.0).tag(Double?.some($0.1)) }
                            }
                            .frame(width: 150)
                            .disabled(rule.float)
                            Picker("Opens", selection: $rule.position) {
                                Text("Default").tag(Strip.InsertPosition?.none)
                                Text("Next").tag(Strip.InsertPosition?.some(.afterFocused))
                                Text("Start").tag(Strip.InsertPosition?.some(.start))
                                Text("End").tag(Strip.InsertPosition?.some(.end))
                            }
                            .frame(width: 150)
                            .disabled(rule.float)
                        }
                        HStack(spacing: 16) {
                            Picker("Per slide", selection: $rule.tiles) {
                                Text("Default").tag(Int?.none)
                                ForEach(1...Column.maximumWindows, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                            }
                            .frame(width: 130)
                            .disabled(rule.float)
                            Picker("Display", selection: $rule.display) {
                                Text("Any").tag(String?.none)
                                ForEach(NSScreen.screens.map(\.localizedName), id: \.self) { Text($0).tag(String?.some($0)) }
                            }
                            .frame(width: 170)
                            .disabled(rule.float)
                            Picker("Workspace", selection: $rule.workspace) {
                                Text("Current").tag(Int?.none)
                                ForEach(0..<store.settings.workspaceCount, id: \.self) { index in
                                    Text(store.settings.workspaceName(index)).tag(Int?.some(index))
                                }
                            }
                            .frame(width: 190)
                            .disabled(rule.float)
                            Picker("Layout", selection: $rule.arrangement) {
                                Text("Default").tag(Arrangement?.none)
                                ForEach(Arrangement.standard, id: \.self) { Text($0.title).tag(Arrangement?.some($0)) }
                            }
                            .frame(width: 200)
                            .disabled(rule.float)
                        }
                        HStack(spacing: 16) {
                            Toggle("Full width", isOn: optionalFlag($rule.fullWidth)).disabled(rule.float)
                            Toggle("Tabbed", isOn: optionalFlag($rule.tabbed)).disabled(rule.float)
                            Picker("Pin", selection: $rule.pin) {
                                Text("No").tag(PinSide?.none)
                                Text("Left").tag(PinSide?.some(.left))
                                Text("Right").tag(PinSide?.some(.right))
                            }
                            .frame(width: 120)
                            .disabled(rule.float)
                            Toggle("On every workspace", isOn: optionalFlag($rule.sticky))
                            Toggle("Scratchpad", isOn: optionalFlag($rule.scratchpad))
                                .help("Its first window becomes the scratchpad: ⌃⌥` shows and hides it")
                        }
                    }
                    .padding(.vertical, 2)
                }
                HStack {
                    Menu("Add a running app…") {
                        ForEach(runningApps, id: \.processIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "App") {
                                store.settings.appRules.append(
                                    AppRule(bundleID: app.bundleIdentifier!, name: app.localizedName ?? app.bundleIdentifier!))
                            }
                        }
                    }
                    Menu("Add a rule by window title…") {
                        ForEach(allRunningApps, id: \.processIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "App") {
                                store.settings.appRules.append(AppRule(
                                    bundleID: app.bundleIdentifier!, name: app.localizedName ?? app.bundleIdentifier!,
                                    titleContains: "", ruleID: UUID().uuidString))
                            }
                        }
                    }
                }
            } header: {
                Text("Per-app rules")
            } footer: {
                Text("Floating apps stay where you put them. Dialogs, panels and fixed-size windows always float. A title rule only applies to windows whose title contains its words (a browser window titled “Meet”), and takes over when the title changes. Rules apply to windows opened after the change; press ⌃⌥T to float or tile a window right now.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Float windows smaller than") {
                    Picker("", selection: $store.settings.floatSmallerThan) {
                        Text("Off").tag(0.0)
                        ForEach([300.0, 400, 500, 600], id: \.self) { Text("\(Int($0)) pt").tag($0) }
                    }
                    .labelsHidden().frame(width: 120)
                }
                Toggle("Settings and Preferences windows float", isOn: $store.settings.floatSettingsWindows)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pause tiling while these apps are in front (games, video, presentations)")
                    ForEach(store.settings.pauseForApps, id: \.self) { bundleID in
                        HStack {
                            Text(Self.appName(bundleID))
                            Text(bundleID).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button { store.settings.pauseForApps.removeAll { $0 == bundleID } } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Menu("Add a running app…") {
                        ForEach(allRunningApps.filter { !store.settings.pauseForApps.contains($0.bundleIdentifier ?? "") },
                                id: \.processIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "App") {
                                if let id = app.bundleIdentifier { store.settings.pauseForApps.append(id) }
                            }
                        }
                    }
                    .fixedSize()
                }
            } header: {
                Text("Automatic floating and pausing")
            }
            QuickLaunchSection(store: store, apps: allRunningApps)
            TemplatesSection(store: store, apps: allRunningApps)
            Section {
                if store.settings.appPairs.isEmpty {
                    Text("No app pairs yet.").foregroundStyle(.secondary)
                }
                ForEach($store.settings.appPairs) { $pair in
                    HStack {
                        Image(systemName: pair.arrangement.symbol)
                        TextField("Name", text: $pair.name).textFieldStyle(.roundedBorder).frame(width: 200)
                        Text(pair.bundleIDs.map(Self.appName).joined(separator: " · "))
                            .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Toggle("Partners", isOn: optionalFlag($pair.autoPair))
                            .help("A new window of one of these apps joins the other's window in a slide by itself")
                        Button {
                            store.settings.appPairs.removeAll { $0.id == pair.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("App pairs")
            } footer: {
                Text("Right-click a window in a slide’s preview or the overview and choose Save Slide as App Pair. Open a pair from App Pairs in the menu bar: Monorail launches its apps and puts them in one slide.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

extension AppsPane {
    static func appName(_ bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
            ?? bundleID
    }
}

// MARK: - Projects

/// Windows naming a project gather in one workspace.
private struct ProjectsSection: View {
    @ObservedObject var store: SettingsStore
    @State private var newName = ""

    var body: some View {
        Section {
            ForEach(store.settings.projects, id: \.self) { name in
                HStack {
                    Image(systemName: "folder")
                    Text(name)
                    Spacer()
                    Button {
                        store.settings.projects.removeAll { $0 == name }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("Project name, as it appears in window titles", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add).disabled(newName.trimmingCharacters(in: .whitespaces).count < 2)
            }
        } header: {
            Text("Projects")
        } footer: {
            Text("Windows whose titles name a project (your editor, terminal and browser showing “monorail”) gather in the workspace where its first window is.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard name.count >= 2, !store.settings.projects.contains(name) else { return }
        store.settings.projects.append(name)
        newName = ""
    }
}

// MARK: - Templates

/// Workspace templates: apps with files or links, started together in one slide.
private struct TemplatesSection: View {
    @ObservedObject var store: SettingsStore
    let apps: [NSRunningApplication]

    var body: some View {
        Section {
            ForEach($store.settings.templates) { $template in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Name", text: $template.name).textFieldStyle(.roundedBorder).frame(width: 200)
                        Picker("", selection: $template.arrangement) {
                            ForEach(Arrangement.standard, id: \.self) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        Toggle("In an empty workspace", isOn: $template.emptyWorkspace)
                        Spacer()
                        Button("Start") { NotificationCenter.default.post(name: .monorailRunTemplate, object: template.id) }
                        Button {
                            store.settings.templates.removeAll { $0.id == template.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    ForEach($template.items) { $entry in
                        HStack(alignment: .top) {
                            Text(UsageStats.appName(entry.bundleID)).frame(width: 120, alignment: .leading)
                            TextField("Files, folders or links to open, one per line", text: $entry.open, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1...3)
                            Button {
                                template.items.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Menu("Add an app…") {
                        ForEach(apps, id: \.processIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "App") {
                                if template.items.count < Column.maximumWindows {
                                    template.items.append(.init(bundleID: app.bundleIdentifier!))
                                }
                            }
                        }
                    }
                    .fixedSize()
                }
                .padding(.vertical, 3)
            }
            HStack {
                Button("New Template") { store.settings.templates.append(WorkspaceTemplate(name: "Coding")) }
                Menu("Add from the Gallery") {
                    ForEach(TemplateGallery.all, id: \.name) { template in
                        Button(template.name) {
                            var copy = template
                            copy.id = UUID().uuidString
                            store.settings.templates.append(copy)
                        }
                        .disabled(store.settings.templates.contains { $0.name == template.name })
                    }
                }
                .fixedSize()
            }
        } header: {
            Text("Workspace templates")
        } footer: {
            Text("Start a template from the menu bar, the command palette or monorail://template/Name: Monorail opens each app with its files and links and puts them side by side in one slide. Share one as a .monorail file from Saved Layouts.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Local API

private struct APISection: View {
    @ObservedObject var store: SettingsStore
    @State private var copied = ""

    private var mcpConfig: String {
        let binary = Bundle.main.executablePath ?? "/Applications/Monorail.app/Contents/MacOS/Monorail"
        return """
        "monorail": { "command": "\(binary)", "args": ["--mcp"] }
        """
    }

    var body: some View {
        Section {
            Toggle("Local API on this Mac only (needed by the MCP server and the Raycast extension)", isOn: $store.settings.localAPI).hiddenInAppStore()
            if store.settings.localAPI {
                LabeledContent("Address") {
                    Text("http://127.0.0.1:\(store.settings.apiPort)").font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                }
                HStack {
                    Button("Copy Token") { copy(LocalAPI.token(), "Token copied") }
                    Button("Copy MCP Server Config") { copy(mcpConfig, "Config copied") }
                    if !copied.isEmpty { Text(copied).font(.callout).foregroundStyle(.green) }
                }
            }
        } header: {
            Text("API and AI assistants")
        } footer: {
            Text("Add the MCP config to Claude Desktop (or any MCP client) and ask: “put my editor and browser side by side”. Requests need the token, which only you can read; the API only listens on this Mac.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func copy(_ text: String, _ message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = "" }
    }
}

extension Notification.Name {
    static let monorailReloadScripts = Notification.Name("org.ashforde.monorail.reloadScripts")
    static let monorailRunTemplate = Notification.Name("org.ashforde.monorail.runTemplate")
    static let monorailCopyDiagnostics = Notification.Name("org.ashforde.monorail.copyDiagnostics")
    static let monorailForgetWholeSlideApp = Notification.Name("org.ashforde.monorail.forgetWholeSlideApp")
}

// MARK: - Wallpapers

/// Choose a desktop picture for one workspace; it is set as you switch to it.
private struct WallpaperButton: View {
    @ObservedObject var store: SettingsStore
    let index: Int

    private var path: String? { store.settings.workspaceWallpapers[String(index)] }

    var body: some View {
        Menu {
            Button("Choose Picture…") { choose() }
            if path != nil {
                Button("No Picture of Its Own") { store.settings.workspaceWallpapers[String(index)] = nil }
            }
        } label: {
            if let path, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image).resizable().scaledToFill().frame(width: 28, height: 18).clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "photo")
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(path.map { "Desktop picture: \(($0 as NSString).lastPathComponent)" } ?? "Give this workspace its own desktop picture")
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.directoryURL = URL(fileURLWithPath: "/System/Library/Desktop Pictures")
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            store.settings.workspaceWallpapers[String(index)] = url.path
        }
    }
}

// MARK: - Backups

private struct BackupsSection: View {
    @ObservedObject var store: SettingsStore
    @State private var restored = ""

    var body: some View {
        Section {
            Toggle("Keep a copy of the settings each day (the last seven)", isOn: $store.settings.dailyBackups)
            let backups = store.backups()
            if backups.isEmpty {
                Text("No backups yet. The first is made when Monorail next starts.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(backups, id: \.self) { url in
                HStack {
                    Text(url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "settings-", with: ""))
                        .monospacedDigit()
                    Spacer()
                    if restored == url.lastPathComponent { Text("Restored").foregroundStyle(.green) }
                    Button("Restore") {
                        store.restore(backup: url)
                        restored = url.lastPathComponent
                    }
                }
            }
        } header: {
            Text("Backups")
        }
    }
}

// MARK: - Whole-slide apps

/// Apps Monorail found can't shrink to share a slide, with a way to let them try again.
private struct WholeSlideAppsSection: View {
    @State private var apps: [String] = []

    var body: some View {
        Section {
            if apps.isEmpty {
                Text("None. Apps whose windows can’t get small enough to share a slide show up here.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(apps, id: \.self) { app in
                HStack {
                    Text(UsageStats.appName(app))
                    Spacer()
                    Button("Let It Share Again") {
                        NotificationCenter.default.post(name: .monorailForgetWholeSlideApp, object: app)
                        apps.removeAll { $0 == app }
                    }
                }
            }
        } header: {
            Text("Apps that need a whole slide")
        }
        .onAppear { apps = WholeSlideApps.list() }
    }
}

/// Lets Settings see the engine's list without holding the engine.
enum WholeSlideApps {
    static var list: () -> [String] = { [] }
}

// MARK: - Restore

private struct RestoreSection: View {
    @ObservedObject var store: SettingsStore
    @State private var confirming = false
    @State private var done = false

    var body: some View {
        Section {
            HStack {
                Button("Restore All Settings to Defaults…") { confirming = true }
                if done { Label("Restored", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            }
            .confirmationDialog("Restore all settings to their defaults?", isPresented: $confirming) {
                Button("Restore Defaults", role: .destructive) {
                    store.restoreAllDefaults()
                    done = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { done = false }
                }
            } message: {
                Text("Shortcuts, gestures, layout and appearance go back to how Monorail comes. Your workspace and profile names, rules, app pairs, layouts and quick launch letters stay.")
            }
        } footer: {
            Text("Export your settings first if you might want them back.").font(.callout).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sync, export and import

private struct SyncSection: View {
    @ObservedObject var store: SettingsStore
    @State private var message = ""

    var body: some View {
        Section {
            Toggle("Sync settings, layouts and app pairs through iCloud Drive", isOn: $store.settings.syncThroughICloud)
                .disabled(SettingsStore.cloudURL == nil)
            HStack {
                Button("Export Settings…") { export() }
                Button("Import Settings…") { importFile() }
                if !message.isEmpty { Text(message).font(.callout).foregroundStyle(.secondary) }
            }
        } header: {
            Text("Your Macs")
        } footer: {
            Text(SettingsStore.cloudURL == nil
                 ? "Turn on iCloud Drive in System Settings to sync. Export makes one file with your settings, shortcuts, rules, app pairs and saved layouts, to share or keep."
                 : "Syncing keeps a file in iCloud Drive ▸ Monorail and checks it every minute. Each Mac keeps its own display settings. Export makes one file with everything, to share or keep.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Monorail Settings.json"
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.export(to: url)
            message = "Exported."
        } catch {
            message = "Couldn’t export: \(error.localizedDescription)"
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.importBundle(from: url)
            message = "Imported."
        } catch {
            message = "That file isn’t a Monorail settings file."
        }
    }
}

// MARK: - Per display

/// Gaps, new-window width and the slider bar for each connected display.
private struct DisplaysSection: View {
    @ObservedObject var store: SettingsStore
    private let displays = Display.all()

    var body: some View {
        Section {
            ForEach(displays, id: \.uuid) { display in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: hasOverride(display)) {
                        Text(display.name).fontWeight(.medium)
                        + Text("  \(Int(display.frame.width)) × \(Int(display.frame.height))").foregroundColor(.secondary)
                    }
                    if store.settings.displayOverrides[display.uuid] != nil {
                        LabeledSlider(title: "Gap between windows", value: value(display, \.gap, store.settings.layout.gap), range: 0...40)
                        LabeledSlider(title: "Gap at screen edges", value: value(display, \.edgeGap, store.settings.layout.edgeGap), range: 0...40)
                        Picker("New window width", selection: value(display, \.defaultWidth, store.settings.layout.defaultWidth)) {
                            ForEach(widthChoices, id: \.1) { Text($0.0).tag($0.1) }
                        }
                        Picker("Slider bar", selection: barBinding(display)) {
                            Text("Same as everywhere").tag(SliderBarMode?.none)
                            Text("Always").tag(SliderBarMode?.some(.always))
                            Text("Only while sliding").tag(SliderBarMode?.some(.whileMoving))
                            Text("Off").tag(SliderBarMode?.some(.off))
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Displays")
        } footer: {
            Text("Give a display its own settings, say wider gaps and no slider bar on a big monitor.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func hasOverride(_ display: Display) -> Binding<Bool> {
        Binding(
            get: { store.settings.displayOverrides[display.uuid] != nil },
            set: { on in
                store.settings.displayOverrides[display.uuid] = on ? DisplayOverride(name: display.name) : nil
            })
    }

    private func value(_ display: Display, _ path: WritableKeyPath<DisplayOverride, Double?>, _ fallback: Double) -> Binding<Double> {
        Binding(
            get: { store.settings.displayOverrides[display.uuid]?[keyPath: path] ?? fallback },
            set: { store.settings.displayOverrides[display.uuid]?[keyPath: path] = $0 })
    }

    private func barBinding(_ display: Display) -> Binding<SliderBarMode?> {
        Binding(
            get: { store.settings.displayOverrides[display.uuid]?.sliderBar },
            set: { store.settings.displayOverrides[display.uuid]?.sliderBar = $0 })
    }
}

// MARK: - Quick launch

/// ⌃⌥U then a letter opens an app, or goes to its window.
private struct QuickLaunchSection: View {
    @ObservedObject var store: SettingsStore
    let apps: [NSRunningApplication]
    @State private var letter = "t"

    private static let letters = "abcdefghijklmnopqrstuvwxyz0123456789".map(String.init)

    var body: some View {
        Section {
            ForEach(store.settings.launchSlots.keys.sorted(), id: \.self) { key in
                HStack {
                    Text(key.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.08)))
                    Text(UsageStats.appName(store.settings.launchSlots[key] ?? ""))
                    Spacer()
                    Button {
                        store.settings.launchSlots[key] = nil
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                Picker("Letter", selection: $letter) {
                    ForEach(Self.letters, id: \.self) { Text($0.uppercased()).tag($0) }
                }
                .frame(width: 120)
                Menu("Assign a running app…") {
                    ForEach(apps, id: \.processIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "App") {
                            store.settings.launchSlots[letter] = app.bundleIdentifier
                        }
                    }
                }
            }
        } header: {
            Text("Quick launch")
        } footer: {
            Text("Press ⌃⌥U, then the letter: Monorail goes to that app’s window, or opens the app if it isn’t running.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Automation

private struct AutomationPane: View {
    @ObservedObject var store: SettingsStore

    private static let weekdayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        Form {
            Section {
                LabeledContent("Pomodoro") {
                    HStack {
                        Stepper("Focus \(store.settings.pomodoroFocus) min", value: $store.settings.pomodoroFocus, in: 5...120, step: 5)
                        Stepper("Break \(store.settings.pomodoroBreak) min", value: $store.settings.pomodoroBreak, in: 1...30)
                    }
                }
                Picker("Remind me to take a break", selection: $store.settings.breakReminderMinutes) {
                    Text("Never").tag(0)
                    ForEach([20, 30, 45, 60, 90], id: \.self) { Text("Every \($0) minutes").tag($0) }
                }
            } header: {
                Text("Focus and breaks")
            } footer: {
                Text("Start a pomodoro from the command palette or a shortcut (Settings → Shortcuts): focus mode turns on for the focus block and the countdown shows in the menu bar. Set a daily focus goal in Insights.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Picker("Park workspaces I haven’t visited for", selection: $store.settings.autoParkHours) {
                    Text("Never").tag(0)
                    ForEach([1, 2, 4, 8, 24], id: \.self) { Text("\($0) hour\($0 == 1 ? "" : "s")").tag($0) }
                }
                Toggle("Lay windows out again after the Mac wakes", isOn: $store.settings.retileAfterWake)
                Toggle("Bring every window back if Monorail quit unexpectedly", isOn: $store.settings.rescueAfterCrash)
            } header: {
                Text("Housekeeping")
            }
            Section {
                TextField("Webhook URL", text: $store.settings.webhookURL, prompt: Text("https://example.com/hooks/monorail"))
                    .textFieldStyle(.roundedBorder)
                Toggle("Let other apps run actions with a distributed notification", isOn: $store.settings.remoteCommands)
            } header: {
                Text("Webhooks and remote commands")
            } footer: {
                Text("Monorail POSTs JSON for workspace, focus and window-closed events, and pomodoro changes, to the webhook. Remote commands: post org.ashforde.monorail.perform with an action name (e.g. overview) as the object, from Swift, AppleScript-ObjC or a shell tool.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            WorkspaceConfigSection(store: store)
            ScriptGallerySection()
            Section {
                ForEach($store.settings.autoRules) { $rule in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("", isOn: $rule.isEnabled).labelsHidden()
                            TextField("Name", text: $rule.name).textFieldStyle(.roundedBorder).frame(width: 180)
                            Picker("", selection: $rule.trigger) {
                                Text("At a time").tag(AutoRule.Trigger.time)
                                Text("On Wi-Fi").tag(AutoRule.Trigger.wifi)
                                Text("On a display").tag(AutoRule.Trigger.display)
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            Spacer()
                            Button {
                                store.settings.autoRules.removeAll { $0.id == rule.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        HStack(spacing: 12) {
                            if rule.trigger == .time {
                                DatePicker("", selection: timeBinding($rule), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                HStack(spacing: 3) {
                                    ForEach(1...7, id: \.self) { day in
                                        let on = rule.weekdays.contains(day)
                                        Button(Self.weekdayNames[day - 1]) {
                                            if on { rule.weekdays.removeAll { $0 == day } } else { rule.weekdays.append(day) }
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(on ? Color.accentColor : Color.primary.opacity(0.08)))
                                        .foregroundStyle(on ? Color.white : Color.primary)
                                    }
                                }
                                .help("Days it runs; none means every day")
                            } else if rule.trigger == .wifi {
                                TextField("Network name", text: $rule.network).textFieldStyle(.roundedBorder).frame(width: 180)
                                if let current = AutoRules.currentNetwork() {
                                    Button("Use “\(current)”") { rule.network = current }
                                }
                            } else {
                                Picker("When connected", selection: $rule.network) {
                                    Text("Choose a display").tag("")
                                    ForEach(NSScreen.screens.map(\.localizedName), id: \.self) { Text($0).tag($0) }
                                    if !rule.network.isEmpty && !NSScreen.screens.contains(where: { $0.localizedName == rule.network }) {
                                        Text(rule.network).tag(rule.network)
                                    }
                                }
                                .frame(width: 280)
                            }
                        }
                        HStack(spacing: 12) {
                            Picker("Profile", selection: $rule.profile) {
                                Text("Keep").tag(Int?.none)
                                ForEach(store.settings.profiles.indices, id: \.self) { Text(store.settings.profiles[$0]).tag(Int?.some($0)) }
                            }
                            .frame(width: 200)
                            Picker("Layout", selection: layoutBinding($rule)) {
                                Text("Keep").tag("")
                                ForEach(layoutNames, id: \.self) { Text($0).tag($0) }
                            }
                            .frame(width: 220)
                        }
                    }
                    .padding(.vertical, 3)
                }
                HStack {
                    Button("Add Time Rule") {
                        store.settings.autoRules.append(AutoRule(name: "Mornings", trigger: .time, weekdays: [2, 3, 4, 5, 6]))
                    }
                    Button("Add Wi-Fi Rule") {
                        store.settings.autoRules.append(AutoRule(
                            name: "Office", trigger: .wifi, network: AutoRules.currentNetwork() ?? ""))
                    }
                }
            } header: {
                Text("Auto rules")
            } footer: {
                Text("Switch profile or apply a saved layout at a time of day, or when you join a Wi-Fi network. macOS asks for Location access the first time, because it only tells apps the network’s name with that permission.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                ForEach(Self.urls.indices, id: \.self) { index in
                    let (url, what) = Self.urls[index]
                    HStack {
                        Text(url).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                        Text(what).font(.callout).foregroundStyle(.secondary)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy")
                    }
                }
            } header: {
                Text("Shortcuts app, scripts and Raycast")
            } footer: {
                Text("In the Shortcuts app add “Open URLs” with one of these; in a script use open \"monorail://…\". Every action in the Shortcuts list works too, like monorail://focus-left.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Publish state for status bars (SketchyBar and others)", isOn: $store.settings.publishState)
                if store.settings.publishState {
                    LabeledContent("State file") {
                        Text(Integrations.stateURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    }
                    LabeledContent("Notification") {
                        Text(Integrations.notification.rawValue).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    }
                }
                HStack {
                    TextField("Event script (optional)", text: $store.settings.eventScript)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = false
                        NSApp.activate(ignoringOtherApps: true)
                        if panel.runModal() == .OK, let url = panel.url { store.settings.eventScript = url.path }
                    }
                }
                Toggle("Apply changes made to settings.json in a text editor", isOn: $store.settings.liveReloadSettings)
                Button("Reveal settings.json") { NSWorkspace.shared.activateFileViewerSelecting([SettingsStore.fileURL]) }
            } header: {
                Text("For power users")
            } footer: {
                Text("The event script runs with workspace_changed, focus_changed, focus_mode_on or focus_mode_off, and MONORAIL_WORKSPACE, MONORAIL_APP, MONORAIL_TITLE and more in its environment. It must be executable (chmod +x).")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Open video calls a minute before they start", isOn: $store.settings.meetingHelper)
                Picker("And switch to profile", selection: $store.settings.meetingProfile) {
                    Text("Keep the current one").tag(Int?.none)
                    ForEach(store.settings.profiles.indices, id: \.self) { Text(store.settings.profiles[$0]).tag(Int?.some($0)) }
                }
                .disabled(!store.settings.meetingHelper)
            } header: {
                Text("Meetings")
            } footer: {
                Text("Looks for Zoom, Meet, Teams, Webex and FaceTime links in your calendar events. macOS asks for calendar access first; nothing leaves your Mac.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            APISection(store: store)
            Section {
                Toggle("Run JavaScript plugins from the Scripts folder", isOn: $store.settings.scripts).hiddenInAppStore()
                HStack {
                    Button("Open Scripts Folder") {
                        try? FileManager.default.createDirectory(at: ScriptHost.folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(ScriptHost.folder)
                    }
                    Button("Reload Scripts") {
                        NotificationCenter.default.post(name: .monorailReloadScripts, object: nil)
                    }
                    .disabled(!store.settings.scripts)
                }
            } header: {
                Text("Scripts")
            } footer: {
                Text("monorail.on(\"windowOpened\", w => …), on(\"workspaceChanged\"), on(\"focusChanged\"); call perform(\"focus-left\"), moveToWorkspace(id, 2), park(3), openPair(name), applyLayout(name), notify(text). An example is in the folder.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private static let urls: [(String, String)] = [
        ("monorail://layout/Coding", "apply a saved layout"),
        ("monorail://pair/Safari + Notes", "open an app pair"),
        ("monorail://snapshot/Friday", "restore a snapshot"),
        ("monorail://save-snapshot/Friday", "take a snapshot"),
        ("monorail://profile/Work", "switch profile"),
        ("monorail://workspace/2", "go to a workspace"),
        ("monorail://focus-mode/on", "focus mode on or off"),
        ("monorail://launch/t", "quick launch"),
        ("monorail://palette", "command palette"),
    ]

    private var layoutNames: [String] {
        ((try? Data(contentsOf: SettingsStore.layoutsURL))
            .flatMap { try? JSONDecoder().decode([SavedLayout].self, from: $0) } ?? [])
            .filter { $0.isSnapshot != true }.map(\.name)
    }

    private func layoutBinding(_ rule: Binding<AutoRule>) -> Binding<String> {
        Binding(get: { rule.wrappedValue.layout ?? "" }, set: { rule.wrappedValue.layout = $0.isEmpty ? nil : $0 })
    }

    private func timeBinding(_ rule: Binding<AutoRule>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: rule.wrappedValue.minuteOfDay / 60, minute: rule.wrappedValue.minuteOfDay % 60,
                    second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                rule.wrappedValue.minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            })
    }
}

// MARK: - Profiles

/// Profiles: whole sets of workspaces, like separate desks for work and home.
private struct ProfilesSection: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Section {
            ForEach(store.settings.profiles.indices, id: \.self) { index in
                HStack {
                    TextField("Profile \(index + 1)", text: name(index)).textFieldStyle(.roundedBorder).frame(width: 220)
                    Spacer()
                    if store.settings.profiles.count > 1 {
                        Button {
                            store.settings.profiles.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            Button("Add Profile") { store.settings.profiles.append("Profile \(store.settings.profiles.count + 1)") }
                .disabled(store.settings.profiles.count >= 9)
        } header: {
            Text("Profiles")
        } footer: {
            Text("Each profile has its own workspaces and windows. Switch with ⌃⌥0 or from the menu bar; the other profiles’ windows wait out of sight.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func name(_ index: Int) -> Binding<String> {
        Binding(
            get: { store.settings.profiles.indices.contains(index) ? store.settings.profiles[index] : "" },
            set: { if store.settings.profiles.indices.contains(index) { store.settings.profiles[index] = $0 } }
        )
    }
}

// MARK: - Custom layouts

/// Design slide layouts: columns side by side, each split into rows.
private struct CustomLayoutsSection: View {
    @ObservedObject var store: SettingsStore
    @State private var designing: String?

    var body: some View {
        Section {
            ForEach($store.settings.customLayouts) { $layout in
                HStack(alignment: .center, spacing: 14) {
                    LayoutDiagram(rows: layout.rows, zones: layout.zones).frame(width: 84, height: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Name", text: $layout.name).textFieldStyle(.roundedBorder).frame(width: 200)
                        HStack(spacing: 10) {
                            ForEach(layout.rows.indices, id: \.self) { column in
                                Stepper(value: rowBinding($layout, column), in: 1...4) {
                                    Text("\(layout.rows[column])").monospacedDigit()
                                }
                                .fixedSize()
                                .help("Rows in column \(column + 1)")
                            }
                            Button {
                                if layout.tiles < Column.maximumWindows { layout.rows.append(1) }
                            } label: {
                                Image(systemName: "plus.rectangle")
                            }
                            .buttonStyle(.borderless)
                            .help("Add a column")
                            .disabled(layout.rows.count >= 4 || layout.tiles >= Column.maximumWindows)
                            Button {
                                if layout.rows.count > 1 { layout.rows.removeLast() }
                            } label: {
                                Image(systemName: "minus.rectangle")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove the last column")
                            .disabled(layout.rows.count <= 1)
                        }
                    }
                    Spacer()
                    Button("Design Zones…") { designing = layout.id }
                        .help("Draw the slide yourself: split any zone side by side or up and down, as deep as you like")
                    Button {
                        store.settings.customLayouts.removeAll { $0.id == layout.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .sheet(isPresented: Binding(get: { designing == layout.id }, set: { if !$0 { designing = nil } })) {
                    ZoneEditor(layout: $layout) { designing = nil }
                }
            }
            Button("New Layout") {
                store.settings.customLayouts.append(CustomLayout(name: "My layout", rows: [1, 2]))
            }
        } header: {
            Text("Custom slide layouts")
        } footer: {
            Text("Each column is split into the number of rows shown, or choose Design Zones… to draw any layout. Use them from a slide’s right-click menu ▸ Slide Layout.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    /// Rows of one column, kept within six windows in all.
    private func rowBinding(_ layout: Binding<CustomLayout>, _ column: Int) -> Binding<Int> {
        Binding(
            get: { layout.wrappedValue.rows.indices.contains(column) ? layout.wrappedValue.rows[column] : 1 },
            set: { value in
                guard layout.wrappedValue.rows.indices.contains(column) else { return }
                let others = layout.wrappedValue.tiles - layout.wrappedValue.rows[column]
                layout.wrappedValue.rows[column] = min(value, Column.maximumWindows - others)
            }
        )
    }
}

/// A small drawing of a custom layout.
private struct LayoutDiagram: View {
    let rows: [Int]
    var zones: SplitTree? = nil

    var body: some View {
        GeometryReader { geometry in
            let frames = zones?.tiles().map(\.frame) ?? Arrangement.customFrames(count: max(rows.reduce(0, +), 1), rows: rows)
            ZStack(alignment: .topLeading) {
                ForEach(Array(frames.enumerated()), id: \.offset) { _, unit in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.35))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.accentColor.opacity(0.8)))
                        .frame(
                            width: max(unit.width * geometry.size.width - 3, 2),
                            height: max(unit.height * geometry.size.height - 3, 2))
                        .offset(x: unit.minX * geometry.size.width + 1.5, y: unit.minY * geometry.size.height + 1.5)
                }
            }
        }
    }
}

/// Draw a slide layout: pick a zone, split it side by side or up and down, resize, remove.
private struct ZoneEditor: View {
    @Binding var layout: CustomLayout
    let done: () -> Void
    @State private var zones: SplitTree = .single(1)
    @State private var selected: WindowID = 1

    private var nextID: WindowID { (zones.windows.max() ?? 0) + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Design “\(layout.name)”").font(.title3.weight(.semibold))
            Text("Click a zone, then split it. Windows fill zones in number order; extra windows join on the right.")
                .font(.callout).foregroundStyle(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ForEach(zones.tiles(), id: \.window) { tile in
                        let f = tile.frame
                        Button { selected = tile.window } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(tile.window == selected ? 0.45 : 0.18))
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.accentColor.opacity(tile.window == selected ? 1 : 0.5), lineWidth: tile.window == selected ? 2.5 : 1)
                                Text("\(position(of: tile.window))").font(.title2.weight(.bold)).foregroundStyle(.primary.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Zone \(position(of: tile.window))\(tile.window == selected ? ", selected" : "")")
                        .frame(width: max(f.width * geometry.size.width - 6, 8), height: max(f.height * geometry.size.height - 6, 8))
                        .offset(x: f.minX * geometry.size.width + 3, y: f.minY * geometry.size.height + 3)
                    }
                }
            }
            .frame(width: 520, height: 320)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
            HStack {
                Button { split(.right) } label: { Label("Split Side by Side", systemImage: "rectangle.split.2x1") }
                    .disabled(zones.windows.count >= 9)
                Button { split(.bottom) } label: { Label("Split Up and Down", systemImage: "rectangle.split.1x2") }
                    .disabled(zones.windows.count >= 9)
                Button { remove() } label: { Label("Remove", systemImage: "minus.rectangle") }
                    .disabled(zones.windows.count <= 1)
            }
            HStack {
                Text("Selected zone:").foregroundStyle(.secondary)
                Button("Narrower") { zones = zones.adjusting(selected, axis: .horizontal, by: -0.05) }
                Button("Wider") { zones = zones.adjusting(selected, axis: .horizontal, by: 0.05) }
                Button("Shorter") { zones = zones.adjusting(selected, axis: .vertical, by: -0.05) }
                Button("Taller") { zones = zones.adjusting(selected, axis: .vertical, by: 0.05) }
                Button("Even Out") { zones = zones.balanced }
            }
            HStack {
                Button("Start from Columns") { zones = CustomLayout(name: "", rows: layout.rows).zonesOrDefault }
                Spacer()
                Button("Cancel", action: done).keyboardShortcut(.cancelAction)
                Button("Save") {
                    layout.zones = zones
                    done()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear {
            zones = layout.zonesOrDefault
            selected = zones.windows.first ?? 1
        }
    }

    /// Zones are numbered in the order windows fill them.
    private func position(of zone: WindowID) -> Int { (zones.windows.firstIndex(of: zone) ?? 0) + 1 }

    private func split(_ edge: SplitTree.Edge) {
        guard zones.windows.count < 9 else { return }
        let id = nextID
        zones = zones.docking(id, onto: selected, edge: edge)
        selected = id
    }

    private func remove() {
        guard zones.windows.count > 1, let next = zones.removing(selected) else { return }
        zones = next
        selected = next.windows.first ?? 1
    }
}

// MARK: - Shortcuts

private struct ShortcutsPane: View {
    @ObservedObject var store: SettingsStore
    @State private var restored = false

    private static let groups: [(String, [Action])] = [
        ("Focus", [.focusLeft, .focusRight, .focusUp, .focusDown, .focusFirst, .focusLast, .overview, .windowSwitcher]),
        ("Move", [.moveLeft, .moveRight, .moveUp, .moveDown, .sendToNextDisplay]),
        ("Size", [.cycleWidth, .cycleWidthBackward, .narrower, .wider, .toggleFullWidth, .center, .toggleNativeFullScreen]),
        ("Slides & columns", [.regroup, .cycleLayout, .mainLarger, .mainSmaller, .makeMain, .consumeIntoLeft, .consumeIntoRight, .expelLeft, .expel,
                              .toggleTabbed, .pinLeft, .pinRight, .toggleFloat]),
        ("Workspaces", Action.allCases.filter { $0.workspaceNumber != nil || $0.moveToWorkspaceNumber != nil }),
        ("Jump", [.focusColumn1, .focusColumn2, .focusColumn3, .focusColumn4, .focusColumn5,
                  .focusColumn6, .focusColumn7, .focusColumn8, .focusColumn9]),
        ("Snap floating windows", Action.allCases.filter { $0.snapPosition != nil } + [.snapRestore]),
        ("Marks, scratchpad & profiles", [.setMark, .jumpToMark, .lastWindow, .toggleScratchpad, .makeScratchpad,
                                          .toggleSticky, .pictureInPicture, .nextProfile]),
        ("Focus, launch & more", [.toggleFocusMode, .zoomTile, .commandPalette, .quickLaunch, .takeSnapshot]),
        ("Power moves", [.radialMenu, .balanceSizes, .workspaceBackAndForth, .moveToEmptyWorkspace, .focusAttention,
                         .showDesktop, .screenshotSlide, .appOverview]),
        ("Monorail", [.undo, .togglePause, .retile]),
        ("Slides (1.1)", [.slideToStart, .slideToEnd, .slideToNextWorkspace, .slideToPreviousWorkspace, .slideToEmptyWorkspace,
                          .unpairSlide, .mergeNext, .mergePrevious, .nextTile, .previousTile, .mainTile, .resetSplit,
                          .scrollToStart, .scrollToEnd]),
        ("Exact widths and layouts", [.widthQuarter, .widthThird, .widthHalf, .widthTwoThirds, .widthThreeQuarters,
                                      .layoutSideBySide, .layoutUpDown, .layoutGrid, .layoutMainSide, .layoutMainBottom,
                                      .layoutSpiral, .layoutAccordion, .layoutTabs]),
        ("Workspaces & apps", [.renameWorkspace, .swapWorkspaceNext, .swapWorkspacePrevious, .mergeWorkspacePrevious,
                               .minimizeWorkspace, .minimizeOthers, .hideApp, .quickLaunchBeside, .openLinkBeside]),
        ("Find, note & share", [.locatePointer, .flashFocus, .noteWindow, .copyLayout, .pasteLayout]),
        ("Quick toggles", [.toggleDim, .toggleBorder, .toggleSliderBar, .toggleAnimations, .toggleQuietMode, .pomodoro,
                           .openSettings, .checkForUpdates, .restart]),
    ]

    var body: some View {
        Form {
            Section {
                Picker("Shortcut modifier keys", selection: prefix) {
                    ForEach(Keymap.prefixes, id: \.rawValue) { Text($0.symbols).tag($0) }
                }
                HStack {
                    Text("Add ⇧ to move instead of focus. Click a shortcut to change it; each action can have several.")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    if restored {
                        Label("Restored", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    Button("Restore defaults") {
                        store.restoreDefaultShortcuts()
                        restored = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { restored = false }
                    }
                    .disabled(store.settings.keymap == .default)
                    .help(store.settings.keymap == .default ? "Your shortcuts are the defaults" : "Put every shortcut back to its default")
                }
            }
            ForEach(Self.groups, id: \.0) { group in
                Section(group.0) {
                    ForEach(group.1, id: \.self) { action in
                        ShortcutRow(store: store, action: action)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var prefix: Binding<Modifiers> {
        Binding(
            get: { store.settings.keymap.dominantPrefix },
            set: { new in
                let old = store.settings.keymap.dominantPrefix
                store.settings.keymap = store.settings.keymap.replacingPrefix(old, with: new)
            }
        )
    }
}

private struct ShortcutRow: View {
    @ObservedObject var store: SettingsStore
    let action: Action
    @StateObject private var capture = ShortcutCapture()

    var body: some View {
        LabeledContent(action.title) {
            HStack(spacing: 6) {
                let shortcuts = store.settings.keymap.shortcuts(for: action)
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { index, shortcut in
                    Button {
                        record(replacing: index)
                    } label: {
                        Text(capture.recordingIndex == index ? "Type shortcut…" : shortcut.displayString)
                            .monospaced()
                    }
                    .contextMenu {
                        Button("Remove") { store.settings.keymap.unbind(action, at: index) }
                    }
                }
                if store.settings.keymap.shortcuts(for: action) != Keymap.default.shortcuts(for: action) {
                    Button {
                        capture.stop()
                        store.settings.keymap.bindings[action] = Keymap.default.shortcuts(for: action)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help("Back to the default for this action")
                }
                Button {
                    record(replacing: nil)
                } label: {
                    if capture.isRecording && capture.recordingIndex == nil {
                        Text("Type shortcut…")
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .help("Add a shortcut")
            }
        }
        // Restoring defaults or closing Settings ends a recording in progress.
        .onReceive(store.$cancelRecording.dropFirst()) { _ in capture.stop() }
        .onDisappear {
            if capture.isRecording {
                capture.stop()
                store.isRecordingShortcut = false
            }
        }
    }

    private func record(replacing index: Int?) {
        store.isRecordingShortcut = true
        capture.start(index: index) { shortcut in
            store.isRecordingShortcut = false
            guard let shortcut else { return }
            store.settings.keymap.bind(shortcut, to: action, replacingIndex: index)
        }
    }
}

/// Captures the next key press in the Settings window. Escape cancels.
/// Shortcuts need a modifier, except for function keys.
final class ShortcutCapture: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordingIndex: Int?
    private var monitor: Any?

    func start(index: Int?, completion: @escaping (Shortcut?) -> Void) {
        stop()
        isRecording = true
        recordingIndex = index
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let mods = Modifiers(event.modifierFlags)
            let isFunctionKey = (96...122).contains(Int(event.keyCode))
            if event.keyCode == KeyCode.escape && mods.isEmpty {
                self.stop()
                completion(nil)
            } else if mods.isEmpty && !isFunctionKey {
                NSSound.beep()  // Needs at least one modifier.
            } else {
                self.stop()
                completion(Shortcut(keyCode: event.keyCode, modifiers: mods))
            }
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        recordingIndex = nil
    }

    deinit { stop() }
}

// MARK: - About

private struct AboutPane: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 2) {
                Text(Brand.name).font(.largeTitle).fontWeight(.semibold)
                Text(Brand.maker).font(.title3).foregroundStyle(.secondary)
            }
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("A scrolling window manager for macOS. Every window keeps its size on one endless strip.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            HStack(spacing: 16) {
                Link("Website & source", destination: URL(string: "https://github.com/ashfordeOU/monorail")!)
                Link("Report an issue", destination: URL(string: "https://github.com/ashfordeOU/monorail/issues")!)
            }
            Text("\(Brand.full) · © Ashforde OÜ · Functional Source License 1.1")
                .font(.footnote).foregroundStyle(.secondary)
            if let log = UsageBridge.log {
                UsageSection(log: log).frame(maxWidth: 620)
            }
            // Tools for troubleshooting and power users, out of the way until wanted.
            DisclosureGroup("Advanced") {
                HStack(spacing: 10) {
                    Button("Copy Diagnostics") { NotificationCenter.default.post(name: .monorailCopyDiagnostics, object: nil) }
                        .help("A short report (no window titles) to paste into a bug report")
                    Button("Show Log") { LogViewer.show() }
                    Button("Reveal Settings File") {
                        NSWorkspace.shared.activateFileViewerSelecting([SettingsStore.fileURL])
                    }
                    .help("settings.json: edit it in any text editor and Monorail picks up the change when you save")
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: 620)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
/// A toggle for an optional flag stored as true or nil.
func optionalFlag(_ value: Binding<Bool?>) -> Binding<Bool> {
    Binding(get: { value.wrappedValue ?? false }, set: { value.wrappedValue = $0 ? true : nil })
}
/// Settings → Automation → Each workspace: colour, layout, gap, focus mode, closed.
private struct WorkspaceConfigSection: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Section {
            ForEach(0..<max(store.settings.workspaceCount, 1), id: \.self) { index in
                let config = binding(index)
                HStack(spacing: 12) {
                    Circle().fill(WorkspaceColor.color(index)).frame(width: 10, height: 10)
                    Text(store.settings.workspaceName(index)).frame(width: 120, alignment: .leading)
                    ColorPicker("", selection: color(config), supportsOpacity: false).labelsHidden()
                    Picker("", selection: config.arrangement) {
                        Text("Default layout").tag(Arrangement?.none)
                        ForEach(Arrangement.standard, id: \.self) { Text($0.title).tag(Arrangement?.some($0)) }
                    }
                    .labelsHidden().frame(width: 150)
                    Picker("", selection: config.gap) {
                        Text("Default gap").tag(Double?.none)
                        ForEach([0.0, 4, 8, 12, 20], id: \.self) { Text("\(Int($0)) pt").tag(Double?.some($0)) }
                    }
                    .labelsHidden().frame(width: 120)
                    Toggle("Focus", isOn: optionalFlag(config.focusMode))
                        .help("Focus mode turns on when you go to this workspace")
                    Toggle("Closed", isOn: optionalFlag(config.closed))
                        .help("New windows skip this workspace")
                    if store.settings.workspaceConfigs[String(index)] != nil {
                        Button { store.settings.workspaceConfigs[String(index)] = nil } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(.borderless)
                        .help("Back to the defaults")
                    }
                }
            }
        } header: {
            Text("Each workspace")
        } footer: {
            Text("Settings for one workspace on every display of the first profile. Leave anything on Default to follow the rest of Settings.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func binding(_ index: Int) -> Binding<WorkspaceConfig> {
        Binding(
            get: { store.settings.workspaceConfigs[String(index)] ?? WorkspaceConfig() },
            set: { value in
                store.settings.workspaceConfigs[String(index)] = value == WorkspaceConfig() ? nil : value
            })
    }

    private func color(_ config: Binding<WorkspaceConfig>) -> Binding<Color> {
        Binding(
            get: { config.wrappedValue.color.flatMap { Color(hex: $0) } ?? WorkspaceColor.palette(store.settings.theme)[0] },
            set: { config.wrappedValue.color = NSColor($0).hexString })
    }
}
/// Theme swatches, one tile per theme.
private struct ThemeGrid: View {
    let title: String
    let themes: [Theme]
    @Binding var selection: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(themes, id: \.self) { theme in
                    let backdrop = WorkspaceColor.backdrop(theme)
                    Button { selection = theme } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 3) {
                                ForEach(0..<6, id: \.self) { i in
                                    Circle().fill(WorkspaceColor.palette(theme)[i]).frame(width: 10, height: 10)
                                }
                            }
                            Text(theme.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                                .foregroundStyle(.white)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: backdrop.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(selection == theme ? Color.accentColor : Color.primary.opacity(0.12),
                                          lineWidth: selection == theme ? 2.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.title) theme")
                    .accessibilityAddTraits(selection == theme ? .isSelected : [])
                }
            }
        }
    }
}
#endif
