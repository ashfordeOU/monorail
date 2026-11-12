#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

// The menu bar panel as one surface with pages inside it, like Control Centre: Home shows everything
// at a glance and sorts itself when something needs you; a card opens its page in the same panel,
// which slides across and resizes to fit. ‹ goes back. Nothing opens on top of anything else.

enum PanelPage: Hashable {
    case home, battery, app(String), awake, evening, theme, whatsNew
}

final class PanelNavigator: ObservableObject {
    @Published private(set) var stack: [PanelPage] = [.home]
    /// Which way the last move went, so pages slide in from the right side.
    @Published private(set) var forward = true

    var top: PanelPage { stack.last ?? .home }

    // The direction is set one turn of the run loop before the page changes, so the page that
    // leaves has already been drawn with the right exit and slides the right way.
    func push(_ page: PanelPage) {
        forward = true
        DispatchQueue.main.async { withAnimation(Motion.page) { self.stack.append(page) } }
    }

    func pop() {
        guard stack.count > 1 else { return }
        forward = false
        DispatchQueue.main.async {
            guard self.stack.count > 1 else { return }
            withAnimation(Motion.page) { _ = self.stack.removeLast() }
        }
    }

    /// Opening the panel: at Home, or straight at a page with Home under it.
    func reset(to page: PanelPage) {
        forward = true
        stack = page == .home ? [.home] : [.home, page]
    }
}

/// What the pages can do: everything the old popover's buttons did, in one place.
struct PanelContext {
    var actions: SliderBarController.Actions
    var isEveningOn: () -> Bool
    var awake: SliderPopover.AwakeControls
    var openEveningSettings: () -> Void
    var resetPairs: () -> Void
    var togglePause: () -> Void
    var openSettings: () -> Void
    var more: SliderPopover.MoreControls
}

private struct PanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct PanelRoot: View {
    @ObservedObject var model: SliderBarModel
    @ObservedObject var paused: PausedState
    @ObservedObject var updater: Updater
    @ObservedObject var store: SettingsStore
    @ObservedObject var nav: PanelNavigator
    let context: PanelContext
    /// Tells the window the content's new height, to grow or shrink with a spring.
    var onHeight: (CGFloat) -> Void = { _ in }
    @State private var awakeTick = 0

    static let width: CGFloat = 360

    var body: some View {
        ZStack(alignment: .top) {
            page(nav.top)
                .id(nav.top)
                .transition(.asymmetric(
                    insertion: .move(edge: nav.forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: nav.forward ? .leading : .trailing).combined(with: .opacity)))
        }
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { proxy in Color.clear.preference(key: PanelHeightKey.self, value: proxy.size.height) })
        .onPreferenceChange(PanelHeightKey.self) { onHeight($0) }
        .clipped()
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private func page(_ page: PanelPage) -> some View {
        switch page {
        case .home:
            HomePage(model: model, paused: paused, updater: updater, store: store, nav: nav, context: context)
        case .battery:
            BatteryPanel(store: store, openSettings: context.more.openPowerSettings, onBack: nav.pop,
                         openApp: { id in nav.push(.app(id)) })
        case .app(let id):
            AppEnergyPage(bundleID: id, onBack: nav.pop)
        case .awake:
            subpage("Stay Awake") { AwakeQuickControls(store: store, awake: context.awake, tick: $awakeTick) }
        case .evening:
            subpage("Evening Mode") { EveningQuickControls(store: store, isOn: context.isEveningOn, openSettings: context.openEveningSettings) }
        case .theme:
            subpage("Theme") { ThemeQuickPicker(store: store) }
        case .whatsNew:
            UpdatePage(updater: updater, onBack: nav.pop)
        }
    }

    private func subpage<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(back: "Monorail", title: title, onBack: nav.pop)
                .padding(.horizontal, 14).padding(.top, 12)
            content()
        }
    }
}

// MARK: - Home

struct HomePage: View {
    @ObservedObject var model: SliderBarModel
    @ObservedObject var paused: PausedState
    @ObservedObject var updater: Updater
    @ObservedObject var store: SettingsStore
    @ObservedObject var nav: PanelNavigator
    let context: PanelContext
    @ObservedObject private var power = PowerWatch.shared
    /// Bumped after a switch is flipped, to redraw once it has settled.
    @State private var tick = 0

