import Foundation
#if os(Windows)
import WinSDK
#elseif canImport(Glibc)
import Glibc
#endif

/// How Ashforde's apps talk inside Apple's sandbox (agreed with Keeper): files in a shared App Group
/// container, and a distributed notification with no payload as the doorbell. Outside the sandbox the
/// localhost API stays as the fallback; both apps support both.
///
///     <container>/Library/Application Support/Ashforde/
///         hello/<app>.json                 who's here: the PeerHello shape
///         state/<app>.json                 the app's state
///         requests/<to>/<id>.json          { id, from, op, args, at }
///         responses/<from>/<id>.json       { id, ok, result | reason, at }
///
/// Every write is atomic (a temporary file, then a rename).
public final class SuiteChannel {
    public static let appGroup = "D69G45342Y.group.ashforde.suite"
    public static let doorbell = "com.ashforde.suite.changed"
    /// The operations a request may ask for: the localhost API's calls, one to one.
    public static let allowedOps: Set<String> = ["awake.on", "awake.off", "awake.handoff", "focus", "stage", "peer"]

    public struct Request: Equatable {
        public var id: String
        public var from: String
        public var op: String
        public var args: [String: String]
        public var at: Double
    }

    public let root: URL

    /// `container` is the App Group container (FileManager.containerURL(forSecurityApplicationGroupIdentifier:)).
    public init(container: URL) {
        root = container.appendingPathComponent("Library/Application Support/Ashforde", isDirectory: true)
    }

    // MARK: Hello and state

    public func writeHello(_ app: String, _ hello: [String: Any]) { write(hello, to: folder("hello").appendingPathComponent("\(app).json")) }
    public func hello(of app: String) -> [String: Any]? { read(folder("hello").appendingPathComponent("\(app).json")) }
    public func writeState(_ app: String, _ state: [String: Any]) { write(state, to: folder("state").appendingPathComponent("\(app).json")) }
    public func state(of app: String) -> [String: Any]? { read(folder("state").appendingPathComponent("\(app).json")) }

    // MARK: Requests and responses

    /// Leaves a request for `app`; returns its id. Ring the doorbell after.
    @discardableResult
    public func send(to app: String, from: String, op: String, args: [String: String] = [:], now: Date = Date()) -> String {
        let id = String(UUID().uuidString.prefix(8)).lowercased()
        let request: [String: Any] = ["id": id, "from": from, "op": op, "args": args, "at": now.timeIntervalSince1970 * 1000]
        write(request, to: folder("requests/\(app)").appendingPathComponent("\(id).json"))
        return id
    }

    /// Takes the requests waiting for `app` (oldest first) and removes them. Requests for operations
    /// outside `allowedOps` are dropped, as are malformed ones.
    public func takeRequests(for app: String) -> [Request] {
        let dir = folder("requests/\(app)")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        var requests: [Request] = []
        for file in files where file.pathExtension == "json" {
            defer { try? FileManager.default.removeItem(at: file) }
            guard let object = read(file), let id = object["id"] as? String, let from = object["from"] as? String,
                let op = object["op"] as? String, Self.allowedOps.contains(op)
            else { continue }
            let args = (object["args"] as? [String: Any] ?? [:]).compactMapValues { value -> String? in
                if let text = value as? String { return text }
                if let number = value as? NSNumber { return number.stringValue }
                return nil
            }
            requests.append(Request(id: id, from: from, op: op, args: args, at: object["at"] as? Double ?? 0))
        }
        return requests.sorted { $0.at < $1.at }
    }

    /// Answers a request, in the asking app's responses folder.
    public func respond(to request: Request, ok: Bool, result: [String: Any]? = nil, reason: String? = nil, now: Date = Date()) {
        var response: [String: Any] = ["id": request.id, "ok": ok, "at": now.timeIntervalSince1970 * 1000]
        if let result { response["result"] = result }
        if let reason { response["reason"] = reason }
        write(response, to: folder("responses/\(request.from)").appendingPathComponent("\(request.id).json"))
    }

    /// The answer to a request this app (`app`) sent, if it has come.
    public func response(_ id: String, for app: String) -> [String: Any]? {
        read(folder("responses/\(app)").appendingPathComponent("\(id).json"))
    }

    // MARK: Files

    private func folder(_ path: String) -> URL {
        let url = root.appendingPathComponent(path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ object: [String: Any], to url: URL) {
        guard JSONSerialization.isValidJSONObject(object),
            let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        else { return }
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        guard (try? data.write(to: temporary)) != nil else { return }
        #if os(Windows)
        // Windows' rename won't replace an existing file; MoveFileEx with REPLACE_EXISTING does, in one step.
        func native(_ u: URL) -> String { u.withUnsafeFileSystemRepresentation { $0.map { String(cString: $0) } } ?? u.path }
        let moved = native(temporary).withCString(encodedAs: UTF16.self) { from in
            native(url).withCString(encodedAs: UTF16.self) { to in
                MoveFileExW(from, to, DWORD(MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)).boolValue
            }
        }
        if !moved { try? FileManager.default.removeItem(at: temporary) }
        #else
        // rename(2) replaces the old file in one step: readers see the old or the new, never half.
        if rename(temporary.path, url.path) != 0 { try? FileManager.default.removeItem(at: temporary) }
        #endif
    }

    private func read(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
