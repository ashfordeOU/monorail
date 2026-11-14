#if os(macOS)
import AppKit
import IOKit.ps
import MonorailCore
import SwiftUI
import UserNotifications

/// Live readings in the menu bar, next to the icon: the ones chosen in Settings, in a compact line
/// ("CPU 12%  MEM 61%  ↓1.2 MB/s  82%"), turning red under strain. Clicking it opens the Dashboard.
final class MenuBarReadings {
    static let shared = MenuBarReadings()
    static let all: [(id: String, title: String)] = [("cpu", "CPU"), ("memory", "Memory"), ("gpu", "GPU"), ("network", "Network"), ("disk", "Disk"), ("battery", "Battery"), ("ai", "AI limit")]

    private var item: NSStatusItem?
    private var timer: Timer?
    private var chosen: [String] = []
    private var last: (ticks: [SystemStats.Ticks], net: (UInt64, UInt64), disk: (UInt64, UInt64), at: Date)?

    func apply(_ readings: [String]) {
        chosen = readings.filter { id in Self.all.contains { $0.id == id } }
        if chosen.isEmpty {
            timer?.invalidate(); timer = nil
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            return
        }
        if item == nil {
            let made = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            made.button?.target = self
            made.button?.action = #selector(open)
            made.button?.toolTip = "Open the Dashboard"
            item = made
        }
        if timer == nil {
            update()
            timer = Timer.every(3) { [weak self] _ in self?.update() }
            timer?.tolerance = 1
        }
    }

    @objc private func open() { DashboardWindow.shared.show() }

    /// A small ring gauge, orange (red under strain), drawn as a template-free image so it stays coloured.
    static func ring(_ fraction: Double, strained: Bool, help: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let inset = rect.insetBy(dx: 1.5, dy: 1.5)
            let track = NSBezierPath(ovalIn: inset)
            track.lineWidth = 2.2
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            track.stroke()
            let arc = NSBezierPath()
            let f = min(max(fraction, 0), 1)
            arc.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY), radius: inset.width / 2, startAngle: 90, endAngle: 90 - 360 * f, clockwise: true)
            arc.lineWidth = 2.2
            arc.lineCapStyle = .round
            (strained ? NSColor.systemRed : NSColor.systemOrange).setStroke()
            arc.stroke()
            return true
        }
        image.accessibilityDescription = help
        return image
    }

    private func update() {
        let now = Date()
        let ticks = SystemWatch.coreTicks()
        let (down, up, _, _) = SystemWatch.network()
        let disk = SystemWatch.diskBytes()
        defer { last = (ticks, (down, up), disk, now) }
        guard let last, let button = item?.button else { return }
        let seconds = now.timeIntervalSince(last.at)
        let text = NSMutableAttributedString()
        func add(_ label: String, _ value: String, strained: Bool, ring: Double? = nil) {
            if text.length > 0 { text.append(NSAttributedString(string: "  ")) }
            if let ring {
                let attachment = NSTextAttachment()
                attachment.image = Self.ring(ring, strained: strained, help: label)
                attachment.bounds = NSRect(x: 0, y: -2, width: 12, height: 12)
                text.append(NSAttributedString(attachment: attachment))
                text.append(NSAttributedString(string: " "))
                text.append(NSAttributedString(string: value, attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: strained ? NSColor.systemRed : NSColor.labelColor]))
                return
            }
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            text.append(NSAttributedString(string: label.isEmpty ? "" : label + " ", attributes: [.font: NSFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor]))
            text.append(NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: strained ? NSColor.systemRed : NSColor.labelColor]))
        }
        for id in chosen {
            switch id {
            case "cpu":
                let cpu = SystemStats.average(SystemStats.load(previous: last.ticks, now: ticks))
                add("CPU", "\(Int(cpu.rounded()))%", strained: cpu > 85, ring: cpu / 100)
            case "memory":
                let pressure = (SystemWatch.memoryNow()?.pressure ?? 0) * 100
                add("MEM", "\(Int(pressure.rounded()))%", strained: pressure > 90, ring: pressure / 100)
            case "gpu":
                if let gpu = SystemWatch.gpuUtilisation() { add("GPU", "\(Int(gpu.rounded()))%", strained: gpu > 90, ring: gpu / 100) }
            case "network":
                add("", "↓\(SystemStats.speed(SystemStats.rate(from: last.net.0, to: down, seconds: seconds))) ↑\(SystemStats.speed(SystemStats.rate(from: last.net.1, to: up, seconds: seconds)))", strained: false)
            case "disk":
                add("DISK", SystemStats.speed(SystemStats.rate(from: last.disk.1, to: disk.written, seconds: seconds)), strained: false)
            case "battery":
                if PowerWatch.hasBattery {
                    let b = PowerWatch.shared.battery
                    add(b.isCharging ? "⚡︎" : "", "\(b.percent)%", strained: b.onBattery && b.percent <= 10)
                }
            case "ai":
                if let top = AIUsageWatch.shared.headline {
                    add(String(top.account.label.uppercased().prefix(8)), "\(Int(top.window.usedPercent.rounded()))%", strained: top.window.usedPercent >= 90)
                }
            default: break
            }
        }
        button.attributedTitle = text
    }

    // MARK: Charger

    /// The power adapter's rating, when one is connected ("96 W").
    static func chargerWatts() -> Int? {
        guard let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] else { return nil }
        return details[kIOPSPowerAdapterWattsKey] as? Int
    }
}

