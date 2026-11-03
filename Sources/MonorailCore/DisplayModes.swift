import Foundation

/// One way a display can run: its size in points (what "Looks like" means in System Settings), its
/// size in pixels and its refresh rate.
public struct DisplayModeInfo: Equatable, Hashable, Codable, Sendable {
    public var width: Int
    public var height: Int
    public var pixelWidth: Int
    public var pixelHeight: Int
    /// Hertz; 0 when the display doesn't say (some built-in panels).
    public var refreshRate: Double

    public init(width: Int, height: Int, pixelWidth: Int, pixelHeight: Int, refreshRate: Double) {
        self.width = width
        self.height = height
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.refreshRate = refreshRate
    }

    /// Sharp (Retina) scaling: more pixels than points.
    public var isHiDPI: Bool { pixelWidth > width }

    public var sizeTitle: String { "\(width) × \(height)" }

    public var refreshTitle: String {
        refreshRate > 0 ? "\(Int(refreshRate.rounded())) Hz" : "Default rate"
    }
}

/// Picking display modes to offer: one per size, the refresh rates for a size, and the next size
/// up or down ("More Space" and "Larger Text", as System Settings calls them).
public enum DisplayModeChoice {
    /// Sizes narrower than this aren't offered (they are for old games, not desktops).
    public static let minimumWidth = 800

    /// The best mode of each size, smallest first: sharp (HiDPI) or not to match `current`, and
    /// the refresh rate closest to the current one.
    public static func sizes(_ modes: [DisplayModeInfo], current: DisplayModeInfo?) -> [DisplayModeInfo] {
        var bySize: [String: DisplayModeInfo] = [:]
        for mode in modes where mode.width >= minimumWidth {
            let key = mode.sizeTitle
            if let existing = bySize[key] {
                if better(mode, than: existing, current: current) { bySize[key] = mode }
            } else {
                bySize[key] = mode
            }
        }
        return bySize.values.sorted { ($0.width, $0.height) < ($1.width, $1.height) }
    }

    /// The refresh rates available at `current`'s size and resolution, fastest first.
    public static func refreshRates(_ modes: [DisplayModeInfo], current: DisplayModeInfo) -> [DisplayModeInfo] {
        var seen = Set<Int>()
        return modes.filter {
            $0.width == current.width && $0.height == current.height && $0.pixelWidth == current.pixelWidth
                && $0.pixelHeight == current.pixelHeight && seen.insert(Int($0.refreshRate.rounded())).inserted
        }
        .sorted { $0.refreshRate > $1.refreshRate }
    }

    /// The next size with more room (or, `moreSpace` false, larger text), if there is one.
    public static func step(from current: DisplayModeInfo, in modes: [DisplayModeInfo], moreSpace: Bool) -> DisplayModeInfo? {
        let sizes = sizes(modes, current: current)
        let area = current.width * current.height
        return moreSpace
            ? sizes.first { $0.width * $0.height > area }
            : sizes.last { $0.width * $0.height < area }
    }

    private static func better(_ a: DisplayModeInfo, than b: DisplayModeInfo, current: DisplayModeInfo?) -> Bool {
        let wantHiDPI = current?.isHiDPI ?? true
        if a.isHiDPI != b.isHiDPI { return a.isHiDPI == wantHiDPI }
        if let rate = current?.refreshRate, rate > 0 {
            let da = abs(a.refreshRate - rate), db = abs(b.refreshRate - rate)
            if abs(da - db) > 0.5 { return da < db }
        }
        if a.refreshRate != b.refreshRate { return a.refreshRate > b.refreshRate }
        return a.pixelWidth > b.pixelWidth
    }
}
