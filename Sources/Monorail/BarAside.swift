#if os(macOS)
import AppKit
import IOKit.pwr_mgt

/// When the slider bar gets out of the way, and only then:
/// 1. the window in front fills its whole display (an app's own full screen, like VLC's or a
///    browser's video), or
/// 2. an app that's playing video has a window under the bar (a player's controls).
/// Native macOS full screen is a separate Space, where the bar never appears anyway.
enum BarAside {
    /// Apps playing video: they hold a display-sleep assertion named for video.
    /// (Monorail's own Stay Awake, caffeinate, audio players and meetings don't count.)
    static func videoPlayers() -> Set<pid_t> {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
            let byProcess = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        let words = ["video", "movie", "youtube", "netflix", "film"]
        var players: Set<pid_t> = []
        for (pid, assertions) in byProcess where pid.int32Value != me {
            for assertion in assertions {
                let type = assertion[kIOPMAssertionTypeKey as String] as? String ?? ""
                guard type == (kIOPMAssertionTypePreventUserIdleDisplaySleep as String) || type == "NoDisplaySleepAssertion" else { continue }
                let name = (assertion[kIOPMAssertionNameKey as String] as? String ?? "").lowercased()
                if words.contains(where: name.contains), !name.contains("audio") { players.insert(pid.int32Value) }
            }
        }
        return players
    }

    private static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    /// An Accessibility frame (top-left origin) in AppKit coordinates.
    private static func appKit(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    /// Whether a bar at `barFrame` (AppKit coordinates) should hide right now.
    static func shouldHide(_ barFrame: CGRect) -> Bool {
        let me = ProcessInfo.processInfo.processIdentifier
        // 1. Something fills the whole display the bar is on.
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(barFrame) }),
            let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != me,
            let frame = AXUIElement.application(app.processIdentifier).focusedWindow?.frame
        {
            let front = appKit(frame)
            let covered = front.intersection(screen.frame)
            if !covered.isNull, covered.width * covered.height >= screen.frame.width * screen.frame.height * 0.95 { return true }
        }
        // 2. A video is playing in a window under the bar.
        for pid in videoPlayers() {
            for window in AXUIElement.application(pid).windows where !window.isMinimized {
                guard let frame = window.frame else { continue }
                let overlap = appKit(frame).intersection(barFrame.insetBy(dx: 6, dy: 4))
                if !overlap.isNull, overlap.width > 40, overlap.height > 6 { return true }
            }
        }
        return false
    }
}
#endif
