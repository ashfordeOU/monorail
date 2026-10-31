#if os(macOS)
import AppKit

/// The menu bar glyph, matching the app icon: an M of three windows with the
/// middle one slid down (hollow while paused). Drawn as a template image so macOS
/// tints it for light and dark menu bars.
enum StatusIcon {
    /// `badge` adds a dot in the corner (an update is waiting).
    static func image(paused: Bool, badge: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: badge ? 22 : 18, height: 16), flipped: false) { _ in
            NSColor.black.set()
            // The M: two outlined windows standing tall…
            let sides = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 4.5, height: 13), xRadius: 1.6, yRadius: 1.6)
            sides.append(NSBezierPath(roundedRect: NSRect(x: 12, y: 1.5, width: 4.5, height: 13), xRadius: 1.6, yRadius: 1.6))
            sides.lineWidth = 1.2
            sides.stroke()
            // …and the middle one, slid down.
            let middle = NSRect(x: 7, y: 2, width: 4, height: 8.5)
            if paused {
                let outline = NSBezierPath(roundedRect: middle.insetBy(dx: 0.6, dy: 0.6), xRadius: 1.4, yRadius: 1.4)
                outline.lineWidth = 1.2
                outline.stroke()
            } else {
                NSBezierPath(roundedRect: middle, xRadius: 1.4, yRadius: 1.4).fill()
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

    /// The narrow menu bar icon: a pip per slide (the focused one tall and
    /// filled) and, with several workspaces, a dot per workspace above.
    static func mini(slide: Int, slides: Int, workspace: Int, workspaces: Int, badge: Bool = false) -> NSImage {
        let pips = min(max(slides, 1), 9)
        let pip: CGFloat = 3, gap: CGFloat = 1.5
        let width = max(CGFloat(pips) * pip + CGFloat(pips - 1) * gap, workspaces > 1 ? CGFloat(min(workspaces, 9)) * 3.5 : 0)
            + 3 + (badge ? 4 : 0)
        let image = NSImage(size: NSSize(width: width, height: 16), flipped: false) { _ in
            NSColor.black.set()
            let showWorkspaces = workspaces > 1
            let height: CGFloat = showWorkspaces ? 9 : 12
            for i in 0..<pips {
                let x = 1.5 + CGFloat(i) * (pip + gap)
                let focused = slides > 0 && i == min(slide, 9) - 1
                let rect = focused
                    ? NSRect(x: x, y: 1.5, width: pip, height: height)
                    : NSRect(x: x, y: 1.5 + height * 0.25, width: pip, height: height * 0.5)
                let path = NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1)
                if focused || slides == 0 {
                    path.fill()
                } else {
                    path.lineWidth = 0.9
                    NSBezierPath(roundedRect: rect.insetBy(dx: 0.45, dy: 0.45), xRadius: 1, yRadius: 1).stroke()
                }
            }
            if showWorkspaces {
                for i in 0..<min(workspaces, 9) {
                    let dot = NSRect(x: 1.5 + CGFloat(i) * 3.5, y: 12.5, width: 2.2, height: 2.2)
                    if i == workspace - 1 {
                        NSBezierPath(ovalIn: dot.insetBy(dx: -0.4, dy: -0.4)).fill()
                    } else {
                        NSColor.black.withAlphaComponent(0.35).set()
                        NSBezierPath(ovalIn: dot).fill()
                        NSColor.black.set()
                    }
                }
            }
            if badge { NSBezierPath(ovalIn: NSRect(x: width - 4, y: 11, width: 3.5, height: 3.5)).fill() }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Monorail · slide \(slide) of \(slides)" + (workspaces > 1 ? ", workspace \(workspace)" : "")
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
extension StatusIcon {
    /// The icon with a small cup beside it while Stay Awake is on, drawn in the same
    /// monochrome style as the rest of the menu bar (a template image, so it follows light and dark).
    static func addingCup(to base: NSImage) -> NSImage {
        let cupWidth: CGFloat = 13, gap: CGFloat = 4
        let size = NSSize(width: base.size.width + gap + cupWidth, height: max(base.size.height, 16))
        let image = NSImage(size: size, flipped: false) { _ in
            base.draw(in: NSRect(x: 0, y: (size.height - base.size.height) / 2, width: base.size.width, height: base.size.height))
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let x = base.size.width + gap
            // The cup: a rounded body, a handle and a saucer.
            let body = NSBezierPath(roundedRect: NSRect(x: x + 0.5, y: 4.5, width: 8.5, height: 7), xRadius: 2, yRadius: 2)
            body.fill()
            let handle = NSBezierPath()
            handle.appendArc(withCenter: NSPoint(x: x + 9.6, y: 8), radius: 2.1, startAngle: -80, endAngle: 80)
            handle.lineWidth = 1.3
            handle.stroke()
            let saucer = NSBezierPath(roundedRect: NSRect(x: x - 0.5, y: 2, width: 11.5, height: 1.4), xRadius: 0.7, yRadius: 0.7)
            saucer.fill()
            // A wisp of steam.
            let steam = NSBezierPath()
            steam.move(to: NSPoint(x: x + 4.8, y: 12.6))
            steam.curve(to: NSPoint(x: x + 4.8, y: 15.4), controlPoint1: NSPoint(x: x + 3.6, y: 13.6), controlPoint2: NSPoint(x: x + 6, y: 14.4))
            steam.lineWidth = 1.1
            steam.lineCapStyle = .round
            steam.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = (base.accessibilityDescription ?? "Monorail") + " · Stay Awake on"
        return image
    }
}
#endif
