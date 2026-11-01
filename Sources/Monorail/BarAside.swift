#if os(macOS)
import AppKit
import IOKit.pwr_mgt

/// When the slider bar should get out of the way: while another app plays video, or
/// when the window in front (a video player, a floating window) covers the bar's spot.
enum BarAside {
    /// Another app is playing video: it holds a display-sleep assertion named for media.
    /// (Monorail's own Stay Awake, caffeinate and similar keep-awake tools don't count.)
    static var videoIsPlaying: Bool {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
            let byProcess = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return false }
        let me = ProcessInfo.processInfo.processIdentifier
        let words = ["video", "media", "playback", "playing", "movie", "youtube", "netflix", "facetime", "zoom", "meeting"]
        for (pid, assertions) in byProcess where pid.int32Value != me {
            for assertion in assertions {
                let type = assertion[kIOPMAssertionTypeKey as String] as? String ?? ""
                guard type == (kIOPMAssertionTypePreventUserIdleDisplaySleep as String) || type == "NoDisplaySleepAssertion" else { continue }
                let name = (assertion[kIOPMAssertionNameKey as String] as? String ?? "").lowercased()
                if words.contains(where: name.contains) { return true }
            }
        }
        return false
    }

    /// The front window's frame in AppKit coordinates, if it isn't Monorail's own.
    static var frontWindowFrame: CGRect? {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
            let frame = AXUIElement.application(app.processIdentifier).focusedWindow?.frame
        else { return nil }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    /// Whether a bar at `barFrame` (AppKit coordinates) should hide right now.
    static func shouldHide(_ barFrame: CGRect) -> Bool {
        if let front = frontWindowFrame {
            let overlap = front.intersection(barFrame.insetBy(dx: 6, dy: 4))
            if !overlap.isNull, overlap.width > 40, overlap.height > 6 { return true }
        }
        return videoIsPlaying
    }
}
#endif
