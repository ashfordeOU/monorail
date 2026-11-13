#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

// MARK: - Shared pieces

/// A dashboard card: a quiet title, then its content.
struct DashCard<Content: View>: View {
    let title: String
    var trailing: String? = nil
    /// A reading that can be pinned to Home ("cpu", "memory", …).
    var pin: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if let trailing { Text(trailing).font(.system(size: 11)).foregroundStyle(.tertiary) }
                if let pin { PinButton(id: pin) }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
    }
}

/// 12h · 24h · 7d · 30d, remembered.
struct RangeButtons: View {
    @Binding var range: SystemHistory.Range

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SystemHistory.Range.allCases, id: \.self) { item in
                Button(item.rawValue) { range = item }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(range == item ? Color(nsColor: .systemOrange).opacity(0.85) : Color.white.opacity(0.08)))
                    .foregroundStyle(range == item ? Color.black : Color.white.opacity(0.8))
            }
        }
    }
}

/// A reading over time: a filled line with a faint grid, and the range's low, average and high.
struct TrendChart: View {
    let values: [Double]
    var maximum: Double? = nil
    var colour: Color = Color(nsColor: .systemOrange)
    var format: (Double) -> String = { String(format: "%.0f%%", $0) }
    var height: CGFloat = 90

    var body: some View {
        let top = max(maximum ?? (values.max() ?? 1) * 1.1, 0.0001)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let step = geo.size.width / CGFloat(max(values.count - 1, 1))
                let point = { (i: Int, v: Double) in CGPoint(x: CGFloat(i) * step, y: geo.size.height * (1 - CGFloat(min(v / top, 1)))) }
                ZStack {
                    ForEach([0.25, 0.5, 0.75], id: \.self) { f in
                        Path { $0.move(to: CGPoint(x: 0, y: geo.size.height * f)); $0.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * f)) }
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
                    if values.count > 1 {
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: geo.size.height))
                            for (i, v) in values.enumerated() { p.addLine(to: point(i, v)) }
                            p.addLine(to: CGPoint(x: CGFloat(values.count - 1) * step, y: geo.size.height))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [colour.opacity(0.35), colour.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        Path { p in for (i, v) in values.enumerated() { i == 0 ? p.move(to: point(i, v)) : p.addLine(to: point(i, v)) } }
                            .stroke(colour, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                        if let last = values.last {
                            Circle().fill(colour).frame(width: 6, height: 6).position(point(values.count - 1, last))
                        }
                    } else {
                        Text("Collecting… history fills in a sample a minute.").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(height: height)
            if let s = SystemHistory.summary(values) {
                HStack(spacing: 14) {
                    Text("Low \(format(s.low))"); Text("Average \(format(s.average))"); Text("High \(format(s.high))")
                }
                .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(SystemHistory.summary(values).map { "Low \(format($0.low)), average \(format($0.average)), high \(format($0.high))" } ?? "No history yet"))
    }
}

private func bytesRate(_ v: Double) -> String { SystemStats.speed(v) }

/// A section's title line with the range buttons.
private struct SectionHeader: View {
    let title: String
    let subtitle: String
    @Binding var range: SystemHistory.Range

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 22, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            RangeButtons(range: $range)
        }
    }
}

extension View {
    func sectionScroll() -> some View { ScrollView { VStack(alignment: .leading, spacing: 14) { self }.padding(.bottom, 24) } }
}

// MARK: - Overview

struct OverviewSection: View {
    let go: (DashboardSection) -> Void
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var recorder = SystemRecorder.shared
    @ObservedObject private var power = PowerWatch.shared
    @ObservedObject private var storage = StorageWatch.shared

