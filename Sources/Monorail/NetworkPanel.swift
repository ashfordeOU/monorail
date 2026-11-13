#if os(macOS)
import AppKit
import CoreWLAN
import MonorailCore
import SwiftUI
import SystemConfiguration

/// Everything about the network connection, read while the Network page is open: how you're connected,
/// the Wi-Fi radio, addresses, router and DNS, which apps are using the network, and how quick it feels.
final class NetworkWatch: ObservableObject {
    static let shared = NetworkWatch()

    struct WiFi: Equatable {
        var name: String?
        var rssi: Int
        var noise: Int
        var transmitRate: Double
        var channel: Int
        var band: String
        var width: String
        var standard: String
        var security: String
        var country: String?
    }

    @Published private(set) var kind = "Network"
    @Published private(set) var symbol = "network"
    @Published private(set) var interface: String?
    @Published private(set) var ipv4: [String] = []
    @Published private(set) var ipv6: [String] = []
    @Published private(set) var router: String?
    @Published private(set) var dns: [String] = []
    @Published private(set) var wifi: WiFi?
    @Published private(set) var apps: [NetworkDetails.Traffic] = []
    @Published private(set) var routerPing: (averageMs: Double, lossPercent: Double)?
    @Published private(set) var internetPing: (averageMs: Double, lossPercent: Double)?
    @Published private(set) var pinging = false
    @Published private(set) var sinceRestart: (down: UInt64, up: UInt64) = (0, 0)

    private var timer: Timer?
    private var lastNettop: (Date, [NetworkDetails.Traffic])?
    private let queue = DispatchQueue(label: "monorail.network", qos: .utility)

    func setLive(_ live: Bool) {
        timer?.invalidate(); timer = nil
        guard live else { return }
        refresh()
        timer = Timer.every(3) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 0.5
    }

    func refresh() {
        let counters = SystemWatch.network()
        sinceRestart = (counters.0, counters.1)
        readWiFi()
        queue.async { [weak self] in
            guard let self else { return }
            let route = Edition.isAppStore ? "" : Self.run("/sbin/route", ["-n", "get", "default"])
            let interface = NetworkDetails.interface(fromRoute: route) ?? (CWWiFiClient.shared().interface()?.interfaceName)
            let router = NetworkDetails.gateway(fromRoute: route)
            let (v4, v6) = Self.addresses(interface)
            let (kind, symbol) = Self.kind(of: interface)
            let dns = Self.dnsServers()
            var apps: [NetworkDetails.Traffic]?
            if !Edition.isAppStore {
                let now = NetworkDetails.parseNettop(Self.run("/usr/bin/nettop", ["-P", "-L", "1", "-n", "-x", "-J", "bytes_in,bytes_out"]))
                if let last = self.lastNettop { apps = Array(NetworkDetails.rates(before: last.1, after: now, seconds: Date().timeIntervalSince(last.0)).prefix(8)) }
                self.lastNettop = (Date(), now)
            }
            DispatchQueue.main.async {
                self.interface = interface; self.router = router; self.ipv4 = v4; self.ipv6 = v6
                self.kind = kind; self.symbol = symbol; self.dns = dns
                if let apps { self.apps = apps }
            }
        }
    }

