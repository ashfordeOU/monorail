#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// Homebrew and Docker from their own command-line tools (Monorail only).
final class DevWatch: ObservableObject {
    static let shared = DevWatch()

    @Published private(set) var brew: String?
    @Published private(set) var docker: String?
    @Published private(set) var packages: [Homebrew.Package] = []
    @Published private(set) var outdated: [Homebrew.Package] = []
    @Published private(set) var services: [Homebrew.Service] = []
    @Published private(set) var containers: [Docker.Container] = []
    @Published private(set) var usage: [String: Docker.Usage] = [:]
    @Published private(set) var dockerRunning = false
    @Published private(set) var busy: Set<String> = []
    @Published var output = ""

    private let queue = DispatchQueue(label: "org.ashforde.monorail.developer", qos: .utility)
    private var lastBrew = Date.distantPast

    init() {
        let home = StorageWatch.realHome.path
        brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
        docker = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", home + "/.docker/bin/docker", home + "/.orbstack/bin/docker",
                  "/Applications/Docker.app/Contents/Resources/bin/docker"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func refresh(brewToo: Bool = false) {
        queue.async {
            if let docker = self.docker {
                let ps = self.run(docker, ["ps", "-a", "--format", "{{json .}}"])
                let containers = Docker.containers(ps.output)
                let stats = ps.status == 0 && containers.contains(where: \.running) ? Docker.stats(self.run(docker, ["stats", "--no-stream", "--format", "{{json .}}"]).output) : [:]
                DispatchQueue.main.async {
                    self.dockerRunning = ps.status == 0
                    self.containers = containers
                    self.usage = stats
                }
            }
            guard let brew = self.brew, brewToo || Date().timeIntervalSince(self.lastBrew) > 600 else { return }
            self.lastBrew = Date()
            let formulae = Homebrew.installed(self.run(brew, ["list", "--formula", "--versions"]).output, casks: false)
            let casks = Homebrew.installed(self.run(brew, ["list", "--cask", "--versions"]).output, casks: true)
            let outdated = Homebrew.outdated(Data(self.run(brew, ["outdated", "--json=v2"]).output.utf8))
            let services = Homebrew.services(Data(self.run(brew, ["services", "list", "--json"]).output.utf8))
            DispatchQueue.main.async {
                self.packages = formulae + casks
                self.outdated = outdated
                self.services = services
            }
        }
    }

    /// Runs a brew or docker command, then reads everything again.
    func act(_ tool: String?, _ args: [String], key: String) {
        guard let tool else { return }
        busy.insert(key)
        queue.async {
            let result = self.run(tool, args)
            DispatchQueue.main.async {
                self.busy.remove(key)
                self.output = result.status == 0 ? "" : String(result.output.suffix(600))
                self.refresh(brewToo: tool == self.brew)
            }
        }
    }

    private func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

struct DeveloperSection: View {
    @ObservedObject private var dev = DevWatch.shared
    @State private var query = ""
    private let tick = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Developer").font(.system(size: 22, weight: .bold))
                    Text("Homebrew packages and services, and Docker containers").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dev.refresh(brewToo: true) } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            }
            if !dev.output.isEmpty {
                Text(dev.output).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .systemRed).opacity(0.15)))
            }
            HStack(alignment: .top, spacing: 14) {
                homebrew
                docker
            }
        }
        .sectionScroll()
        .onAppear { dev.refresh(brewToo: dev.packages.isEmpty) }
        .onReceive(tick) { _ in dev.refresh() }
    }

    private var homebrew: some View {
        DashCard(title: "Homebrew", trailing: dev.brew == nil ? nil : "\(dev.packages.count) installed") {
            if dev.brew == nil {
                Text("Homebrew isn't installed. It's the usual way to get developer tools on a Mac.").foregroundStyle(.secondary)
                Link("brew.sh", destination: URL(string: "https://brew.sh")!)
            } else {
                HStack {
                    Text(dev.outdated.isEmpty ? "Everything is up to date." : "\(dev.outdated.count) can be updated")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if !dev.outdated.isEmpty {
                        Button(dev.busy.contains("all") ? "Updating…" : "Update All") { dev.act(dev.brew, ["upgrade"], key: "all") }
                            .disabled(dev.busy.contains("all")).controlSize(.small)
                    }
                }
                ForEach(dev.outdated) { p in
                    HStack {
                        Image(systemName: p.isCask ? "app.badge" : "shippingbox").foregroundStyle(.secondary).frame(width: 16)
                        Text(p.name).font(.system(size: 12.5))
                        Text("\(p.installed) → \(p.latest ?? "")").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                        Spacer()
                        Button(dev.busy.contains(p.id) ? "…" : "Update") { dev.act(dev.brew, ["upgrade"] + (p.isCask ? ["--cask"] : []) + [p.name], key: p.id) }
                            .disabled(dev.busy.contains(p.id) || p.pinned).controlSize(.small)
                    }
                }
                if !dev.services.isEmpty {
                    Divider()
                    Text("SERVICES").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(dev.services) { s in
                        HStack {
                            Circle().fill(s.running ? Color(nsColor: .systemGreen) : s.status == "error" ? Color(nsColor: .systemRed) : Color.secondary.opacity(0.4)).frame(width: 7, height: 7)
                            Text(s.name).font(.system(size: 12.5))
                            Spacer()
                            if s.running { Button("Restart") { dev.act(dev.brew, ["services", "restart", s.name], key: s.id) }.controlSize(.small) }
                            Button(s.running ? "Stop" : "Start") { dev.act(dev.brew, ["services", s.running ? "stop" : "start", s.name], key: s.id) }
                                .disabled(dev.busy.contains(s.id)).controlSize(.small)
                        }
                    }
                }
                Divider()
                TextField("Search installed", text: $query).textFieldStyle(.roundedBorder)
                if !query.isEmpty {
                    ForEach(dev.packages.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(12)) { p in
                        HStack {
                            Text(p.name).font(.system(size: 12))
                            Spacer()
                            Text(p.installed).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var docker: some View {
        DashCard(title: "Docker", trailing: dev.docker == nil ? nil : "\(dev.containers.filter(\.running).count) running") {
            if dev.docker == nil {
                Text("Docker (or OrbStack) isn't installed.").foregroundStyle(.secondary)
            } else if !dev.dockerRunning {
                Text("Docker isn't running.").foregroundStyle(.secondary)
                Button("Open Docker") {
                    for id in ["com.docker.docker", "dev.kdrag0n.MacVirt"] {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { NSWorkspace.shared.open(url); break }
                    }
                }
            } else if dev.containers.isEmpty {
                Text("No containers.").foregroundStyle(.secondary)
            } else {
                ForEach(dev.containers) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Circle().fill(c.running ? Color(nsColor: .systemGreen) : Color.secondary.opacity(0.4)).frame(width: 7, height: 7)
                            Text(c.name).font(.system(size: 12.5, weight: .semibold))
                            Spacer()
                            if let u = dev.usage[String(c.id.prefix(12))] {
                                Text(String(format: "%.1f%%", u.cpu) + " · " + u.memory).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                            }
                            if c.running { Button("Restart") { dev.act(dev.docker, ["restart", c.id], key: c.id) }.controlSize(.small) }
                            Button(c.running ? "Stop" : "Start") { dev.act(dev.docker, [c.running ? "stop" : "start", c.id], key: c.id) }
                                .disabled(dev.busy.contains(c.id)).controlSize(.small)
                        }
                        Text([c.image, c.ports.isEmpty ? nil : c.ports, c.status].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
    }
}
#endif
