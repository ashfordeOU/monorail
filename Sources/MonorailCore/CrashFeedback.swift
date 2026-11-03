import Foundation

/// After Monorail quits unexpectedly: when to ask what happened, and a short, private summary of
/// macOS's crash report (.ips) for the GitHub issue: the error and the crashed functions, never
/// paths, window titles or user names.
public enum CrashFeedback {
    /// Ask once per version (never nag), and never once turned off.
    public static func shouldAsk(crashed: Bool, enabled: Bool, lastAskedVersion: String?, version: String) -> Bool {
        crashed && enabled && lastAskedVersion != version
    }

    public struct Summary: Equatable, Sendable {
        public var exception: String
        public var reason: String?
        public var frames: [String]
    }

    /// Reads a macOS crash report (.ips: a JSON header line, then the JSON report).
    public static func summary(ips: String, maxFrames: Int = 8) -> Summary? {
        guard let newline = ips.firstIndex(of: "\n"),
            let data = ips[ips.index(after: newline)...].data(using: .utf8),
            let report = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let exception = report["exception"] as? [String: Any] ?? [:]
        var parts = [exception["type"] as? String, exception["signal"] as? String].compactMap { $0 }
        if let subtype = exception["subtype"] as? String { parts.append(subtype) }
        let termination = report["termination"] as? [String: Any]
        let reason = (termination?["indicator"] as? String).map(scrub)
        let images = (report["usedImages"] as? [[String: Any]] ?? []).map { ($0["name"] as? String) ?? "?" }
        let threads = report["threads"] as? [[String: Any]] ?? []
        let faulting = report["faultingThread"] as? Int ?? threads.firstIndex { ($0["triggered"] as? Bool) == true } ?? 0
        let frames = threads.indices.contains(faulting) ? (threads[faulting]["frames"] as? [[String: Any]] ?? []) : []
        let lines = frames.prefix(maxFrames).map { frame -> String in
            let index = frame["imageIndex"] as? Int ?? -1
            let image = images.indices.contains(index) ? images[index] : "?"
            let symbol = (frame["symbol"] as? String).map(scrub) ?? "???"
            return "\(image)  \(symbol)"
        }
        guard !parts.isEmpty || !lines.isEmpty else { return nil }
        return Summary(exception: parts.isEmpty ? "unknown" : parts.joined(separator: " · "), reason: reason, frames: lines)
    }

    /// The issue text: version lines and the summary. Nothing personal.
    public static func issueBody(version: String, macOS: String, summary: Summary?) -> String {
        var body = "**What were you doing when Monorail quit?**\n\n\n**Does it happen again if you do the same?**\n\n\n---\n"
        body += "Monorail \(version) · macOS \(macOS)\n\n"
        if let summary {
            body += "Crash: \(summary.exception)\n"
            if let reason = summary.reason { body += "Reason: \(reason)\n" }
            if !summary.frames.isEmpty { body += "```\n" + summary.frames.joined(separator: "\n") + "\n```\n" }
        } else {
            body += "No crash report from macOS (it may have been stopped or frozen).\n"
        }
        return body
    }

    /// Removes anything that looks like a path or a user name.
    static func scrub(_ text: String) -> String {
        text.replacingOccurrences(of: #"/Users/[^/\s]+"#, with: "~", options: .regularExpression)
            .replacingOccurrences(of: #"(/[^\s/]+){2,}"#, with: "…", options: .regularExpression)
    }
}
