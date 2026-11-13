#if os(macOS)
import AppKit
import IOKit
import Metal
import MonorailCore
import SwiftUI

// The Dashboard's system pages, built out: every page leads with live figures, then the detail behind them,
// then history and what to do about it. Nothing is one lone chart.

// MARK: - Building blocks

/// A key figure: a small label, a big number that rolls as it changes, and a line under it.
struct Kpi: View {
    let label: String
    let value: String
    var sub: String? = nil
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 9.5, weight: .semibold)).kerning(0.4).foregroundStyle(.tertiary).lineLimit(1)
            Text(value).font(.figure(21, weight: .semibold)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6).rolling(value)
            if let sub { Text(sub).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
        .entrance()
    }
}

/// A row of key figures.
struct KpiRow: View {
    let items: [Kpi]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: min(max(items.count, 1), 5)), spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in item }
        }
    }
}

/// Each core's last few minutes as its own little chart, performance cores first.
struct CoreGrid: View {
    @ObservedObject var system: SystemWatch

    var body: some View {
        let p = system.performance.count
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            ForEach(Array(system.coreHistory.enumerated()), id: \.offset) { index, history in
                let efficiency = index >= p && !system.efficiency.isEmpty
                let now = history.last ?? 0
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(efficiency ? "E\(index - p + 1)" : (system.efficiency.isEmpty ? "Core \(index + 1)" : "P\(index + 1)"))
                            .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(now.rounded()))%").font(.figure(11, weight: .semibold)).rolling(Int(now.rounded()))
                    }
                    TrendChart(values: history, maximum: 100, colour: efficiency ? Color(nsColor: .systemTeal) : Color(nsColor: .systemOrange), height: 30)
                        .allowsHitTesting(false)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.05)))
            }
        }
    }
}

