import Foundation

/// Apps Monorail is built to work alongside, starting with Ashforde's Keeper.
public enum Companions {
    /// Keeper by Ashforde (and its helper processes).
    public static let keeper = "io.github.ashfordeou.keeper"

    public static func isKeeper(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleID == keeper || bundleID.hasPrefix(keeper + ".")
    }

    /// The window-server layer of modal panels (open and save panels, alerts).
    public static let modalPanelLayer = 8

    /// Keeper's overlays and pop-overs, by their fixed titles (Keeper's `OVERLAY_TITLES`).
    /// Monorail never manages these, whatever their subrole.
    public static let keeperOverlayTitles: [String] = [
        "Keeper Island", "Keeper Clipboard", "Keeper Glance", "Keeper Voice", "Keeper cue", "Keeper Launcher",
        "Keeper Stage overlay", "Keeper Stage backdrop", "Keeper Widget", "Keeper Wallpaper",
        "Quick Connect — Keeper", "Keeper guide", "Keeper — sharing this screen",
    ]

    /// Whether `title` is one of Keeper's overlays (or another one it announced in its hello).
    public static func isKeeperOverlay(title: String?, announced: [String] = []) -> Bool {
        guard let title, !title.isEmpty else { return false }
        if title.hasPrefix("Keeper Stage") { return true }
        return keeperOverlayTitles.contains(title) || announced.contains(title)
    }

    /// Whether a Keeper window must never be tiled: not a standard window, no title bar, or an overlay title.
    public static func isKeeperUnmanaged(bundleID: String?, title: String?, isStandard: Bool, hasTitleBar: Bool,
                                         announced: [String] = []) -> Bool {
        guard isKeeper(bundleID) else { return false }
        return !isStandard || !hasTitleBar || isKeeperOverlay(title: title, announced: announced)
    }

    /// Whether Monorail must never move, centre, tile or snap this window.
    ///
    /// - Anything above modal panels: status-bar, notch and menu bar widgets, HUDs, overlays.
    /// - Keeper's own frameless windows (the Island at the notch, desktop widgets, Quick Search,
    ///   Quick Terminal, Capture, the tray popover and HUDs). Keeper places these itself and puts
    ///   them back when anything else moves them, so Monorail stays out of the way. Keeper's main
    ///   window (it has a title bar) is tiled like any other app's.
    public static func leavesAlone(bundleID: String?, hasTitleBar: Bool, layer: Int?, title: String? = nil,
                                   announced: [String] = []) -> Bool {
        if let layer, layer > modalPanelLayer { return true }
        if isKeeper(bundleID), !hasTitleBar || isKeeperOverlay(title: title, announced: announced) { return true }
        return false
    }
}

// MARK: - Installer windows

public enum InstallerWindows {
    /// A Finder window showing a mounted, read-only disk image (an app's installer: the app next
    /// to an Applications shortcut on a fixed-size background). It floats at its own size; tiling
    /// would stretch it around a picture that doesn't grow.
    public static func isDiskImageWindow(bundleID: String?, title: String?, readOnlyVolumes: Set<String>) -> Bool {
        guard bundleID == "com.apple.finder", let title, !title.isEmpty else { return false }
        return readOnlyVolumes.contains(title)
    }
}

// MARK: - The handshake with Keeper

/// What Keeper tells Monorail about itself (`POST /peer`; Keeper's `PeerHello`).
public struct PeerHello: Equatable, Sendable {
    public struct Owns: Equatable, Sendable {
        public var awake = false
        public var focus = false
        public var stage = false
        public init(awake: Bool = false, focus: Bool = false, stage: Bool = false) {
            self.awake = awake
            self.focus = focus
            self.stage = stage
        }
    }

    public var app: String
    public var bundleID: String
    public var version: String
    public var pid: Int32
    public var owns: Owns
    /// Its windows Monorail must leave alone (fixed titles).
    public var overlays: [String]
    /// Its links (keeper://awake, keeper://focus, keeper://stage).
    public var links: [String]

    public init(app: String, bundleID: String, version: String, pid: Int32, owns: Owns = Owns(), overlays: [String] = [], links: [String] = []) {
        self.app = app
        self.bundleID = bundleID
        self.version = version
        self.pid = pid
        self.owns = owns
        self.overlays = overlays
        self.links = links
    }

    /// Only Ashforde's own apps may announce themselves.
    public static func isAshforde(_ bundleID: String) -> Bool {
        bundleID.hasPrefix("io.github.ashfordeou.") || bundleID.hasPrefix("org.ashforde.")
    }

    /// Reads Keeper's JSON body (already parsed); nil when it isn't a hello from an Ashforde app.
    public static func decode(_ body: [String: Any]) -> PeerHello? {
        guard let app = body["app"] as? String, let bundleID = body["bundleID"] as? String, isAshforde(bundleID),
            let pid = (body["pid"] as? Int) ?? (body["pid"] as? Double).map({ Int($0) }), pid > 0, pid <= Int(Int32.max)
        else { return nil }
        let owns = body["owns"] as? [String: Any] ?? [:]
        func flag(_ key: String) -> Bool { owns[key] as? Bool ?? false }
        return PeerHello(app: app, bundleID: bundleID, version: body["version"] as? String ?? "", pid: Int32(pid),
                         owns: Owns(awake: flag("awake"), focus: flag("focus"), stage: flag("stage")),
                         overlays: (body["overlays"] as? [Any] ?? []).compactMap { $0 as? String },
                         links: (body["links"] as? [Any] ?? []).compactMap { $0 as? String })
    }

    /// Where a Stay Awake session started in Monorail goes while Keeper owns staying awake:
    /// keeper://awake (until ended) or keeper://awake?for=Nm. Sessions tied to an app or a
    /// download stay with Monorail (nil), since Keeper has no such session.
    public static func awakeLink(for session: AwakeSession, now: Date = Date()) -> String? {
        switch session {
        case .indefinitely:
            return "keeper://awake"
        case .until(let date):
            let minutes = max(Int((date.timeIntervalSince(now) / 60).rounded(.up)), 1)
            return "keeper://awake?for=\(minutes)m"
        case .whileApp, .whileDownloading:
            return nil
        }
    }

    /// Whether a monorail:// link says it comes from Keeper following its own mode (`?from=keeper`).
    public static func isFromKeeper(_ url: URL) -> Bool {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .contains { $0.name == "from" && $0.value?.lowercased() == "keeper" } ?? false
    }
}