    private func readWiFi() {
        guard let wlan = CWWiFiClient.shared().interface(), wlan.powerOn(), wlan.rssiValue() != 0 else { wifi = nil; return }
        let channel = wlan.wlanChannel()
        let band: String
        switch channel?.channelBand {
        case .band2GHz: band = "2.4 GHz"
        case .band5GHz: band = "5 GHz"
        default:
            if #available(macOS 13, *), channel?.channelBand == .band6GHz { band = "6 GHz" }
            else { band = NetworkDetails.band(channel: channel?.channelNumber ?? 0) }
        }
        let width: String
        switch channel?.channelWidth {
        case .width20MHz: width = "20 MHz"
        case .width40MHz: width = "40 MHz"
        case .width80MHz: width = "80 MHz"
        case .width160MHz: width = "160 MHz"
        default: width = ""
        }
        let standard: String
        switch wlan.activePHYMode() {
        case .mode11ax: standard = "Wi-Fi 6 (802.11ax)"
        case .mode11ac: standard = "Wi-Fi 5 (802.11ac)"
        case .mode11n: standard = "Wi-Fi 4 (802.11n)"
        case .mode11a: standard = "802.11a"
        case .mode11g: standard = "802.11g"
        case .mode11b: standard = "802.11b"
        default: standard = band == "6 GHz" ? "Wi-Fi 6E" : "Wi-Fi"
        }
        let security: String
        switch wlan.security() {
        case .none: security = "None (open)"
        case .WEP: security = "WEP (weak)"
        case .wpaPersonal, .wpaPersonalMixed: security = "WPA Personal"
        case .wpa2Personal: security = "WPA2 Personal"
        case .personal: security = "WPA2/WPA3 Personal"
        case .wpa3Personal: security = "WPA3 Personal"
        case .wpaEnterprise, .wpaEnterpriseMixed, .wpa2Enterprise, .enterprise, .wpa3Enterprise, .wpa3Transition: security = "Enterprise"
        default: security = "Secured"
        }
        wifi = WiFi(name: wlan.ssid(), rssi: wlan.rssiValue(), noise: wlan.noiseMeasurement(), transmitRate: wlan.transmitRate(),
                    channel: channel?.channelNumber ?? 0, band: band, width: width, standard: standard, security: security,
                    country: wlan.countryCode())
    }

    /// Round trips to the router and to the internet (1.1.1.1), three pings each.
    func checkLatency() {
        guard !pinging, !Edition.isAppStore else { return }
        pinging = true
        let router = self.router
        queue.async { [weak self] in
            let toRouter = router.flatMap { NetworkDetails.ping(Self.run("/sbin/ping", ["-c", "3", "-q", "-t", "4", $0])) }
            let toInternet = NetworkDetails.ping(Self.run("/sbin/ping", ["-c", "3", "-q", "-t", "4", "1.1.1.1"]))
            DispatchQueue.main.async { self?.routerPing = toRouter; self?.internetPing = toInternet; self?.pinging = false }
        }
    }

    /// The details as plain text, for support or a note.
    var summary: String {
        var lines = ["\(kind)\(interface.map { " (\($0))" } ?? "")"]
        if let wifi {
            let q = NetworkDetails.quality(rssi: wifi.rssi, noise: wifi.noise)
            lines.append("Wi-Fi: \(wifi.name ?? "network name hidden"), \(wifi.standard), \(wifi.band) channel \(wifi.channel) \(wifi.width), \(wifi.security)")
            lines.append("Signal \(wifi.rssi) dBm, noise \(wifi.noise) dBm, SNR \(q.snr) dB (\(q.quality.rawValue)), \(Int(wifi.transmitRate)) Mbit/s")
        }
        if !ipv4.isEmpty { lines.append("IPv4: \(ipv4.joined(separator: ", "))") }
        if !ipv6.isEmpty { lines.append("IPv6: \(ipv6.joined(separator: ", "))") }
        if let router { lines.append("Router: \(router)") }
        if !dns.isEmpty { lines.append("DNS: \(dns.joined(separator: ", "))") }
        if let p = routerPing { lines.append("Router latency \(Int(p.averageMs.rounded())) ms, \(Int(p.lossPercent))% loss") }
        if let p = internetPing { lines.append("Internet latency \(Int(p.averageMs.rounded())) ms, \(Int(p.lossPercent))% loss") }
        return lines.joined(separator: "\n")
    }

    // MARK: Reading the system