/// When the Mac is busiest: the average by weekday and hour, darker for more.
struct WeekHeatmap: View {
    let grid: [[Double?]]
    var maximum: Double = 100
    var colour: Color = Color(nsColor: .systemOrange)
    var format: (Double) -> String = { "\(Int($0.rounded()))%" }
    @State private var hover: (Int, Int)?
    private let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        let top = max(grid.flatMap { $0 }.compactMap { $0 }.max() ?? maximum, 0.0001)
        VStack(alignment: .leading, spacing: 3) {
            ForEach(0..<7, id: \.self) { d in
                HStack(spacing: 3) {
                    Text(days[d]).font(.system(size: 9.5)).foregroundStyle(.tertiary).frame(width: 26, alignment: .leading)
                    ForEach(0..<24, id: \.self) { h in
                        let v = grid.indices.contains(d) && grid[d].indices.contains(h) ? grid[d][h] : nil
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(v.map { colour.opacity(0.12 + 0.85 * min($0 / top, 1)) } ?? Color.white.opacity(0.04))
                            .frame(height: 13)
                            .onHover { hover = $0 ? (d, h) : nil }
                            .help(v.map { "\(days[d]) \(h):00 · \(format($0))" } ?? "\(days[d]) \(h):00 · no readings yet")
                    }
                }
            }
            HStack(spacing: 3) {
                Spacer().frame(width: 26)
                ForEach([0, 6, 12, 18], id: \.self) { h in
                    Text("\(h):00").font(.system(size: 9)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text(hover.flatMap { d, h in grid[d][h].map { "\(days[d]) \(h):00 – \(h + 1):00: \(format($0)) on average" } } ?? "Darker squares are busier hours, over everything Monorail has kept (up to 30 days).")
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Busiest hours by weekday"))
    }
}

/// One bar a day.
struct DailyBars: View {
    let totals: [(day: Date, total: Double)]
    var colour: Color = Color(nsColor: .systemTeal)
    var format: (Double) -> String
    @State private var grown: CGFloat = Motion.reduced ? 1 : 0

    var body: some View {
        let top = max(totals.map(\.total).max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(totals.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Calendar.current.isDateInToday(item.day) ? colour : colour.opacity(0.55))
                            .frame(height: max(3, 90 * grown * CGFloat(item.total / top)))
                            .help("\(item.day.formatted(.dateTime.weekday(.wide).day().month())): \(format(item.total))")
                        Text(item.day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 9.5)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 108, alignment: .bottom)
            if let today = totals.last {
                Text("Today \(format(today.total)) · \(totals.count)-day total \(format(totals.reduce(0) { $0 + $1.total }))")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .onAppear { guard grown < 1 else { return }; withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) { grown = 1 } }
    }
}

/// Apps ranked by a reading, with Quit.
struct AppTable: View {
    struct Row: Identifiable {
        var id: String
        var name: String
        var icon: NSImage?
        var value: String
        var detail: String?
        var share: Double
        var pid: pid_t?
    }
    let rows: [Row]
    var tint: Color = Color(nsColor: .systemOrange)
    @State private var confirm: Row?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    if let icon = row.icon { Image(nsImage: icon).resizable().frame(width: 20, height: 20) }
                    else { Image(systemName: "app.dashed").frame(width: 20, height: 20).foregroundStyle(.secondary) }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.name).font(.system(size: 12.5)).lineLimit(1)
                        if let detail = row.detail { Text(detail).font(.system(size: 10.5)).foregroundStyle(.tertiary).lineLimit(1) }
                    }
                    .frame(width: 190, alignment: .leading)
                    GeometryReader { g in
                        Capsule().fill(Color.white.opacity(0.06))
                            .overlay(alignment: .leading) { Capsule().fill(tint.opacity(0.8)).frame(width: max(2, g.size.width * min(max(row.share, 0), 1))) }
                    }
                    .frame(height: 6)
                    Text(row.value).font(.figure(12, weight: .semibold)).frame(width: 70, alignment: .trailing).rolling(row.value)
                    if !Edition.isAppStore, row.pid != nil || NSRunningApplication.runningApplications(withBundleIdentifier: row.id).first != nil {
                        Button { confirm = row } label: {
                            Image(systemName: "xmark.circle").font(.system(size: 12)).foregroundStyle(.secondary).accessibilityLabel("Quit \(row.name)")
                        }
                        .buttonStyle(.plain).help("Quit \(row.name)")
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .confirmationDialog(confirm.map { "Quit \($0.name)?" } ?? "", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })) {
            Button("Quit") { if let row = confirm { quit(row, force: false) }; confirm = nil }
            Button("Force Quit", role: .destructive) { if let row = confirm { quit(row, force: true) }; confirm = nil }
            Button("Cancel", role: .cancel) { confirm = nil }
        } message: { Text("Unsaved changes may be lost if you force quit.") }
    }

    private func quit(_ row: Row, force: Bool) {
        let apps = row.pid.flatMap { NSRunningApplication(processIdentifier: $0) }.map { [$0] } ?? NSRunningApplication.runningApplications(withBundleIdentifier: row.id)
        for app in apps { _ = force ? app.forceTerminate() : app.terminate() }
    }
}

/// The range buttons' binding, shared by every history page.
private func dashboardRange(_ name: Binding<String>) -> Binding<SystemHistory.Range> {
    Binding(get: { SystemHistory.Range(rawValue: name.wrappedValue) ?? .hours24 }, set: { name.wrappedValue = $0.rawValue })
}

// MARK: - CPU

struct CPUSection: View {
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var recorder = SystemRecorder.shared
    @ObservedObject private var details = SystemDetails.shared
    @ObservedObject private var power = PowerWatch.shared
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue

