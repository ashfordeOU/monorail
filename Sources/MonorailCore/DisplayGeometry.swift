import Foundation

/// A side of a display.
public enum ScreenEdge: String, Codable, CaseIterable, Sendable {
    case left, right, top, bottom
}

/// A direction from one display to another.
public enum DisplayDirection: String, Codable, CaseIterable, Sendable {
    case left, right, up, down
}

/// Choosing displays by direction or by number, and moving a window between them. Frames are in
/// the top-left-origin space the Accessibility API uses.
public enum DisplayTargets {
    /// Display indices in the order they are numbered: left to right, then top to bottom.
    public static func numbered(_ frames: [Rect]) -> [Int] {
        frames.indices.sorted { a, b in
            let fa = frames[a], fb = frames[b]
            if abs(fa.minX - fb.minX) > 1 { return fa.minX < fb.minX }
            if abs(fa.minY - fb.minY) > 1 { return fa.minY < fb.minY }
            return a < b
        }
    }

    /// The index of display `number` (1-based, numbered left to right), if there is one.
    public static func index(ofNumber number: Int, in frames: [Rect]) -> Int? {
        let order = numbered(frames)
        return order.indices.contains(number - 1) ? order[number - 1] : nil
    }

    /// The nearest display in `direction` from display `index`. Displays that line up with it
    /// (overlap across the direction of travel) win over ones off to the side.
    public static func neighbour(of index: Int, _ direction: DisplayDirection, in frames: [Rect]) -> Int? {
        guard frames.indices.contains(index) else { return nil }
        let from = frames[index]
        var best: (index: Int, score: Double)?
        for (i, to) in frames.enumerated() where i != index {
            let along: Double, across: Double, overlap: Double
            switch direction {
            case .left:
                guard to.midX < from.midX, to.minX < from.minX else { continue }
                along = from.minX - to.maxX
                across = abs(to.midY - from.midY)
                overlap = min(from.maxY, to.maxY) - max(from.minY, to.minY)
            case .right:
                guard to.midX > from.midX, to.maxX > from.maxX else { continue }
                along = to.minX - from.maxX
                across = abs(to.midY - from.midY)
                overlap = min(from.maxY, to.maxY) - max(from.minY, to.minY)
            case .up:
                guard to.midY < from.midY, to.minY < from.minY else { continue }
                along = from.minY - to.maxY
                across = abs(to.midX - from.midX)
                overlap = min(from.maxX, to.maxX) - max(from.minX, to.minX)
            case .down:
                guard to.midY > from.midY, to.maxY > from.maxY else { continue }
                along = to.minY - from.maxY
                across = abs(to.midX - from.midX)
                overlap = min(from.maxX, to.maxX) - max(from.minX, to.minX)
            }
            // Lined-up displays first, then the closest; sideways distance counts double.
            let score = (overlap > 0 ? 0 : 1_000_000) + max(along, 0) + across * 2
            if best == nil || score < best!.score { best = (i, score) }
        }
        return best?.index
    }

    /// `frame` moved from one display's area to another's, keeping its place and size in
    /// proportion, and always fully inside the new area.
    public static func transfer(_ frame: Rect, from source: Rect, to target: Rect) -> Rect {
        guard source.width > 0, source.height > 0 else { return frame }
        let width = min(frame.width, target.width), height = min(frame.height, target.height)
        // Where the window's top-left sat within the room it had to move in.
        let roomX = source.width - frame.width, roomY = source.height - frame.height
        let fx = roomX > 0 ? min(max((frame.x - source.x) / roomX, 0), 1) : 0.5
        let fy = roomY > 0 ? min(max((frame.y - source.y) / roomY, 0), 1) : 0.5
        return Rect(x: target.x + fx * (target.width - width), y: target.y + fy * (target.height - height),
                    width: width, height: height).rounded()
    }

    /// The edges of display `index` that another display touches (the pointer passes over them
    /// instead of stopping).
    public static func sharedEdges(of index: Int, in frames: [Rect], tolerance: Double = 2) -> Set<ScreenEdge> {
        guard frames.indices.contains(index) else { return [] }
        let f = frames[index]
        var result = Set<ScreenEdge>()
        for (i, o) in frames.enumerated() where i != index {
            let overlapY = min(f.maxY, o.maxY) - max(f.minY, o.minY)
            let overlapX = min(f.maxX, o.maxX) - max(f.minX, o.minX)
            if overlapY > 0, abs(o.maxX - f.minX) <= tolerance { result.insert(.left) }
            if overlapY > 0, abs(o.minX - f.maxX) <= tolerance { result.insert(.right) }
            if overlapX > 0, abs(o.maxY - f.minY) <= tolerance { result.insert(.top) }
            if overlapX > 0, abs(o.minY - f.maxY) <= tolerance { result.insert(.bottom) }
        }
        return result
    }
}

