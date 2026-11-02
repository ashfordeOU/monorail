import MonorailCore

/// The platform-free window manager (docs/PLATFORMS.md): one strip per display, built from the
/// windows a `WindowSystem` reports. New windows slide in beside the focused one, closed and
/// minimised ones leave, focus scrolls the strip, and every change is applied in one batch.
///
/// This is the core the Windows and Linux versions start from. The Mac app still runs its own
/// engine; the Mac's `AXWindowSystem` can drive this one for testing.
public final class SharedEngine {
    public let system: WindowSystem
    public var config: LayoutConfig
    /// Strips by display ID.
    public private(set) var strips: [String: Strip] = [:]
    /// Which display each managed window is on.
    public private(set) var displayOf: [WindowID: String] = [:]
    /// Where returning (restored, re-shown) windows go back to.
    private var memory = ReturnMemory<String>()
    private var appOf: [WindowID: String] = [:]
    /// The frame each window was last given, so unchanged windows aren't moved again.
    public private(set) var lastApplied: [WindowID: Rect] = [:]
    /// The displays the strips were last laid out on.
    private var knownDisplays: [DisplayInfo] = []

    public init(system: WindowSystem, config: LayoutConfig = LayoutConfig()) {
        self.system = system
        self.config = config
    }

    /// Takes over: tiles every tileable window and starts following events.
    public func start() {
        system.onEvent = { [weak self] event in self?.handle(event) }
        for info in system.windows() { adopt(info, focus: false) }
        if let focused = system.focusedWindow() { focusOnStrip(focused) }
        layout()
    }

    public func isManaged(_ id: WindowID) -> Bool { displayOf[id] != nil }

    // MARK: Events

    public func handle(_ event: WindowEvent) {
        switch event {
        case .created(let id), .restored(let id):
            if let info = system.window(id), adopt(info, focus: true) { layout() }
        case .destroyed(let id), .minimized(let id):
            if release(id) { layout() }
        case .focused(let id):
            if focusOnStrip(id) { layout() }
        case .appHidden(let app):
            let ids = appOf.filter { $0.value == app }.map(\.key).sorted()
            if ids.map({ release($0) }).contains(true) { layout() }
        case .appShown:
            var changed = false
            for info in system.windows() where !isManaged(info.id) { changed = adopt(info, focus: false) || changed }
            if changed { layout() }
        case .displaysChanged:
            // macOS reports screen changes it makes itself (the Dock, the menu bar, spaces);
            // only a real change of displays or their usable areas needs a new layout.
            guard system.displays != knownDisplays else { return }
            rehome()
            layout()
        case .moved, .titleChanged:
            break
        }
    }

    // MARK: Windows

    /// Starts managing a window if it can be tiled; true when a strip changed.
    @discardableResult
    func adopt(_ info: WindowInfo, focus: Bool) -> Bool {
        guard info.isTileable, !isManaged(info.id), let display = display(for: info) else { return false }
        var strip = strips[display] ?? Strip()
        guard strip.insert(info.id, width: config.defaultWidth, position: .afterFocused, focus: focus) else { return false }
        strips[display] = strip
        displayOf[info.id] = display
        appOf[info.id] = info.appID
        return true
    }

    /// Stops managing a window, remembering where it was; true when a strip changed.
    @discardableResult
    func release(_ id: WindowID) -> Bool {
        guard let display = displayOf.removeValue(forKey: id), var strip = strips[display] else { return false }
        lastApplied[id] = nil
        if let app = appOf.removeValue(forKey: id) { memory.remember(id, app: app, at: display) }
        strip.remove(id)
        strips[display] = strip
        return true
    }

    @discardableResult
    private func focusOnStrip(_ id: WindowID) -> Bool {
        guard let display = displayOf[id], var strip = strips[display], strip.focusedWindow != id else { return false }
        strip.focus(id)
        strips[display] = strip
        return true
    }

    /// The display a window belongs on: where it came from if it's returning, otherwise the one
    /// it overlaps most, otherwise the first.
    private func display(for info: WindowInfo) -> String? {
        let displays = system.displays
        if let back = memory.recall(info.id, app: info.appID, appIsAt: { place in
            appOf.contains { $0.value == info.appID && displayOf[$0.key] == place }
        }), displays.contains(where: { $0.id == back }) {
            return back
        }
        let best = displays.max { $0.frame.intersection(info.frame).area < $1.frame.intersection(info.frame).area }
        if let best, best.frame.intersection(info.frame).area > 0 { return best.id }
        return displays.first?.id
    }

    /// After displays change: windows on a display that's gone move to the first one left.
    private func rehome() {
        let present = Set(system.displays.map(\.id))
        guard let fallback = system.displays.first?.id else { return }
        for (display, strip) in strips where !present.contains(display) {
            var target = strips[fallback] ?? Strip()
            for id in strip.allWindows {
                target.insert(id, width: config.defaultWidth, position: .end, focus: false)
                displayOf[id] = fallback
            }
            strips[fallback] = target
            strips[display] = nil
        }
    }

    // MARK: Layout

    /// Every managed window's frame, in one batch.
    public func layout() {
        var frames: [WindowID: Rect] = [:]
        knownDisplays = system.displays
        for display in knownDisplays {
            guard var strip = strips[display.id], !strip.isEmpty else { continue }
            strip.revealFocused(config: config, viewportWidth: display.visibleFrame.width)
            strips[display.id] = strip
            for placement in strip.layout(config: config, viewport: display.visibleFrame) {
                // Only windows whose place changed are moved (each move costs the app a redraw).
                if let last = lastApplied[placement.window], last.isClose(to: placement.frame, tolerance: 1) { continue }
                frames[placement.window] = placement.frame
                lastApplied[placement.window] = placement.frame
            }
        }
        if !frames.isEmpty { system.apply(frames) }
    }
}