    private var more: SliderPopover.MoreControls { context.more }

    private var layout: HomeLayout {
        let b = power.battery
        return HomePlanner.plan(HomeSignals(
            onBattery: PowerWatch.hasBattery && b.onBattery, percent: PowerWatch.hasBattery ? b.percent : nil,
            minutesLeft: b.minutesAtCurrentRate, drainRatio: power.rings.drainRatio,
            agentsRunning: power.agents.count, clashes: more.clashCount(),
            updateAvailable: updater.available != nil, paused: paused.value))
    }

    var body: some View {
        let _ = tick
        let plan = layout
        VStack(alignment: .leading, spacing: 8) {
            statusLine(plan)
            ForEach(rows(plan), id: \.self) { row in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(row, id: \.self) { card in self.card(card, raised: plan.raised.contains(card)) }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            searchBar
        }
        .padding(12)
        .animation(Motion.reorder, value: plan.cards)
        .onAppear { power.refreshIfStale() }
    }

    /// Battery and agents sit side by side as two small widgets when neither needs you.
    private func rows(_ plan: HomeLayout) -> [[HomeCard]] {
        var rows: [[HomeCard]] = []
        let cards = plan.cards.filter { $0 != .battery || PowerWatch.hasBattery }
        var index = 0
        while index < cards.count {
            let card = cards[index]
            let pairable: (HomeCard) -> Bool = { ($0 == .battery || $0 == .agents) && !plan.raised.contains($0) }
            if pairable(card), index + 1 < cards.count, pairable(cards[index + 1]) {
                rows.append([card, cards[index + 1]])
                index += 2
            } else {
                rows.append([card])
                index += 1
            }
        }
        return rows
    }

    // MARK: Top line

    private func statusLine(_ plan: HomeLayout) -> some View {
        HStack(spacing: 7) {
            Circle().fill(updater.available != nil && plan.tone != .urgent ? Tone.blue : Tone.of(plan.tone)).frame(width: 8, height: 8)
            Text(updater.isInstalling ? "Updating" : plan.title).font(.system(size: 13, weight: .semibold))
            Text(detail(plan)).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
            Spacer(minLength: 4)
            Group {
                Button(action: context.actions.showOverview) { Image(systemName: "square.grid.3x2") }
                    .help("Overview").accessibilityLabel("Overview")
                Button(action: context.openSettings) { Image(systemName: "gearshape") }
                    .help("Settings").accessibilityLabel("Settings")
            }
            .buttonStyle(.borderless).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    private func detail(_ plan: HomeLayout) -> String {
        if let extra = more.statusExtra() { return "· " + extra }
        guard plan.tone == .calm, let map = model.map else { return "" }
        let windows = map.tiles.reduce(0) { $0 + $1.windows.count }
        return "· \(windows) window\(windows == 1 ? "" : "s")" + (map.workspaceCount > 1 ? " · \(map.workspaceCount) workspaces" : "")
    }

    // MARK: Cards

    @ViewBuilder private func card(_ card: HomeCard, raised: Bool) -> some View {
        switch card {
        case .notices: notices
        case .battery: raised ? AnyView(batteryRaised) : AnyView(batteryWidget)
        case .windows: windows
        case .agents: agentsWidget
        case .controls: controls
        case .layouts: layoutsRow
        }
    }

    private var notices: some View {
        VStack(alignment: .leading, spacing: 8) {
            if updater.available != nil {
                UpdateCard(updater: updater, openWhatsNew: { nav.push(.whatsNew) })
            }
            let clashes = more.clashCount()
            if clashes > 0 {
                notice("exclamationmark.triangle.fill", Tone.ok, clashes == 1 ? "A shortcut clashes with macOS" : "\(clashes) shortcuts clash with macOS",
                       "One click picks free keys", button: "Fix", action: more.openShortcuts)
            }
            if paused.value {
                notice("pause.circle.fill", .secondary, "Tiling is paused", "Windows stay where they are", button: "Resume", action: context.togglePause)
            }
            if more.pausedForStageManager() {
                notice("rectangle.stack", .secondary, "Paused for Stage Manager", "Carries on when you turn it off", button: nil) {}
            }
        }
        // Blue when it's only an update, amber when something else needs you.
        .tile(tint: more.clashCount() == 0 && !paused.value && !more.pausedForStageManager() ? Tone.blue : Tone.ok)
    }

    private func notice(_ icon: String, _ color: Color, _ title: String, _ subtitle: String, button: String?, action: @escaping () -> Void) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 15)).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let button { Button(button, action: action).buttonStyle(.borderedProminent).controlSize(.small) }
        }
    }

    private var batteryWidget: some View {
        let b = power.battery
        return Button { nav.push(.battery) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label("BATTERY", systemImage: "bolt.fill").font(.label).foregroundStyle(Tone.good).labelStyle(.titleAndIcon)
                HStack(spacing: 10) {
                    BatteryRingsView(rings: power.rings, size: 50, glow: false)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(b.percent)%").font(.figure(22))
                        Text(b.isCharging ? "Charging" : b.onBattery ? "\(Self.clock(b.minutesAtCurrentRate)) left" : "Plugged in")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
            }
            .tile()
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text("Battery \(b.percent)%. Opens the Battery page"))
    }

    private var batteryRaised: some View {
        let b = power.battery
        let rings = power.rings
        let low = HomePlanner.batteryIsLow(HomeSignals(onBattery: b.onBattery, percent: b.percent, minutesLeft: b.minutesAtCurrentRate))
        let tone = low ? Tone.high : Tone.ok
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(low ? "BATTERY · LOW" : "BATTERY · DRAINING FAST", systemImage: "bolt.fill").font(.label).foregroundStyle(tone)
                Spacer()
                Button { nav.push(.battery) } label: { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain).accessibilityLabel("Open the Battery page")
            }
            HStack(spacing: 12) {
                BatteryRingsView(rings: rings, size: 72)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(Self.clock(b.minutesAtCurrentRate)).font(.figure(22))
                        Text("left at this rate").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                    Text(sentence(rings)).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let app = power.attention {
                        HStack(spacing: 6) {
                            Button("Quit \(app.use.appName)") { power.quit(app.id) }.buttonStyle(.borderedProminent)
                            if power.canPause(app.id) { Button("Pause") { power.pause(app.id) } }
                        }
                        .controlSize(.small).padding(.top, 2)
                    } else if low, !b.lowPowerMode {
                        Button("Turn On Low Power Mode") { power.setLowPowerMode(true) }.controlSize(.small).padding(.top, 2)
                    }
                }
            }
        }
        .tile(tint: tone, padding: 12)
    }

    private func sentence(_ rings: BatteryRings) -> String {
        var parts: [String] = []
        if let r = rings.drainRatio, r >= 1.6 { parts.append(r >= 2.5 ? "About \(Int(r.rounded()))× your usual." : "About \(String(format: "%.1f", r))× your usual.") }
        if let app = power.attention { parts.append("\(app.use.appName) is the most of it.") } else if parts.isEmpty { parts.append("Plug in soon.") }
        return parts.joined(separator: " ")
    }

    private var windows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let map = model.map {
                    Text(map.workspaceNames.indices.contains(map.workspace) && !map.workspaceNames[map.workspace].isEmpty
                         ? map.workspaceNames[map.workspace] : "Workspace \(map.workspace + 1)")
                        .font(.system(size: 13, weight: .semibold))
                    Text(paused.value ? "· paused" : "· \(map.tiles.count) slide\(map.tiles.count == 1 ? "" : "s")")
                        .font(.system(size: 11)).foregroundStyle(paused.value ? Tone.ok : Color.secondary.opacity(0.7))
                    Spacer()
                    pauseButton
                } else {
                    Text("Windows").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    pauseButton
                }
            }
            SliderBarView(model: model, actions: context.actions) {}
                .frame(height: 52)
            if let map = model.map, !map.tiles.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(map.tiles.enumerated()), id: \.element.id) { number, tile in
                                Button { if let window = tile.windows.first { context.actions.focus(window.id) } } label: {
                                    PanelSlideCard(number: number + 1, tile: tile)
                                }
                                .buttonStyle(PressStyle())
                                .id(tile.id)
                            }
                        }
                        .padding(.vertical, 2)
                        .environment(\.layoutDirection, map.isRightToLeft ? .rightToLeft : .leftToRight)
                    }
                    .onAppear { if let focused = map.tiles.first(where: \.isFocused) { proxy.scrollTo(focused.id, anchor: .center) } }
                }
            } else {
                Text("No windows on this workspace yet.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .tile()
    }

    /// Pause or resume tiling, right on the Windows card, as in the first popover.
    private var pauseButton: some View {
        Button(action: context.togglePause) {
            Image(systemName: paused.value ? "play.fill" : "pause.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(paused.value ? Color.white : Color.primary)
                .frame(width: 26, height: 22)
                .background(Capsule().fill(paused.value ? Tone.ok : Color.primary.opacity(0.1)))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(paused.value ? "Resume tiling" : "Pause tiling")
        .help(paused.value ? "Resume tiling" : "Pause tiling: windows stay where they are")
    }

    private var agentsWidget: some View {
        let first = power.agents.first
        return Button { nav.push(.battery) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label("AGENTS", systemImage: "sparkles").font(.label).foregroundStyle(.secondary)
                if let first {
                    Text(first.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(first.cpuPercent >= 5 ? String(format: "Working · %.0f%% CPU", first.cpuPercent) : "Idle")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    if power.agents.count > 1 {
                        Text("+\(power.agents.count - 1) more").font(.system(size: 11)).foregroundStyle(.tertiary)
                    } else {
                        Capsule().fill(Color.primary.opacity(0.1)).frame(height: 4)
                            .overlay(alignment: .leading) {
                                GeometryReader { g in Capsule().fill(Tone.blue).frame(width: g.size.width * min(first.cpuPercent / 100, 1)) }
                            }
                    }
                }
            }
            .tile()
        }
        .buttonStyle(PressStyle())
    }

    /// Control Centre's pattern: the round icon switches it on or off; the rest of the tile, with
    /// its › , opens its options. Nothing hidden behind a right-click.
    private var controls: some View {
        let awakeOn = context.awake.isOn()
        let eveningOn = store.settings.eveningOn || context.isEveningOn()
        let focusOn = more.isFocusOn()
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
            ControlTile(title: "Stay Awake", status: awakeOn ? context.awake.status() : "Off", systemImage: "cup.and.saucer.fill",
                        isOn: awakeOn, tint: Tone.warm,
                        toggle: { awakeOn ? context.awake.end() : context.awake.start(store.settings.awakeDefaultMinutes); settle() },
                        open: { nav.push(.awake) })
            ControlTile(title: "Evening", status: eveningOn ? "On" : "Off", systemImage: "moon.fill", isOn: eveningOn, tint: Tone.warm,
                        toggle: { store.settings.eveningOn.toggle(); settle() },
                        open: { nav.push(.evening) })
            ControlTile(title: "Focus", status: focusOn ? "This slide only" : "Off", systemImage: "scope", isOn: focusOn, tint: Tone.blue,
                        toggle: { more.toggleFocus(); settle() }, open: nil)
            if PowerWatch.hasBattery {
                ControlTile(title: "Low Power", status: power.battery.lowPowerMode ? "On" : "Off", systemImage: "leaf.fill",
                            isOn: power.battery.lowPowerMode, tint: Tone.ok,
                            toggle: { power.setLowPowerMode(!power.battery.lowPowerMode) }, open: { nav.push(.battery) })
            }
        }
    }

    private var layoutsRow: some View {
        let layouts = more.layouts(), snapshots = more.snapshots()
        return HStack(spacing: 6) {
            Text("LAYOUTS").font(.label).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            ForEach(layouts.prefix(2), id: \.self) { name in
                Button(name) { more.applyLayout(name) }.buttonStyle(ChipStyle())
            }
            Menu {
                if !layouts.isEmpty { Section("Layouts") { ForEach(layouts, id: \.self) { name in Button(name) { more.applyLayout(name) } } } }
                if !snapshots.isEmpty { Section("Snapshots") { ForEach(snapshots, id: \.self) { name in Button(name) { more.restoreSnapshot(name) } } } }
                Divider()
                Button("Take a Snapshot Now") { more.takeSnapshot() }
                Button("Reset to Smart Pairs") { context.resetPairs() }
                Button(paused.value ? "Resume Tiling" : "Pause Tiling") { context.togglePause() }
                Divider()
                Button("Theme: \(store.settings.theme.title)…") { nav.push(.theme) }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("More layouts and actions")
        }
        .tile()
    }

    private var searchBar: some View {
        Button(action: more.openPalette) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                Text("Search Monorail")
                Spacer()
            }
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .help("Commands, settings and windows in one search")
    }

    private func settle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { tick += 1 }
    }

    /// "5:52", the way the Lock Screen writes time left.
    static func clock(_ minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "—" }
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

/// One switch on Home, as in Control Centre: a round icon that switches it, and a name and state
/// that open its page (with a › so you can see there's more).
struct ControlTile: View {
    let title: String
    let status: String
    let systemImage: String
    let isOn: Bool
    var tint: Color = Tone.blue
    let toggle: () -> Void
    let open: (() -> Void)?

    var body: some View {
        HStack(spacing: 9) {
            Button(action: toggle) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(isOn ? tint : Color.primary.opacity(0.1)))
                    .animation(Motion.pop, value: isOn)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(Text("\(title), \(isOn ? "on" : "off")"))
            .help(isOn ? "Turn off" : "Turn on")
            Button { (open ?? toggle)() } label: {
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                        Text(status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if open != nil {
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(open == nil ? "\(title): \(status)" : "\(title) options"))
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
}

struct ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08)))
            .scaleEffect(configuration.isPressed && !Motion.reduced ? 0.96 : 1)
            .animation(Motion.pop, value: configuration.isPressed)
    }
}

