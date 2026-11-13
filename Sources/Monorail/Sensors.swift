#if os(macOS)
import Foundation
import IOKit
import MonorailCore
import SwiftUI

/// Fans and temperatures from the SMC (Monorail only: the App Store's sandbox can't open it).
/// Read-only: Monorail never changes fan speeds.
enum SMC {
    private struct KeyData {
        struct Version { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0, release: UInt16 = 0 }
        struct LimitData { var version: UInt16 = 0, length: UInt16 = 0, cpu: UInt32 = 0, gpu: UInt32 = 0, mem: UInt32 = 0 }
        struct KeyInfo { var size: UInt32 = 0, type: UInt32 = 0, attributes: UInt8 = 0 }
        var key: UInt32 = 0
        var version = Version()
        var limit = LimitData()
        var info = KeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private static var connection: io_connect_t = {
        guard !Edition.isAppStore else { return 0 }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }
        var c: io_connect_t = 0
        return IOServiceOpen(service, mach_task_self_, 0, &c) == KERN_SUCCESS ? c : 0
    }()

    static var available: Bool { connection != 0 }

    private static func code(_ s: String) -> UInt32 { s.utf8.reduce(0) { $0 << 8 | UInt32($1) } }

    private static func call(_ input: inout KeyData) -> KeyData? {
        var output = KeyData()
        var size = MemoryLayout<KeyData>.stride
        let r = IOConnectCallStructMethod(connection, 2, &input, MemoryLayout<KeyData>.stride, &output, &size)
        return r == KERN_SUCCESS && output.result == 0 ? output : nil
    }

    /// A key's value as a number (handles the common types: flt, fpe2, sp78, ui8/16/32).
    static func read(_ key: String) -> Double? {
        guard available else { return nil }
        var input = KeyData()
        input.key = code(key)
        input.data8 = 9 // key info
        guard let info = call(&input) else { return nil }
        input.info = info.info
        input.data8 = 5 // read bytes
        guard let out = call(&input) else { return nil }
        let b = withUnsafeBytes(of: out.bytes) { Array($0) }
        let type = String(bytes: withUnsafeBytes(of: info.info.type.bigEndian) { Array($0) }, encoding: .ascii) ?? ""
        switch type {
        case "flt ": return Double(b.withUnsafeBytes { $0.load(as: Float.self) })
        case "fpe2": return Double(UInt16(b[0]) << 8 | UInt16(b[1])) / 4
        case "sp78": return Double(Int16(bitPattern: UInt16(b[0]) << 8 | UInt16(b[1]))) / 256
        case "ui8 ": return Double(b[0])
        case "ui16": return Double(UInt16(b[0]) << 8 | UInt16(b[1]))
        case "ui32": return Double(UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3]))
        default: return nil
        }
    }

    struct Fan: Identifiable {
        var id: Int
        var rpm: Double
        var min: Double?
        var max: Double?
        var fraction: Double? { guard let min, let max, max > min else { return nil }; return (rpm - min) / (max - min) }
    }

    static func fans() -> [Fan] {
        let count = Int(read("FNum") ?? 0)
        var list: [Fan] = []
        for i in 0..<min(count, 4) {
            guard let rpm = read("F\(i)Ac") else { continue }
            list.append(Fan(id: i, rpm: max(rpm, 0), min: read("F\(i)Mn"), max: read("F\(i)Mx")))
        }
        return list
    }

    /// The warmest of a few well-known chip and case sensors, in °C.
    static func temperatures() -> [(name: String, celsius: Double)] {
        let keys: [(String, String)] = [("CPU", "TC0P"), ("CPU die", "TC0D"), ("CPU cores", "Tp09"), ("Performance cores", "Tp01"),
                                        ("GPU", "TG0P"), ("GPU (Apple chip)", "Tg05"), ("Memory", "Tm02"), ("Battery", "TB0T"), ("Palm rest", "Ts0P")]
        var list: [(String, Double)] = []
        for (name, key) in keys {
            if let t = read(key), t > 5, t < 130 { list.append((name, t)) }
        }
        return list
    }
}

/// The Dashboard's Fans & Heat page.
struct SensorsSection: View {
    @State private var fans: [SMC.Fan] = []
    @State private var temps: [(name: String, celsius: Double)] = []
    @State private var thermal = ProcessInfo.processInfo.thermalState
    private let tick = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fans & Heat").font(.system(size: 22, weight: .bold))
            DashCard(title: "How hot", trailing: thermalText) {
                HStack(spacing: 10) {
                    Circle().fill(thermalColour).frame(width: 10, height: 10)
                    Text(thermalAdvice).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                }
            }
            if Edition.isAppStore {
                DashCard(title: "Fans and sensors") {
                    Text("The App Store's sandbox doesn't let \(Brand.name) read the fans or temperature sensors. Monorail, the free download, shows them.").foregroundStyle(.secondary)
                }
            } else {
                DashCard(title: "Fans") {
                    if fans.isEmpty { Text(SMC.available ? "No fans: this Mac is cooled without one." : "The fan sensors aren't readable on this Mac.").foregroundStyle(.secondary) }
                    ForEach(fans) { fan in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "fanblades").foregroundStyle(Color(nsColor: .systemTeal))
                                Text(fans.count > 1 ? "Fan \(fan.id + 1)" : "Fan").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(Int(fan.rpm.rounded())) rpm").font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                            }
                            if let f = fan.fraction { Meter(fraction: f) }
                            if let lo = fan.min, let hi = fan.max { Text("\(Int(lo)) to \(Int(hi)) rpm").font(.system(size: 10.5)).foregroundStyle(.secondary) }
                        }
                    }
                }
                DashCard(title: "Temperatures") {
                    if temps.isEmpty { Text("No temperature sensors are readable here.").foregroundStyle(.secondary) }
                    ForEach(temps, id: \.name) { t in
                        HStack {
                            Text(t.name)
                            Spacer()
                            Text(String(format: "%.0f°C", t.celsius)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(t.celsius >= 90 ? Color(nsColor: .systemRed) : t.celsius >= 75 ? Color(nsColor: .systemOrange) : Color.primary)
                        }
                        .font(.system(size: 12.5))
                    }
                }
            }
        }
        .sectionScroll()
        .onAppear(perform: refresh)
        .onReceive(tick) { _ in refresh() }
    }

    private func refresh() {
        thermal = ProcessInfo.processInfo.thermalState
        guard !Edition.isAppStore else { return }
        fans = SMC.fans()
        temps = SMC.temperatures()
    }

    private var thermalText: String {
        switch thermal {
        case .nominal: return "Cool"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Very hot"
        @unknown default: return ""
        }
    }

    private var thermalColour: Color {
        switch thermal {
        case .nominal: return Color(nsColor: .systemGreen)
        case .fair: return Color(nsColor: .systemYellow)
        case .serious: return Color(nsColor: .systemOrange)
        default: return Color(nsColor: .systemRed)
        }
    }

    private var thermalAdvice: String {
        switch thermal {
        case .nominal: return "Cool. Nothing is being slowed down."
        case .fair: return "Warm. Fans may be spinning up; everything still runs at full speed."
        case .serious: return "Hot. macOS is slowing the chip to cool it. The Apps page shows what's busy."
        default: return "Very hot. The Mac is throttling hard. Quit busy apps and give it air."
        }
    }
}
#endif
