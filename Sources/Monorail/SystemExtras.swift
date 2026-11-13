#if os(macOS)
import AppKit
import Darwin
import MonorailCore
import SwiftUI

/// More of what the Mac is doing, for the System page: how the processor's time splits, load, processes,
/// swap and paging, graphics, heat, the apps holding the most memory, and the Mac itself.
final class SystemDetails: ObservableObject {
    static let shared = SystemDetails()

    struct MemoryApp: Identifiable, Equatable {
        var id: pid_t
        var name: String
        var bytes: UInt64
        var icon: NSImage?
    }

    @Published private(set) var user: Double = 0
    @Published private(set) var system: Double = 0
    @Published private(set) var idle: Double = 100
    @Published private(set) var load: [Double] = []
    @Published private(set) var processes = 0
    @Published private(set) var swap: UInt64 = 0
    @Published private(set) var pagingPerSecond: (ins: Double, outs: Double) = (0, 0)
    @Published private(set) var gpu: Double?
    @Published private(set) var thermal: ProcessInfo.ThermalState = .nominal
    @Published private(set) var diskPerSecond: (read: Double, written: Double) = (0, 0)
    @Published private(set) var memoryApps: [MemoryApp] = []

    let model: String
    let chip: String
    let cores: (performance: Int, efficiency: Int)
    let memory: UInt64
    let macOS: String
    let booted: Date?

    private var timer: Timer?
    private var lastTicks: [SystemStats.Ticks] = []
    private var lastPaging: (ins: UInt64, outs: UInt64, at: Date)?
    private var lastDisk: (read: UInt64, written: UInt64, at: Date)?

    init() {
        model = Self.marketingName() ?? SystemWatch.sysctlString("hw.model") ?? "Mac"
        chip = SystemWatch.sysctlString("machdep.cpu.brand_string") ?? "Apple silicon"
        cores = (SystemWatch.sysctlInt("hw.perflevel0.physicalcpu") ?? SystemWatch.sysctlInt("hw.physicalcpu") ?? 0,
                 SystemWatch.sysctlInt("hw.perflevel1.physicalcpu") ?? 0)
        memory = ProcessInfo.processInfo.physicalMemory
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let build = SystemWatch.sysctlString("kern.osversion").map { " (\($0))" } ?? ""
        macOS = "macOS \(v.majorVersion).\(v.minorVersion)\(v.patchVersion > 0 ? ".\(v.patchVersion)" : "")\(build)"
        var boottime = timeval(), size = MemoryLayout<timeval>.size
        booted = sysctlbyname("kern.boottime", &boottime, &size, nil, 0) == 0 ? Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec)) : nil
    }

    func setLive(_ live: Bool) {
        timer?.invalidate(); timer = nil
        guard live else { return }
        sample()
        timer = Timer.every(2) { [weak self] _ in self?.sample() }
        timer?.tolerance = 0.4
    }

    private func sample() {
        let ticks = SystemWatch.coreTicks()
        if !lastTicks.isEmpty, lastTicks.count == ticks.count {
            var u: UInt64 = 0, s: UInt64 = 0, i: UInt64 = 0
            for (a, b) in zip(lastTicks, ticks) {
                u += (b.user &- a.user) &+ (b.nice &- a.nice); s += b.system &- a.system; i += b.idle &- a.idle
            }
            let all = Double(max(u + s + i, 1))
            user = Double(u) / all * 100; system = Double(s) / all * 100; idle = Double(i) / all * 100
        }
        lastTicks = ticks
        load = SystemWatch.loadAverage()
        swap = SystemWatch.swapUsed()
        gpu = SystemWatch.gpuUtilisation()
        thermal = ProcessInfo.processInfo.thermalState
        let now = Date()
        let paging = SystemWatch.paging()
        if let last = lastPaging {
            let t = max(now.timeIntervalSince(last.at), 0.1)
            pagingPerSecond = (Double(paging.ins &- last.ins) / t, Double(paging.outs &- last.outs) / t)
        }
        lastPaging = (paging.ins, paging.outs, now)
        let disk = SystemWatch.diskBytes()
        if let last = lastDisk {
            let t = max(now.timeIntervalSince(last.at), 0.1)
            diskPerSecond = (Double(disk.read &- last.read) / t, Double(disk.written &- last.written) / t)
        }
        lastDisk = (disk.read, disk.written, now)
        processes = Self.processCount()
        if !Edition.isAppStore { memoryApps = Self.topMemoryApps() }
    }

    static func processCount() -> Int {
        let count = proc_listallpids(nil, 0)
        return max(Int(count), 0)
    }

    /// The apps using the most memory: each app's own memory footprint (what Activity Monitor calls Memory).
    static func topMemoryApps(limit: Int = 6) -> [MemoryApp] {
        var list: [MemoryApp] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            var info = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(app.processIdentifier, RUSAGE_INFO_V4, $0) }
            }
            guard result == 0 else { continue }
            list.append(MemoryApp(id: app.processIdentifier, name: app.localizedName ?? "App", bytes: info.ri_phys_footprint, icon: app.icon))
        }
        return Array(list.sorted { $0.bytes > $1.bytes }.prefix(limit))
    }

    /// "MacBook Pro (14-inch, 2024)" from the system's own list, when it has one.
    static func marketingName() -> String? {
        let url = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/ServerInformation.framework/Resources/en.lproj/SIMachineAttributes.plist")
        guard let model = SystemWatch.sysctlString("hw.model"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let entry = dict[model] as? [String: Any],
              let localized = entry["_LOCALIZABLE_"] as? [String: Any],
              let name = localized["marketingModel"] as? String else { return nil }
        return name
    }

    var thermalWords: (String, Color) {
        switch thermal {
        case .nominal: return ("Cool", Tone.good)
        case .fair: return ("Warm", Tone.ok)
        case .serious: return ("Hot: slowing down to cool", Tone.high)
        case .critical: return ("Very hot: slowed right down", Tone.high)
        @unknown default: return ("–", .secondary)
        }
    }
}