// MARK: - Updates

/// An update, waiting quietly at the top of Home: the version, one line about it, Update Now,
/// Tonight and What's New. While installing, the icon turns in a ring and the stage shows.
struct UpdateCard: View {
    @ObservedObject var updater: Updater
    let openWhatsNew: () -> Void

    var body: some View {
        if let release = updater.available {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 11) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 38, height: 38)
                        if updater.isInstalling {
                            Circle().trim(from: 0, to: 0.3).stroke(Tone.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .frame(width: 46, height: 46).offset(x: 4, y: 4)
                                .rotationEffect(.degrees(updater.isInstalling ? 360 : 0))
                                .animation(Motion.reduced ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: updater.isInstalling)
                        } else {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 15)).foregroundStyle(.white, Tone.blue)
                                .offset(x: 4, y: 4)
                        }
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(updater.isInstalling ? "Installing Monorail \(release.version)" : "Monorail \(release.version)")
                            .font(.system(size: 13, weight: .semibold))
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                if !updater.isInstalling {
                    HStack(spacing: 6) {
                        Button("Update Now") { updater.installAvailable() }.buttonStyle(.borderedProminent)
                        if updater.installsTonight {
                            Button("Not Tonight") { updater.cancelTonight() }
                        } else {
                            Button("Tonight") { updater.installTonight() }.help("Installs between 1 and 5 am while nobody's using the Mac")
                        }
                        Spacer()
                        Button("What's New") { openWhatsNew() }.buttonStyle(.link)
                    }
                    .controlSize(.small)
                }
                Text(updater.isInstalling ? "Monorail restarts by itself. Nothing on your screen moves."
                     : updater.installsTonight ? "Installs tonight while your Mac is idle." : "About ten seconds. Your windows stay exactly where they are.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .transition(.opacity)
        }
    }

    private var subtitle: String {
        if updater.isInstalling { return (updater.stage ?? "Installing") + "…" }
        let titles = ReleaseNotes.highlights(updater.notes, limit: 3).map(\.title)
        return titles.isEmpty ? "A new version is ready" : titles.joined(separator: " · ")
    }
}

