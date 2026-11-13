import Foundation

/// The pieces of the Network page that don't need a Mac to work out: signal quality, Wi-Fi bands,
/// and reading the output of `nettop`, `route` and `ping`.
public enum NetworkDetails {
    public enum Quality: String, Sendable { case excellent = "Excellent", good = "Good", fair = "Fair", poor = "Poor" }

    /// Wi-Fi quality from signal (RSSI) and noise, both in dBm: by signal-to-noise ratio, capped by signal strength.
    public static func quality(rssi: Int, noise: Int) -> (quality: Quality, snr: Int) {
        let snr = rssi - noise
        let bySNR: Quality = snr >= 40 ? .excellent : snr >= 25 ? .good : snr >= 15 ? .fair : .poor
        let byRSSI: Quality = rssi >= -55 ? .excellent : rssi >= -67 ? .good : rssi >= -75 ? .fair : .poor
        let order: [Quality] = [.poor, .fair, .good, .excellent]
        let worst = min(order.firstIndex(of: bySNR) ?? 0, order.firstIndex(of: byRSSI) ?? 0)
        return (order[worst], snr)
    }

    /// The band for a Wi-Fi channel number when the band itself isn't known.
    public static func band(channel: Int, isSixGHz: Bool = false) -> String {
        if isSixGHz { return "6 GHz" }
        return channel <= 14 ? "2.4 GHz" : "5 GHz"
    }

    /// One process's traffic in `nettop` (bytes in and out since it started, or per second once compared).
    public struct Traffic: Equatable, Sendable {
        public var name: String
        public var bytesIn: Double
        public var bytesOut: Double
        public init(name: String, bytesIn: Double, bytesOut: Double) { self.name = name; self.bytesIn = bytesIn; self.bytesOut = bytesOut }
        public var total: Double { bytesIn + bytesOut }
    }

    /// Reads `nettop -P -L 1 -n -x -J bytes_in,bytes_out` output: rows like "Safari.512,1234,567,".
    /// Processes with the same name are added together (their PIDs are dropped).
    public static func parseNettop(_ text: String) -> [Traffic] {
        var totals: [String: (Double, Double)] = [:]
        var order: [String] = []
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count >= 3, !fields[0].isEmpty, let bytesIn = Double(fields[1]), let bytesOut = Double(fields[2]) else { continue }
            var name = fields[0]
            if let dot = name.lastIndex(of: "."), Int(name[name.index(after: dot)...]) != nil { name = String(name[..<dot]) }
            if totals[name] == nil { order.append(name) }
            let old = totals[name] ?? (0, 0)
            totals[name] = (old.0 + bytesIn, old.1 + bytesOut)
        }
        return order.map { Traffic(name: $0, bytesIn: totals[$0]!.0, bytesOut: totals[$0]!.1) }
    }

    /// Per-second rates between two `nettop` readings, busiest first, leaving out the idle.
    public static func rates(before: [Traffic], after: [Traffic], seconds: Double) -> [Traffic] {
        guard seconds > 0 else { return [] }
        let old = Dictionary(before.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        return after.compactMap { now in
            let then = old[now.name] ?? Traffic(name: now.name, bytesIn: now.bytesIn, bytesOut: now.bytesOut)
            let rate = Traffic(name: now.name, bytesIn: max(now.bytesIn - then.bytesIn, 0) / seconds, bytesOut: max(now.bytesOut - then.bytesOut, 0) / seconds)
            return rate.total > 0 ? rate : nil
        }
        .sorted { $0.total > $1.total }
    }

    /// The default gateway (router) in `route -n get default` output.
    public static func gateway(fromRoute text: String) -> String? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == "gateway", !parts[1].isEmpty { return parts[1] }
        }
        return nil
    }

    /// The interface the default route uses ("en0"), from the same output.
    public static func interface(fromRoute text: String) -> String? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == "interface", !parts[1].isEmpty { return parts[1] }
        }
        return nil
    }

    /// Average round trip and packet loss from `ping -c N` output.
    public static func ping(_ text: String) -> (averageMs: Double, lossPercent: Double)? {
        var average: Double?, loss: Double = 0
        for line in text.split(separator: "\n") {
            if line.contains("packet loss"), let range = line.range(of: #"([\d.]+)% packet loss"#, options: .regularExpression) {
                loss = Double(line[range].replacingOccurrences(of: "% packet loss", with: "")) ?? 0
            }
            if line.contains("min/avg/max"), let equals = line.firstIndex(of: "=") {
                let numbers = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces).split(separator: "/")
                if numbers.count >= 2 { average = Double(numbers[1].trimmingCharacters(in: .whitespaces)) }
            }
        }
        if let average { return (average, loss) }
        return loss >= 100 ? (0, 100) : nil
    }

    /// "12 ms", graded for how it feels.
    public static func latencyWord(_ ms: Double) -> String {
        ms < 20 ? "Snappy" : ms < 60 ? "Good" : ms < 120 ? "Noticeable" : "Slow"
    }
}