    var body: some View {
        let range = dashboardRange($rangeName)
        let values = recorder.history.samples(range.wrappedValue).map(\.cpu)
        let cores = details.cores.performance + details.cores.efficiency
        let perCore = details.load.first.map { $0 / Double(max(cores, 1)) } ?? 0
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "CPU", subtitle: "\(Int(system.total.rounded()))% now · \(system.chipName)", range: range)
            KpiRow(items: [
                Kpi(label: "In use now", value: "\(Int(system.total.rounded()))%", sub: "apps \(Int(details.user.rounded()))% · macOS \(Int(details.system.rounded()))%", tint: Color(nsColor: .systemOrange)),
                Kpi(label: "Load (1 min)", value: details.load.first.map { String(format: "%.1f", $0) } ?? "–",
                    sub: perCore > 1 ? "more work than cores" : "\(Int((perCore * 100).rounded()))% of \(cores) cores"),
                Kpi(label: "Processes", value: "\(details.processes)", sub: "running now"),
                Kpi(label: "Heat", value: details.thermalWords.0, sub: details.thermal == .nominal ? "running at full speed" : "slowing down to cool", tint: details.thermalWords.1),
                Kpi(label: "Up for", value: SystemStats.uptime(system.uptime), sub: details.booted.map { "since \($0.formatted(date: .abbreviated, time: .shortened))" }),
            ])
            DashCard(title: "Processor time now") {
                GeometryReader { g in
                    HStack(spacing: 2) {
                        Rectangle().fill(Color(nsColor: .systemBlue)).frame(width: max(0, g.size.width * details.user / 100 - 1))
                        Rectangle().fill(Color(nsColor: .systemRed)).frame(width: max(0, g.size.width * details.system / 100 - 1))
                        Rectangle().fill(Color.white.opacity(0.08))
                    }
                    .animation(.easeOut(duration: 0.4), value: details.user)
                }
                .frame(height: 12).clipShape(RoundedRectangle(cornerRadius: 4))
                HStack(spacing: 16) {
                    Label("Apps \(Int(details.user.rounded()))%", systemImage: "square.fill").foregroundStyle(Color(nsColor: .systemBlue))
                    Label("macOS \(Int(details.system.rounded()))%", systemImage: "square.fill").foregroundStyle(Color(nsColor: .systemRed))
                    Label("Idle \(Int(details.idle.rounded()))%", systemImage: "square.fill").foregroundStyle(.secondary)
                    Spacer()
                    Text(details.load.count == 3 ? String(format: "Load %.1f · %.1f · %.1f (1, 5, 15 min)", details.load[0], details.load[1], details.load[2]) : "").foregroundStyle(.tertiary)
                }
                .font(.system(size: 11.5)).labelStyle(.titleAndIcon)
            }
            DashCard(title: "Every core, live", trailing: "\(details.cores.performance) performance\(details.cores.efficiency > 0 ? " · \(details.cores.efficiency) efficiency" : "")") {
                CoreGrid(system: system)
            }
            HStack(alignment: .top, spacing: 14) {
                DashCard(title: "Load over time", pin: "cpu") { TrendChart(values: values, maximum: 100, height: 130) }
                DashCard(title: "Your chip") { ChipView(name: system.chipName, performance: system.performance, efficiency: system.efficiency) }
                    .frame(maxWidth: 330)
            }
            DashCard(title: "When your Mac is busiest") { WeekHeatmap(grid: recorder.history.weekHours { $0.cpu }) }
            if !Edition.isAppStore {
                DashCard(title: "Using the processor", trailing: "share of one core") {
                    let top = Array(power.apps.sorted { $0.use.cpuPercent > $1.use.cpuPercent }.prefix(10))
                    let most = max(top.first?.use.cpuPercent ?? 1, 1)
                    if top.isEmpty { Text("Measuring…").font(.system(size: 12)).foregroundStyle(.secondary) }
                    AppTable(rows: top.map { app in
                        .init(id: app.id, name: app.use.appName, icon: NSRunningApplication.runningApplications(withBundleIdentifier: app.id).first?.icon,
                              value: String(format: "%.0f%%", app.use.cpuPercent),
                              detail: "\(app.processes) process\(app.processes == 1 ? "" : "es")" + (app.use.percentPerHour.map { String(format: " · %.1f%% battery an hour", $0) } ?? ""),
                              share: app.use.cpuPercent / most)
                    })
                }
            }
        }
        .sectionScroll()
        .onAppear { system.setLive(true); details.setLive(true); power.setLive(true) }
        .onDisappear { system.setLive(false); details.setLive(false); power.setLive(false) }
    }
}