/// What's New for a waiting update, as a page in the panel: the icon, the version and three rows.
struct UpdatePage: View {
    @ObservedObject var updater: Updater
    let onBack: () -> Void

    var body: some View {
        let rows = ReleaseNotes.highlights(updater.notes, limit: 4)
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(back: "Monorail", title: "What's New", onBack: onBack)
            VStack(spacing: 4) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                Text("Monorail \(updater.available?.version ?? updater.currentVersion)").font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            if rows.isEmpty {
                Text("Reading the release notes…").font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                FeatureRow(symbol: ReleaseStyle.symbol(row.kind), tint: ReleaseStyle.tint(row.kind), title: row.title, text: row.text,
                           delay: Double(index) * 0.07)
            }
            HStack {
                if updater.available != nil, !updater.isInstalling {
                    Button { updater.installAvailable() } label: { Text("Update Now").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                }
                Link("All changes", destination: Updater.releasesURL).font(.system(size: 11))
            }
            .controlSize(.regular)
        }
        .padding(12)
    }
}

/// The icon and colour for each kind of change.
enum ReleaseStyle {
    static func symbol(_ kind: ReleaseNotes.Kind) -> String {
        switch kind {
        case .panel: return "square.grid.2x2.fill"
        case .battery: return "bolt.fill"
        case .menuBar: return "menubar.rectangle"
        case .agents: return "sparkles"
        case .keyboard: return "keyboard"
        case .windows: return "rectangle.split.3x1"
        case .privacy: return "eye.slash"
        case .welcome: return "hand.wave.fill"
        case .general: return "star.fill"
        }
    }