/// Notifications when the Mac strains: memory pressure stays high, swap gets heavy, or (Monorail) an
/// app keeps the processor busy for minutes. Once an hour per kind at most.
final class SystemAlerts {
    static let shared = SystemAlerts()
    var enabled: () -> Bool = { true }
    private var lastSent: [String: Date] = [:]
    private var busy: [String: Int] = [:]

    func check(_ sample: SystemHistory.Sample) {
        guard enabled(), !SuiteRole.shared.quiet(.alertSystem) else { return }
        if sample.memory >= 92 { send("memory", "Memory is nearly full", "Apps may slow down. The Dashboard shows which ones use the most.") }
        if sample.swapGB >= 8 { send("swap", "Your Mac is swapping heavily", String(format: "%.1f GB in swap. Quitting a big app or restarting will speed things up.", sample.swapGB)) }
        guard !Edition.isAppStore else { return }
        // An app above 90% of a core for five minutes in a row (samples are a minute apart).
        let hot = Set(PowerWatch.shared.apps.filter { $0.use.cpuPercent >= 90 }.map(\.id))
        for id in Array(busy.keys) where !hot.contains(id) { busy[id] = nil }
        for app in PowerWatch.shared.apps where hot.contains(app.id) {
            busy[app.id, default: 0] += 1
            if busy[app.id] == 5 { send("app-\(app.id)", "\(app.use.appName) has been busy for 5 minutes", String(format: "About %.0f%% of a core. It may be stuck; the Dashboard can quit it.", app.use.cpuPercent)) }
        }
    }

    private func send(_ kind: String, _ title: String, _ body: String) {
        if let last = lastSent[kind], Date().timeIntervalSince(last) < 3600 { return }
        lastSent[kind] = Date()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

/// Readings pinned from the Dashboard, on Home: each with its last hour.
struct PinnedReadings: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject private var recorder = SystemRecorder.shared

    static let titles: [String: String] = ["cpu": "CPU", "memory": "Memory", "swap": "Swap", "gpu": "GPU", "down": "Download", "write": "Disk writes", "battery": "Battery"]

    static func values(_ id: String, _ samples: [SystemHistory.Sample]) -> [Double] {
        switch id {
        case "cpu": return samples.map(\.cpu)
        case "memory": return samples.map(\.memory)
        case "swap": return samples.map(\.swapGB)
        case "gpu": return samples.compactMap(\.gpu)
        case "down": return samples.map(\.downBytes)
        case "write": return samples.map(\.writeBytes)
        case "battery": return samples.compactMap { $0.battery.map(Double.init) }
        default: return []
        }
    }

    static func text(_ id: String, _ value: Double) -> String {
        switch id {
        case "swap": return String(format: "%.1f GB", value)
        case "down", "write": return SystemStats.speed(value)
        default: return "\(Int(value.rounded()))%"
        }
    }

    var body: some View {
        if !store.settings.homePins.isEmpty {
            let hour = Array(recorder.history.samples(.hours12).suffix(60))
            VStack(alignment: .leading, spacing: 8) {
                CardTitle(title: "PINNED", symbol: "pin.fill", tint: Color(nsColor: .systemOrange), opens: true)
                ForEach(store.settings.homePins, id: \.self) { id in
                    let values = Self.values(id, hour)
                    HStack(spacing: 10) {
                        Text(Self.titles[id] ?? id).font(.system(size: 12)).frame(width: 80, alignment: .leading)
                        TrendChart(values: values, colour: Color(nsColor: .systemOrange), height: 22).allowsHitTesting(false)
                        Text(values.last.map { Self.text(id, $0) } ?? "–").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                            .frame(width: 72, alignment: .trailing)
                    }
                }
            }
            .tile()
            .contentShape(Rectangle())
            .onTapGesture { DashboardWindow.shared.show() }
        }
    }
}

/// The ☆ on a Dashboard chart: pins it to Home, or unpins it.
struct PinButton: View {
    let id: String
    var body: some View {
        if let store = DashboardContext.store {
            PinToggle(id: id, store: store)
        }
    }

    private struct PinToggle: View {
        let id: String
        @ObservedObject var store: SettingsStore
        var body: some View {
            let pinned = store.settings.homePins.contains(id)
            Button {
                if pinned { store.settings.homePins.removeAll { $0 == id } } else { store.settings.homePins.append(id) }
            } label: {
                Label(pinned ? "Pinned" : "Pin to Home", systemImage: pinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(pinned ? 0.18 : 0.08)))
            }
            .buttonStyle(.plain)
        }
    }
}
#endif
