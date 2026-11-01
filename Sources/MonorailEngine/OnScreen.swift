import MonorailCore

/// Keeping floating windows and dialogs reachable: the same rules on every OS.
/// Coordinates are points, origin at the top left of the main display, y down.
public enum OnScreen {
    /// How far a frame may stick past a visible area and still count as inside it (rounding, shadows).
    public static let slack = 2.0

    /// The frame sits fully inside one display's visible area.
    public static func isFullyShown(_ frame: Rect, on visibleAreas: [Rect]) -> Bool {
        visibleAreas.contains { $0.expanded(by: slack).contains(frame) }
    }

    /// Good enough for a window someone (or the app) moved: the middle of its title bar is on a
    /// visible area, so it can be dragged, and at least `minShown` of it is on some display.
    public static func isReachable(_ frame: Rect, visibleAreas: [Rect], displayFrames: [Rect], minShown: Double = 0.6) -> Bool {
        if isFullyShown(frame, on: visibleAreas) { return true }
        let titleBar = Rect(x: frame.minX + 40, y: frame.minY, width: max(frame.width - 80, 1), height: 24)
        let grabbable = visibleAreas.contains { $0.contains(x: titleBar.midX, y: titleBar.midY) }
        let shown = displayFrames.reduce(0.0) { $0 + $1.intersection(frame).area }
        return grabbable && shown >= frame.area * minShown
    }

    /// The size a window may have on `visible`: its own, or smaller (keeping `margin` free) when it doesn't fit.
    public static func fittedSize(width: Double, height: Double, in visible: Rect, margin: Double = 16) -> (width: Double, height: Double) {
        (min(width, visible.width - margin * 2), min(height, visible.height - margin * 2))
    }

    /// Slides a frame (already sized to fit) the shortest way fully onto `visible`.
    public static func clamped(_ frame: Rect, into visible: Rect) -> Rect {
        var result = frame
        result.x = min(max(frame.x, visible.minX), max(visible.maxX - frame.width, visible.minX))
        result.y = min(max(frame.y, visible.minY), max(visible.maxY - frame.height, visible.minY))
        return result
    }

    /// Where to put a floating window that isn't reachable: over its app's own window when there is
    /// one (near the top, like a sheet), otherwise the middle of the display, staggered by `cascade`
    /// so several opened together don't stack exactly. Shrinks it to fit when `resizable`.
    public static func placement(for frame: Rect, visible: Rect, parent: Rect?, cascade: Int, resizable: Bool) -> Rect {
        var width = frame.width, height = frame.height
        if resizable, width > visible.width || height > visible.height {
            width = min(width, visible.width - 40)
            height = min(height, visible.height - 40)
        }
        let offset = Double(cascade % 8) * 26
        let anchor = parent ?? visible
        let x = anchor.midX - width / 2 + offset
        let y = (parent != nil ? anchor.minY + min(60, max(anchor.height - height, 0) / 2) : anchor.midY - height / 2) + offset
        return clamped(Rect(x: x, y: y, width: width, height: height), into: visible)
    }
}

extension Rect {
    public var area: Double { max(width, 0) * max(height, 0) }

    /// Grown by `d` on every side (shrunk when negative).
    public func expanded(by d: Double) -> Rect {
        Rect(x: x - d, y: y - d, width: width + d * 2, height: height + d * 2)
    }

    public func contains(_ other: Rect) -> Bool {
        other.minX >= minX && other.maxX <= maxX && other.minY >= minY && other.maxY <= maxY
    }

    /// The overlap, or an empty rect at the origin when there is none.
    public func intersection(_ other: Rect) -> Rect {
        let x0 = max(minX, other.minX), x1 = min(maxX, other.maxX)
        let y0 = max(minY, other.minY), y1 = min(maxY, other.maxY)
        guard x1 > x0, y1 > y0 else { return Rect(x: 0, y: 0, width: 0, height: 0) }
        return Rect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}
