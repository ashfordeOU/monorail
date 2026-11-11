#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// The battery panel: charge, time left and draw, Low Power Mode, a day of history, the app that
/// needs your attention (with what quitting it would give you back), every app and AI agent by
/// battery use, and paused or hidden apps. Opens from ⚡ in the slider popover or the battery item
/// in the menu bar.
struct BatteryPanel: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var power: PowerWatch = .shared
    var openSettings: () -> Void = {}
    @State private var showAll = false
    @State private var search = ""
    @FocusState private var searching: Bool

    private static let pink = Color(red: 0.91, green: 0.33, blue: 0.60)
    private static let green = Color(red: 0.30, green: 0.78, blue: 0.48)
    private static let gradient = LinearGradient(colors: [Color(red: 1, green: 0.54, blue: 0.36), Color(red: 0.91, green: 0.26, blue: 0.48),
                                                          Color(red: 0.56, green: 0.23, blue: 0.72)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 10) {
                    stats
                    lowPower
                    if PowerWatch.hasBattery { historyCard }
                    if let app = power.attention { attentionCard(app) }
                    if !power.paused.isEmpty || !power.parked.isEmpty { restCard }
                    appsCard
                    if !power.agents.isEmpty { agentsCard }
                    settingsCard
                }
                .padding(12)
            }
            .frame(maxHeight: 560)
            searchBar
        }
        .frame(width: 370)
        .onAppear { power.setLive(true) }
        .onDisappear { power.setLive(false) }
    }

    // MARK: Header and numbers

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Self.gradient))
            Text("Battery").font(.headline)
            if power.battery.lowPowerMode {
                Text("Low Power").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.yellow.opacity(0.25)))
            }
            Spacer()
            Button(action: openSettings) { Image(systemName: "gearshape").accessibilityLabel("Battery settings") }
                .buttonStyle(.borderless).help("Battery settings")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var stats: some View {
        let b = power.battery
        let state = b.isCharging ? "Charging" : b.onBattery ? "On battery" : "Plugged in"
        let left = b.onBattery ? BatteryState.duration(b.minutesAtCurrentRate) : "—"
        return HStack(spacing: 8) {
            stat(icon: b.isCharging ? "battery.100.bolt" : "battery.75", title: "Mac battery", value: "\(b.percent)%", sub: state)
            stat(icon: "clock", title: "Time left", value: left, sub: b.onBattery ? "At the current rate" : "Needs battery draw")
            if !power.paused.isEmpty {
                stat(icon: "pause.circle", title: "Paused", value: "\(power.paused.count)", sub: "Wake when opened")
            } else {
                stat(icon: "bolt", title: "Using", value: b.watts.map { String(format: "%.1f W", $0) } ?? "—",
                     sub: b.onBattery ? "Whole Mac, now" : "Measured on battery")
            }
        }
    }

    private func stat(icon: String, title: String, value: String, sub: String) -> some View {
        VStack(spacing: 3) {
            Label(title, systemImage: icon).font(.caption2).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
            Text(value).font(.system(size: 19, weight: .semibold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 6)
        .background(card)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06))
    }

    private var lowPower: some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.fill").foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.green.opacity(0.75)))
            VStack(alignment: .leading, spacing: 1) {
                Text("Low Power Mode").font(.callout.weight(.semibold))
                Text("\(power.battery.lowPowerMode ? "On" : "Off") · \(power.battery.onBattery ? "On battery" : "Plugged in")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { power.battery.lowPowerMode }, set: { power.setLowPowerMode($0) }))
                .toggleStyle(.switch).labelsHidden()
                .help("macOS asks for your password to change it")
        }
        .padding(10).background(card)
    }

    // MARK: History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Battery history").font(.callout.weight(.semibold))
                Spacer()
                Text("\(power.battery.percent)%").font(.callout.weight(.semibold)).monospacedDigit()
            }
            HistoryChart(points: power.history, discharging: Self.pink, charging: Self.green)
                .frame(height: 86)
            HStack {
                Text(power.battery.capacityPercent.map { "Capacity \($0)%" } ?? "")
                Spacer()
                Text(power.battery.cycleCount.map { "\($0) charge cycles" } ?? "")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10).background(card)
    }

    // MARK: Needs your attention

    private func attentionCard(_ app: PowerWatch.AppUse) -> some View {
        let b = power.battery
        let now = b.minutesAtCurrentRate
        let after = app.watts.flatMap { b.minutesIfSaved(appWatts: $0) }
        return VStack(alignment: .leading, spacing: 8) {
            Label("Needs your attention", systemImage: "bolt.fill").font(.caption.weight(.semibold)).foregroundStyle(.orange)
            HStack(spacing: 8) {
                icon(app.id, size: 22)
                Text(app.use.appName).font(.title3.weight(.semibold)).lineLimit(1)
                Spacer()
                Text(rate(app.use)).font(.callout.weight(.semibold)).monospacedDigit()
            }
            HStack(spacing: 8) {
                Button("Quit App") { power.quit(app.id) }.buttonStyle(.borderedProminent).tint(Self.pink)
                if power.canPause(app.id) { Button("Pause") { power.pause(app.id) }.help("Freeze it until you open it or plug in: its windows and work stay as they are") }
                Button("Hide") { power.hide(app.id) }
                Button("Keep") { power.keep(app.id) }.buttonStyle(.borderless)
            }
            .controlSize(.small)
            if let now, let after, after > now {
                HStack(spacing: 4) {
                    Text("If you quit").foregroundStyle(.secondary)
                    Text(BatteryState.duration(now))
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                    Text(BatteryState.duration(after)).foregroundStyle(Self.green).fontWeight(.semibold)
                }
                .font(.caption)
                Text("About \(BatteryState.duration(after - now)) more at the current rate").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.orange.opacity(0.25)))
    }

    // MARK: Paused and hidden

    private var restCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resting to save battery").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(power.paused.keys.sorted(), id: \.self) { id in
                HStack {
                    icon(id, size: 16)
                    Text(PowerWatch.appName(id) ?? id).lineLimit(1)
                    Text("paused").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Resume") { power.resume(id) }.controlSize(.small)
                }
            }
            if !power.parked.isEmpty {
                HStack {
                    Text("\(power.parked.count) hidden apps").foregroundStyle(.secondary)
                    Spacer()
                    Button("Show") { power.showParked() }.controlSize(.small)
                }
            }
            Text("They come back by themselves when you plug in.").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10).background(card)
    }

    // MARK: Apps

    private var filtered: [PowerWatch.AppUse] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let list = query.isEmpty ? power.apps : power.apps.filter { $0.use.appName.lowercased().contains(query) }
        return showAll || !query.isEmpty ? list : Array(list.prefix(5))
    }

    private var appsCard: some View {
        let maxScore = max(power.apps.map(score).max() ?? 1, 0.0001)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Apps", systemImage: "macwindow").font(.callout.weight(.semibold))
                Text("\(power.apps.count)").foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $showAll) { Text("Top").tag(false); Text("All").tag(true) }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 110)
            }
            if power.apps.isEmpty {
                Text(power.battery.onBattery ? "Measuring… a few seconds" : "Measuring while this panel is open…")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 6)
            }
            ForEach(filtered) { app in
                HStack(spacing: 8) {
                    icon(app.id, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(app.use.appName).lineLimit(1)
                            if app.isPaused { Image(systemName: "pause.circle.fill").foregroundStyle(.secondary).font(.caption) }
                            if app.use.isHungry && power.battery.onBattery { Image(systemName: "bolt.fill").foregroundStyle(.orange).font(.caption2) }
                        }
                        Text(detail(app)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    BatteryGauge(fraction: score(app) / maxScore, tint: app.use.isHungry ? .orange : Self.pink)
                    Text(rate(app.use)).font(.caption.weight(.semibold)).monospacedDigit().frame(width: 62, alignment: .trailing)
                    Menu {
                        Button("Show Its Windows") { NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first?.activate() }
                        Button("Hide") { power.hide(app.id) }
                        if app.isPaused {
                            Button("Resume") { power.resume(app.id) }
                        } else if power.canPause(app.id) {
                            Button("Pause Until I Open It") { power.pause(app.id) }
                        }
                        Divider()
                        Button("Quit") { power.quit(app.id) }
                    } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                }
            }
        }
        .padding(10).background(card)
    }

    private func score(_ app: PowerWatch.AppUse) -> Double { app.watts ?? app.use.cpuPercent / 100 }

    private func detail(_ app: PowerWatch.AppUse) -> String {
        var parts = ["\(app.processes) process\(app.processes == 1 ? "" : "es")"]
        if let w = app.watts { parts.append(w < 0.01 ? "<0.01 W" : String(format: "%.2f W", w)) }
        parts.append(String(format: "%.0f%% CPU", app.use.cpuPercent))
        return parts.joined(separator: " · ")
    }

    private func rate(_ use: PowerUse) -> String {
        if let p = use.percentPerHour { return p < 0.1 ? "<0.1%/hr" : String(format: "%.1f%%/hr", p) }
        return String(format: "%.0f%% CPU", use.cpuPercent)
    }

    // MARK: AI agents

    private var agentsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("AI agents", systemImage: "sparkles").font(.callout.weight(.semibold))
                Text("\(power.agents.count)").foregroundStyle(.secondary)
            }
            ForEach(power.agents) { agent in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(agent.name)
                        Text("\(agent.processes) process\(agent.processes == 1 ? "" : "es")\(agent.watts.map { String(format: " · %.2f W", $0) } ?? "")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(agent.percentPerHour.map { $0 < 0.1 ? "<0.1%/hr" : String(format: "%.1f%%/hr", $0) } ?? String(format: "%.0f%% CPU", agent.cpuPercent))
                        .font(.caption.weight(.semibold)).monospacedDigit()
                }
            }
            Text("Agents running in a terminal or editor are also counted under that app.").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10).background(card)
    }

    // MARK: Settings and search

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Mark power-hungry windows with ⚡", isOn: $store.settings.powerMarkers)
            Toggle("Hide hungry apps left alone for an hour on battery", isOn: $store.settings.parkPowerHogs)
            Toggle("Show the battery in the menu bar", isOn: $store.settings.batteryMenuBar)
            Text("Estimates from the processor time and energy macOS counts for each app and its helpers. Quit asks the app to quit, as ⌘Q does. Nothing leaves your Mac.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(.switch).controlSize(.small)
        .padding(10).background(card)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search running apps…", text: $search)
                .textFieldStyle(.plain).focused($searching)
            Text("⌘F").font(.caption2.monospaced()).foregroundStyle(.secondary)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.4)))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
        .background(Button("") { searching = true }.keyboardShortcut("f", modifiers: .command).opacity(0))
    }

    private func icon(_ bundleID: String, size: CGFloat) -> some View {
        Group {
            if let image = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.icon {
                Image(nsImage: image).resizable()
            } else {
                Image(systemName: "app").resizable()
            }
        }
        .frame(width: size, height: size)
    }
}