    static func run(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func addresses(_ interface: String?) -> ([String], [String]) {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else { return ([], []) }
        defer { freeifaddrs(first) }
        var v4: [String] = [], v6: [String] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = pointer {
            defer { pointer = entry.pointee.ifa_next }
            let name = String(cString: entry.pointee.ifa_name)
            guard interface == nil || name == interface, let address = entry.pointee.ifa_addr else { continue }
            let family = Int32(address.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let text = String(cString: host).components(separatedBy: "%").first ?? ""
            if family == AF_INET { v4.append(text) } else if !text.hasPrefix("fe80") { v6.append(text) }
        }
        return (v4, Array(v6.prefix(2)))
    }

    static func kind(of interface: String?) -> (String, String) {
        guard let interface else { return ("Not connected", "wifi.slash") }
        let all = (SCNetworkInterfaceCopyAll() as? [SCNetworkInterface]) ?? []
        let match = all.first { (SCNetworkInterfaceGetBSDName($0) as String?) == interface }
        let type = match.flatMap { SCNetworkInterfaceGetInterfaceType($0) as String? } ?? ""
        let name = match.flatMap { SCNetworkInterfaceGetLocalizedDisplayName($0) as String? }
        if type == (kSCNetworkInterfaceTypeIEEE80211 as String) { return (name ?? "Wi-Fi", "wifi") }
        if name?.localizedCaseInsensitiveContains("iPhone") == true { return (name ?? "iPhone", "iphone") }
        if name?.localizedCaseInsensitiveContains("Thunderbolt") == true { return (name ?? "Thunderbolt", "bolt.horizontal") }
        if type == (kSCNetworkInterfaceTypeEthernet as String) { return (name ?? "Ethernet", "cable.connector") }
        return (name ?? interface, "network")
    }

    static func dnsServers() -> [String] {
        guard let store = SCDynamicStoreCreate(nil, "Monorail" as CFString, nil, nil),
              let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any] else { return [] }
        return (value["ServerAddresses"] as? [String]) ?? []
    }
}

/// The Network page: live speed, how you're connected, the Wi-Fi radio in detail, addresses, which apps
/// are using the network, latency and a speed test.
struct NetworkPage: View {
    let onBack: () -> Void
    @ObservedObject private var system = SystemWatch.shared
    @ObservedObject private var net = NetworkWatch.shared
    @State private var contentHeight: CGFloat = 480
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                PageHeader(back: Brand.name, title: "Network", onBack: onBack)
                speedCard
                connectionCard
                if let wifi = net.wifi { wifiCard(wifi) }
                if !Edition.isAppStore { appsCard }
                qualityCard
                HStack {
                    Text("Since the Mac started: ↓ \(SystemStats.gigabytes(net.sinceRestart.down)) · ↑ \(SystemStats.gigabytes(net.sinceRestart.up))")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                    Spacer()
                    Button(copied ? "Copied" : "Copy Details") {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(net.summary, forType: .string); copied = true
                    }
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(GeometryReader { proxy in Color.clear.preference(key: NetworkPageHeight.self, value: proxy.size.height) })
        }
        .onPreferenceChange(NetworkPageHeight.self) { contentHeight = $0 }
        .frame(height: min(max(contentHeight, 200), 640))
        .onAppear { system.setLive(true); net.setLive(true) }
        .onDisappear { system.setLive(false); net.setLive(false) }
    }

    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                VStack(alignment: .leading, spacing: 1) {
                    Label("Download", systemImage: "arrow.down.circle.fill").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color(nsColor: .systemTeal))
                    Text(SystemStats.speed(system.down)).font(.figure(22))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Label("Upload", systemImage: "arrow.up.circle.fill").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color(nsColor: .systemOrange))
                    Text(SystemStats.speed(system.up)).font(.figure(22))
                }
                Spacer()
                if system.vpn { Label("VPN", systemImage: "lock.shield.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(Tone.good) }
            }
            ZStack {
                TrendChart(values: system.downHistory, colour: Color(nsColor: .systemTeal), format: SystemStats.speed, height: 46)
                TrendChart(values: system.upHistory, maximum: max(system.downHistory.max() ?? 1, system.upHistory.max() ?? 1) * 1.1,
                           colour: Color(nsColor: .systemOrange), format: SystemStats.speed, height: 46).opacity(0.75)
            }
            .allowsHitTesting(false)
            Text("The last few minutes, updated every second.").font(.system(size: 10.5)).foregroundStyle(.tertiary)
        }
        .tile()
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: net.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28).background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .systemBlue)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(net.kind).font(.system(size: 13, weight: .semibold))
                    Text(net.interface.map { "Interface \($0)" } ?? "Looking…").font(.system(size: 10.5)).foregroundStyle(.tertiary)
                }
                Spacer()
            }
            detail("IPv4", net.ipv4.joined(separator: ", "))
            detail("IPv6", net.ipv6.joined(separator: ", "))
            detail("Router", net.router ?? "")
            detail("DNS", net.dns.prefix(3).joined(separator: ", "))
        }
        .tile()
    }

    private func wifiCard(_ wifi: NetworkWatch.WiFi) -> some View {
        let q = NetworkDetails.quality(rssi: wifi.rssi, noise: wifi.noise)
        let bars = q.quality == .excellent ? 4 : q.quality == .good ? 3 : q.quality == .fair ? 2 : 1
        let tone: Color = bars >= 3 ? Tone.good : bars == 2 ? Tone.ok : Tone.high
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(1...4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5).fill(i <= bars ? tone : Color.primary.opacity(0.15)).frame(width: 4, height: CGFloat(4 + i * 4))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(wifi.name ?? "Wi-Fi").font(.system(size: 13, weight: .semibold))
                    Text("\(q.quality.rawValue) signal · \(wifi.standard)").font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(wifi.transmitRate)) Mbit/s").font(.figure(13, weight: .semibold))
            }
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 5) {
                stat("Signal", "\(wifi.rssi) dBm")
                stat("Noise", "\(wifi.noise) dBm")
                stat("Signal to noise", "\(q.snr) dB")
                stat("Band", wifi.band)
                stat("Channel", "\(wifi.channel)\(wifi.width.isEmpty ? "" : " · \(wifi.width)")")
                stat("Security", wifi.security)
            }
            if wifi.name == nil {
                Text("macOS shows the network's name only to apps with Location access.").font(.system(size: 10.5)).foregroundStyle(.tertiary)
            }
            if q.quality == .poor || q.quality == .fair {
                Text(wifi.band == "2.4 GHz" ? "Move closer to the router, or join its 5 GHz network if it has one." : "Move closer to the router for a stronger signal.")
                    .font(.system(size: 11)).foregroundStyle(Tone.ok).fixedSize(horizontal: false, vertical: true)
            }
        }
        .tile()
    }

    private var appsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("USING THE NETWORK NOW").font(.label).foregroundStyle(.secondary)
            if net.apps.isEmpty { Text("Measuring… (a few seconds)").font(.system(size: 11)).foregroundStyle(.secondary) }
            ForEach(net.apps, id: \.name) { app in
                HStack(spacing: 8) {
                    if let running = NSWorkspace.shared.runningApplications.first(where: { ($0.localizedName ?? "").hasPrefix(app.name) || app.name.hasPrefix($0.localizedName ?? "\u{0}") }),
                       let icon = running.icon {
                        Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                    } else {
                        Image(systemName: "gearshape.2").font(.system(size: 11)).frame(width: 18, height: 18).foregroundStyle(.secondary)
                    }
                    Text(app.name).font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    Text("↓ \(SystemStats.speed(app.bytesIn))").font(.figure(11, weight: .medium)).foregroundStyle(Color(nsColor: .systemTeal))
                    Text("↑ \(SystemStats.speed(app.bytesOut))").font(.figure(11, weight: .medium)).foregroundStyle(Color(nsColor: .systemOrange))
                }
            }
        }
        .tile()
    }

    private var qualityCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("HOW QUICK IT FEELS").font(.label).foregroundStyle(.secondary)
                Spacer()
                if !Edition.isAppStore {
                    Button(net.pinging ? "Checking…" : "Check Latency") { net.checkLatency() }.disabled(net.pinging).controlSize(.small)
                }
                Button(system.testing ? "Testing…" : "Speed Test") { system.runSpeedTest() }.disabled(system.testing).controlSize(.small)
            }
            if let p = net.routerPing { latency("To your router", p) }
            if let p = net.internetPing { latency("To the internet", p) }
            if let result = system.speedTest { Text(result).font(.system(size: 11.5, weight: .medium)) }
            if net.routerPing == nil, net.internetPing == nil, system.speedTest == nil {
                Text("Latency is how long a round trip takes; it's what makes calls and games feel smooth. The speed test measures how fast data can come in.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .tile()
    }

    private func latency(_ title: String, _ p: (averageMs: Double, lossPercent: Double)) -> some View {
        HStack {
            Text(title).font(.system(size: 12))
            Spacer()
            if p.lossPercent >= 100 { Text("No reply").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tone.high) }
            else {
                Text("\(Int(p.averageMs.rounded())) ms · \(NetworkDetails.latencyWord(p.averageMs))").font(.figure(12, weight: .semibold))
                if p.lossPercent > 0 { Text("\(Int(p.lossPercent))% lost").font(.system(size: 11)).foregroundStyle(Tone.ok) }
            }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        Group {
            if !value.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(label).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
                    Text(value).font(.system(size: 11.5, design: .monospaced)).textSelection(.enabled).lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 10)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
        }
    }
}

private struct NetworkPageHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
#endif