// MARK: - Memory

struct MemorySection: View {
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var recorder = SystemRecorder.shared
    @ObservedObject private var details = SystemDetails.shared
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue

    var body: some View {
        let range = dashboardRange($rangeName)
        let m = system.memory
        let samples = recorder.history.samples(range.wrappedValue)
        let tone: Color = m.level == .low ? Color(nsColor: .systemGreen) : m.level == .medium ? Color(nsColor: .systemYellow) : Color(nsColor: .systemRed)
        let swapping = details.pagingPerSecond.outs > 50
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Memory", subtitle: "\(SystemStats.gigabytes(m.used)) of \(SystemStats.gigabytes(m.total)) in use · pressure \(m.level.rawValue)", range: range)
            KpiRow(items: [
                Kpi(label: "Pressure", value: "\(Int((m.pressure * 100).rounded()))%", sub: m.level == .high ? "the Mac is short of memory" : m.level == .medium ? "getting full" : "plenty free", tint: tone),
                Kpi(label: "In use", value: SystemStats.gigabytes(m.used), sub: "of \(SystemStats.gigabytes(m.total))"),
                Kpi(label: "Compressed", value: SystemStats.gigabytes(m.compressed), sub: "squeezed to make room"),
                Kpi(label: "Swap", value: SystemStats.gigabytes(details.swap), sub: swapping ? "writing to disk now" : "on disk", tint: details.swap > 4_000_000_000 ? Color(nsColor: .systemOrange) : .primary),
                Kpi(label: "Cached", value: SystemStats.gigabytes(m.cached), sub: "free to reuse"),
            ])
            HStack(alignment: .top, spacing: 14) {
                DashCard(title: "Where it went") {
                    let total = Double(max(m.total, 1))
                    let parts: [(String, UInt64, NSColor, String)] = [
                        ("Apps", m.app, .systemBlue, "Memory apps asked for."), ("Wired", m.wired, .systemPurple, "Kept by macOS; can't be moved out."),
                        ("Compressed", m.compressed, .systemOrange, "Squeezed in place instead of written to disk."),
                        ("Cached", m.cached, .systemGray, "Recently used files; freed the moment apps need it."), ("Free", m.free, .tertiaryLabelColor, "Not in use at all.")]
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                                Rectangle().fill(Color(nsColor: part.2)).frame(width: max(0, geo.size.width * Double(part.1) / total - 2))
                            }
                        }
                    }
                    .frame(height: 16).clipShape(RoundedRectangle(cornerRadius: 5))
                    VStack(spacing: 6) {
                        ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: part.2)).frame(width: 9, height: 9)
                                Text(part.0).font(.system(size: 12.5, weight: .medium)).frame(width: 90, alignment: .leading)
                                Text(part.3).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
                                Spacer()
                                Text(SystemStats.gigabytes(part.1)).font(.figure(12.5, weight: .semibold))
                            }
                        }
                    }
                }
                DashCard(title: "Swapping now") {
                    Kpi(label: "Into memory", value: "\(Int(details.pagingPerSecond.ins))/s", sub: "pages read back from disk")
                    Kpi(label: "Out to disk", value: "\(Int(details.pagingPerSecond.outs))/s", sub: "pages written to disk", tint: swapping ? Color(nsColor: .systemOrange) : .primary)
                    Text(swapping ? "The Mac is short of memory right now. Quitting the app at the top of the list below helps most."
                         : SystemHistory.restartAdvice(uptime: system.uptime, swapGB: Double(details.swap) / 1_073_741_824) ?? "Nothing to do: there's enough memory.")
                        .font(.system(size: 11.5)).foregroundStyle(swapping ? Color(nsColor: .systemOrange) : .secondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 300)
            }
            HStack(alignment: .top, spacing: 14) {
                DashCard(title: "Pressure over time", pin: "memory") { TrendChart(values: samples.map(\.memory), maximum: 100, colour: Color(nsColor: .systemBlue), height: 120) }
                DashCard(title: "Swap over time", pin: "swap") {
                    TrendChart(values: samples.map(\.swapGB), colour: Color(nsColor: .systemOrange), format: { String(format: "%.1f GB", $0) }, height: 120)
                }
            }
            if !Edition.isAppStore {
                DashCard(title: "Using the most memory", trailing: "each app's own footprint") {
                    let most = Double(max(details.memoryApps.first?.bytes ?? 1, 1))
                    AppTable(rows: details.memoryApps.map {
                        .init(id: "\($0.id)", name: $0.name, icon: $0.icon, value: SystemStats.gigabytes($0.bytes),
                              detail: "\(Int((Double($0.bytes) / Double(max(m.total, 1)) * 100).rounded()))% of this Mac's memory", share: Double($0.bytes) / most, pid: $0.id)
                    }, tint: Color(nsColor: .systemBlue))
                }
            }
            DashCard(title: "When memory runs fullest") { WeekHeatmap(grid: recorder.history.weekHours { $0.memory }, colour: Color(nsColor: .systemBlue)) }
        }
        .sectionScroll()
        .onAppear { system.setLive(true); details.setLive(true) }
        .onDisappear { system.setLive(false); details.setLive(false) }
    }
}

