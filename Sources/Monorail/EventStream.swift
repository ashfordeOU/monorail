#if os(macOS)
import Darwin
import Foundation

/// A live stream of what Monorail does, one JSON object per line, on a Unix socket in
/// Monorail's folder (`monorail subscribe` follows it). For menu bars like SketchyBar and
/// for scripts. Only this Mac's user can open it; nothing listens on the network.
final class EventStream {
    static let shared = EventStream()
    static var socketURL: URL { SettingsStore.directory.appendingPathComponent("events.sock") }

    private var listener: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clients: [Int32] = []
    private let queue = DispatchQueue(label: "monorail.events")

    var hasListeners: Bool { queue.sync { !clients.isEmpty } }

    func start() {
        queue.async { [self] in
            guard listener < 0 else { return }
            try? FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
            let path = Self.socketURL.path
            unlink(path)
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { return }
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let bytes = Array(path.utf8.prefix(MemoryLayout.size(ofValue: address.sun_path) - 1))
            withUnsafeMutableBytes(of: &address.sun_path) { raw in
                for (i, b) in bytes.enumerated() { raw[i] = b }
                raw[bytes.count] = 0
            }
            let bound = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            }
            guard bound == 0, listen(fd, 8) == 0 else {
                close(fd)
                return
            }
            chmod(path, 0o600)
            listener = fd
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            source.setEventHandler { [weak self] in self?.acceptClient() }
            source.resume()
            acceptSource = source
        }
    }

    func stop() {
        queue.async { [self] in
            acceptSource?.cancel()
            acceptSource = nil
            clients.forEach { close($0) }
            clients = []
            if listener >= 0 { close(listener) }
            listener = -1
            unlink(Self.socketURL.path)
        }
    }

    private func acceptClient() {
        let client = accept(listener, nil, nil)
        guard client >= 0 else { return }
        var on: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        clients.append(client)
        write(client, line(["event": "hello", "version": Bundle.main.shortVersion]))
    }

    /// Sends an event to everyone listening (free when no one is).
    func send(_ event: String, _ payload: [String: Any] = [:]) {
        queue.async { [self] in
            guard !clients.isEmpty else { return }
            var object = payload
            object["event"] = event
            object["time"] = ISO8601DateFormatter().string(from: Date())
            let data = line(object)
            clients.removeAll { client in
                if write(client, data) { return false }
                close(client)
                return true
            }
        }
    }

    private func line(_ object: [String: Any]) -> Data {
        var data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        data.append(0x0A)
        return data
    }

    @discardableResult
    private func write(_ fd: Int32, _ data: Data) -> Bool {
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return true }
            return Darwin.send(fd, base, raw.count, 0) == raw.count
        }
    }
}
#endif