    var body: some View {
        let hour = recorder.history.samples(.hours12).suffix(60)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Overview").font(.system(size: 22, weight: .bold))
                Text("\(system.chipName) · up \(SystemStats.uptime(system.uptime))").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if let advice = SystemHistory.restartAdvice(uptime: system.uptime, swapGB: Double(SystemWatch.swapUsed()) / 1_073_741_824) {
                Label { VStack(alignment: .leading, spacing: 2) { Text("Restart recommended").fontWeight(.semibold); Text(advice).foregroundStyle(.secondary) } }
                    icon: { Image(systemName: "arrow.clockwise.circle.fill").foregroundStyle(Color(nsColor: .systemOrange)) }
                    .font(.system(size: 12.5))
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .systemOrange).opacity(0.12)))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                tile(.cpu, "CPU", "\(Int(system.total.rounded()))%", "\(system.performance.count + system.efficiency.count) cores", hour.map(\.cpu), .systemOrange)
                tile(.memory, "Memory", "\(Int((system.memory.pressure * 100).rounded()))%", "pressure \(system.memory.level.rawValue)", hour.map(\.memory), .systemBlue)
                tile(.gpu, "GPU", hour.last?.gpu.map { "\(Int($0.rounded()))%" } ?? "–", "graphics", hour.compactMap(\.gpu), .systemPurple)
                tile(.network, "Network", "↓ \(bytesRate(system.down))", "↑ \(bytesRate(system.up))", hour.map(\.downBytes), .systemTeal)
                tile(.disk, "Disk", Storage.size(storage.free), "free · writing \(bytesRate(hour.last?.writeBytes ?? 0))", hour.map(\.writeBytes), .systemPink)
                tile(.battery, "Battery", PowerWatch.hasBattery ? "\(power.battery.percent)%" : "Plugged in",
                     power.battery.isCharging ? "charging" : power.battery.onBattery ? "\(HomePage.clock(power.battery.minutesAtCurrentRate)) left" : "on power",
                     hour.compactMap { $0.battery.map(Double.init) }, .systemGreen)
            }
            if !Edition.isAppStore {
                DashCard(title: "Busiest apps") {
                    let top = power.apps.prefix(6)
                    if top.isEmpty { Text("Measuring…").font(.system(size: 12)).foregroundStyle(.secondary) }
                    ForEach(Array(top)) { app in
                        HStack(spacing: 10) {
                            AppIconView(bundleID: app.id, size: 18)
                            Text(app.use.appName).lineLimit(1)
                            Spacer()
                            Text(String(format: "%.0f%%", app.use.cpuPercent)).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.system(size: 12.5))
                    }
                    Button("All apps") { go(.apps) }.buttonStyle(.link).font(.system(size: 12))
                }
            }
        }
        .sectionScroll()
        .onAppear { system.setLive(true); power.setLive(true); storage.refresh() }
        .onDisappear { system.setLive(false); power.setLive(false) }
    }

    private func tile(_ section: DashboardSection, _ title: String, _ value: String, _ detail: String, _ spark: [Double], _ colour: NSColor) -> some View {
        Button { go(section) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(title, systemImage: section.symbol).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Color(nsColor: colour))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                }
                Text(value).font(.figure(24, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                TrendChart(values: spark, colour: Color(nsColor: colour), height: 34).allowsHitTesting(false)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Apps (Monorail)

struct AppsSection: View {
    @ObservedObject private var power = PowerWatch.shared
    @State private var selected: String?
    @State private var filter = ""

    var body: some View {
        let apps = power.apps.filter { filter.isEmpty || $0.use.appName.localizedCaseInsensitiveContains(filter) }
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Apps").font(.system(size: 22, weight: .bold))
                    Text("\(power.apps.count) apps · \(power.apps.reduce(0) { $0 + $1.processes }) processes").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    TextField("Filter apps", text: $filter).textFieldStyle(.roundedBorder).frame(width: 180)
                }
                HStack {
                    Text("Name"); Spacer()
                    Text("CPU").frame(width: 70, alignment: .trailing)
                    Text("Battery").frame(width: 90, alignment: .trailing)
                    Text("Processes").frame(width: 80, alignment: .trailing)
                }
                .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.tertiary)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(apps) { app in
                            Button { selected = app.id } label: {
                                HStack {
                                    AppIconView(bundleID: app.id, size: 18)
                                    Text(app.use.appName).lineLimit(1)
                                    if app.isPaused { Text("paused").font(.system(size: 10)).foregroundStyle(.secondary) }
                                    Spacer()
                                    Text(String(format: "%.1f%%", app.use.cpuPercent)).frame(width: 70, alignment: .trailing)
                                    Text(app.use.percentPerHour.map { String(format: "%.1f%%/hr", $0) } ?? "–").frame(width: 90, alignment: .trailing)
                                    Text("\(app.processes)").frame(width: 80, alignment: .trailing)
                                }
                                .font(.system(size: 12.5)).monospacedDigit()
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(selected == app.id ? Color.white.opacity(0.14) : .clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if let id = selected, let app = power.apps.first(where: { $0.id == id }) {
                AppDrawer(app: app) { selected = nil }.frame(width: 300)
            }
        }
        .onAppear { power.setLive(true) }
        .onDisappear { power.setLive(false) }
    }
}

/// One app's details, with Quit and Force Quit (each asks first).
private struct AppDrawer: View {
    let app: PowerWatch.AppUse
    let close: () -> Void
    @ObservedObject private var power = PowerWatch.shared

    var body: some View {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppIconView(bundleID: app.id, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.use.appName).font(.system(size: 15, weight: .semibold))
                    Text("\(app.processes) process\(app.processes == 1 ? "" : "es")").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: close) { Image(systemName: "xmark").accessibilityLabel("Close") }.buttonStyle(.plain)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                stat("CPU", String(format: "%.1f%%", app.use.cpuPercent))
                stat("Power", app.watts.map { String(format: "%.1f W", $0) } ?? "–")
                stat("Battery", app.use.percentPerHour.map { String(format: "%.1f%%/hr", $0) } ?? "–")
                stat("Since charge", power.sinceCharge(limit: 50).first { $0.0 == app.id }?.3 ?? "–")
            }
            Text(app.use.summary).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let path = running?.bundleURL?.path {
                Text(path).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(2).textSelection(.enabled)
            }
            Spacer()
            HStack {
                Button("Force Quit…") {
                    if confirm("Force quit \(app.use.appName)?", "Unsaved changes will be lost.") { running?.forceTerminate() }
                }
                .foregroundStyle(Color(nsColor: .systemRed))
                Spacer()
                Button("Quit") { if confirm("Quit \(app.use.appName)?", "It can ask you to save first.") { power.quit(app.id) } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
    }

    private func confirm(_ title: String, _ text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

// MARK: - CPU, Memory, GPU

struct CPUSection: View {
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var recorder = SystemRecorder.shared
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue
    private var range: Binding<SystemHistory.Range> { Binding(get: { SystemHistory.Range(rawValue: rangeName) ?? .hours24 }, set: { rangeName = $0.rawValue }) }

    var body: some View {
        let load = SystemWatch.loadAverage()
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "CPU", subtitle: "\(Int(system.total.rounded()))% now · \(system.chipName)", range: range)
            DashCard(title: "Load over time", trailing: load.count == 3 ? String(format: "load %.1f · %.1f · %.1f", load[0], load[1], load[2]) : nil, pin: "cpu") {
                TrendChart(values: recorder.history.samples(range.wrappedValue).map(\.cpu), maximum: 100, height: 130)
            }
            DashCard(title: "Your chip, core by core") {
                ChipView(name: system.chipName, performance: system.performance, efficiency: system.efficiency)
            }
        }
        .sectionScroll()
        .onAppear { system.setLive(true) }
        .onDisappear { system.setLive(false) }
    }
}

struct MemorySection: View {
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var recorder = SystemRecorder.shared
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue
    private var range: Binding<SystemHistory.Range> { Binding(get: { SystemHistory.Range(rawValue: rangeName) ?? .hours24 }, set: { rangeName = $0.rawValue }) }

    var body: some View {
        let m = system.memory, swap = SystemWatch.swapUsed(), paging = SystemWatch.paging()
        let samples = recorder.history.samples(range.wrappedValue)
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Memory", subtitle: "\(SystemStats.gigabytes(m.used)) of \(SystemStats.gigabytes(m.total)) in use · pressure \(m.level.rawValue)", range: range)
            DashCard(title: "Pressure over time", pin: "memory") {
                TrendChart(values: samples.map(\.memory), maximum: 100, colour: Color(nsColor: .systemBlue), height: 120)
            }
            HStack(alignment: .top, spacing: 14) {
                DashCard(title: "Where it went") {
                    let total = Double(max(m.total, 1))
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(Array([(m.app, NSColor.systemBlue), (m.wired, .systemPurple), (m.compressed, .systemOrange), (m.cached, .systemGray)].enumerated()), id: \.offset) { _, part in
                                Rectangle().fill(Color(nsColor: part.1)).frame(width: max(0, geo.size.width * Double(part.0) / total))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 14).clipShape(RoundedRectangle(cornerRadius: 5))
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
                        GridRow { Text("Apps").foregroundStyle(.secondary); Text(SystemStats.gigabytes(m.app)) }
                        GridRow { Text("Wired").foregroundStyle(.secondary); Text(SystemStats.gigabytes(m.wired)) }
                        GridRow { Text("Compressed").foregroundStyle(.secondary); Text(SystemStats.gigabytes(m.compressed)) }
                        GridRow { Text("Cached").foregroundStyle(.secondary); Text(SystemStats.gigabytes(m.cached)) }
                    }
                    .font(.system(size: 12.5)).monospacedDigit()
                }
                DashCard(title: "Swap", pin: "swap") {
                    Text(SystemStats.gigabytes(swap)).font(.figure(24, weight: .semibold))
                    Text("Pages swapped in \(paging.ins) · out \(paging.outs) since start-up").font(.system(size: 11.5)).foregroundStyle(.secondary)
                    TrendChart(values: samples.map(\.swapGB), colour: Color(nsColor: .systemOrange), format: { String(format: "%.1f GB", $0) }, height: 60)
                }
            }
        }
        .sectionScroll()
        .onAppear { system.setLive(true) }
        .onDisappear { system.setLive(false) }
    }
}

