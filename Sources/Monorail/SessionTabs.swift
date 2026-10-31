#if os(macOS)
import AppKit

/// Saves and reopens browser tabs and Finder windows for snapshots
/// (Settings → Smart → Snapshots → “Save browser tabs and Finder windows”).
/// Uses AppleScript, so macOS asks once per app for permission. Only apps that
/// are already running are asked; nothing is launched just to read it.
enum SessionTabs {
    /// Browsers that speak the Chrome AppleScript dictionary.
    static let chromeFamily = [
        "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac", "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser", "com.google.Chrome.beta",
    ]
    static let safari = "com.apple.Safari"
    static let finder = "com.apple.finder"
    static var supported: [String] { [safari, finder] + chromeFamily }

    /// Reads tabs and folders off the main thread, then hands back bundle ID → windows → URLs.
    static func capture(_ done: @escaping ([String: [[String]]]) -> Void) {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let apps = supported.filter(running.contains)
        guard !apps.isEmpty else { return done([:]) }
        DispatchQueue.global(qos: .utility).async {
            var result: [String: [[String]]] = [:]
            for app in apps {
                guard let text = run(readScript(app)) else { continue }
                let windows = text.components(separatedBy: "\n---\n").map { block in
                    block.split(separator: "\n").map(String.init).filter { !$0.isEmpty && $0 != "---" && $0 != "missing value" }
                }.filter { !$0.isEmpty }
                if !windows.isEmpty { result[app] = Array(windows.prefix(20)) }
            }
            DispatchQueue.main.async { done(result) }
        }
    }

    /// Reopens saved tabs and folders for apps that weren't running.
    static func reopen(_ documents: [String: [[String]]], skipping running: Set<String>) {
        let work = documents.filter { !running.contains($0.key) && supported.contains($0.key) }
        guard !work.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async {
            for (app, windows) in work {
                for urls in windows { _ = run(openScript(app, urls)) }
            }
        }
    }

    private static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    static func readScript(_ app: String) -> String {
        if app == finder {
            return """
                tell application id "com.apple.finder"
                    set out to ""
                    repeat with w in Finder windows
                        try
                            set out to out & POSIX path of (target of w as alias) & linefeed & "---" & linefeed
                        end try
                    end repeat
                    return out
                end tell
                """
        }
        return """
            tell application id \(quoted(app))
                set out to ""
                repeat with w in windows
                    try
                        repeat with t in tabs of w
                            set out to out & (URL of t) & linefeed
                        end repeat
                        set out to out & "---" & linefeed
                    end try
                end repeat
                return out
            end tell
            """
    }

    static func openScript(_ app: String, _ urls: [String]) -> String {
        let list = "{" + urls.prefix(60).map(quoted).joined(separator: ", ") + "}"
        if app == finder {
            return """
                tell application id "com.apple.finder"
                    repeat with p in \(list)
                        try
                            make new Finder window to (POSIX file (p as text))
                        end try
                    end repeat
                end tell
                """
        }
        if app == safari {
            return """
                tell application id "com.apple.Safari"
                    set urls to \(list)
                    make new document with properties {URL:item 1 of urls}
                    repeat with i from 2 to count of urls
                        tell front window to make new tab at end of tabs with properties {URL:item i of urls}
                    end repeat
                end tell
                """
        }
        return """
            tell application id \(quoted(app))
                set urls to \(list)
                set w to make new window
                set URL of active tab of w to item 1 of urls
                repeat with i from 2 to count of urls
                    tell w to make new tab at end of tabs with properties {URL:item i of urls}
                end repeat
            end tell
            """
    }

    /// Runs AppleScript through osascript (keeps the main thread free); nil on failure.
    @discardableResult
    static func run(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        // A stuck app can't hold Monorail up for more than ten seconds.
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { if process.isRunning { process.terminate() } }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
#endif
