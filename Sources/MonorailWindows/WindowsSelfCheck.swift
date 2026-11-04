#if os(Windows)
import Foundation
import MonorailCore
import MonorailEngine
import WinSDK

/// `Monorail.exe --self-check`: starts far enough to prove this copy can run here, then exits
/// (0 when it can). CI runs it from the unzipped portable folder with the Swift toolchain off
/// PATH, so a runtime DLL missing from the zip fails the build, and again with a standard user's
/// token. It loads every DLL Monorail uses, reads the displays, writes the per-user settings
/// (never next to the exe) and builds the engine, without moving any window.
enum WindowsSelfCheck {
    static func run() -> Int32 {
        var failures = 0
        func check(_ condition: Bool, _ what: String) {
            print("\(condition ? "ok  " : "FAIL") \(what)")
            if !condition { failures += 1 }
        }

        let exe = executablePath()
        print("Monorail for Windows (beta) self-check")
        print("exe: \(exe)")
        print("administrator rights: \(isAdministrator() ? "yes" : "no") (token marked elevated: \(isElevated() ? "yes" : "no"))")

        // Settings are per user, so Monorail runs from a read-only or unzipped Downloads folder.
        let settings = WindowsSettings.url
        print("settings: \(settings.path)")
        let exeFolder = URL(fileURLWithPath: exe).deletingLastPathComponent().standardizedFileURL.path.lowercased()
        check(!settings.standardizedFileURL.path.lowercased().hasPrefix(exeFolder),
              "settings live in the user's profile, not next to the exe")
        SharedSettings.writeDefaultsIfMissing(to: settings)
        check(FileManager.default.fileExists(atPath: settings.path), "the settings file exists or was written")
        let loaded = SharedSettings.load(from: settings)

        let system = Win32WindowSystem()
        let displays = system.displays
        check(!displays.isEmpty, "Windows reports \(displays.count) display(s)")
        print("windows on the desktop: \(system.windows().filter(\.isStandard).count)")

        let engine = SharedEngine(system: system)
        engine.config = loaded.layout
        check(engine.strips.isEmpty, "the engine is built (not started: nothing moved)")

        // Stay Awake, as a standard user: set and clear the execution state (not saved to settings).
        check(WindowsStayAwake.apply(StayAwakeSettings(mode: .untilTurnedOff)) && WindowsStayAwake.isAwake,
              "Stay Awake on: SetThreadExecutionState accepted it")
        let sent = WindowsStayAwake.nudge()
        let idle = WindowsStayAwake.idleSeconds().map { String(format: "%.1f s", $0) } ?? "unknown"
        print("chat-app nudge (F15 through SendInput): Windows took \(sent) of 2 events; idle now \(idle)")
        check(WindowsStayAwake.apply(StayAwakeSettings(mode: .off)) && !WindowsStayAwake.isAwake,
              "Stay Awake off: SetThreadExecutionState accepted it")
        check(WindowsStayAwake.lastPrevious == WindowsStayAwake.awakeState,
              "and the PC and display had been kept awake (state was 0x\(String(WindowsStayAwake.lastPrevious, radix: 16)))")

        print(failures == 0 ? "Self-check passed." : "Self-check failed: \(failures) check(s).")
        return failures == 0 ? 0 : 1
    }

    static func executablePath() -> String {
        var buffer = [WCHAR](repeating: 0, count: 32_768)
        let count = Int(GetModuleFileNameW(nil, &buffer, DWORD(buffer.count)))
        return String(decoding: buffer.prefix(count), as: UTF16.self)
    }

    /// Whether this process's token is elevated (UAC "Run as administrator").
    static func isElevated() -> Bool {
        var token: HANDLE?
        guard ok(OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY), &token)), let token else { return false }
        defer { CloseHandle(token) }
        var elevation = TOKEN_ELEVATION()
        var size = DWORD(0)
        guard ok(GetTokenInformation(token, TokenElevation, &elevation, DWORD(MemoryLayout<TOKEN_ELEVATION>.size), &size)) else { return false }
        return elevation.TokenIsElevated != 0
    }

    /// Whether the Administrators group is active in this process's token.
    static func isAdministrator() -> Bool {
        var authority = SID_IDENTIFIER_AUTHORITY(Value: (0, 0, 0, 0, 0, 5))  // SECURITY_NT_AUTHORITY
        var group: PSID?
        guard ok(AllocateAndInitializeSid(&authority, 2, DWORD(32), DWORD(544), 0, 0, 0, 0, 0, 0, &group)), let group else { return false }
        defer { FreeSid(group) }
        var member: WindowsBool = false
        guard ok(CheckTokenMembership(nil, group, &member)) else { return false }
        return member.boolValue
    }
}
#endif