struct GPUSection: View {
    @ObservedObject private var recorder = SystemRecorder.shared
    @State private var now: Double?
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue
    private var range: Binding<SystemHistory.Range> { Binding(get: { SystemHistory.Range(rawValue: rangeName) ?? .hours24 }, set: { rangeName = $0.rawValue }) }
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "GPU", subtitle: now.map { "\(Int($0.rounded()))% in use now" } ?? "This Mac's graphics driver doesn't report its load", range: range)
            DashCard(title: "Graphics load over time", pin: "gpu") {
                TrendChart(values: recorder.history.samples(range.wrappedValue).compactMap(\.gpu), maximum: 100, colour: Color(nsColor: .systemPurple), height: 140)
            }
        }
        .sectionScroll()
        .onAppear { now = SystemWatch.gpuUtilisation() }
        .onReceive(tick) { _ in now = SystemWatch.gpuUtilisation() }
    }
}

// MARK: - Disk and Network

struct DiskSection: View {
    @ObservedObject private var recorder = SystemRecorder.shared
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue
    private var range: Binding<SystemHistory.Range> { Binding(get: { SystemHistory.Range(rawValue: rangeName) ?? .hours24 }, set: { rangeName = $0.rawValue }) }

    var body: some View {
        let samples = recorder.history.samples(range.wrappedValue)
        let today = recorder.history.samples(.hours24).filter { Calendar.current.isDateInToday($0.at) }
        let written = today.reduce(0) { $0 + $1.writeBytes * 60 }, read = today.reduce(0) { $0 + $1.readBytes * 60 }
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Disk", subtitle: "Today: \(Storage.size(Int64(read))) read · \(Storage.size(Int64(written))) written", range: range)
            HStack(alignment: .top, spacing: 14) {
                DashCard(title: "Reading") { TrendChart(values: samples.map(\.readBytes), colour: Color(nsColor: .systemTeal), format: bytesRate, height: 90) }
                DashCard(title: "Writing", pin: "write") { TrendChart(values: samples.map(\.writeBytes), colour: Color(nsColor: .systemPink), format: bytesRate, height: 90) }
            }
            StoragePage(onBack: {}, embedded: true)
        }
        .sectionScroll()
    }
}

