import Foundation
import MonorailCore

/// Stay Awake on Windows (like Caffeine), kept in the per-user settings.json under "stayAwake":
///
///     "stayAwake": { "on": true, "until": 1793000000, "keepChatAvailable": true }
///
/// `until` is seconds since 1970 (missing: until turned off). Reading ignores everything else in
/// the file; writing changes only this key and keeps every other one exactly as it was.
public struct StayAwakeSettings: Equatable {
    public enum Mode: Equatable {
        case off
        case untilTurnedOff
        case until(Date)
    }

    public static let key = "stayAwake"

    public var mode: Mode
    /// Keep chat apps showing you as available (AwakeNudge). On unless turned off in the file.
    public var keepChatAvailable: Bool

    public init(mode: Mode = .off, keepChatAvailable: Bool = true) {
        self.mode = mode
        self.keepChatAvailable = keepChatAvailable
    }

    /// The session running now, nil when off or its time has passed.
    public func session(now: Date = Date()) -> AwakeSession? {
        switch mode {
        case .off: return nil
        case .untilTurnedOff: return .indefinitely
        case .until(let end):
            let session = AwakeSession.until(end)
            return AwakeRules.sessionContinues(session, in: AwakeContext(now: now)) ? session : nil
        }
    }

    public func isOn(now: Date = Date()) -> Bool { session(now: now) != nil }

    // MARK: The file

    private struct Stored: Codable {
        var on: Bool?
        var until: Double?
        var keepChatAvailable: Bool?
    }

    private struct File: Decodable {
        var stayAwake: Stored?
    }

    /// Reads the "stayAwake" key; off (with chat apps kept available) when missing or unreadable.
    public init(json data: Data) {
        let stored = (try? JSONDecoder().decode(File.self, from: data))?.stayAwake
        let keep = stored?.keepChatAvailable ?? true
        guard stored?.on == true else { self.init(mode: .off, keepChatAvailable: keep); return }
        if let until = stored?.until {
            self.init(mode: .until(Date(timeIntervalSince1970: until)), keepChatAvailable: keep)
        } else {
            self.init(mode: .untilTurnedOff, keepChatAvailable: keep)
        }
    }

    public static func load(from url: URL) -> StayAwakeSettings {
        StayAwakeSettings(json: (try? Data(contentsOf: url)) ?? Data())
    }

    /// The settings file with this written into its "stayAwake" key and nothing else changed;
    /// nil when the file isn't a JSON object (so it's never overwritten by mistake).
    public func written(into data: Data?) -> Data? {
        var object: [String: JSONValue] = [:]
        if let data, !data.isEmpty {
            guard case .object(let existing)? = try? JSONDecoder().decode(JSONValue.self, from: data) else { return nil }
            object = existing
        }
        var stored: [String: JSONValue] = ["keepChatAvailable": .bool(keepChatAvailable)]
        switch mode {
        case .off: stored["on"] = .bool(false)
        case .untilTurnedOff: stored["on"] = .bool(true)
        case .until(let end):
            stored["on"] = .bool(true)
            stored["until"] = .number(end.timeIntervalSince1970.rounded())
        }
        object[Self.key] = .object(stored)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(JSONValue.object(object))
    }

    /// Writes this into the settings file (made when missing); false when it couldn't.
    @discardableResult
    public func save(to url: URL) -> Bool {
        let existing = try? Data(contentsOf: url)
        guard let data = written(into: existing) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: url)) != nil
    }
}

/// Any JSON, read and written without changing it (true stays true, 480 stays a number).
enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int64.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