/// Windows-style snapping by dragging a floating window to a screen edge: the left or right edge
/// for a half, a corner for a quarter, the top edge to maximise.
public enum EdgeSnapZones {
    /// How close to an edge (points) the pointer must be.
    public static let edgeDistance = 5.0
    /// How far along an edge from a corner still counts as the corner.
    public static let cornerSize = 80.0

    /// Where a window dropped with the pointer at `x`, `y` would snap, on a display whose whole
    /// frame is `bounds`. Edges another display touches don't count: the pointer crosses them.
    public static func position(x: Double, y: Double, in bounds: Rect, sharedEdges: Set<ScreenEdge> = [],
                                edge: Double = edgeDistance, corner: Double = cornerSize) -> SnapPosition? {
        guard x >= bounds.minX - 1, x <= bounds.maxX + 1, y >= bounds.minY - 1, y <= bounds.maxY + 1 else { return nil }
        let left = !sharedEdges.contains(.left) && x <= bounds.minX + edge
        let right = !sharedEdges.contains(.right) && x >= bounds.maxX - 1 - edge
        let top = !sharedEdges.contains(.top) && y <= bounds.minY + edge
        let bottom = !sharedEdges.contains(.bottom) && y >= bounds.maxY - 1 - edge
        let nearTop = y <= bounds.minY + corner, nearBottom = y >= bounds.maxY - corner
        let nearLeft = x <= bounds.minX + corner, nearRight = x >= bounds.maxX - corner
        if left {
            if nearTop { return .topLeft }
            if nearBottom { return .bottomLeft }
            return .leftHalf
        }
        if right {
            if nearTop { return .topRight }
            if nearBottom { return .bottomRight }
            return .rightHalf
        }
        if top {
            if nearLeft { return .topLeft }
            if nearRight { return .topRight }
            return .maximize
        }
        if bottom {
            // The middle of the bottom edge is the Dock's: only the corners snap there.
            if nearLeft { return .bottomLeft }
            if nearRight { return .bottomRight }
        }
        return nil
    }
}

/// Stashing a window at a screen edge: it slides out of view, leaving a sliver to hover over.
public enum StashGeometry {
    /// How much of a stashed window stays on screen.
    public static let sliver = 10.0

    /// The side to stash a window at: the nearer of left and right that no other display
    /// touches (nil if both are taken).
    public static func edge(for window: Rect, display: Rect, sharedEdges: Set<ScreenEdge>) -> ScreenEdge? {
        let free = [ScreenEdge.left, .right].filter { !sharedEdges.contains($0) }
        guard !free.isEmpty else { return nil }
        if free.count == 1 { return free[0] }
        return window.midX < display.midX ? .left : .right
    }

    /// Where the window waits: all but a sliver past the edge of the display's `frame`, kept within
    /// the `visible` area top to bottom.
    public static func stashedFrame(_ window: Rect, edge: ScreenEdge, frame: Rect, visible: Rect,
                                    sliver: Double = StashGeometry.sliver) -> Rect {
        let y = clampedY(window, visible: visible)
        switch edge {
        case .right:
            return Rect(x: frame.maxX - sliver, y: y, width: window.width, height: window.height).rounded()
        default:
            return Rect(x: frame.minX + sliver - window.width, y: y, width: window.width, height: window.height).rounded()
        }
    }

    /// Where the window shows while revealed: fully on screen against its edge.
    public static func revealedFrame(_ window: Rect, edge: ScreenEdge, visible: Rect, gap: Double = 0) -> Rect {
        let width = min(window.width, visible.width - gap * 2)
        let y = clampedY(window, visible: visible)
        let x = edge == .right ? visible.maxX - gap - width : visible.minX + gap
        return Rect(x: x, y: y, width: width, height: min(window.height, visible.height)).rounded()
    }

    /// The strip of screen that reveals the window when the pointer is over it.
    public static func hotZone(stashed: Rect, edge: ScreenEdge, frame: Rect, sliver: Double = StashGeometry.sliver) -> Rect {
        let x = edge == .right ? frame.maxX - sliver : frame.minX
        return Rect(x: x, y: stashed.minY, width: sliver, height: stashed.height)
    }

    private static func clampedY(_ window: Rect, visible: Rect) -> Double {
        let height = min(window.height, visible.height)
        return min(max(window.y, visible.minY), visible.maxY - height)
    }
}
