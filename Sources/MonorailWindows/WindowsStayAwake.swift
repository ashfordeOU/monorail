#if os(Windows)
import Foundation
import MonorailCore
import MonorailEngine
import WinSDK

/// Stay Awake on Windows, like Caffeine: keeps the PC and its display awake, and (unless turned
/// off) keeps chat apps such as Teams and Slack showing you as available by pressing F15, a key
/// no app uses, whenever the PC has been idle for 50 seconds. Everything here works for a
/// standard user: no administrator, no service, no registry.
enum WindowsStayAwake {
    static let continuous: DWORD = 0x8000_0000  // ES_CONTINUOUS
    static let systemRequired: DWORD = 0x0000_0001  // ES_SYSTEM_REQUIRED
    static let displayRequired: DWORD = 0x0000_0002  // ES_DISPLAY_REQUIRED
    static var awakeState: DWORD { continuous | systemRequired | displayRequired }

    /// What the menu and the settings file say.
    private(set) static var settings = StayAwakeSettings()
    /// Whether the PC is being kept awake now.
    private(set) static var isAwake = false
    /// The execution state Windows had before the last change (0: the call failed).
    private(set) static var lastPrevious: DWORD = 0

    /// Turns Stay Awake on or off to match `new`. Must run on the thread that keeps running (the
    /// main one): Windows ties the state to the thread that set it. False when Windows refused.
    @discardableResult
    static func apply(_ new: StayAwakeSettings, now: Date = Date()) -> Bool {
        settings = new
        let wanted = new.isOn(now: now)
        guard wanted != isAwake else { return true }
        lastPrevious = SetThreadExecutionState(wanted ? awakeState : continuous)
        guard lastPrevious != 0 else { return false }
        isAwake = wanted
        return true
    }

    /// Called about once a second: ends a timed session when its time is up (true then, so the
    /// caller saves it) and nudges chat apps when the PC has been idle long enough.
    static func tick(now: Date = Date()) -> Bool {
        var ended = false
        if isAwake, !settings.isOn(now: now) {
            var off = settings
            off.mode = .off
            apply(off, now: now)
            ended = true
        }
        if let idle = idleSeconds(), AwakeNudge.isDue(awake: isAwake, keepAvailable: settings.keepChatAvailable, idle: idle) {
            nudge()
        }
        return ended
    }

    /// How long since the last key press or mouse move anywhere in this session (nil when Windows won't say).
    static func idleSeconds() -> TimeInterval? {
        var info = LASTINPUTINFO()
        info.cbSize = UINT(MemoryLayout<LASTINPUTINFO>.size)
        guard ok(GetLastInputInfo(&info)) else { return nil }
        return AwakeNudge.idleSeconds(now: GetTickCount(), lastInput: info.dwTime)
    }

    /// Presses and releases F15, as Caffeine does: counts as input (so chat apps see you), does
    /// nothing in any app. Returns how many events Windows accepted (2 when it worked).
    @discardableResult
    static func nudge() -> UINT {
        var inputs = [INPUT(), INPUT()]
        for index in inputs.indices {
            inputs[index].type = DWORD(INPUT_KEYBOARD)
            inputs[index].ki.wVk = WORD(0x7E)  // VK_F15
            inputs[index].ki.dwFlags = index == 0 ? 0 : DWORD(KEYEVENTF_KEYUP)
        }
        return SendInput(UINT(inputs.count), &inputs, Int32(MemoryLayout<INPUT>.size))
    }

    /// The menu's line for the current state.
    static func describe(now: Date = Date()) -> String {
        guard let session = settings.session(now: now) else { return "Stay Awake: Off" }
        switch session {
        case .until(let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Stay Awake: On until \(formatter.string(from: end))"
        default: return "Stay Awake: On"
        }
    }
}
#endif
