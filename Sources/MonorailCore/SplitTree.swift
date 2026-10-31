/// A slide divided into splits inside splits, to any depth. Each leaf holds one window, or
/// several as a tab group (one shown, the rest behind it). Built by docking windows onto the
/// edges of other windows, or onto the middle of one to make a tab group.
public indirect enum SplitTree: Hashable, Codable, Sendable {
    /// One window, or a tab group of windows with the front one at `active`.
    case leaf([WindowID], active: Int)
    /// Two parts side by side (`.horizontal`) or one above the other (`.vertical`);
    /// `ratio` is the first part's share.
    case split(Axis, Double, SplitTree, SplitTree)

    public enum Axis: String, Codable, Hashable, Sendable { case horizontal, vertical }

    /// Where a window lands relative to another.
    public enum Edge: String, Codable, Sendable, CaseIterable {
        case left, right, top, bottom, center

        var axis: Axis { self == .left || self == .right ? .horizontal : .vertical }
        var goesFirst: Bool { self == .left || self == .top }
    }

    public static let ratioRange = 0.1...0.9

    public static func single(_ window: WindowID) -> SplitTree { .leaf([window], active: 0) }

    // MARK: Reading

    /// Every window, in reading order (left to right, top to bottom; tabs in tab order).
    public var windows: [WindowID] {
        switch self {
        case .leaf(let ids, _): return ids
        case .split(_, _, let a, let b): return a.windows + b.windows
        }
    }

    /// The tab groups (leaves with more than one window).
    public var tabGroups: [[WindowID]] {
        switch self {
        case .leaf(let ids, _): return ids.count > 1 ? [ids] : []
        case .split(_, _, let a, let b): return a.tabGroups + b.tabGroups
        }
    }

    /// How deep the splits go (a single leaf is 0).
    public var depth: Int {
        switch self {
        case .leaf: return 0
        case .split(_, _, let a, let b): return 1 + max(a.depth, b.depth)
        }
    }

    public func contains(_ window: WindowID) -> Bool { windows.contains(window) }

    public struct Tile: Equatable, Sendable {
        public var window: WindowID
        public var frame: Rect
        /// A tab behind the front one of its group.
        public var isHiddenTab: Bool
        /// The windows of its tab group (just itself when not tabbed), and the front one.
        public var group: [WindowID]
        public var front: WindowID
    }

    /// Where every window goes, in unit coordinates of `frame` (0...1, y down by default).
    public func tiles(in frame: Rect = Rect(x: 0, y: 0, width: 1, height: 1)) -> [Tile] {
        switch self {
        case .leaf(let ids, let active):
            let front = ids.indices.contains(active) ? ids[active] : ids.first ?? 0
            return ids.map { Tile(window: $0, frame: frame, isHiddenTab: $0 != front, group: ids, front: front) }
        case .split(let axis, let ratio, let a, let b):
            let (first, second) = Self.divide(frame, axis, ratio)
            return a.tiles(in: first) + b.tiles(in: second)
        }
    }

    static func divide(_ frame: Rect, _ axis: Axis, _ ratio: Double) -> (Rect, Rect) {
        let r = min(max(ratio, ratioRange.lowerBound), ratioRange.upperBound)
        switch axis {
        case .horizontal:
            let w = frame.width * r
            return (Rect(x: frame.x, y: frame.y, width: w, height: frame.height),
                    Rect(x: frame.x + w, y: frame.y, width: frame.width - w, height: frame.height))
        case .vertical:
            let h = frame.height * r
            return (Rect(x: frame.x, y: frame.y, width: frame.width, height: h),
                    Rect(x: frame.x, y: frame.y + h, width: frame.width, height: frame.height - h))
        }
    }

    /// The unit frame of `window`, if it's in the tree.
    public func frame(of window: WindowID) -> Rect? { tiles().first { $0.window == window }?.frame }

    // MARK: Changing

    /// Puts `window` beside `target` (or into its tab group, for `.center`), splitting
    /// `target`'s place in two. A window already in the tree moves.
    public func docking(_ window: WindowID, onto target: WindowID, edge: Edge, ratio: Double = 0.5) -> SplitTree {
        guard window != target else { return self }
        let base = contains(window) ? (removing(window) ?? .single(target)) : self
        guard base.contains(target) else { return base }
        return base.replacingLeaf(containing: target) { leaf in
            guard case .leaf(var ids, _) = leaf else { return leaf }
            if edge == .center {
                ids.append(window)
                return .leaf(ids, active: ids.count - 1)
            }
            // A target inside a tab group: the whole group moves aside together.
            let new = SplitTree.single(window)
            return edge.goesFirst
                ? .split(edge.axis, ratio, new, leaf)
                : .split(edge.axis, 1 - ratio, leaf, new)
        }
    }

    /// Without `window`; its sibling takes its place. Nil when it was the last window.
    public func removing(_ window: WindowID) -> SplitTree? {
        switch self {
        case .leaf(var ids, let active):
            guard let index = ids.firstIndex(of: window) else { return self }
            ids.remove(at: index)
            guard !ids.isEmpty else { return nil }
            let front = index < active ? active - 1 : min(active, ids.count - 1)
            return .leaf(ids, active: front)
        case .split(let axis, let ratio, let a, let b):
            guard contains(window) else { return self }
            let na = a.removing(window)
            let nb = b.removing(window)
            switch (na, nb) {
            case (nil, nil): return nil
            case (let x?, nil): return x
            case (nil, let y?): return y
            case (let x?, let y?): return .split(axis, ratio, x, y)
            }
        }
    }

    /// Brings `window` to the front of its tab group.
    public func activating(_ window: WindowID) -> SplitTree {
        replacingLeaf(containing: window) { leaf in
            guard case .leaf(let ids, _) = leaf, let index = ids.firstIndex(of: window) else { return leaf }
            return .leaf(ids, active: index)
        }
    }

    /// Moves the split nearest `window` on `axis` by `delta` (positive grows `window`).
    public func adjusting(_ window: WindowID, axis: Axis, by delta: Double) -> SplitTree {
        guard case .split(let ax, let ratio, let a, let b) = self, contains(window) else { return self }
        let inFirst = a.contains(window)
        // The deepest matching split wins: try inside first.
        let inner = inFirst ? a.adjusting(window, axis: axis, by: delta) : b.adjusting(window, axis: axis, by: delta)
        let changedInside = inFirst ? inner != a : inner != b
        if changedInside { return inFirst ? .split(ax, ratio, inner, b) : .split(ax, ratio, a, inner) }
        guard ax == axis else { return self }
        let next = Self.clamp(ratio + (inFirst ? delta : -delta))
        return .split(ax, next, a, b)
    }

    /// Sets splits so `window` gets as close as possible to `wanted` (unit coordinates),
    /// moving only the splits that border it: the result of someone dragging its edges.
    public func resizing(_ window: WindowID, to wanted: Rect, in frame: Rect = Rect(x: 0, y: 0, width: 1, height: 1)) -> SplitTree {
        guard case .split(let axis, let ratio, let a, let b) = self, contains(window) else { return self }
        let inFirst = a.contains(window)
        var newRatio = ratio
        switch axis {
        case .horizontal where frame.width > 0:
            let boundary = inFirst ? wanted.maxX : wanted.minX
            newRatio = Self.clamp((boundary - frame.x) / frame.width)
        case .vertical where frame.height > 0:
            let boundary = inFirst ? wanted.maxY : wanted.minY
            newRatio = Self.clamp((boundary - frame.y) / frame.height)
        default: break
        }
        // Only move this split if the window's edge on this axis actually moved.
        let (oldFirst, oldSecond) = Self.divide(frame, axis, ratio)
        let current = inFirst ? oldFirst : oldSecond
        let moved: Bool
        switch axis {
        case .horizontal: moved = abs((inFirst ? current.maxX - wanted.maxX : current.minX - wanted.minX)) > 0.005
        case .vertical: moved = abs((inFirst ? current.maxY - wanted.maxY : current.minY - wanted.minY)) > 0.005
        }
        if !moved { newRatio = ratio }
        let (first, second) = Self.divide(frame, axis, newRatio)
        let na = inFirst ? a.resizing(window, to: wanted, in: first) : a
        let nb = inFirst ? b : b.resizing(window, to: wanted, in: second)
        return .split(axis, newRatio, na, nb)
    }

    /// Every split back to an even share.
    public var balanced: SplitTree {
        switch self {
        case .leaf: return self
        case .split(let axis, _, let a, let b): return .split(axis, 0.5, a.balanced, b.balanced)
        }
    }

    /// Matches the tree to `windows`: drops windows that left and docks new ones to the
    /// right of the last window, so the shape someone built survives other changes.
    public func reconciled(with windows: [WindowID]) -> SplitTree? {
        var tree: SplitTree? = self
        for window in self.windows where !windows.contains(window) { tree = tree?.removing(window) }
        for window in windows where !(tree?.contains(window) ?? false) {
            if let current = tree, let last = current.windows.last {
                tree = current.docking(window, onto: last, edge: .right)
            } else {
                tree = .single(window)
            }
        }
        return tree
    }

    /// The same tree with windows renamed by `map` (windows it leaves out are dropped).
    public func mapping(_ map: [WindowID: WindowID]) -> SplitTree? {
        switch self {
        case .leaf(let ids, let active):
            let mapped = ids.compactMap { map[$0] }
            guard !mapped.isEmpty else { return nil }
            return .leaf(mapped, active: min(active, mapped.count - 1))
        case .split(let axis, let ratio, let a, let b):
            switch (a.mapping(map), b.mapping(map)) {
            case (nil, nil): return nil
            case (let x?, nil): return x
            case (nil, let y?): return y
            case (let x?, let y?): return .split(axis, ratio, x, y)
            }
        }
    }

    /// Zones from the zone editor (leaves numbered in fill order) filled with `windows`:
    /// spare zones close up, extra windows dock to the right of the last one.
    public func filling(_ windows: [WindowID]) -> SplitTree? {
        let zones = self.windows
        var map: [WindowID: WindowID] = [:]
        for (zone, window) in zip(zones, windows) { map[zone] = window }
        return mapping(map)?.reconciled(with: windows) ?? (windows.first.map { SplitTree.single($0).reconciled(with: windows) } ?? nil)
    }

    /// A tree with the same tiles as a standard layout, to start nesting from it.
    public static func from(_ windows: [WindowID], arrangement: Arrangement) -> SplitTree? {
        guard let first = windows.first else { return nil }
        let axis: Axis = arrangement == .stack ? .vertical : .horizontal
        var tree = SplitTree.single(first)
        for (index, window) in windows.enumerated().dropFirst() {
            // Even shares: each new window takes 1/(n) of the run so far.
            let share = 1.0 / Double(index + 1)
            tree = .split(axis, 1 - share, tree, .single(window))
        }
        return tree
    }

    private func replacingLeaf(containing window: WindowID, _ change: (SplitTree) -> SplitTree) -> SplitTree {
        switch self {
        case .leaf(let ids, _): return ids.contains(window) ? change(self) : self
        case .split(let axis, let ratio, let a, let b):
            if a.contains(window) { return .split(axis, ratio, a.replacingLeaf(containing: window, change), b) }
            if b.contains(window) { return .split(axis, ratio, a, b.replacingLeaf(containing: window, change)) }
            return self
        }
    }

    private static func clamp(_ ratio: Double) -> Double { min(max(ratio, ratioRange.lowerBound), ratioRange.upperBound) }
}

