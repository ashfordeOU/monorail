import MonorailCore

/// Everything Monorail needs from an operating system's windows, and nothing more. The macOS
/// version uses the Accessibility API, the Windows version Win32 and DWM; the engine above it is
/// the same on both. Coordinates are points, origin at the top left of the main display, y down.
public protocol WindowSystem: AnyObject {
    /// Displays, left to right as arranged.
    var displays: [DisplayInfo] { get }
    /// Every window the OS reports on the current desktop(s), including ones Monorail won't manage.
    func windows() -> [WindowInfo]
    func window(_ id: WindowID) -> WindowInfo?
    func focusedWindow() -> WindowID?

    /// Moves and resizes windows together, in one batch where the OS allows it
    /// (DeferWindowPos on Windows; one pass on a background queue on macOS).
    func apply(_ frames: [WindowID: Rect])
    func focus(_ id: WindowID)
    func setMinimized(_ id: WindowID, _ minimized: Bool)
    func close(_ id: WindowID)

    /// Called on the main thread for every change the engine should react to.
    var onEvent: (WindowEvent) -> Void { get set }
}

/// A window as the OS describes it.
public struct WindowInfo: Equatable, Sendable {
    public var id: WindowID
    /// Bundle ID on macOS, the executable's AppUserModelID or path on Windows, the app ID on Linux.
    public var appID: String
    public var appName: String
    public var title: String
    public var frame: Rect
    /// A normal document or app window, not a dialog, panel, tool window or popover.
    public var isStandard: Bool
    public var isMinimized: Bool
    public var isFullScreen: Bool
    public var canMove: Bool
    public var canResize: Bool

    public init(id: WindowID, appID: String, appName: String, title: String = "", frame: Rect,
                isStandard: Bool = true, isMinimized: Bool = false, isFullScreen: Bool = false,
                canMove: Bool = true, canResize: Bool = true) {
        self.id = id
        self.appID = appID
        self.appName = appName
        self.title = title
        self.frame = frame
        self.isStandard = isStandard
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.canMove = canMove
        self.canResize = canResize
    }

    /// Whether Monorail should put this window on a strip.
    public var isTileable: Bool { isStandard && !isMinimized && !isFullScreen && canMove && frame.width >= 80 && frame.height >= 60 }
}

public struct DisplayInfo: Equatable, Sendable {
    /// Stable across restarts (a UUID on macOS, the device path on Windows, the connector on Linux).
    public var id: String
    public var name: String
    public var frame: Rect
    /// The frame minus the menu bar, Dock or taskbar.
    public var visibleFrame: Rect
    public var scale: Double

    public init(id: String, name: String, frame: Rect, visibleFrame: Rect, scale: Double = 2) {
        self.id = id
        self.name = name
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scale = scale
    }
}

public enum WindowEvent: Equatable, Sendable {
    case created(WindowID)
    case destroyed(WindowID)
    /// Moved or resized, by the person (`byUser`) or by the app itself.
    case moved(WindowID, byUser: Bool)
    case focused(WindowID)
    case minimized(WindowID)
    case restored(WindowID)
    case titleChanged(WindowID)
    case appHidden(appID: String)
    case appShown(appID: String)
    case displaysChanged
}

/// An in-memory WindowSystem for tests, and for running the engine with no OS at all.
public final class FakeWindowSystem: WindowSystem {
    public var displays: [DisplayInfo]
    public private(set) var all: [WindowID: WindowInfo] = [:]
    public private(set) var focused: WindowID?
    /// Every batch the engine applied, in order.
    public private(set) var applied: [[WindowID: Rect]] = []
    public var onEvent: (WindowEvent) -> Void = { _ in }
    private var order: [WindowID] = []

    public init(displays: [DisplayInfo] = [FakeWindowSystem.laptop]) {
        self.displays = displays
    }

    public static let laptop = DisplayInfo(
        id: "built-in", name: "Built-in Display",
        frame: Rect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: Rect(x: 0, y: 33, width: 1512, height: 949))

    public func windows() -> [WindowInfo] { order.compactMap { all[$0] } }
    public func window(_ id: WindowID) -> WindowInfo? { all[id] }
    public func focusedWindow() -> WindowID? { focused }

    public func apply(_ frames: [WindowID: Rect]) {
        applied.append(frames)
        for (id, frame) in frames { all[id]?.frame = frame }
    }

    public func focus(_ id: WindowID) {
        guard all[id] != nil else { return }
        focused = id
        onEvent(.focused(id))
    }

    public func setMinimized(_ id: WindowID, _ minimized: Bool) {
        guard all[id] != nil else { return }
        all[id]?.isMinimized = minimized
        onEvent(minimized ? .minimized(id) : .restored(id))
    }

    public func close(_ id: WindowID) {
        guard all.removeValue(forKey: id) != nil else { return }
        order.removeAll { $0 == id }
        if focused == id { focused = order.last }
        onEvent(.destroyed(id))
    }

    // MARK: Driving the fake from tests

    /// An app opens a window: it appears and takes focus.
    public func open(_ window: WindowInfo) {
        all[window.id] = window
        order.append(window.id)
        onEvent(.created(window.id))
        focus(window.id)
    }

    /// The person (or the app) moves a window.
    public func move(_ id: WindowID, to frame: Rect, byUser: Bool = true) {
        guard all[id] != nil else { return }
        all[id]?.frame = frame
        onEvent(.moved(id, byUser: byUser))
    }
}
