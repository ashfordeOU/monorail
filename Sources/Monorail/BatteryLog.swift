#if os(macOS)
import AppKit
import IOKit
import MonorailCore
import SwiftUI
import UserNotifications

/// Keeps the battery journal: health once a day, each charge, and the drain over each sleep.
/// Also reads Bluetooth accessories' batteries and says once when one runs low. All on this Mac.
final class BatteryLog: ObservableObject {
    static let shared = BatteryLog()

    @Published private(set) var journal = BatteryJournal()
    @Published private(set) var accessories: [AccessoryBattery] = []

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var charging: (start: Date, from: Int)?
    private var slept: (at: Date, percent: Int)?
    private var file: URL { SettingsStore.directory.appendingPathComponent("battery-journal.json") }

    static let model: String = {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &bytes, &size, nil, 0)
        return String(cString: bytes)
    }()

    func start() {
        guard timer == nil else { return }
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(BatteryJournal.self, from: data) { journal = saved }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard PowerWatch.hasBattery else { return }
            self?.slept = (Date(), PowerWatch.shared.battery.percent)
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            // The battery reading settles a few seconds after waking.
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { self?.woke() }
        })
        timer = Timer.every(120) { [weak self] _ in self?.tick() }
        timer?.tolerance = 30
        tick()
    }

    private func woke() {
        guard let slept, PowerWatch.hasBattery else { return }
        self.slept = nil
        let b = PowerWatch.shared.battery
        // A night on the charger says nothing about drain.
        guard b.onBattery, !b.isCharging else { return }
        journal.record(BatteryJournal.Night(slept: slept.at, woke: Date(), from: slept.percent, to: b.percent))
        save()
    }

    private func tick() {
        readAccessories()
        guard PowerWatch.hasBattery else { return }
        let b = PowerWatch.shared.battery
        if let capacity = b.capacityPercent {
            let before = journal.health.last?.day
            journal.record(capacity: capacity, cycles: b.cycleCount, on: Date())
            if journal.health.last?.day != before { save() }
        }
        if b.isCharging {
            if charging == nil { charging = (Date(), b.percent) }
        } else if let started = charging {
            charging = nil
            journal.record(BatteryJournal.Charge(start: started.start, end: Date(), from: started.from, to: b.percent))
            save()
        }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(journal) { try? data.write(to: file, options: .atomic) }
    }

    // MARK: Accessories

    private func readAccessories() {
        var found: [AccessoryBattery] = []
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            if let percent = property("BatteryPercent") as? Int, let name = property("Product") as? String,
               !found.contains(where: { $0.name == name }) {
                found.append(AccessoryBattery(name: name, percent: percent))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        found.sort { $0.name < $1.name }
        for low in AccessoryBattery.newlyLow(found, before: accessories) {
            notify("\(low.name) is at \(low.percent)%", "Charge it soon so it doesn't cut out.")
        }
        if found != accessories { accessories = found }
    }

    private func notify(_ title: String, _ body: String) {
        guard !SuiteRole.shared.pauses(.notifications) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    // MARK: Report

    var report: String {
        let b = PowerWatch.shared.battery
        return journal.report(model: Self.model, percent: b.percent, capacity: b.capacityPercent, cycles: b.cycleCount)
    }

    func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    func saveReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Battery report.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? report.write(to: url, atomically: true, encoding: .utf8)
    }
}

private let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

/// Health now, how fast it's falling and when it reaches 80%, with a small trend line and the report.
struct BatteryHealthCard: View {
    @ObservedObject private var log = BatteryLog.shared
    @ObservedObject private var power = PowerWatch.shared

    var body: some View {
        let j = log.journal
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Battery health").font(.callout.weight(.semibold))
                Spacer()
                Text(power.battery.capacityPercent.map { "\($0)%" } ?? "–").font(.callout.weight(.semibold)).monospacedDigit()
            }
            if j.health.count >= 2 {
                HealthLine(points: j.health.suffix(180).map(\.capacity)).frame(height: 34)
            }
            Text(summary(j)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button("Copy Report") { log.copyReport() }.controlSize(.small)
                Button("Save Report…") { log.saveReport() }.controlSize(.small)
                Spacer()
                if let charge = j.charges.last {
                    Text("Last charge \(charge.from)→\(charge.to)% · \(charge.minutes) min").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10).background(cardShape.fill(Color.primary.opacity(0.06)))
    }

    private func summary(_ j: BatteryJournal) -> String {
        var parts: [String] = []
        if let cycles = power.battery.cycleCount { parts.append("\(cycles) cycles") }
        if let loss = j.lossPerMonth {
            parts.append(String(format: "losing %.1f%% a month", loss))
            if let months = j.monthsTo80 { parts.append(months == 0 ? "Apple suggests service below 80%" : "about \(months) months to 80%") }
        } else {
            parts.append("The trend appears after two weeks")
        }
        return parts.joined(separator: " · ")
    }
}

private struct HealthLine: View {
    let points: [Int]
    var body: some View {
        GeometryReader { geo in
            let lo = Double((points.min() ?? 80) - 1), hi = Double((points.max() ?? 100) + 1)
            Path { path in
                for (i, p) in points.enumerated() {
                    let x = geo.size.width * Double(i) / Double(max(points.count - 1, 1))
                    let y = geo.size.height * (1 - (Double(p) - lo) / max(hi - lo, 1))
                    i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color(nsColor: .systemGreen), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .accessibilityLabel(Text("Battery health trend"))
    }
}

/// The last week of sleeps: how much each one cost, and a nudge when sleep is draining too much.
struct SleepDrainCard: View {
    @ObservedObject private var log = BatteryLog.shared

    var body: some View {
        let nights = Array(log.journal.nights.suffix(7))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Overnight drain").font(.callout.weight(.semibold))
                Spacer()
                if let typical = log.journal.typicalNightDrain {
                    Text(String(format: "%.1f%%/hr", typical)).font(.callout.weight(.semibold)).monospacedDigit()
                }
            }
            if nights.isEmpty {
                Text("Fills in after the Mac sleeps on battery.").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(nights.enumerated()), id: \.offset) { _, night in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(night.isHeavy ? Color(nsColor: .systemOrange) : Color(nsColor: .systemIndigo))
                                .frame(height: max(4, min(CGFloat(night.lost) * 3, 40)))
                            Text(night.woke.formatted(.dateTime.weekday(.narrow))).font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .help("\(night.lost)% over \(String(format: "%.1f", night.hours)) hours")
                    }
                }
                .frame(height: 54, alignment: .bottom)
                if nights.contains(where: \.isHeavy) {
                    Text("Some nights lost more than usual. Unplugging accessories and closing apps that keep the Mac awake helps.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10).background(cardShape.fill(Color.primary.opacity(0.06)))
    }
}

/// Mouse, keyboard, trackpad and other Bluetooth batteries.
struct AccessoriesCard: View {
    @ObservedObject private var log = BatteryLog.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Accessories").font(.callout.weight(.semibold))
            if log.accessories.isEmpty {
                Text("Connected mice, keyboards and trackpads show here.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(log.accessories) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.symbol).frame(width: 18).foregroundStyle(.secondary)
                    Text(item.name).font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    ProgressView(value: Double(item.percent), total: 100).frame(width: 60)
                        .tint(item.percent <= 15 ? Color(nsColor: .systemRed) : Color(nsColor: .systemGreen))
                    Text("\(item.percent)%").font(.system(size: 12, weight: .semibold)).monospacedDigit().frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(10).background(cardShape.fill(Color.primary.opacity(0.06)))
    }
}
#endif