// MARK: - GPU and displays

struct GPUSection: View {
    @ObservedObject private var recorder = SystemRecorder.shared
    @State private var now: Double?
    @State private var memoryInUse: UInt64 = 0
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let device = MTLCreateSystemDefaultDevice()

    private static func gpuCores() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            if let cores = IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                return cores.intValue
            }
        }
        return nil
    }

    var body: some View {
        let range = dashboardRange($rangeName)
        let samples = recorder.history.samples(range.wrappedValue).compactMap(\.gpu)
        let peak = samples.max()
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "GPU", subtitle: now.map { "\(Int($0.rounded()))% in use now · \(device?.name ?? "Graphics")" } ?? "This Mac's graphics driver doesn't report its load", range: range)
            KpiRow(items: [
                Kpi(label: "In use now", value: now.map { "\(Int($0.rounded()))%" } ?? "–", sub: device?.name, tint: Color(nsColor: .systemPurple)),
                Kpi(label: "Peak", value: peak.map { "\(Int($0.rounded()))%" } ?? "–", sub: "in this range"),
                Kpi(label: "Graphics cores", value: Self.gpuCores().map(String.init) ?? "–", sub: device?.hasUnifiedMemory == true ? "sharing memory with the CPU" : nil),
                Kpi(label: "Memory in use", value: SystemStats.gigabytes(memoryInUse), sub: device.map { "of \(SystemStats.gigabytes($0.recommendedMaxWorkingSetSize)) it can use" }),
            ])
            DashCard(title: "Graphics load over time", pin: "gpu") {
                TrendChart(values: samples, maximum: 100, colour: Color(nsColor: .systemPurple), height: 140)
            }
            DashCard(title: "When graphics work hardest") { WeekHeatmap(grid: recorder.history.weekHours { $0.gpu ?? 0 }, colour: Color(nsColor: .systemPurple)) }
            DashCard(title: "Displays") {
                ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { _, screen in
                    let scale = screen.backingScaleFactor
                    let size = screen.frame.size
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: screen.safeAreaInsets.top > 0 ? "laptopcomputer" : "display").font(.system(size: 20)).foregroundStyle(.secondary).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(screen.localizedName).font(.system(size: 13, weight: .semibold))
                            Text("\(Int(size.width)) × \(Int(size.height)) points · \(Int(size.width * scale)) × \(Int(size.height * scale)) pixels\(scale > 1 ? " · Retina" : "")")
                                .font(.system(size: 11.5)).foregroundStyle(.secondary)
                            Text([screen.maximumFramesPerSecond > 0 ? "\(screen.maximumFramesPerSecond) Hz" : nil,
                                  screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1 ? "HDR (up to \(String(format: "%.0f", screen.maximumPotentialExtendedDynamicRangeColorComponentValue))× brightness)" : "SDR",
                                  screen.colorSpace?.localizedName].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 11.5)).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if screen == NSScreen.main { Text("Main").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary) }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sectionScroll()
        .onAppear { now = SystemWatch.gpuUtilisation(); memoryInUse = UInt64(device?.currentAllocatedSize ?? 0) }
        .onReceive(tick) { _ in now = SystemWatch.gpuUtilisation(); memoryInUse = UInt64(device?.currentAllocatedSize ?? 0) }
    }
}

