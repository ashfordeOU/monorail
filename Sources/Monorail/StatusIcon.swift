#if os(macOS)
import AppKit

/// The menu bar glyph, matching the app icon: an M of three windows with the middle one slid
/// down (an outline while paused). Never black: in Monorail's colours (the app icon's orange to
/// pink) or plain white, as chosen in Settings, and orange while Stay Awake is on, red while recording.
enum StatusIcon {
    enum Style: String { case colour, white }

    /// `badge` adds a dot in the corner (an update is waiting). `tint` overrides the style's colour.
    /// `pulse` draws Signalbox's glyph: the same two windows with a pulse through them instead of the middle one.
    static func image(paused: Bool, badge: Bool = false, style: Style = .colour, tint: NSColor? = nil, pulse: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: badge ? 22 : 18, height: 16), flipped: false) { rect in
            // The M: two outlined windows standing tall…
            let sides = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 4.5, height: 13), xRadius: 1.6, yRadius: 1.6)
            sides.append(NSBezierPath(roundedRect: NSRect(x: 12, y: 1.5, width: 4.5, height: 13), xRadius: 1.6, yRadius: 1.6))
            sides.lineWidth = 1.5
            // …and the middle one, slid down: solid while running, an outline while paused. Signalbox
            // has a pulse there instead.
            let middle: NSBezierPath
            if pulse {
                middle = NSBezierPath()
                middle.move(to: NSPoint(x: 0.6, y: 7.4))
                for point in [(6.2, 7.4), (7.4, 11.2), (9, 3.8), (10.4, 9.2), (11.4, 7.4), (17.4, 7.4)] {
                    middle.line(to: NSPoint(x: point.0, y: point.1))
                }
                middle.lineWidth = 1.4
                middle.lineCapStyle = .round
                middle.lineJoinStyle = .round
            } else if paused {
                middle = NSBezierPath(roundedRect: NSRect(x: 7.6, y: 2.6, width: 2.8, height: 7.3), xRadius: 1.1, yRadius: 1.1)
                middle.lineWidth = 1.3
            } else {
                middle = NSBezierPath(roundedRect: NSRect(x: 7, y: 2, width: 4, height: 8.5), xRadius: 1.4, yRadius: 1.4)
            }
            // Where it slid from.
            let notch = NSBezierPath(roundedRect: NSRect(x: 8.4, y: 12, width: 1.2, height: 2.5), xRadius: 0.6, yRadius: 0.6)
            let dot = badge ? NSBezierPath(ovalIn: NSRect(x: 18, y: 10.5, width: 4, height: 4)) : nil

            // Draw the shape as a mask, then fill it with the colour.
            NSGraphicsContext.saveGraphicsState()
            NSColor.white.set()
            sides.stroke()
            if paused || pulse { middle.stroke() } else { middle.fill() }
            if !pulse { notch.fill() }
            dot?.fill()
            if let tint {
                tint.set()
                rect.fill(using: .sourceAtop)
            } else if style == .colour {
                let gradient = NSGradient(colors: [NSColor(red: 1, green: 0.58, blue: 0.36, alpha: 1),
                                                   NSColor(red: 0.95, green: 0.32, blue: 0.52, alpha: 1)])
                NSGraphicsContext.current?.compositingOperation = .sourceAtop
                gradient?.draw(in: rect, angle: -60)
            }
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        // Not a template: it keeps its own colour on every menu bar, light or dark.
        image.isTemplate = false
        image.accessibilityDescription = pulse ? "Signalbox" : paused ? "Monorail (paused)" : "Monorail"
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
