#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// The big views behind the panel's cards, at full size, in a sidebar like System Settings: Overview,
/// Apps, CPU, Memory, GPU, Disk, Network, Battery, Devices, Sound, Ports, Agents, Today and Trends.
/// Monorail shows it as the Overview's second tab (beside Windows); Signalbox, which has no Overview,
/// in a Dashboard window of its own.
enum DashboardTab: String, CaseIterable, Identifiable {
    case windows = "Windows", dashboard = "Dashboard"
    var id: String { rawValue }
    var symbol: String { self == .windows ? "rectangle.split.3x1" : "gauge.with.dots.needle.67percent" }
    static var available: [DashboardTab] { Edition.isAppStore ? [.dashboard] : allCases }
}

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "Overview", apps = "Apps", cpu = "CPU", memory = "Memory", gpu = "GPU", disk = "Disk", network = "Network",
         battery = "Battery", devices = "Devices", sound = "Sound", ports = "Ports", agents = "Agents", today = "Today", trends = "Trends"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .apps: return "list.bullet.rectangle"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .gpu: return "cube.transparent"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .battery: return "battery.75percent"
        case .devices: return "headphones"
        case .sound: return "speaker.wave.2"
        case .ports: return "point.3.connected.trianglepath.dotted"
        case .agents: return "sparkles"
        case .today: return "calendar"
        case .trends: return "chart.xyaxis.line"
        }
    }
    /// What this edition can show: the App Store's sandbox hides other apps' processes and ports.
    static var available: [DashboardSection] {
        Edition.isAppStore ? allCases.filter { ![.apps, .ports, .agents].contains($0) } : allCases
    }
}

/// Settings for the dashboard's views that need them (the app delegate sets it).
enum DashboardContext {
    static var store: SettingsStore?
}