// MARK: - Disk

struct DiskSection: View {
    @ObservedObject private var recorder = SystemRecorder.shared
    @ObservedObject private var details = SystemDetails.shared
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue

    struct Volume: Identifiable {
        var id: URL
        var name: String
        var total: Int64
        var free: Int64
        var format: String
        var removable: Bool
        var icon: NSImage
    }

    private static func volumes() -> [Volume] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey,
                                      .volumeLocalizedFormatDescriptionKey, .volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsBrowsableKey]
        return (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []).compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.volumeIsBrowsable != false, let total = v.volumeTotalCapacity, total > 0 else { return nil }
            let free = v.volumeAvailableCapacityForImportantUsage ?? Int64(v.volumeAvailableCapacity ?? 0)
            return Volume(id: url, name: v.volumeName ?? url.lastPathComponent, total: Int64(total), free: free, format: v.volumeLocalizedFormatDescription ?? "",
                          removable: v.volumeIsRemovable == true || v.volumeIsEjectable == true, icon: NSWorkspace.shared.icon(forFile: url.path))
        }
    }

    var body: some View {
        let range = dashboardRange($rangeName)
        let samples = recorder.history.samples(range.wrappedValue)
        let reads = recorder.history.dailyTotals({ $0.readBytes }, days: 14), writes = recorder.history.dailyTotals({ $0.writeBytes }, days: 14)
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Disk", subtitle: "Today: \(Storage.size(Int64(reads.last?.total ?? 0))) read · \(Storage.size(Int64(writes.last?.total ?? 0))) written", range: range)
            KpiRow(items: [
                Kpi(label: "Reading now", value: SystemStats.speed(details.diskPerSecond.read), tint: Color(nsColor: .systemTeal)),
                Kpi(label: "Writing now", value: SystemStats.speed(details.diskPerSecond.written), tint: Color(nsColor: .systemPink)),
                Kpi(label: "Read today", value: Storage.size(Int64(reads.last?.total ?? 0))),
                Kpi(label: "Written today", value: Storage.size(Int64(writes.last?.total ?? 0)), sub: "SSDs wear with writing, very slowly"),
            ])
            HStack(alignment: .top, spacing: 14) {
                DashCard(title: "Reading") { TrendChart(values: samples.map(\.readBytes), colour: Color(nsColor: .systemTeal), format: SystemStats.speed, height: 90) }
                DashCard(title: "Writing", pin: "write") { TrendChart(values: samples.map(\.writeBytes), colour: Color(nsColor: .systemPink), format: SystemStats.speed, height: 90) }
            }
            DashCard(title: "Written each day", trailing: "last 14 days") { DailyBars(totals: writes, colour: Color(nsColor: .systemPink), format: { Storage.size(Int64($0)) }) }
            DashCard(title: "Disks and volumes") {
                ForEach(Self.volumes()) { volume in
                    HStack(spacing: 12) {
                        Image(nsImage: volume.icon).resizable().frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(volume.name).font(.system(size: 13, weight: .semibold))
                                Text(volume.format).font(.system(size: 11)).foregroundStyle(.tertiary)
                                Spacer()
                                Text("\(Storage.size(volume.free)) free of \(Storage.size(volume.total))").font(.system(size: 11.5)).foregroundStyle(.secondary).monospacedDigit()
                            }
                            ProgressView(value: Double(volume.total - volume.free), total: Double(volume.total))
                                .tint(Storage.level(free: volume.free, total: volume.total) == .fine ? Color(nsColor: .systemBlue) : Color(nsColor: .systemOrange))
                        }
                        if volume.removable {
                            Button { try? NSWorkspace.shared.unmountAndEjectDevice(at: volume.id) } label: {
                                Image(systemName: "eject.fill").font(.system(size: 11)).accessibilityLabel("Eject \(volume.name)")
                            }
                            .buttonStyle(.plain).help("Eject \(volume.name)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            StoragePage(onBack: {}, embedded: true)
        }
        .sectionScroll()
        .onAppear { details.setLive(true) }
        .onDisappear { details.setLive(false) }
    }
}

// MARK: - Network

struct NetworkSection: View {
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var recorder = SystemRecorder.shared
    @ObservedObject private var net = NetworkWatch.shared
    @AppStorage("DashboardRange") private var rangeName = SystemHistory.Range.hours24.rawValue

    var body: some View {
        let range = dashboardRange($rangeName)
        let samples = recorder.history.samples(range.wrappedValue)
        let down = recorder.history.dailyTotals({ $0.downBytes }, days: 14), up = recorder.history.dailyTotals({ $0.upBytes }, days: 14)
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Network", subtitle: "\(net.kind)\(system.vpn ? " · VPN on" : "") · ↓ \(SystemStats.speed(system.down))  ↑ \(SystemStats.speed(system.up))", range: range)
            KpiRow(items: [
                Kpi(label: "Download", value: SystemStats.speed(system.down), sub: "right now", tint: Color(nsColor: .systemTeal)),
                Kpi(label: "Upload", value: SystemStats.speed(system.up), sub: "right now", tint: Color(nsColor: .systemIndigo)),
                Kpi(label: "Today", value: Storage.size(Int64((down.last?.total ?? 0) + (up.last?.total ?? 0))), sub: "↓ \(Storage.size(Int64(down.last?.total ?? 0))) · ↑ \(Storage.size(Int64(up.last?.total ?? 0)))"),
                Kpi(label: "Since start-up", value: SystemStats.gigabytes(net.sinceRestart.down + net.sinceRestart.up), sub: "↓ \(SystemStats.gigabytes(net.sinceRestart.down)) · ↑ \(SystemStats.gigabytes(net.sinceRestart.up))"),
                Kpi(label: "Signal", value: net.wifi.map { NetworkDetails.quality(rssi: $0.rssi, noise: $0.noise).quality.rawValue } ?? (net.interface == nil ? "Offline" : "Wired"),
                    sub: net.wifi.map { "\($0.rssi) dBm · \(Int($0.transmitRate)) Mbit/s" }),
            ])
            HStack(alignment: .top, spacing: 14) {
                DashCard(title: "Download", pin: "down") { TrendChart(values: samples.map(\.downBytes), colour: Color(nsColor: .systemTeal), format: SystemStats.speed, height: 100) }
                DashCard(title: "Upload") { TrendChart(values: samples.map(\.upBytes), colour: Color(nsColor: .systemIndigo), format: SystemStats.speed, height: 100) }
            }
            DashCard(title: "Downloaded each day", trailing: "last 14 days") { DailyBars(totals: down, colour: Color(nsColor: .systemTeal), format: { Storage.size(Int64($0)) }) }
            NetworkPage(onBack: {}, embedded: true).frame(maxWidth: 720, alignment: .leading)
        }
        .sectionScroll()
        .onAppear { system.setLive(true); net.setLive(true) }
        .onDisappear { system.setLive(false); net.setLive(false) }
    }
}
#endif
