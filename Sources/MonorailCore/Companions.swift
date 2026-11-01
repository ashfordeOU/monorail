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

    /// Whether Monorail must never move, centre, tile or snap this window.
    ///
    /// - Anything above modal panels: status-bar, notch and menu bar widgets, HUDs, overlays.
    /// - Keeper's own frameless windows (the Island at the notch, desktop widgets, Quick Search,
    ///   Quick Terminal, Capture, the tray popover and HUDs). Keeper places these itself and puts
    ///   them back when anything else moves them, so Monorail stays out of the way. Keeper's main
    ///   window (it has a title bar) is tiled like any other app's.
    public static func leavesAlone(bundleID: String?, hasTitleBar: Bool, layer: Int?) -> Bool {
        if let layer, layer > modalPanelLayer { return true }
        if isKeeper(bundleID), !hasTitleBar { return true }
        return false
    }
}
