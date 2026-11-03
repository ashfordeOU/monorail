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
    /// Windows this returns true for stay off the strip (app rules set to float).
    public var floats: (WindowInfo) -> Bool = { _ in false }
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
    /// Apps that won't go narrower than asked (by app ID): their slides are made wide enough, so
    /// they never spill over the next slide (the same rule as the Mac app).
    public private(set) var minimumWidths: [String: Double] = [:]

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

    /// While paused, windows are left where they are and events and actions are ignored.
    public private(set) var isPaused = false

    public func pause() { isPaused = true }

    /// Picks up the desktop as it is now: windows opened, closed or moved while paused.
    public func resume() {
        guard isPaused else { return }
        isPaused = false
        strips = [:]
        displayOf = [:]
        appOf = [:]
        lastApplied = [:]
        start()
    }

    /// Uses new settings: the layout and float rules apply at once, to every window.
    public func apply(_ settings: SharedSettings) {
        config = settings.layout
        floats = { settings.floats($0) }
        for id in displayOf.keys.sorted() {
            if let info = system.window(id), floats(info) { release(id) }
        }
        for info in system.windows() where !isManaged(info.id) { adopt(info, focus: false) }
        layout()
    }

    // MARK: Events

    public func handle(_ event: WindowEvent) {
        guard !isPaused else { return }
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
        case .moved(let id, let byUser):
            if !byUser, learnMinimumWidth(id) { layout() }
        case .hidden(let id):
            if hide(id) { layout() }
        case .unhidden(let id):
            if unhide(id) { layout() }
        case .titleChanged:
            break
        }
    }

    // MARK: Windows

    /// Starts managing a window if it can be tiled; true when a strip changed.
    @discardableResult
    func adopt(_ info: WindowInfo, focus: Bool) -> Bool {
        guard info.isTileable, !floats(info), !isManaged(info.id), let display = display(for: info) else { return false }
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

    // MARK: Hidden windows (other virtual desktops)

    /// The strip's order when windows started leaving for another desktop, so they come back in
    /// the same order and widths, each desktop keeping its own arrangement.
    private var snapshots: [Int: [WindowID]] = [:]
    private var openSnapshot: [String: Int] = [:]
    private var nextSnapshot = 0
    private var hiddenAt: [WindowID: (snapshot: Int, display: String, width: Double)] = [:]

    func hide(_ id: WindowID) -> Bool {
        guard let display = displayOf[id], let strip = strips[display] else { return false }
        var snapshot = openSnapshot[display]
        if snapshot.map({ !(snapshots[$0] ?? []).contains(id) }) ?? true {
            nextSnapshot += 1
            snapshot = nextSnapshot
            snapshots[nextSnapshot] = strip.allWindows
            openSnapshot[display] = nextSnapshot
        }
        let width = strip.columns.first { $0.windows.contains(id) }?.width ?? config.defaultWidth
        hiddenAt[id] = (snapshot ?? 0, display, width)
        return release(id)
    }

    func unhide(_ id: WindowID) -> Bool {
        guard let info = system.window(id), info.isTileable, !floats(info), !isManaged(id) else { return false }
        guard let place = hiddenAt.removeValue(forKey: id), let order = snapshots[place.snapshot],
            let rank = order.firstIndex(of: id), system.displays.contains(where: { $0.id == place.display })
        else { return adopt(info, focus: false) }
        defer {
            if !hiddenAt.values.contains(where: { $0.snapshot == place.snapshot }) {
                snapshots[place.snapshot] = nil
                if openSnapshot[place.display] == place.snapshot { openSnapshot[place.display] = nil }
            }
        }
        var strip = strips[place.display] ?? Strip()
        guard strip.insert(id, width: place.width, position: .end, focus: false) else { return false }
        // After the last slide holding a window that came before it; before the first that came
        // after it; at the end when none of its desktop's windows are back yet.
        var after: Int?, before: Int?
        for (index, column) in strip.columns.enumerated() where !column.windows.contains(id) {
            let ranks = column.windows.compactMap { order.firstIndex(of: $0) }
            if ranks.contains(where: { $0 < rank }) { after = index + 1 }
            if before == nil, ranks.contains(where: { $0 > rank }) { before = index }
        }
        if let target = after ?? before { strip.moveColumn(from: strip.columns.count - 1, to: target) }
        strips[place.display] = strip
        displayOf[id] = place.display
        appOf[id] = info.appID
        return true
    }

    /// A window came out wider than its tile (the app has a minimum size): remember it for the
    /// app and widen the slide to fit. True when the strip changed.
    @discardableResult
    func learnMinimumWidth(_ id: WindowID) -> Bool {
        guard let display = displayOf[id], var strip = strips[display], let asked = lastApplied[id],
            let real = system.window(id)?.frame, real.width > asked.width + 24, abs(real.x - asked.x) < 40,
            let column = strip.columns.first(where: { $0.windows.contains(id) }), !column.isFullWidth,
            let viewport = system.displays.first(where: { $0.id == display })?.visibleFrame
        else { return false }
        let app = appOf[id] ?? ""
        guard (minimumWidths[app] ?? 0) < real.width - 4 else { return false }
        minimumWidths[app] = real.width
        let across = Double(max(column.tilesAcross, 1))
        let needed = real.width * across + config.gap * (across - 1)
        let fraction = config.fraction(forColumnWidth: needed, viewportWidth: viewport.width)
        guard fraction > column.width + 0.005 else { return false }
        strip.setWidth(fraction, of: id)
        strips[display] = strip
        for other in column.windows { lastApplied[other] = nil }
        return true
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

    // MARK: Actions

    /// The actions the shared engine runs itself (the rest are platform features or still to come).
    public static let supportedActions: [Action] = [
        .focusLeft, .focusRight, .focusUp, .focusDown, .focusFirst, .focusLast,
        .moveLeft, .moveRight, .moveUp, .moveDown,
        .cycleWidth, .cycleWidthBackward, .toggleFullWidth,
        .consumeIntoLeft, .consumeIntoRight, .expel, .expelLeft,
    ]

    /// The display with the focused window (or the first one that has windows).
    public var activeDisplay: String? {
        if let focused = system.focusedWindow(), let display = displayOf[focused] { return display }
        return system.displays.first { !(strips[$0.id]?.isEmpty ?? true) }?.id
    }

    /// Runs `action` on the active display's strip, lays out and focuses the result.
    /// Returns false when it doesn't apply (nothing to the left, an action this engine doesn't run).
    @discardableResult
    public func perform(_ action: Action) -> Bool {
        guard !isPaused, Self.supportedActions.contains(action), let display = activeDisplay, var strip = strips[display] else { return false }
        // Work from the window that really has focus, if it's on this strip.
        if let focused = system.focusedWindow(), displayOf[focused] == display { strip.focus(focused) }
        let changed: Bool
        switch action {
        case .focusLeft: changed = strip.moveFocus(.left)
        case .focusRight: changed = strip.moveFocus(.right)
        case .focusUp: changed = strip.moveFocus(.up)
        case .focusDown: changed = strip.moveFocus(.down)
        case .focusFirst:
            changed = strip.focusedColumn != 0
            strip.focusColumn(at: 0)
        case .focusLast:
            changed = strip.focusedColumn != strip.columns.count - 1
            strip.focusColumn(at: strip.columns.count - 1)
        case .moveLeft: changed = strip.moveFocused(.left)
        case .moveRight: changed = strip.moveFocused(.right)
        case .moveUp: changed = strip.moveFocused(.up)
        case .moveDown: changed = strip.moveFocused(.down)
        case .cycleWidth:
            strip.cycleWidth(presets: config.widthPresets)
            changed = true
        case .cycleWidthBackward:
            strip.cycleWidth(presets: config.widthPresets, forward: false)
            changed = true
        case .toggleFullWidth:
            strip.toggleFullWidth()
            changed = true
        case .consumeIntoLeft: changed = strip.consumeIntoLeft()
        case .consumeIntoRight: changed = strip.consumeIntoRight()
        case .expel: changed = strip.expel()
        case .expelLeft: changed = strip.expelLeft()
        default: changed = false
        }
        guard changed else { return false }
        strips[display] = strip
        layout()
        if let focused = strip.focusedWindow, system.focusedWindow() != focused { system.focus(focused) }
        return true
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