    static func tint(_ kind: ReleaseNotes.Kind) -> Color {
        switch kind {
        case .panel: return Color(red: 0.91, green: 0.33, blue: 0.45)
        case .battery: return Tone.good
        case .menuBar: return Color(nsColor: .systemGray)
        case .agents: return Color(nsColor: .systemPurple)
        case .keyboard: return Color(nsColor: .systemIndigo)
        case .windows: return Tone.blue
        case .privacy: return Color(nsColor: .systemTeal)
        case .welcome: return Tone.warm
        case .general: return Tone.ok
        }
    }
}

// MARK: - One app's energy

struct AppEnergyPage: View {
    let bundleID: String
    let onBack: () -> Void
    @ObservedObject private var power = PowerWatch.shared

    var body: some View {
        let app = power.apps.first { $0.id == bundleID }
        let name = app?.use.appName ?? PowerWatch.appName(bundleID) ?? bundleID
        VStack(alignment: .leading, spacing: 10) {
            PageHeader(back: "Battery", title: name, onBack: onBack)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    AppIconView(bundleID: bundleID, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name).font(.system(size: 13, weight: .semibold))
                        Text(app.map { "\($0.processes) process\($0.processes == 1 ? "" : "es")" + ($0.isPaused ? " · paused" : "") } ?? "Not running")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
                HStack(alignment: .top, spacing: 18) {
                    figure(app?.watts.map { $0 < 0.01 ? "<0.01 W" : String(format: "%.2f W", $0) } ?? "—", "now")
                    figure(app?.use.percentPerHour.map { $0 < 0.1 ? "<0.1%" : String(format: "%.1f%%", $0) } ?? "—", "an hour")
                    figure(sinceCharge ?? "—", "since charge")
                }
                if let app {
                    Text(String(format: "%.0f%% CPU", app.use.cpuPercent)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .tile(padding: 12)
            if let app {
                HStack(spacing: 6) {
                    Button("Quit") { power.quit(app.id); onBack() }.buttonStyle(.borderedProminent)
                    if app.isPaused {
                        Button("Resume") { power.resume(app.id) }
                    } else if power.canPause(app.id) {
                        Button("Pause") { power.pause(app.id) }.help("Freeze it until you open it or plug in")
                    }
                    Button("Hide") { power.hide(app.id) }
                    Spacer()
                    Button("Show Windows") { NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first?.activate() }
                }
                .controlSize(.small)
            }
        }
        .padding(12)
    }

    private var sinceCharge: String? {
        guard let total = power.session.totals[bundleID] else { return nil }
        return ChargeSession.usedText(total, wattHours: power.wattHours)
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.figure(20))
            Text(label).font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AppIconView: View {
    let bundleID: String
    var size: CGFloat = 22

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous).fill(Color.primary.opacity(0.12)).frame(width: size, height: size)
        }
    }
}

extension PowerWatch {
    /// Your usual draw on battery, learnt from the day's history.
    var usualWatts: Double? {
        DrainBaseline.watts(percentPerHour: DrainBaseline.percentPerHour(history), wattHours: wattHours)
    }

    /// The three rings: charge, time left against your usual, drain against your usual.
    var rings: BatteryRings { BatteryRings.make(battery, usualWatts: usualWatts) }
}
#endif
