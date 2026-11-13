import Foundation

/// The Developer page: Homebrew packages and services, and Docker containers, read from their own
/// command-line tools (Monorail only; the App Store's sandbox can't run them).
public enum Homebrew {
    public struct Package: Equatable, Sendable, Identifiable {
        public var name: String
        public var installed: String
        public var latest: String?
        public var isCask: Bool
        public var pinned: Bool
        public var id: String { (isCask ? "cask:" : "") + name }
        public var outdated: Bool { latest != nil && latest != installed }
    }

    public struct Service: Equatable, Sendable, Identifiable {
        public var name: String
        /// "started", "stopped", "error", "none", "scheduled"…
        public var status: String
        public var user: String?
        public var id: String { name }
        public var running: Bool { status == "started" || status == "scheduled" }
    }

    /// `brew outdated --json=v2`
    public static func outdated(_ data: Data) -> [Package] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [] }
        var list: [Package] = []
        for item in root["formulae"] as? [[String: Any]] ?? [] {
            guard let name = item["name"] as? String else { continue }
            let installed = (item["installed_versions"] as? [String])?.last ?? ""
            list.append(Package(name: name, installed: installed, latest: item["current_version"] as? String, isCask: false, pinned: (item["pinned"] as? Bool) ?? false))
        }
        for item in root["casks"] as? [[String: Any]] ?? [] {
            guard let name = item["name"] as? String else { continue }
            let installed = (item["installed_versions"] as? [String])?.last ?? ""
            list.append(Package(name: name, installed: installed, latest: item["current_version"] as? String, isCask: true, pinned: false))
        }
        return list
    }

    /// `brew list --versions` and `brew list --cask --versions`: one "name version…" per line.
    public static func installed(_ text: String, casks: Bool) -> [Package] {
        var list: [Package] = []
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ")
            guard let name = parts.first else { continue }
            list.append(Package(name: String(name), installed: parts.last.map(String.init) ?? "", latest: nil, isCask: casks, pinned: false))
        }
        return list
    }

    /// `brew services list --json`
    public static func services(_ data: Data) -> [Service] {
        guard let items = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }
        var list: [Service] = []
        for item in items {
            guard let name = item["name"] as? String else { continue }
            list.append(Service(name: name, status: (item["status"] as? String) ?? "none", user: item["user"] as? String))
        }
        return list
    }
}

public enum Docker {
    public struct Container: Equatable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var image: String
        /// "running", "exited", "paused"…
        public var state: String
        public var status: String
        public var ports: String
        public var running: Bool { state == "running" }
    }

    public struct Usage: Equatable, Sendable {
        public var cpu: Double
        public var memory: String
    }

    /// `docker ps -a --format '{{json .}}'`: one JSON object per line.
    public static func containers(_ text: String) -> [Container] {
        var list: [Container] = []
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8), let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let id = o["ID"] as? String else { continue }
            let state = (o["State"] as? String) ?? (((o["Status"] as? String) ?? "").hasPrefix("Up") ? "running" : "exited")
            list.append(Container(id: id, name: (o["Names"] as? String) ?? id, image: (o["Image"] as? String) ?? "", state: state,
                                  status: (o["Status"] as? String) ?? "", ports: (o["Ports"] as? String) ?? ""))
        }
        list.sort { a, b in
            if a.running != b.running { return a.running }
            return a.name < b.name
        }
        return list
    }

    /// `docker stats --no-stream --format '{{json .}}'`, by container ID.
    public static func stats(_ text: String) -> [String: Usage] {
        var out: [String: Usage] = [:]
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8), let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let id = (o["ID"] as? String) ?? (o["Container"] as? String) else { continue }
            let cpu = Double(((o["CPUPerc"] as? String) ?? "0").replacingOccurrences(of: "%", with: "")) ?? 0
            let memory = ((o["MemUsage"] as? String) ?? "").components(separatedBy: " / ").first ?? ""
            out[String(id.prefix(12))] = Usage(cpu: cpu, memory: memory)
        }
        return out
    }
}