/// The extra cards on the System page.
struct SystemDetailCards: View {
    @ObservedObject private var details = SystemDetails.shared
    @ObservedObject private var watch = SystemWatch.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            processorCard
            memoryMoreCard
            if !Edition.isAppStore, !details.memoryApps.isEmpty { memoryAppsCard }
            macCard
        }
        .onAppear { details.setLive(true) }
        .onDisappear { details.setLive(false) }
    }

    private var processorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PROCESSOR TIME").font(.label).foregroundStyle(.secondary)
                Spacer()
                if let gpu = details.gpu { Text("Graphics \(Int(gpu.rounded()))%").font(.system(size: 11, weight: .medium)).foregroundStyle(Color(nsColor: .systemPurple)) }
            }
            GeometryReader { g in
                HStack(spacing: 2) {
                    Rectangle().fill(Tone.blue).frame(width: max(0, g.size.width * details.user / 100 - 1))
                    Rectangle().fill(Tone.high).frame(width: max(0, g.size.width * details.system / 100 - 1))
                    Rectangle().fill(Color.primary.opacity(0.1))
                }
            }
            .frame(height: 10).clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            HStack(spacing: 12) {
                legend(Tone.blue, "Apps", details.user)
                legend(Tone.high, "macOS", details.system)
                legend(Color.primary.opacity(0.25), "Idle", details.idle)
            }
            TrendChart(values: watch.totalHistory, maximum: 100, colour: Tone.good, height: 40).allowsHitTesting(false)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                stat("Load (1, 5, 15 min)", details.load.map { String(format: "%.1f", $0) }.joined(separator: " · "))
                stat("Processes", "\(details.processes)")
                stat("Heat", details.thermalWords.0, tint: details.thermalWords.1)
                stat("Disk read", SystemStats.speed(details.diskPerSecond.read))
                stat("Disk write", SystemStats.speed(details.diskPerSecond.written))
                stat("Cores", "\(details.cores.performance) P\(details.cores.efficiency > 0 ? " + \(details.cores.efficiency) E" : "")")
            }
            let busy = details.load.first.map { $0 / Double(max(details.cores.performance + details.cores.efficiency, 1)) } ?? 0
            if busy > 1 {
                Text("More work is waiting than there are cores to do it: things may feel slow until it clears.")
                    .font(.system(size: 11)).foregroundStyle(Tone.ok).fixedSize(horizontal: false, vertical: true)
            }
        }
        .tile()
    }

    private var memoryMoreCard: some View {
        let swapping = details.pagingPerSecond.outs > 50
        return VStack(alignment: .leading, spacing: 7) {
            Text("MEMORY PRESSURE").font(.label).foregroundStyle(.secondary)
            TrendChart(values: SystemRecorder.shared.history.samples(.hours12).map(\.memory).suffix(60).map { $0 }, maximum: 100, colour: Color(nsColor: .systemBlue), height: 40)
                .allowsHitTesting(false)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                stat("Swap used", SystemStats.gigabytes(details.swap), tint: details.swap > 4_000_000_000 ? Tone.ok : nil)
                stat("Swapping in", "\(Int(details.pagingPerSecond.ins))/s")
                stat("Swapping out", "\(Int(details.pagingPerSecond.outs))/s", tint: swapping ? Tone.ok : nil)
            }
            Text(swapping ? "The Mac is writing memory to disk right now: quitting a big app will help."
                 : details.swap > 4_000_000_000 ? "A lot is in swap. A restart clears it." : "Swap is memory the Mac moves to disk when RAM runs short.")
                .font(.system(size: 11)).foregroundStyle(swapping ? Tone.ok : .secondary).fixedSize(horizontal: false, vertical: true)
        }
        .tile()
    }

    private var memoryAppsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("USING THE MOST MEMORY").font(.label).foregroundStyle(.secondary)
            ForEach(details.memoryApps) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                    Text(app.name).font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    Text(SystemStats.gigabytes(app.bytes)).font(.figure(12, weight: .semibold))
                }
            }
        }
        .tile()
    }

    private var macCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THIS MAC").font(.label).foregroundStyle(.secondary)
            Text(details.model).font(.system(size: 13, weight: .semibold))
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                stat("Chip", details.chip.replacingOccurrences(of: "Apple ", with: ""))
                stat("Memory", SystemStats.gigabytes(details.memory))
                stat("macOS", details.macOS.replacingOccurrences(of: "macOS ", with: ""))
                stat("Up for", SystemStats.uptime(watch.uptime))
                if let booted = details.booted { stat("Started", booted.formatted(date: .abbreviated, time: .shortened)) }
                if let ip = watch.localIP { stat("IP address", ip) }
            }
            if SystemStats.suggestsRestart(uptime: watch.uptime) {
                Text("It's been a while since your Mac restarted; a restart can free memory and finish updates.")
                    .font(.system(size: 11)).foregroundStyle(Tone.ok).fixedSize(horizontal: false, vertical: true)
            }
        }
        .tile()
    }

    private func legend(_ colour: Color, _ label: String, _ value: Double) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(colour).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text("\(Int(value.rounded()))%").font(.figure(11, weight: .semibold))
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
            Text(value.isEmpty ? "–" : value).font(.system(size: 11.5, weight: .medium)).foregroundStyle(tint ?? .primary).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}
#endif