/// Where a dragged window would land on another: near an edge docks beside it, the middle tabs.
public enum DockZone {
    /// The point and `frame` in the same coordinates (y down). The outer `edgeShare` of each
    /// side docks on that side; the rest is the middle.
    public static func edge(x: Double, y: Double, in frame: Rect, edgeShare: Double = 0.4) -> SplitTree.Edge? {
        guard frame.width > 0, frame.height > 0, frame.contains(x: x, y: y) else { return nil }
        let fx = (x - frame.x) / frame.width
        let fy = (y - frame.y) / frame.height
        let distances: [(SplitTree.Edge, Double)] = [(.left, fx), (.right, 1 - fx), (.top, fy), (.bottom, 1 - fy)]
        let nearest = distances.min { $0.1 < $1.1 }!
        return nearest.1 < edgeShare ? nearest.0 : .center
    }

    /// The part of `frame` the window would take, for the drop preview.
    public static func preview(_ edge: SplitTree.Edge, in frame: Rect) -> Rect {
        switch edge {
        case .left: return Rect(x: frame.x, y: frame.y, width: frame.width / 2, height: frame.height)
        case .right: return Rect(x: frame.x + frame.width / 2, y: frame.y, width: frame.width / 2, height: frame.height)
        case .top: return Rect(x: frame.x, y: frame.y, width: frame.width, height: frame.height / 2)
        case .bottom: return Rect(x: frame.x, y: frame.y + frame.height / 2, width: frame.width, height: frame.height / 2)
        case .center: return frame
        }
    }
}
