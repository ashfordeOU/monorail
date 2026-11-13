#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// Live: a window that watches the Mac as it works. The chip core by core, load over the last
/// few minutes, network, memory and (in Monorail) the apps doing the work.
final class LiveWindow {
    static let shared = LiveWindow()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Live"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 520)
        window.contentView = NSHostingView(rootView: LiveView())
        window.center()
        window.setFrameAutosaveName("MonorailLive")
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct LiveView: View {
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var power = PowerWatch.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Live").font(.system(size: 20, weight: .bold))
                    Text(system.chipName).font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Text("Up \(SystemStats.uptime(system.uptime))").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 12) {
                    card("YOUR CHIP") {
                        ChipView(name: system.chipName, performance: system.performance, efficiency: system.efficiency)
                    }
                    .frame(width: 330)
                    VStack(spacing: 12) {
                        card("PROCESSOR · \(Int(system.total.rounded()))%") {
                            AreaChart(values: system.totalHistory, maximum: 100, colour: Color(nsColor: .systemGreen)).frame(height: 70)
                        }
                        card("NETWORK · ↓ \(SystemStats.speed(system.down))  ↑ \(SystemStats.speed(system.up))") {
                            let peak = max((system.downHistory + system.upHistory).max() ?? 1, 1)
                            ZStack {
                                AreaChart(values: system.downHistory, maximum: peak, colour: Color(nsColor: .systemBlue))
                                AreaChart(values: system.upHistory, maximum: peak, colour: Color(nsColor: .systemPurple))
                            }
                            .frame(height: 70)
                        }
                    }
                }
                card("EACH CORE") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(Array(system.coreHistory.enumerated()), id: \.offset) { index, history in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(index < system.performance.count ? "P\(index + 1)" : "E\(index - system.performance.count + 1)")
                                    Spacer()
                                    Text("\(Int((history.last ?? 0).rounded()))%").monospacedDigit()
                                }
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                                AreaChart(values: history, maximum: 100, colour: loadColour(history.last ?? 0)).frame(height: 30)
                            }
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                        }
                    }
                }
                card("MEMORY · \(system.memory.level.rawValue.uppercased())") {
                    let m = system.memory, total = Double(max(m.total, 1))
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                segment(Double(m.app) / total, .systemBlue, geo.size.width)
                                segment(Double(m.wired) / total, .systemPurple, geo.size.width)
                                segment(Double(m.compressed) / total, .systemOrange, geo.size.width)
                                segment(Double(m.cached) / total, .systemGray, geo.size.width)
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(height: 14)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.08)))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        HStack(spacing: 14) {
                            legend("Apps", m.app, .systemBlue); legend("Wired", m.wired, .systemPurple)
                            legend("Compressed", m.compressed, .systemOrange); legend("Cached", m.cached, .systemGray)
                        }
                    }
                }
                if !Edition.isAppStore {
                    card("WHAT'S RUNNING") {
                        let apps = power.apps.sorted { $0.use.cpuPercent > $1.use.cpuPercent }.prefix(10)
                        VStack(spacing: 0) {
                            HStack {
                                Text("App"); Spacer(); Text("Processor").frame(width: 90, alignment: .trailing); Text("Battery").frame(width: 110, alignment: .trailing)
                            }
                            .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.tertiary).padding(.bottom, 4)
                            ForEach(Array(apps), id: \.id) { app in
                                HStack {
                                    AppIconView(bundleID: app.id, size: 18)
                                    Text(app.use.appName).font(.system(size: 12)).lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.0f%%", app.use.cpuPercent)).monospacedDigit().frame(width: 90, alignment: .trailing)
                                    Text(app.use.percentPerHour.map { String(format: "%.1f%%/hr", $0) } ?? "–").monospacedDigit().frame(width: 110, alignment: .trailing)
                                }
                                .font(.system(size: 12))
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear { system.setLive(true); power.setLive(true) }
        .onDisappear { system.setLive(false); power.setLive(false) }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
    }

    private func segment(_ share: Double, _ colour: NSColor, _ width: CGFloat) -> some View {
        Rectangle().fill(Color(nsColor: colour)).frame(width: max(0, width * share))
    }

    private func legend(_ name: String, _ bytes: UInt64, _ colour: NSColor) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: colour)).frame(width: 8, height: 8)
            Text("\(name) \(SystemStats.gigabytes(bytes))").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private func loadColour(_ load: Double) -> Color {
        Color(nsColor: load < 40 ? .systemGreen : load < 75 ? .systemYellow : .systemRed)
    }
}

/// A filled line over the last few minutes, newest on the right.
struct AreaChart: View {
    let values: [Double]
    let maximum: Double
    let colour: Color

    var body: some View {
        GeometryReader { geo in
            let n = SystemWatch.historyLength
            let step = geo.size.width / CGFloat(max(n - 1, 1))
            let offset = CGFloat(n - values.count) * step
            let point = { (i: Int, v: Double) in CGPoint(x: offset + CGFloat(i) * step, y: geo.size.height * (1 - CGFloat(min(v / max(maximum, 0.0001), 1)))) }
            ZStack {
                Path { p in
                    guard !values.isEmpty else { return }
                    p.move(to: CGPoint(x: offset, y: geo.size.height))
                    for (i, v) in values.enumerated() { p.addLine(to: point(i, v)) }
                    p.addLine(to: CGPoint(x: offset + CGFloat(values.count - 1) * step, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(colour.opacity(0.18))
                Path { p in
                    for (i, v) in values.enumerated() { i == 0 ? p.move(to: point(i, v)) : p.addLine(to: point(i, v)) }
                }
                .stroke(colour, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
#endif