struct NetworkSection: View {
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var recorder = SystemRecorder.shared
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue
    private var range: Binding<SystemHistory.Range> { Binding(get: { SystemHistory.Range(rawValue: rangeName) ?? .hours24 }, set: { rangeName = $0.rawValue }) }

    var body: some View {
        let samples = recorder.history.samples(range.wrappedValue)
        let today = recorder.history.samples(.hours24).filter { Calendar.current.isDateInToday($0.at) }
        let down = today.reduce(0) { $0 + $1.downBytes * 60 }, up = today.reduce(0) { $0 + $1.upBytes * 60 }
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Network", subtitle: "↓ \(bytesRate(system.down))  ↑ \(bytesRate(system.up)) · today \(Storage.size(Int64(down))) down, \(Storage.size(Int64(up))) up", range: range)
            DashCard(title: "Download", pin: "down") { TrendChart(values: samples.map(\.downBytes), colour: Color(nsColor: .systemTeal), format: bytesRate, height: 100) }
            DashCard(title: "Upload") { TrendChart(values: samples.map(\.upBytes), colour: Color(nsColor: .systemIndigo), format: bytesRate, height: 70) }
            DashCard(title: "Connection") {
                HStack(spacing: 24) {
                    VStack(alignment: .leading) { Text("IP ADDRESS").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.tertiary); Text(system.localIP ?? "–").textSelection(.enabled) }
                    VStack(alignment: .leading) { Text("VPN").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.tertiary); Text(system.vpn ? "On" : "Off") }
                    VStack(alignment: .leading) { Text("SPEED TEST").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.tertiary); Text(system.speedTest ?? "Not run") }
                    Spacer()
                    Button(system.testing ? "Testing…" : "Test Speed") { system.runSpeedTest() }.disabled(system.testing)
                }
                .font(.system(size: 13))
            }
        }
        .sectionScroll()
        .onAppear { system.setLive(true) }
        .onDisappear { system.setLive(false) }
    }
}

