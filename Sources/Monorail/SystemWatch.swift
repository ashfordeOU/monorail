#if os(macOS)
import AppKit
import Darwin
import IOKit
import MonorailCore

/// Reads the processor (per core), memory and network for the System page, only while it's on
/// screen. Everything here is allowed in Signalbox's sandbox too.
final class SystemWatch: ObservableObject {
    static let shared = SystemWatch()

    @Published private(set) var performance: [Double] = []
    @Published private(set) var efficiency: [Double] = []
    @Published private(set) var total: Double = 0
    @Published private(set) var memory = SystemStats.Memory(total: 0, app: 0, wired: 0, compressed: 0, cached: 0)
    @Published private(set) var down: Double = 0
    @Published private(set) var up: Double = 0
    @Published private(set) var localIP: String?
    @Published private(set) var vpn = false
    @Published private(set) var speedTest: String?
    @Published private(set) var testing = false
    /// The last few minutes, for the Live window: total load, each core, and network down and up.
    @Published private(set) var totalHistory: [Double] = []
    @Published private(set) var coreHistory: [[Double]] = []
    @Published private(set) var downHistory: [Double] = []
    @Published private(set) var upHistory: [Double] = []
    static let historyLength = 120

    let chipName: String = SystemWatch.sysctlString("machdep.cpu.brand_string") ?? "Your Mac"
    var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private var timer: Timer?
    private var users = 0
    private var lastTicks: [SystemStats.Ticks] = []
    private var lastBytes: (down: UInt64, up: UInt64, at: Date)?

    /// Pages that show live figures call this on appear (true) and disappear (false).
    func setLive(_ live: Bool) {
        users = max(0, users + (live ? 1 : -1))
        if users > 0, timer == nil {
            sample()
            timer = Timer.every(1.5) { [weak self] _ in self?.sample() }
        } else if users == 0 {
            timer?.invalidate()
            timer = nil
        }
    }

    private func sample() {
        let ticks = Self.coreTicks()
        if !lastTicks.isEmpty, lastTicks.count == ticks.count {
            let loads = SystemStats.load(previous: lastTicks, now: ticks)
            let p = Self.sysctlInt("hw.perflevel0.logicalcpu") ?? loads.count
            let split = SystemStats.split(loads, performance: p)
            performance = split.performance
            efficiency = split.efficiency
            total = SystemStats.average(loads)
            Self.push(total, onto: &totalHistory)
            if coreHistory.count != loads.count { coreHistory = Array(repeating: [], count: loads.count) }
            for (i, load) in loads.enumerated() { Self.push(load, onto: &coreHistory[i]) }
        }
        lastTicks = ticks
        if let m = Self.memoryNow() { memory = m }
        let (d, u, ip, vpnOn) = Self.network()
        let now = Date()
        if let last = lastBytes {
            let seconds = now.timeIntervalSince(last.at)
            down = SystemStats.rate(from: last.down, to: d, seconds: seconds)
            up = SystemStats.rate(from: last.up, to: u, seconds: seconds)
            Self.push(down, onto: &downHistory)
            Self.push(up, onto: &upHistory)
        }
        lastBytes = (d, u, now)
        localIP = ip
        vpn = vpnOn
    }

    private static func push(_ value: Double, onto list: inout [Double]) {
        list.append(value)
        if list.count > historyLength { list.removeFirst(list.count - historyLength) }
    }

