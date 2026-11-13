#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// The Mac's chip as Apple draws it in keynotes: a dark glossy package with the performance and
/// efficiency cores laid out as clusters, each core glowing by its load.
struct ChipView: View {
    let name: String
    let performance: [Double]
    let efficiency: [Double]

    private static func color(_ load: Double) -> Color {
        load < 40 ? Color(red: 0.19, green: 0.82, blue: 0.35) : load < 75 ? Color(red: 1, green: 0.84, blue: 0.04) : Color(red: 1, green: 0.27, blue: 0.23)
    }

    private func core(_ load: Double, _ label: String, height: CGFloat) -> some View {
        let color = Self.color(load), amount = max(0.12, load / 100)
        return VStack(spacing: 0) {
            Text(label).font(.system(size: 9, weight: .semibold))
            Text("\(Int(load.rounded()))%").font(.system(size: 8.5, weight: .medium)).opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).frame(height: height)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(color.opacity(0.2 + amount * 0.6)))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
        .shadow(color: color.opacity(amount * 0.7), radius: 3 + amount * 7)
        .animation(Motion.reorder, value: load)
    }

    private func cluster(_ title: String, _ loads: [Double], prefix: String, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 8, weight: .semibold)).kerning(0.6).foregroundStyle(.white.opacity(0.45))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(max(loads.count, 1), 4)), spacing: 4) {
                ForEach(Array(loads.enumerated()), id: \.offset) { index, load in core(load, "\(prefix)\(index + 1)", height: height) }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(name.replacingOccurrences(of: "Apple ", with: "")).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text("load per core").font(.system(size: 9.5, weight: .medium)).foregroundStyle(.white.opacity(0.45))
            }
            if performance.isEmpty && efficiency.isEmpty {
                Text("Reading…").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            if !performance.isEmpty { cluster(efficiency.isEmpty ? "CORES" : "PERFORMANCE", performance, prefix: efficiency.isEmpty ? "" : "P", height: 32) }
            if !efficiency.isEmpty { cluster("EFFICIENCY", efficiency, prefix: "E", height: 24) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(RadialGradient(colors: [Color(white: 0.16), Color(white: 0.04)], center: .topLeading, startRadius: 10, endRadius: 320)))
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.07), Color(white: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 6))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(name): \(Int(SystemStats.average(performance + efficiency).rounded()))% average load"))
    }
}

/// The System page: three rings (processor, memory, heat), the chip core by core, memory, network,
/// and in Monorail the apps using the processor most.
struct SystemPage: View {
    let onBack: () -> Void
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var moments = MomentsWatch.shared
    @ObservedObject private var power = PowerWatch.shared
    @State private var contentHeight: CGFloat = 480

    private var heatShare: Double { [0.35, 0.6, 0.85, 1][moments.heat.rawValue] }