// MARK: - Sound, Ports, Agents, Trends

struct SoundSection: View {
    let compact: Bool
    @ObservedObject private var sound = SoundControl.shared
    @State private var micMuted = MomentsWatch.micMuted()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !compact { Text("Sound").font(.system(size: 22, weight: .bold)) }
            DashCard(title: "Output") {
                Picker("Plays through", selection: Binding(get: { sound.current }, set: { sound.choose($0) })) {
                    ForEach(sound.outputs) { Text($0.name).tag($0.id) }
                }
                HStack {
                    Button { sound.toggleMute() } label: {
                        Image(systemName: sound.muted ? "speaker.slash.fill" : "speaker.wave.2.fill").accessibilityLabel(sound.muted ? "Unmute" : "Mute")
                    }
                    .buttonStyle(.plain)
                    Slider(value: $sound.volume, in: 0...1)
                    Text("\(Int((sound.volume * 100).rounded()))%").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
            DashCard(title: "Microphone") {
                Toggle(micMuted ? "Muted" : "On", isOn: Binding(get: { !micMuted }, set: { _ in MomentsWatch.shared.toggleMute(); micMuted = MomentsWatch.micMuted() }))
                    .toggleStyle(.switch)
            }
            if !compact {
                Text("Volume for each app isn't possible without installing an audio driver into macOS, so \(Brand.name) doesn't.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .onAppear { sound.refresh() }
    }
}

struct PortsSection: View {
    @ObservedObject private var ports = PortsWatch.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Ports").font(.system(size: 22, weight: .bold))
                Text("Programs listening for connections on this Mac").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                if ports.loading { ProgressView().controlSize(.small) }
                Button("Refresh") { ports.refresh() }
            }
            DashCard(title: "\(ports.ports.count) listening") {
                if ports.ports.isEmpty && !ports.loading { Text("Nothing is listening.").foregroundStyle(.secondary) }
                ForEach(ports.ports) { port in
                    HStack(spacing: 12) {
                        Text(":\(port.port)").font(.system(size: 14, weight: .semibold, design: .monospaced)).frame(width: 80, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(port.command).font(.system(size: 12.5, weight: .medium))
                            Text("\(port.kind) · \(port.address) · pid \(port.pid)").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        if port.isExposed {
                            Text("Open to your network").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color(nsColor: .systemOrange))
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Color(nsColor: .systemOrange).opacity(0.15)))
                        }
                        Spacer()
                        if [3000, 3001, 4200, 5173, 8000, 8080].contains(port.port) {
                            Button("Open") { if let url = URL(string: "http://localhost:\(port.port)") { NSWorkspace.shared.open(url) } }
                        }
                        Button("Stop…") { ports.stop(port) }
                    }
                    .controlSize(.small)
                    Divider().opacity(0.4)
                }
            }
        }
        .sectionScroll()
        .onAppear { ports.refresh() }
    }
}

