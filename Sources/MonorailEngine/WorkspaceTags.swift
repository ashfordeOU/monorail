import MonorailCore

/// Windows kept on more than one workspace ("tags"). A tagged window follows you between the
/// workspaces it's tagged with; one left with a single workspace isn't tagged at all.
/// Workspaces are the engine's own numbers (not the 1-based ones people see).
public struct WorkspaceTags: Equatable, Sendable {
    public private(set) var byWindow: [WindowID: Set<Int>]

    public init(_ byWindow: [WindowID: Set<Int>] = [:]) {
        self.byWindow = byWindow.filter { $0.value.count > 1 }
    }

    public func tags(of id: WindowID) -> Set<Int> { byWindow[id] ?? [] }

    /// Keeps `id` on `workspace` too, or stops keeping it there. Tagging a window also keeps it on
    /// the workspace it's on now (`current`). Returns whether it was added, and its tags afterwards.
    @discardableResult
    public mutating func toggle(_ id: WindowID, workspace: Int, current: Int) -> (added: Bool, tags: Set<Int>) {
        var tags = byWindow[id] ?? []
        let added: Bool
        if tags.contains(workspace) {
            tags.remove(workspace)
            added = false
        } else {
            tags.insert(workspace)
            tags.insert(current)
            added = true
        }
        byWindow[id] = tags.count > 1 ? tags : nil
        return (added, byWindow[id] ?? [])
    }

    /// Whether a window now on workspace `from` comes along to `to`.
    public func follows(_ id: WindowID, from: Int, to: Int) -> Bool {
        let tags = tags(of: id)
        return from != to && tags.contains(from) && tags.contains(to)
    }

    /// Windows tagged with `workspace`, in a stable order.
    public func windows(taggedWith workspace: Int) -> [WindowID] {
        byWindow.filter { $0.value.contains(workspace) }.map(\.key).sorted()
    }

    /// Only the windows `isAlive` still knows (for saving).
    public func keeping(_ isAlive: (WindowID) -> Bool) -> [WindowID: Set<Int>] {
        byWindow.filter { isAlive($0.key) }
    }
}
