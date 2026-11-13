#if os(macOS)
import AppKit

/// The menu bar glyph, matching the app icon: an M of three windows with the
/// middle one slid down (outlined while paused). Drawn as a template image so macOS tints it for
/// light and dark menu bars, exactly like the icons beside it.
enum StatusIcon {
    /// `badge` adds a dot in the corner (an update is waiting).
    static func image(paused: Bool, badge: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: badge ? 22 : 18, height: 16), flipped: false) { _ in
            NSColor.black.set()
            // The M: two outlined windows standing tall…
            let sides = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 4.5, height: 13), xRadius: 1.6, yRadius: 1.6)
            sides.append(NSBezierPath(roundedRect: NSRect(x: 12, y: 1.5, width: 4.5, height: 13), xRadius: 1.6, yRadius: 1.6))
            // As heavy as the other icons in the menu bar.
            sides.lineWidth = 1.5
            sides.stroke()
            // …and the middle one, slid down: solid while running, an outline while paused (same
            // strength either way, so it's as easy to see as the icons next to it).
            if paused {
                let middle = NSBezierPath(roundedRect: NSRect(x: 7.6, y: 2.6, width: 2.8, height: 7.3), xRadius: 1.1, yRadius: 1.1)
                middle.lineWidth = 1.3
                middle.stroke()
            } else {
                NSBezierPath(roundedRect: NSRect(x: 7, y: 2, width: 4, height: 8.5), xRadius: 1.4, yRadius: 1.4).fill()
            }
            if badge {
                NSBezierPath(ovalIn: NSRect(x: 18, y: 10.5, width: 4, height: 4)).fill()
            }
            // Where it slid from.
            NSBezierPath(roundedRect: NSRect(x: 8.4, y: 12, width: 1.2, height: 2.5), xRadius: 0.6, yRadius: 0.6).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = paused ? "Monorail (paused)" : "Monorail"
        return image
    }

    /// One narrow item with both arrows: click its left or right half.
    static func arrows() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 16), flipped: false) { _ in
            NSColor.black.setStroke()
            for (from, tip) in [(CGFloat(7.5), CGFloat(3.5)), (CGFloat(12.5), CGFloat(16.5))] {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: from, y: 12))
                path.line(to: NSPoint(x: tip, y: 8))
                path.line(to: NSPoint(x: from, y: 4))
                path.lineWidth = 1.6
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Previous or next window"
        return image
    }
}
#endif
