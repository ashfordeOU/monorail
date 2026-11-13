import Foundation

/// Listening ports, read from `lsof -nP -iTCP -sTCP:LISTEN -F pcn` (Monorail only).
public struct ListeningPort: Equatable, Sendable, Identifiable {
    public var pid: Int32
    public var command: String
    public var port: Int
    public var address: String
    public var id: String { "\(pid):\(port)" }

    public init(pid: Int32, command: String, port: Int, address: String) {
        self.pid = pid; self.command = command; self.port = port; self.address = address
    }

    /// Reachable from other machines on the network (not just this Mac).
    public var isExposed: Bool { !(address.hasPrefix("127.") || address == "[::1]" || address == "localhost") }

    /// A friendly guess at what it is, from the port and the program.
    public var kind: String {
        let c = command.lowercased()
        if c.contains("postgres") { return "PostgreSQL" }
        if c.contains("redis") { return "Redis" }
        if c.contains("mysql") { return "MySQL" }
        if c.contains("docker") || c.contains("com.docke") { return "Docker" }
        switch port {
        case 3000, 3001, 5173, 4200, 8080, 8000, 5000, 4000: return "Dev server"
        case 5432: return "PostgreSQL"
        case 6379: return "Redis"
        default: return c.contains("node") || c.contains("python") || c.contains("ruby") ? "Dev server" : "Service"
        }
    }

    /// Parses lsof's field output: lines starting p (pid), c (command), n (name, like "*:3000").
    public static func parse(_ output: String) -> [ListeningPort] {
        var result: [ListeningPort] = []
        var pid: Int32 = 0, command = ""
        for line in output.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": pid = Int32(value) ?? 0
            case "c": command = value
            case "n":
                guard let colon = value.lastIndex(of: ":"), let port = Int(value[value.index(after: colon)...]) else { continue }
                let address = String(value[..<colon])
                let item = ListeningPort(pid: pid, command: command, port: port, address: address.isEmpty ? "*" : address)
                if !result.contains(where: { $0.pid == item.pid && $0.port == item.port }) { result.append(item) }
            default: continue
            }
        }
        return result.sorted { $0.port < $1.port }
    }
}