struct AgentsSection: View {
    @ObservedObject private var power = PowerWatch.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Agents").font(.system(size: 22, weight: .bold))
            DashCard(title: "Coding agents running") {
                if power.agents.isEmpty { Text("No coding agents are running.").foregroundStyle(.secondary) }
                ForEach(power.agents) { agent in
                    HStack {
                        Image(systemName: "sparkles").frame(width: 18)
                        Text(agent.name)
                        Spacer()
                        Text("\(agent.processes) processes").foregroundStyle(.secondary)
                        Text(String(format: "%.0f%% CPU", agent.cpuPercent)).frame(width: 80, alignment: .trailing)
                        Text(agent.watts.map { String(format: "%.1f W", $0) } ?? "–").frame(width: 60, alignment: .trailing)
                    }
                    .font(.system(size: 12.5)).monospacedDigit()
                }
            }
        }
        .sectionScroll()
        .onAppear { power.setLive(true) }
        .onDisappear { power.setLive(false) }
    }
}

struct TrendsSection: View {
    @ObservedObject private var recorder = SystemRecorder.shared
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.days7.rawValue
    private var range: Binding<SystemHistory.Range> { Binding(get: { SystemHistory.Range(rawValue: rangeName) ?? .days7 }, set: { rangeName = $0.rawValue }) }

    var body: some View {
        let s = recorder.history.samples(range.wrappedValue)
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Trends", subtitle: "Everything \(Brand.name) has seen, kept on this Mac for 30 days", range: range)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                DashCard(title: "CPU") { TrendChart(values: s.map(\.cpu), maximum: 100) }
                DashCard(title: "Memory pressure") { TrendChart(values: s.map(\.memory), maximum: 100, colour: Color(nsColor: .systemBlue)) }
                DashCard(title: "Swap") { TrendChart(values: s.map(\.swapGB), colour: Color(nsColor: .systemOrange), format: { String(format: "%.1f GB", $0) }) }
                DashCard(title: "GPU") { TrendChart(values: s.compactMap(\.gpu), maximum: 100, colour: Color(nsColor: .systemPurple)) }
                DashCard(title: "Download") { TrendChart(values: s.map(\.downBytes), colour: Color(nsColor: .systemTeal), format: bytesRate) }
                DashCard(title: "Disk writes") { TrendChart(values: s.map(\.writeBytes), colour: Color(nsColor: .systemPink), format: bytesRate) }
                if PowerWatch.hasBattery {
                    DashCard(title: "Battery") { TrendChart(values: s.compactMap { $0.battery.map(Double.init) }, maximum: 100, colour: Color(nsColor: .systemGreen)) }
                }
            }
        }
        .sectionScroll()
    }
}
#endif