    var body: some View {
        let m = system.memory
        let memoryTone: Color = m.level == .low ? Tone.blue : m.level == .medium ? Tone.ok : Tone.high
        let heatTone: Color = moments.heat == .normal ? Tone.good : moments.heat == .warm ? Tone.ok : Tone.high
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                PageHeader(back: Brand.name, title: "System", onBack: onBack)
                HStack(spacing: 14) {
                    Rings3(values: [system.total / 100, m.pressure, heatShare], colors: [Tone.good, memoryTone, heatTone], size: 96, width: 9)
                    VStack(alignment: .leading, spacing: 7) {
                        RingLegend(color: Tone.good, label: "PROCESSOR", value: "\(Int(system.total.rounded()))%",
                                   note: "\(system.performance.count + system.efficiency.count) cores")
                        RingLegend(color: memoryTone, label: "MEMORY", value: SystemStats.gigabytes(m.used),
                                   note: "pressure \(m.level.rawValue)", delay: 0.09)
                        RingLegend(color: heatTone, label: "HEAT", value: moments.heat.title, note: "", delay: 0.18)
                    }
                    Spacer(minLength: 0)
                }
                .tile(padding: 12)
                ChipView(name: system.chipName, performance: system.performance, efficiency: system.efficiency)
                memoryCard(m)
                if !Edition.isAppStore { processesCard }
                SystemDetailCards()
                HStack {
                    Text("Every core over the last few minutes").font(.system(size: 11)).foregroundStyle(.tertiary)
                    Spacer()
                    Button("Open Live View") { LiveWindow.shared.show() }.controlSize(.small)
                }
            }
            .padding(12)
            .background(GeometryReader { proxy in Color.clear.preference(key: SystemPageHeight.self, value: proxy.size.height) })
        }
        .onPreferenceChange(SystemPageHeight.self) { contentHeight = $0 }
        // As tall as its content, up to a limit; then it scrolls.
        .frame(height: min(max(contentHeight, 200), 640))
        .onAppear { system.setLive(true) }
        .onDisappear { system.setLive(false) }
    }

    private func memoryCard(_ m: SystemStats.Memory) -> some View {
        let parts: [(String, UInt64, Color)] = [("Apps", m.app, Tone.blue), ("Wired", m.wired, Color(nsColor: .systemPurple)),
                                                ("Compressed", m.compressed, Tone.ok), ("Cached", m.cached, Color.secondary),
                                                ("Free", m.free, Color.primary.opacity(0.12))]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MEMORY").font(.label).foregroundStyle(.secondary)
                Spacer()
                Text("\(SystemStats.gigabytes(m.used)) of \(SystemStats.gigabytes(m.total))").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        Rectangle().fill(part.2).frame(width: max(0, g.size.width * CGFloat(Double(part.1) / Double(max(m.total, 1))) - 2))
                    }
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 4) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(part.2).frame(width: 8, height: 8)
                        Text(part.0).font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer(minLength: 2)
                        Text(SystemStats.gigabytes(part.1)).font(.figure(11, weight: .medium))
                    }
                }
            }
        }
        .tile()
    }

    private var processesCard: some View {
        let top = power.apps.sorted { $0.use.cpuPercent > $1.use.cpuPercent }.prefix(5)
        return VStack(alignment: .leading, spacing: 6) {
            Text("USING THE PROCESSOR").font(.label).foregroundStyle(.secondary)
            if top.isEmpty { Text("Measuring…").font(.system(size: 11)).foregroundStyle(.secondary) }
            ForEach(Array(top), id: \.id) { app in
                HStack(spacing: 8) {
                    AppIconView(bundleID: app.id, size: 18)
                    Text(app.use.appName).font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    Text(String(format: "%.0f%%", app.use.cpuPercent)).font(.figure(12, weight: .semibold))
                }
            }
        }
        .tile()
        .onAppear { power.setLive(true) }
        .onDisappear { power.setLive(false) }
    }
}

private struct SystemPageHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The small System widget on Home: processor and memory at a glance; opens the System page.
struct SystemWidget: View {
    let open: () -> Void
    @ObservedObject private var system = SystemWatch.shared

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(title: "SYSTEM", symbol: "cpu", tint: Tone.blue)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(system.total.rounded()))%").font(.figure(22))
                    Text("processor").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                Text("Memory \(system.memory.level.rawValue)").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .tile()
        }
        .buttonStyle(PressStyle())
        .onAppear { system.setLive(true) }
        .onDisappear { system.setLive(false) }
        .accessibilityLabel(Text("System: processor \(Int(system.total.rounded())) percent. Opens the System page"))
    }
}
/// Home's network card: speed now, and whether a VPN is on; opens the Network page.
struct NetworkWidget: View {
    let open: () -> Void
    @ObservedObject private var system = SystemWatch.shared

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(title: "NETWORK", symbol: "network", tint: Color(nsColor: .systemTeal))
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Image(systemName: "arrow.down").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    Text(SystemStats.speed(system.down)).font(.figure(17))
                }
                HStack(spacing: 6) {
                    Text("↑ \(SystemStats.speed(system.up))")
                    if system.vpn { Text("· VPN").foregroundStyle(Tone.good) }
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .tile()
        }
        .buttonStyle(PressStyle())
        .onAppear { system.setLive(true) }
        .onDisappear { system.setLive(false) }
        .accessibilityLabel(Text("Network: down \(SystemStats.speed(system.down)), up \(SystemStats.speed(system.up)). Opens the Network page"))
    }
}
#endif