    /// Downloads 25 MB from Cloudflare's speed test and reports megabits per second.
    func runSpeedTest() {
        guard !testing, let url = URL(string: "https://speed.cloudflare.com/__down?bytes=25000000") else { return }
        testing = true
        speedTest = nil
        let start = Date()
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            let seconds = Date().timeIntervalSince(start)
            DispatchQueue.main.async {
                guard let self else { return }
                self.testing = false
                if let data, error == nil {
                    self.speedTest = String(format: "%.0f Mbps down", SystemStats.megabits(bytes: data.count, seconds: seconds))
                } else {
                    self.speedTest = "Couldn't reach the test server"
                }
            }
        }.resume()
    }

    // MARK: Reading the system

    static func coreTicks() -> [SystemStats.Ticks] {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
            let info else { return [] }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }
        var result: [SystemStats.Ticks] = []
        for core in 0..<Int(count) {
            let base = core * Int(CPU_STATE_MAX)
            func tick(_ state: Int32) -> UInt64 { UInt64(UInt32(bitPattern: info[base + Int(state)])) }
            result.append(SystemStats.Ticks(user: tick(CPU_STATE_USER), system: tick(CPU_STATE_SYSTEM),
                                            idle: tick(CPU_STATE_IDLE), nice: tick(CPU_STATE_NICE)))
        }
        return result
    }

    static func memoryNow() -> SystemStats.Memory? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        return SystemStats.Memory.fromPages(pageSize: UInt64(vm_kernel_page_size), total: ProcessInfo.processInfo.physicalMemory,
                                            internalPages: UInt64(stats.internal_page_count), purgeable: UInt64(stats.purgeable_count),
                                            wired: UInt64(stats.wire_count), compressed: UInt64(stats.compressor_page_count),
                                            external: UInt64(stats.external_page_count))
    }

    /// Total bytes in and out on every interface but loopback, the Mac's own address, and whether a VPN is up.
    static func network() -> (UInt64, UInt64, String?, Bool) {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else { return (0, 0, nil, false) }
        defer { freeifaddrs(first) }
        var down: UInt64 = 0, up: UInt64 = 0
        var ip: String?, vpn = false
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = pointer {
            let name = String(cString: entry.pointee.ifa_name)
            if let address = entry.pointee.ifa_addr {
                let family = Int32(address.pointee.sa_family)
                if family == AF_LINK, !name.hasPrefix("lo"), let data = entry.pointee.ifa_data {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    down += UInt64(stats.ifi_ibytes)
                    up += UInt64(stats.ifi_obytes)
                } else if family == AF_INET {
                    if (name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")) { vpn = true }
                    if ip == nil, name.hasPrefix("en") {
                        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                            ip = String(cString: host)
                        }
                    }
                }
            }
            pointer = entry.pointee.ifa_next
        }
        return (down, up, ip, vpn)
    }

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? Int(value) : nil
    }
}

// MARK: - More readings for the Dashboard

extension SystemWatch {
    /// Swap in use, in bytes.
    static func swapUsed() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }

    /// Pages read from and written to swap since start-up.
    static func paging() -> (ins: UInt64, outs: UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        return (UInt64(stats.swapins), UInt64(stats.swapouts))
    }

    /// The 1, 5 and 15-minute load averages.
    static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        return getloadavg(&loads, 3) == 3 ? loads : []
    }

    /// Bytes read from and written to disks since start-up (the storage drivers' public statistics).
    static func diskBytes() -> (read: UInt64, written: UInt64) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iterator) }
        var read: UInt64 = 0, written: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                read += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                written += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return (read, written)
    }

    /// The graphics processor's use, percent, from its driver's public statistics.
    static func gpuUtilisation() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var best: Double?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
               let value = (stats["Device Utilization %"] ?? stats["GPU Activity(%)"]) as? NSNumber {
                best = max(best ?? 0, value.doubleValue)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return best
    }
}

/// One sample a minute into the Dashboard's history, whether or not anything is on screen. Cheap:
/// a handful of system calls a minute. Saved on this Mac.
final class SystemRecorder: ObservableObject {
    static let shared = SystemRecorder()

    @Published private(set) var history = SystemHistory()
    private var timer: Timer?
    private var last: (ticks: [SystemStats.Ticks], net: (UInt64, UInt64), disk: (UInt64, UInt64), at: Date)?
    private var file: URL { SettingsStore.directory.appendingPathComponent("system-history.json") }
    private var unsaved = 0

    func start() {
        guard timer == nil else { return }
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(SystemHistory.self, from: data) { history = saved }
        record()
        timer = Timer.every(60) { [weak self] _ in self?.record() }
        timer?.tolerance = 10
    }

    private func record() {
        let now = Date()
        let ticks = SystemWatch.coreTicks()
        let (down, up, _, _) = SystemWatch.network()
        let disk = SystemWatch.diskBytes()
        defer { last = (ticks, (down, up), disk, now) }
        guard let last else { return }
        let seconds = now.timeIntervalSince(last.at)
        let memory = SystemWatch.memoryNow()
        let sample = SystemHistory.Sample(
            at: now,
            cpu: SystemStats.average(SystemStats.load(previous: last.ticks, now: ticks)),
            memory: (memory?.pressure ?? 0) * 100,
            swapGB: Double(SystemWatch.swapUsed()) / 1_073_741_824,
            downBytes: SystemStats.rate(from: last.net.0, to: down, seconds: seconds),
            upBytes: SystemStats.rate(from: last.net.1, to: up, seconds: seconds),
            readBytes: SystemStats.rate(from: last.disk.0, to: disk.read, seconds: seconds),
            writeBytes: SystemStats.rate(from: last.disk.1, to: disk.written, seconds: seconds),
            gpu: SystemWatch.gpuUtilisation(),
            battery: PowerWatch.hasBattery ? PowerWatch.shared.battery.percent : nil)
        history.add(sample)
        SystemAlerts.shared.check(sample)
        unsaved += 1
        if unsaved >= 10 { save() }
    }

    func save() {
        unsaved = 0
        try? FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(history) { try? data.write(to: file, options: .atomic) }
    }
}
#endif