/// A small battery-shaped bar for an app's share of the biggest user.
private struct BatteryGauge: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1)
                RoundedRectangle(cornerRadius: 2).fill(tint)
                    .frame(width: max(0, CGFloat(min(1, fraction)) * 34))
                    .padding(2)
            }
            .frame(width: 40, height: 12)
            RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.5)).frame(width: 2, height: 5)
        }
        .accessibilityLabel(Text("\(Int(fraction * 100)) percent of the biggest user"))
    }
}

/// The last 24 hours of charge: pink while running on battery, green while charging.
private struct HistoryChart: View {
    let points: [BatteryPoint]
    let discharging: Color
    let charging: Color

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let end = Date()
            let start = min(points.first?.time ?? end.addingTimeInterval(-3600), end.addingTimeInterval(-3600))
            let span = max(end.timeIntervalSince(start), 60)
            let x = { (date: Date) -> CGFloat in CGFloat(date.timeIntervalSince(start) / span) * (size.width - 30) }
            let y = { (percent: Int) -> CGFloat in (1 - CGFloat(percent) / 100) * (size.height - 14) }
            ZStack(alignment: .topLeading) {
                ForEach([0, 50, 100], id: \.self) { level in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y(level)))
                        path.addLine(to: CGPoint(x: size.width - 30, y: y(level)))
                    }
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    Text("\(level)%").font(.system(size: 8)).foregroundStyle(.secondary)
                        .position(x: size.width - 13, y: y(level))
                }
                ForEach(Array(BatteryHistory.segments(points).enumerated()), id: \.offset) { _, segment in
                    ForEach(Array(zip(segment, segment.dropFirst()).enumerated()), id: \.offset) { _, pair in
                        Path { path in
                            path.move(to: CGPoint(x: x(pair.0.time), y: y(pair.0.percent)))
                            path.addLine(to: CGPoint(x: x(pair.1.time), y: y(pair.1.percent)))
                        }
                        .stroke(pair.1.charging ? charging : discharging, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
                if let last = points.last {
                    Circle().fill(last.charging ? charging : discharging).frame(width: 6, height: 6)
                        .position(x: x(last.time), y: y(last.percent))
                }
                HStack {
                    Text(start.formatted(date: .omitted, time: .shortened))
                    Spacer()
                    Text(end.formatted(date: .omitted, time: .shortened))
                }
                .font(.system(size: 8)).foregroundStyle(.secondary)
                .frame(width: size.width - 30)
                .offset(y: size.height - 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Battery over the last \(points.count > 1 ? "hours" : "hour")"))
    }
}
#endif