/// Glass pill tabs, as in the Overview header.
struct DashboardTabs: View {
    @Binding var tab: DashboardTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DashboardTab.available) { item in
                Button { withAnimation(Motion.page) { tab = item } } label: {
                    Label(item.rawValue, systemImage: item.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(tab == item ? Color.white.opacity(0.22) : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(tab == item ? 1 : 0.7))
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }
}

/// The Overview's Dashboard tab.
struct DashboardContent: View {
    let tab: DashboardTab
    var body: some View {
        if tab == .dashboard { SidebarDashboard().environment(\.colorScheme, .dark) }
    }
}

/// The sidebar and the chosen section.
struct SidebarDashboard: View {
    @AppStorage("DashboardSection") private var sectionName = DashboardSection.overview.rawValue
    private var section: DashboardSection { DashboardSection(rawValue: sectionName).flatMap { DashboardSection.available.contains($0) ? $0 : nil } ?? .overview }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(DashboardSection.available) { item in
                    Button { sectionName = item.rawValue } label: {
                        HStack(spacing: 9) {
                            Image(systemName: item.symbol).frame(width: 18)
                            Text(item.rawValue)
                            Spacer()
                        }
                        .font(.system(size: 13, weight: section == item ? .semibold : .regular))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(section == item ? Color.white.opacity(0.16) : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(section == item ? Color.white : Color.white.opacity(0.75))
                    .accessibilityAddTraits(section == item ? .isSelected : [])
                }
                Spacer()
            }
            .frame(width: 170)
            Group {
                switch section {
                case .overview: OverviewSection(go: { sectionName = $0.rawValue })
                case .apps: AppsSection()
                case .cpu: CPUSection()
                case .memory: MemorySection()
                case .gpu: GPUSection()
                case .disk: DiskSection()
                case .network: NetworkSection()
                case .battery: BatteryDashboard()
                case .devices: ScrollView { VStack(spacing: 14) { AccessoriesCard(); SoundSection(compact: true) }.frame(maxWidth: 640) }
                case .sound: SoundSection(compact: false)
                case .ports: PortsSection()
                case .agents: AgentsSection()
                case .today: TodayDashboard()
                case .trends: TrendsSection()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private func panelCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
        content()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
}

/// Everything about the battery: now, today, the last 30 days of what used it, and its health over months.
struct BatteryDashboard: View {
    @ObservedObject private var power = PowerWatch.shared
    @ObservedObject private var log = BatteryLog.shared
    @State private var range = 7

    var body: some View {
        let b = power.battery
        let keys = EnergyLog.lastDays(range)
        ScrollView {
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    panelCard("NOW") {
                        HStack(spacing: 18) {
                            BatteryRingsView(rings: power.rings, size: 96)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(b.percent)%").font(.figure(40, weight: .bold))
                                Text(b.isCharging ? "Charging" : b.onBattery ? "\(HomePage.clock(b.minutesAtCurrentRate)) left at this rate" : "Plugged in")
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 14) {
                                    if let w = b.watts { stat("Draw", String(format: "%.1f W", w)) }
                                    if let c = b.capacityPercent { stat("Health", "\(c)%") }
                                    if let n = b.cycleCount { stat("Cycles", "\(n)") }
                                    if let w = MenuBarReadings.chargerWatts() { stat("Charger", "\(w) W") }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    panelCard("TODAY") {
                        DayChart(points: power.history).frame(height: 110)
                        Text("Charge over the last day; green while charging.").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
                panelCard("WHAT USED THE BATTERY") {
                    HStack {
                        Picker("", selection: $range) {
                            Text("Today").tag(1); Text("7 days").tag(7); Text("30 days").tag(30)
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 240)
                        Spacer()
                        Text(power.energy.hasEnergy ? "Energy macOS billed to each app, on battery" : "Processor time on battery (this Mac doesn't report energy per app)")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                    if range > 1 { DailyBars(values: power.energy.dailyTotals(keys), labels: keys).frame(height: 70) }
                    let top = power.energy.top(over: keys, limit: 12)
                    if top.isEmpty {
                        Text(Edition.isAppStore ? "The App Store's sandbox doesn't let \(Brand.name) see other apps' energy. Monorail, the free download, records it."
                             : "Fills in as you use your Mac on battery.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    let biggest = max(top.first.map { power.energy.hasEnergy ? $0.entry.joules : $0.entry.cpuSeconds } ?? 1, 0.0001)
                    ForEach(top, id: \.id) { row in
                        let value = power.energy.hasEnergy ? row.entry.joules : row.entry.cpuSeconds
                        HStack(spacing: 10) {
                            if row.entry.isAgent { Image(systemName: "sparkles").frame(width: 18) } else { AppIconView(bundleID: row.id, size: 18) }
                            Text(row.entry.name).frame(width: 170, alignment: .leading).lineLimit(1)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: .systemOrange))
                                    .frame(width: max(3, geo.size.width * value / biggest))
                            }
                            .frame(height: 8)
                            Text(ChargeSession.usedText(ChargeSession.Total(name: row.entry.name, joules: row.entry.joules, cpuSeconds: row.entry.cpuSeconds),
                                                        wattHours: power.wattHours))
                                .font(.system(size: 11.5)).monospacedDigit().frame(width: 150, alignment: .trailing)
                        }
                        .font(.system(size: 12.5))
                    }
                }
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 14) {
                        BatteryHealthCard()
                        AccessoriesCard()
                    }
                    VStack(spacing: 14) {
                        SleepDrainCard()
                        panelCard("RECENT CHARGES") {
                            if log.journal.charges.isEmpty { Text("Fills in as you charge.").font(.system(size: 12)).foregroundStyle(.secondary) }
                            ForEach(Array(log.journal.charges.suffix(8).reversed().enumerated()), id: \.offset) { _, c in
                                HStack {
                                    Text(c.start.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(c.from)% → \(c.to)%").monospacedDigit()
                                    Text("\(c.minutes) min").foregroundStyle(.tertiary).monospacedDigit().frame(width: 64, alignment: .trailing)
                                }
                                .font(.system(size: 12))
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .onAppear { power.setLive(true) }
        .onDisappear { power.setLive(false) }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 14, weight: .semibold)).monospacedDigit()
        }
    }
}

/// The day's charge as a line, green where it was charging.
private struct DayChart: View {
    let points: [BatteryPoint]

    var body: some View {
        GeometryReader { geo in
            let start = Date().addingTimeInterval(-86400)
            let pts = points.filter { $0.time >= start }
            let x = { (t: Date) in geo.size.width * CGFloat(t.timeIntervalSince(start) / 86400) }
            let y = { (p: Int) in geo.size.height * (1 - CGFloat(p) / 100) }
            ZStack {
                ForEach([25, 50, 75], id: \.self) { level in
                    Path { $0.move(to: CGPoint(x: 0, y: y(level))); $0.addLine(to: CGPoint(x: geo.size.width, y: y(level))) }
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                ForEach(Array(zip(pts, pts.dropFirst()).enumerated()), id: \.offset) { _, pair in
                    Path { p in
                        p.move(to: CGPoint(x: x(pair.0.time), y: y(pair.0.percent)))
                        p.addLine(to: CGPoint(x: x(pair.1.time), y: y(pair.1.percent)))
                    }
                    .stroke(pair.1.charging ? Color(nsColor: .systemGreen) : Color(red: 0.91, green: 0.33, blue: 0.6), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
            }
        }
        .accessibilityLabel(Text("Battery charge over the last day"))
    }
}

/// One bar a day, newest on the right.
private struct DailyBars: View {
    let values: [Double]
    let labels: [String]

    var body: some View {
        let top = max(values.max() ?? 1, 0.0001)
        HStack(alignment: .bottom, spacing: values.count > 10 ? 2 : 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: .systemOrange).opacity(index == values.count - 1 ? 1 : 0.6))
                        .frame(height: max(2, 52 * value / top))
                    if values.count <= 10 { Text(String(labels[index].suffix(2))).font(.system(size: 9)).foregroundStyle(.tertiary) }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Calendar, Reminders and Notes side by side.
struct TodayDashboard: View {
    var body: some View {
        if let store = DashboardContext.store {
            HStack(alignment: .top, spacing: 14) {
                column("Calendar") { CalendarTab(store: store) }
                column("Reminders") { RemindersTab() }
                column("Notes") { NotesTab() }
            }
        }
    }

    private func column<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 20, weight: .bold))
            ScrollView { content().padding(.bottom, 20) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Signalbox's Dashboard window (Monorail has these as Overview tabs).
final class DashboardWindow {
    static let shared = DashboardWindow()
    private var window: NSWindow?
    private let model = Model()

    final class Model: ObservableObject {}

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.title = "\(Brand.name) Dashboard"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 860, height: 600)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: Root(model: model))
        window.center()
        window.setFrameAutosaveName("SignalboxDashboard")
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private struct Root: View {
        @ObservedObject var model: Model
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Dashboard").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white)
                SidebarDashboard().environment(\.colorScheme, .dark)
            }
            .padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 12)
            .background(LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.3), Color(red: 0.04, green: 0.06, blue: 0.16)],
                                       startPoint: .top, endPoint: .bottom))
        }
    }
}
#endif
