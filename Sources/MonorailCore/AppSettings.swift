import Foundation

/// How Monorail treats the windows of one app.
public struct AppRule: Equatable, Hashable, Codable, Sendable, Identifiable {
    public var bundleID: String
    /// Display name, for Settings only.
    public var name: String
    /// Keep the app's windows off the strip.
    public var float: Bool
    /// Width for new windows of this app, overriding the default width.
    public var width: Double?
    /// Where new windows of this app join the strip, overriding the default.
    public var position: Strip.InsertPosition?
    /// How many of this app's windows share one slide when grouping by app.
    public var tiles: Int?
    /// Layout of this app's slides, overriding the default.
    public var arrangement: Arrangement?
    /// Workspace (0-based) this app's new windows open in.
    public var workspace: Int?
    /// The display (by name) this app's new windows open on.
    public var display: String?
    /// New windows open full width, tabbed, pinned to an edge, on every
    /// workspace, or as the scratchpad.
    public var fullWidth: Bool?
    public var tabbed: Bool?
    public var pin: PinSide?
    public var sticky: Bool?
    public var scratchpad: Bool?
    /// Only windows whose title contains this (any case), e.g. "Meet" in a
    /// browser. Empty or nil applies to every window of the app.
    public var titleContains: String?
    /// Windows matching this rule get a slide to themselves.
    public var ownSlide: Bool?
    /// A stable identity for title rules (several can share an app).
    public var ruleID: String?

    public var id: String { ruleID ?? titleContains.map { "\(bundleID)|\($0)" } ?? bundleID }

    /// True for a rule that only applies to some window titles.
    public var isTitleRule: Bool { !(titleContains ?? "").trimmingCharacters(in: .whitespaces).isEmpty }

    public func matches(title: String) -> Bool {
        guard isTitleRule, let text = titleContains?.trimmingCharacters(in: .whitespaces) else { return true }
        return title.localizedCaseInsensitiveContains(text)
    }

    public init(
        bundleID: String,
        name: String,
        float: Bool = false,
        width: Double? = nil,
        position: Strip.InsertPosition? = nil,
        tiles: Int? = nil,
        arrangement: Arrangement? = nil,
        workspace: Int? = nil,
        titleContains: String? = nil,
        ownSlide: Bool? = nil,
        ruleID: String? = nil
    ) {
        self.bundleID = bundleID
        self.name = name
        self.float = float
        self.width = width
        self.position = position
        self.tiles = tiles
        self.arrangement = arrangement
        self.workspace = workspace
        self.titleContains = titleContains
        self.ownSlide = ownSlide
        self.ruleID = ruleID
    }
}

/// Settings that differ on one display (a laptop screen versus a big monitor).
public struct DisplayOverride: Equatable, Hashable, Codable, Sendable {
    /// The display's name when it was set up, for Settings.
    public var name: String
    public var gap: Double?
    public var edgeGap: Double?
    public var defaultWidth: Double?
    public var sliderBar: SliderBarMode?

    public init(name: String, gap: Double? = nil, edgeGap: Double? = nil, defaultWidth: Double? = nil,
                sliderBar: SliderBarMode? = nil) {
        self.name = name
        self.gap = gap
        self.edgeGap = edgeGap
        self.defaultWidth = defaultWidth
        self.sliderBar = sliderBar
    }
}

/// Switches profile or applies a saved layout by itself: at a time of day, or
/// when the Mac joins a Wi-Fi network.
public struct AutoRule: Equatable, Hashable, Codable, Sendable, Identifiable {
    public enum Trigger: String, Codable, CaseIterable, Sendable {
        /// At a time of day; on joining a Wi-Fi network; when a display
        /// with this name is connected (`network` holds the name).
        case time, wifi, display
    }

    public var id: String
    public var name: String
    public var trigger: Trigger
    /// For `time`: minutes after midnight, and the weekdays (1 = Sunday … 7); empty = every day.
    public var minuteOfDay: Int
    public var weekdays: [Int]
    /// For `wifi`: the network name.
    public var network: String
    public var profile: Int?
    public var layout: String?
    public var isEnabled: Bool

    public init(id: String = UUID().uuidString, name: String, trigger: Trigger, minuteOfDay: Int = 9 * 60,
                weekdays: [Int] = [], network: String = "", profile: Int? = nil, layout: String? = nil,
                isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.minuteOfDay = minuteOfDay
        self.weekdays = weekdays
        self.network = network
        self.profile = profile
        self.layout = layout
        self.isEnabled = isEnabled
    }

    /// True if a time rule is due at this minute of this weekday.
    public func isDue(minuteOfDay minute: Int, weekday: Int) -> Bool {
        trigger == .time && isEnabled && minute == minuteOfDay && (weekdays.isEmpty || weekdays.contains(weekday))
    }
}

/// A workspace template: apps (with files or links to open) that start in
/// one slide together, ready to work.
public struct WorkspaceTemplate: Equatable, Hashable, Codable, Sendable, Identifiable {
    public struct Item: Equatable, Hashable, Codable, Sendable, Identifiable {
        public var id: String
        public var bundleID: String
        /// Files, folders or links to open in the app (one per line); empty opens the app.
        public var open: String

        public init(id: String = UUID().uuidString, bundleID: String, open: String = "") {
            self.id = id
            self.bundleID = bundleID
            self.open = open
        }

        /// The links and paths to open, one per non-empty line.
        public var targets: [String] {
            open.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
    }

    public var id: String
    public var name: String
    public var items: [Item]
    public var arrangement: Arrangement
    /// Start in an empty workspace (otherwise the current one).
    public var emptyWorkspace: Bool

    public init(id: String = UUID().uuidString, name: String, items: [Item] = [], arrangement: Arrangement = .columns,
                emptyWorkspace: Bool = true) {
        self.id = id
        self.name = name
        self.items = items
        self.arrangement = arrangement
        self.emptyWorkspace = emptyWorkspace
    }
}

/// Finds a project name in a window title, for gathering a project's windows.
public enum ProjectMatcher {
    /// The first of `projects` that the title mentions (any case, whole word-ish).
    public static func project(in title: String, projects: [String]) -> String? {
        let lower = title.lowercased()
        return projects.first { name in
            let needle = name.trimmingCharacters(in: .whitespaces).lowercased()
            guard needle.count >= 2, let range = lower.range(of: needle) else { return false }
            // Not just part of a longer word: "mono" shouldn't match "monorail".
            let before = range.lowerBound == lower.startIndex ? nil : lower[lower.index(before: range.lowerBound)]
            let after = range.upperBound == lower.endIndex ? nil : lower[range.upperBound]
            func isWordCharacter(_ c: Character?) -> Bool { c.map { $0.isLetter || $0.isNumber } ?? false }
            return !isWordCharacter(before) && !isWordCharacter(after)
        }
    }
}

/// A starting point for how Monorail behaves, picked in the welcome tour.
public enum StartStyle: String, Codable, CaseIterable, Sendable {
    /// The endless strip: windows keep their size and the strip scrolls.
    case scrolling
    /// Every slide fits on screen, like classic tiling.
    case fit
    /// Quiet: no slider bar, no notices, just the menu bar icon and keys.
    case minimal

    public var title: String {
        switch self {
        case .scrolling: return "Scrolling strip"
        case .fit: return "Fit on screen"
        case .minimal: return "Minimal"
        }
    }

    public var detail: String {
        switch self {
        case .scrolling: return "Windows keep their size on an endless strip that slides."
        case .fit: return "Every slide shares the screen, like classic tiling. Nothing scrolls."
        case .minimal: return "No slider bar or notices: the menu bar icon and your keys."
        }
    }
}

/// Compares versions like 1.0.0, 1.1.0-beta.2: a final release is newer
/// than its own betas.
public enum Version {
    public static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ version: String) -> (numbers: [Int], prerelease: String?) {
            let trimmed = version.hasPrefix("v") ? String(version.dropFirst()) : version
            let pieces = trimmed.split(separator: "-", maxSplits: 1).map(String.init)
            return (pieces[0].split(separator: ".").map { Int($0) ?? 0 }, pieces.count > 1 ? pieces[1] : nil)
        }
        let (lhs, lhsPre) = parts(a), (rhs, rhsPre) = parts(b)
        for i in 0..<max(lhs.count, rhs.count) {
            let x = i < lhs.count ? lhs[i] : 0, y = i < rhs.count ? rhs[i] : 0
            if x != y { return x > y }
        }
        switch (lhsPre, rhsPre) {
        case (nil, nil): return false
        case (nil, _): return true
        case (_, nil): return false
        case let (l?, r?): return l.compare(r, options: .numeric) == .orderedDescending
        }
    }
}

/// What a screen corner does when the pointer rests in it.
public enum HotCorner: String, Codable, CaseIterable, Sendable {
    case none, overview, showDesktop, palette, focusMode, cheatSheet, stripZoom

    public var title: String {
        switch self {
        case .none: return "Nothing"
        case .overview: return "Overview"
        case .showDesktop: return "Show desktop"
        case .palette: return "Command palette"
        case .focusMode: return "Focus mode"
        case .cheatSheet: return "Cheat sheet"
        case .stripZoom: return "Zoom out on the strip"
        }
    }
}

/// Settings for one workspace.
public struct WorkspaceConfig: Equatable, Hashable, Codable, Sendable {
    /// Its colour (hex), instead of the theme's.
    public var color: String?
    /// The layout of its new slides.
    public var arrangement: Arrangement?
    /// Its own gap between windows.
    public var gap: Double?
    /// Focus mode turns on when you go there.
    public var focusMode: Bool?
    /// New windows never open here; they go to the next workspace.
    public var closed: Bool?
    /// Minutes a day before a gentle nudge (nil = no budget).
    public var budgetMinutes: Int?
    /// A Shortcut to run on arriving (set a Focus, an audio device, Slack status…).
    public var shortcut: String?

    public init(color: String? = nil, arrangement: Arrangement? = nil, gap: Double? = nil, focusMode: Bool? = nil,
                closed: Bool? = nil, budgetMinutes: Int? = nil) {
        self.budgetMinutes = budgetMinutes
        self.color = color
        self.arrangement = arrangement
        self.gap = gap
        self.focusMode = focusMode
        self.closed = closed
    }
}

/// Which key acts as the Monorail key (held for every shortcut, tapped for the palette).
public enum MonorailKeySource: String, Codable, CaseIterable, Sendable {
    case capsLock, rightCommand, rightOption, rightControl
    /// The key's HID usage, for hidutil.
    public var usage: Int {
        switch self {
        case .capsLock: return 0x7_0000_0039
        case .rightCommand: return 0x7_0000_00E7
        case .rightOption: return 0x7_0000_00E6
        case .rightControl: return 0x7_0000_00E4
        }
    }
    public var title: String {
        switch self {
        case .capsLock: return "Caps Lock"
        case .rightCommand: return "Right ⌘ Command"
        case .rightOption: return "Right ⌥ Option"
        case .rightControl: return "Right ⌃ Control"
        }
    }
}

/// What a sound pack plays.
public enum SoundPack: String, Codable, CaseIterable, Sendable {
    case classic, soft, retro, silent
    public var title: String { rawValue.capitalized }
    /// Sounds for a slide change and a workspace change.
    public var sounds: (slide: String?, workspace: String?) {
        switch self {
        case .classic: return ("Tink", "Pop")
        case .soft: return ("Pop", "Purr")
        case .retro: return ("Morse", "Bottle")
        case .silent: return (nil, nil)
        }
    }
}

/// How windows move.
public enum AnimationCurve: String, Codable, CaseIterable, Sendable {
    case smooth, snappy, linear
    public var title: String { rawValue.capitalized }
}

/// Where notices appear.
public enum NoticePosition: String, Codable, CaseIterable, Sendable {
    case top, middle, bottom
    public var title: String { rawValue.capitalized }
}

/// What the menu bar item shows.
public enum MenuBarStyle: String, Codable, CaseIterable, Sendable {
    /// The M glyph and the slide number.
    case glyph
    /// A dot per slide, the focused one filled.
    case dots
    /// Just the workspace number.
    case number
    /// The position drawn into the icon itself: a pip per slide, no text.
    case mini

    public var title: String {
        switch self {
        case .mini: return "Mini map in the icon (narrowest)"
        case .glyph: return "M and slide number"
        case .dots: return "A dot per slide"
        case .number: return "Workspace number"
        }
    }
}

/// Colours for the overview, the slider bar and workspace dots.
public enum Theme: String, Codable, CaseIterable, Sendable {
    case vivid, ocean, sunset, forest, mono, ashforde
    case aurora, nord, dracula, solarized, rosePine, mint, lavender, ember, glacier, sand, spring, summer, autumn, winter, festive, synthwave, phosphor, paper, nebula, holographic
    /// Follows the season: spring, summer, autumn, winter, festive in December.
    case seasons

    public var title: String {
        switch self {
        case .vivid: return "Vivid"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .mono: return "Monochrome"
        case .ashforde: return "Ashforde"
        case .aurora: return "Aurora"
        case .nord: return "Nord"
        case .dracula: return "Dracula"
        case .solarized: return "Solarized"
        case .rosePine: return "Rosé Pine"
        case .mint: return "Mint"
        case .lavender: return "Lavender"
        case .ember: return "Ember"
        case .glacier: return "Glacier"
        case .sand: return "Desert Sand"
        case .spring: return "Spring Bloom"
        case .summer: return "Summer Sun"
        case .autumn: return "Autumn Leaves"
        case .winter: return "Winter Frost"
        case .festive: return "Festive"
        case .synthwave: return "Synthwave"
        case .phosphor: return "Phosphor Terminal"
        case .paper: return "Ink & Paper"
        case .nebula: return "Nebula"
        case .holographic: return "Holographic"
        case .seasons: return "Seasons (changes through the year)"
        }
    }
}

extension Theme {
    /// The themes grouped for Settings.
    public static let classic: [Theme] = [.vivid, .ocean, .sunset, .forest, .mono, .ashforde, .aurora, .nord, .dracula,
                                          .solarized, .rosePine, .mint, .lavender, .ember, .glacier, .sand]
    public static let seasonal: [Theme] = [.seasons, .spring, .summer, .autumn, .winter, .festive]
    public static let unique: [Theme] = [.synthwave, .phosphor, .paper, .nebula, .holographic]

    /// The theme to draw with: Seasons becomes the season's theme for `date`.
    public func resolved(on date: Date = Date(), southernHemisphere: Bool = false) -> Theme {
        guard self == .seasons else { return self }
        var month = Calendar(identifier: .gregorian).component(.month, from: date)
        if month == 12 { return .festive }
        if southernHemisphere { month = (month + 5) % 12 + 1 }
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }
}

/// A slide layout the user designed: columns side by side, each split into rows.
public struct CustomLayout: Equatable, Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// Rows in each column, e.g. [1, 2] = one big tile beside two stacked.
    public var rows: [Int]

    public init(id: String = UUID().uuidString, name: String, rows: [Int]) {
        self.id = id
        self.name = name
        self.rows = rows
    }

    public var tiles: Int { rows.reduce(0, +) }
}

/// Apps that open together in one slide (like Android's app pairs).
public struct AppPair: Equatable, Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var bundleIDs: [String]
    public var arrangement: Arrangement
    public var customRows: [Int]?
    /// Partner apps: when one of them opens a window, it pairs with the other's.
    public var autoPair: Bool?

    public init(id: String = UUID().uuidString, name: String, bundleIDs: [String], arrangement: Arrangement,
                customRows: [Int]? = nil) {
        self.id = id
        self.name = name
        self.bundleIDs = bundleIDs
        self.arrangement = arrangement
        self.customRows = customRows
    }
}

/// Number of fingers for the trackpad swipe that scrolls the strip without
/// holding modifier keys. `off` leaves three- and four-finger swipes to macOS.
public enum SwipeFingers: Int, Codable, CaseIterable, Sendable {
    case off = 0
    case three = 3
    case four = 4
}

/// When the slider bar (the mini-map of the strip) is on screen.
public enum SliderBarMode: String, Codable, CaseIterable, Sendable {
    case off
    /// Appears while the strip moves, then fades away.
    case whileMoving
    /// Always visible; windows leave room for it.
    case always
}

public enum SliderBarEdge: String, Codable, CaseIterable, Sendable {
    case top, bottom
}

/// User settings, persisted as JSON. Every field has a default and missing
/// fields decode to it, so older or hand-edited files keep working.
public struct AppSettings: Equatable, Codable, Sendable {
    public var layout = LayoutConfig()
    /// Animate windows into place instead of jumping.
    public var animate = true
    /// Animation length in seconds.
    public var animationDuration = 0.2
    /// Scroll the strip with the mouse wheel or trackpad while holding `scrollModifier`.
    public var modifierSwipe = true
    /// Keys to hold while scrolling to move the strip instead of the app under the pointer.
    public var scrollModifier: Modifiers = [.option]
    /// Scrolling over the menu bar moves the strip, no keys needed.
    public var scrollOverMenuBar = true
    /// Show clickable ‹ › buttons in the menu bar.
    public var showNavigationArrows = false
    /// Tapping this key on its own turns on slide mode.
    public var slideTrigger: SlideTrigger = .rightOption
    /// Scroll the strip with a three- or four-finger swipe.
    public var swipeFingers: SwipeFingers = .off
    /// Multiplier applied to swipe distance.
    public var swipeSensitivity = 1.0
    /// Flip the swipe direction.
    public var invertSwipe = false
    /// Move the mouse pointer to the centre of a window focused from the keyboard.
    public var mouseFollowsFocus = false
    /// Focus the window under the mouse pointer.
    public var focusFollowsMouse = false
    /// Windows in single-window columns keep their own height, top aligned.
    public var keepHeights = false
    /// Draw a coloured border around the focused window.
    public var focusBorder = false
    public var focusBorderWidth = 3.0
    /// Hex colour of the focus border, e.g. "#4C8DFF".
    public var focusBorderColor = "#4C8DFF"
    /// Darken tiled windows that do not have focus.
    public var dimInactive = false
    /// Opacity of the dimming overlay, 0...1.
    public var dimAmount = 0.2
    /// Show "3/8" (focused column / columns) next to the menu bar icon.
    public var showColumnIndicator = true
    /// Where newly opened windows join the strip.
    public var newWindowPosition: Strip.InsertPosition = .afterFocused
    /// Per-app rules.
    public var appRules: [AppRule] = AppSettings.defaultAppRules
    public var keymap: Keymap = .default
    /// The slider bar: a mini-map of the strip you can drag to slide.
    public var sliderBar: SliderBarMode = .whileMoving
    public var sliderBarEdge: SliderBarEdge = .bottom
    /// Clicking the menu bar icon shows the slider; right-click shows the menu.
    public var iconOpensSlider = true
    /// Height reserved for the slider bar when it is always shown.
    public static let sliderBarHeight = 64.0
    /// Group windows into full-screen slides by app as they open.
    public var groupByApp = true
    /// Windows per slide when grouping, unless an app rule says otherwise.
    public var tilesPerSlide = 2
    /// Push the pointer against the left or right screen edge to slide.
    public var hotEdges = false
    /// Slide layouts designed in Settings.
    public var customLayouts: [CustomLayout] = [
        CustomLayout(id: "big-and-two", name: "Big + two", rows: [1, 2]),
        CustomLayout(id: "two-big-two", name: "Two, big, two", rows: [2, 1, 2]),
    ]
    /// Saved app pairs.
    public var appPairs: [AppPair] = []
    /// Profiles: whole sets of workspaces ("Work", "Home").
    public var profiles: [String] = ["Default"]
    /// Show only the workspaces in use, plus one empty one.
    public var dynamicWorkspaces = false
    /// A light tap on Force Touch trackpads when the strip settles.
    public var hapticFeedback = true
    /// Hold ⌥ and pinch on the trackpad to open (pinch in) or close the overview.
    public var pinchForOverview = true
    /// Red dots on slides whose apps show a badge in the Dock.
    public var attentionMarkers = true
    /// Dragging a window to the top of the screen shows layouts to drop it into.
    public var snapPicker = true
    /// Focus mode: how long it lasts (0 = until turned off) and how dark the rest gets.
    public var focusMinutes = 25
    public var focusDim = 0.6
    /// Overrides per display, by display UUID.
    public var displayOverrides: [String: DisplayOverride] = [:]
    public var theme: Theme = .vivid
    /// Keep settings, layouts and app pairs in iCloud Drive, shared by your Macs.
    public var syncThroughICloud = false
    /// A three-finger tap on the trackpad opens the overview.
    public var threeFingerTapOverview = false
    /// Hold ⌥ while hovering a slide in the slider to peek at it full size.
    public var peekWithOption = true
    /// Count switches and pairings on this Mac, for Insights and suggestions.
    public var collectStats = true
    /// Profile and layout changes by time of day or Wi-Fi network.
    public var autoRules: [AutoRule] = []
    /// No gaps around a lone window; wider gaps on big displays.
    public var smartGaps = false
    /// Quick launch: a letter opens or focuses an app (by bundle ID).
    public var launchSlots: [String: String] = [:]
    /// The menu bar shows the focused app's name next to the position.
    public var menuBarShowsApp = false
    /// Hold ⌃⌥ and drag anywhere in a window to move it; right-drag to resize.
    public var modifierDrag = true
    /// Two-finger swipes on a window's title bar: left and right move its
    /// slide, up toggles full width, down minimises.
    public var titleBarSwipes = false
    /// The focus border fades from its colour into a second one.
    public var focusBorderGradient = false
    public var focusBorderColor2 = "#FF5F9E"
    /// A desktop picture per workspace (index → file path).
    public var workspaceWallpapers: [String: String] = [:]
    /// Watch settings.json and pick up changes made in a text editor.
    public var liveReloadSettings = true
    /// Write state.json and post a notification on changes, for SketchyBar
    /// and other status bars.
    public var publishState = false
    /// A script run on events (workspace and focus changes), with details
    /// in environment variables.
    public var eventScript = ""
    /// Skip animations when macOS's Reduce Motion or Low Power Mode is on.
    public var followReduceMotion = true
    /// While resizing by hand, show the window's size.
    public var resizeHUD = true
    /// New windows of an app open at the width you last gave it.
    public var rememberWidths = true
    /// A lone window sits centred at this share of the screen (0 = off).
    public var centerLoneWindow = 0.0
    /// The focused one of two windows in a slide grows to this share (0 = off).
    public var autoGrowFocus = 0.0
    /// Windows whose titles name one of these projects gather in one workspace.
    public var projects: [String] = []
    /// Workspace templates.
    public var templates: [WorkspaceTemplate] = []
    /// Before a calendar event with a meeting link: open it and switch profile.
    public var meetingHelper = false
    public var meetingProfile: Int?
    /// Three- or four-finger vertical swipes switch workspace (sliding up or down).
    public var verticalWorkspaceSwipes = false
    /// ⌥ + pinch zooms out on the strip (instead of opening the overview).
    public var pinchZoomsStrip = true
    /// A local API (and MCP server) for other apps and AI assistants.
    public var localAPI = false
    public var apiPort = 4767
    /// Run JavaScript plugins from the Scripts folder.
    public var scripts = false
    /// Interface language: empty follows macOS.
    public var language = ""
    /// New windows open right after their app's other windows.
    public var openNextToSameApp = false
    /// New windows join the focused slide (toggled by an action).
    public var openIntoFocusedSlide = false
    /// Show the workspace's name in the middle of the screen when switching.
    public var workspaceHUD = true
    /// Window titles on the slider bar's tiles, and a smaller bar.
    public var sliderTitles = false
    public var compactSlider = false
    public var menuBarStyle: MenuBarStyle = .mini
    /// Set once the narrower 1.1 menu bar has been applied to older settings.
    public var compactMenuBarApplied = true
    /// No pop-up notices (confirmations, tips).
    public var quietMode = false
    /// A soft click as the strip lands on a slide.
    public var slideSound = false
    /// VoiceOver says which slide and workspace you moved to.
    public var announceChanges = true
    /// Floating windows go back where you last put them, per app.
    public var rememberFloatingPositions = true
    /// Take a "Last session" snapshot on quit and before sleep.
    public var autoSnapshot = true
    /// Keep a copy of the settings each day (the last seven).
    public var dailyBackups = true
    /// Skip animations while running on battery.
    public var skipAnimationsOnBattery = false
    /// Hold ⌃⌥ for a moment to see a cheat sheet of shortcuts.
    public var cheatSheetOnHold = true
    /// Focus follows mouse waits this long (seconds) before switching.
    public var focusFollowsMouseDelay = 0.15
    /// Caps Lock becomes the Monorail key: hold it instead of ⌃⌥.
    public var capsLockKey = false
    /// Fit mode: every slide shares the screen. On for all workspaces, or
    /// just some; `fitExceptions` lists workspaces (absolute numbers) that differ.
    public var fitByDefault = false
    public var fitExceptions: [Int] = []
    /// A line of notes per workspace (by its number from 0).
    public var workspaceNotes: [String: String] = [:]
    /// Workspaces without a name take their apps' names.
    public var autoNameWorkspaces = true
    /// Get early (beta) versions as well as final ones.
    public var betaUpdates = false
    /// A notification on Monday mornings with last week's Insights.
    public var weeklySummary = true
    /// The version whose What's New was last shown.
    public var lastSeenVersion = ""
    // 1.1
    /// Screen corners: top-left, top-right, bottom-left, bottom-right.
    public var hotCorners: [HotCorner] = [.none, .none, .none, .none]
    /// Mouse buttons 4 and 5 (back and forward) step through slides.
    public var mouseButtonsStep = true
    /// ⌃⌥ + scroll over a window changes its slide's width.
    public var scrollResizes = true
    /// ⇧ + scroll over the slider bar switches workspace.
    public var shiftScrollSwitchesWorkspace = true
    /// ⌥ + middle-click a window zooms it.
    public var middleClickZoom = true
    /// The focus border glows, and can take the app icon's colour.
    public var focusGlow = false
    public var borderFromAppIcon = false
    /// A quick highlight of the focused window when focus moves by keyboard.
    public var focusFlash = false
    /// The slider bar's opacity and size (0.8, 1 or 1.25).
    public var sliderOpacity = 1.0
    public var sliderScale = 1.0
    /// The overview's backdrop: colourful, or plain.
    public var plainOverview = false
    /// The overview with app icons only (no live previews).
    public var overviewIconsOnly = false
    /// The menu bar shows the focused window's title.
    public var menuBarShowsTitle = false
    /// Where notices appear and for how long (seconds).
    public var noticePosition: NoticePosition = .top
    public var noticeDuration = 1.8
    /// Pomodoro: focus and break lengths in minutes.
    public var pomodoroFocus = 25
    public var pomodoroBreak = 5
    /// Remind to rest your eyes every so many minutes (0 = off).
    public var breakReminderMinutes = 0
    /// A daily focus goal in minutes (0 = none), shown in Insights.
    public var dailyFocusGoal = 0
    /// Settings per workspace, by absolute workspace number.
    public var workspaceConfigs: [String: WorkspaceConfig] = [:]
    /// Park a workspace you haven't visited for this many hours (0 = never).
    public var autoParkHours = 0
    /// Windows smaller than this (points, either side) float on their own (0 = off).
    public var floatSmallerThan = 0.0
    /// Settings and preferences windows float.
    public var floatSettingsWindows = true
    /// Tiling pauses while one of these apps (bundle IDs) is in front.
    public var pauseForApps: [String] = []
    /// Lay everything out again after the Mac wakes.
    public var retileAfterWake = true
    public var animationCurve: AnimationCurve = .smooth
    /// Animation frames per second: 30, 60 or 120.
    public var animationFPS = 60
    /// Bring every window back after Monorail quit unexpectedly.
    public var rescueAfterCrash = true
    /// The click sound for slide changes.
    public var clickSound = "Tink"
    /// VoiceOver also says which window got focus.
    public var announceWindows = false
    /// POST events as JSON to this address (empty = off).
    public var webhookURL = ""
    /// Let other apps run actions with the org.ashforde.monorail.perform distributed notification.
    public var remoteCommands = false
    /// Bring the window you usually go to next right beside the one you are in.
    public var stageNextWindow = false
    /// Suggest focus mode when you switch windows very often.
    public var distractionNudges = true
    /// New slides get a width that suits the app: ~100 columns of code, a page of text, a web page.
    public var contentAwareWidths = false
    /// Documents from these folders open in these workspaces.
    public var pathRules: [PathRule] = []
    /// Remember the layout for each set of displays and bring it back when they connect again.
    public var displayProfiles = false
    /// Tell me when an AI coding agent in a terminal is waiting for me.
    public var agentAlerts = true
    /// Slide a waiting agent's window into view.
    public var agentBringIntoView = false
    /// Suggest rules from the fixes you keep making.
    public var ruleSuggestions = true
    /// Widths Monorail noticed you keep giving apps (bundle ID → share), waiting to become rules.
    public var suggestedRules: [String: Double] = [:]
    /// The key that acts as the Monorail key.
    public var monorailKeySource: MonorailKeySource = .capsLock
    /// ⌃⌥⇧ + drag left, right, up or down for workspaces, the overview and the desktop.
    public var mouseGestures = false
    /// Run actions from a MIDI controller.
    public var midiControl = false
    /// MIDI note number → action name.
    public var midiMap: [String: String] = [:]
    /// Drive Monorail with a game controller.
    public var gameController = false
    /// A remote control page for your phone on the local network.
    public var webRemote = false
    /// The secret in the remote page link.
    public var webRemoteToken = ""
    /// Experimental: turn your head towards a display to focus it (uses the camera).
    public var headFocus = false
    /// Apps hidden during deep work (bundle IDs).
    public var deepWorkApps: [String] = ["com.tinyspeck.slackmacgap", "com.apple.MobileSMS", "com.hnc.Discord", "com.apple.mail"]
    /// Calendar events called Focus or Deep work turn deep work on.
    public var deepWorkFromCalendar = false
    /// Hide private apps while you share your screen.
    public var safeScreenShare = true
    /// Apps whose windows count as private (bundle IDs).
    public var privateApps: [String] = ["com.apple.MobileSMS", "net.whatsapp.WhatsApp", "com.apple.mail", "com.apple.Passwords", "com.1password.1password"]
    /// Blur private windows in the overview and previews.
    public var privacyBlur = true
    /// Dimming follows the pointer instead of focus.
    public var dimFollowsPointer = false
    /// On battery, animate at 30 fps and pause live previews.
    public var energySaver = true
    /// Your presenter notes (never shown in screen shares).
    public var presenterNotes = ""
    /// Keep a clipboard history for each workspace.
    public var workspaceClipboard = true
    /// A picture that drifts gently behind the strip as it scrolls (empty = off).
    public var driftWallpaper = ""
    /// Show slides and workspaces around the MacBook notch as you move.
    public var notchHUD = false
    /// The sounds Monorail plays.
    public var soundPack: SoundPack = .classic
    /// Keep crash and hang reports on this Mac so you can send them.
    public var crashReports = false
    /// Ask before an assistant or script closes windows.
    public var confirmDestructiveAPI = true
    /// Slides off screen wait hidden in the corner (no slivers at the screen edges).
    public var parkInCorner = true
    /// Hide slides that only partly fit on screen, instead of showing them cut off at the edge.
    public var wholeSlidesOnly = true
    /// Fit mode never makes a window narrower than this (points; a pair needs twice as much); extra slides scroll.
    public var fitMinimumWidth = 480.0
    /// Stay Awake keeps the display on too (otherwise only the Mac stays awake and the display may sleep).
    public var awakeKeepDisplayOn = true
    /// Let the screen saver start during a Stay Awake session (the Mac still stays awake).
    public var awakeAllowScreenSaver = false
    /// How long Stay Awake lasts when toggled on (0 = until you end it).
    public var awakeDefaultMinutes = 0
    /// End Stay Awake when the battery drops to this percent on battery power (0 = never).
    public var awakeBatteryCutoff = 10
    /// During Stay Awake, nudge the pointer now and then so chat apps don’t mark you away.
    public var awakeMoveCursor = false
    /// How often the pointer is nudged (minutes).
    public var awakeMoveCursorMinutes = 4
    /// During Stay Awake, keep external drives from spinning down.
    public var awakeDriveAlive = false
    /// During Stay Awake, keep running with the lid closed, even without an external display (asks for your password).
    public var awakeClosedLid = false
    /// Show a notice when Stay Awake starts and ends.
    public var awakeNotify = true
    /// Play a sound when Stay Awake starts and ends.
    public var awakeSound = false
    /// Show the time left in the menu bar.
    public var awakeShowTime = true
    /// Start Stay Awake when Monorail opens.
    public var awakeOnLaunch = false
    /// Things that start Stay Awake by themselves.
    public var awakeTriggers: [AwakeTrigger] = []
    /// Automatic Stay Awake triggers are on.
    public var awakeTriggersOn = true
    /// During Stay Awake, still lock the screen after this many idle minutes (0 = never).
    public var awakeLockAfterMinutes = 0
    /// List the workspace’s windows right in the menu bar menu (otherwise they are in a Windows submenu).
    public var menuWindowsInline = false
    /// When a call opens from your calendar, put your notes app beside it (and keep your layout to bring back afterwards).
    public var meetingLayout = false
    /// The notes app put beside calls (bundle ID).
    public var meetingNotesApp = "com.apple.Notes"
    /// On a Sidecar iPad, every slide fits on screen.
    public var sidecarFit = true
    /// Tips already shown.
    public var seenTips: [String] = []
    /// Snap windows back when an app moves or resizes one by itself.
    public var keepWindowsInPlace = true
    /// After resizing a window in a slide, offer to rearrange the slide.
    public var resizeAssist = true
    /// Put a newly opened lone window into a slide with another app's lone
    /// window. When off, that only happens when regrouping (⌃⌥A).
    public var pairLoneWindowsOnOpen = false
    /// Layout of new slides, unless an app rule says otherwise.
    public var slideArrangement: Arrangement = .grid
    /// Workspaces per display (1...9). Each has its own strip.
    public var workspaceCount = 4
    /// Names for workspaces, by index; empty or missing means "Workspace N".
    public var workspaceNames: [String] = []
    /// Look for new versions on GitHub once a day.
    public var checkForUpdates = true
    /// Install new versions without asking (Monorail relaunches itself).
    public var installUpdatesAutomatically = false
    /// Bumped when new default app rules ship, so existing settings pick them up once.
    public var rulesVersion = AppSettings.currentRulesVersion
    public static let currentRulesVersion = 2
    /// Set once the welcome tour has been shown.
    public var hasCompletedOnboarding = false

    public static let defaultAppRules = [
        AppRule(bundleID: "com.apple.systempreferences", name: "System Settings", float: true),
        AppRule(bundleID: "com.apple.calculator", name: "Calculator", float: true),
        AppRule(bundleID: "com.apple.ActivityMonitor", name: "Activity Monitor", float: true),
        AppRule(bundleID: "com.apple.archiveutility", name: "Archive Utility", float: true),
        AppRule(bundleID: "com.apple.Terminal", name: "Terminal", tiles: 4),
        AppRule(bundleID: "com.googlecode.iterm2", name: "iTerm", tiles: 4),
        AppRule(bundleID: "com.mitchellh.ghostty", name: "Ghostty", tiles: 4),
        AppRule(bundleID: "dev.warp.Warp-Stable", name: "Warp", tiles: 4),
        AppRule(bundleID: "net.kovidgoyal.kitty", name: "kitty", tiles: 4),
        AppRule(bundleID: "org.alacritty", name: "Alacritty", tiles: 4),
        AppRule(bundleID: "com.github.wez.wezterm", name: "WezTerm", tiles: 4),
    ]

    public init() {}

    /// The rule for every window of an app (not a title rule).
    public func rule(for bundleID: String?) -> AppRule? {
        guard let bundleID else { return nil }
        return appRules.first { $0.bundleID == bundleID && !$0.isTitleRule }
    }

    /// The rule for one window: a title rule that matches it, else the app's rule.
    public func rule(for bundleID: String?, title: String) -> AppRule? {
        guard let bundleID else { return nil }
        return appRules.first { $0.bundleID == bundleID && $0.isTitleRule && $0.matches(title: title) }
            ?? rule(for: bundleID)
    }

    /// Gaps and widths on one display, with its overrides applied. With smart
    /// gaps, a lone window gets no gaps and displays 2560 points or wider get
    /// half as much again.
    public func layout(for displayUUID: String, displayWidth: Double = 0, windowCount: Int = 2) -> LayoutConfig {
        var config = layout
        if let override = displayOverrides[displayUUID] {
            if let gap = override.gap { config.gap = gap }
            if let edgeGap = override.edgeGap { config.edgeGap = edgeGap }
            if let width = override.defaultWidth { config.defaultWidth = width }
        }
        guard smartGaps else { return config }
        if windowCount <= 1 {
            config.gap = 0
            config.edgeGap = 0
        } else if displayWidth >= 2560 {
            config.gap = (config.gap * 1.5).rounded()
            config.edgeGap = (config.edgeGap * 1.5).rounded()
        }
        return config
    }

    /// Settings for one workspace (absolute number).
    public func workspaceConfig(_ workspace: Int) -> WorkspaceConfig {
        workspaceConfigs[String(workspace)] ?? WorkspaceConfig()
    }

    /// True if workspace `workspace` (absolute number) fits every slide on screen.
    public func isFit(_ workspace: Int) -> Bool {
        fitByDefault != fitExceptions.contains(workspace)
    }

    /// Turns fit mode on or off for one workspace.
    public mutating func setFit(_ on: Bool, for workspace: Int) {
        fitExceptions.removeAll { $0 == workspace }
        if on != fitByDefault { fitExceptions.append(workspace) }
    }

    /// Applies a start-up style on top of the current settings.
    public mutating func apply(_ style: StartStyle) {
        switch style {
        case .scrolling:
            fitByDefault = false
            fitExceptions = []
            sliderBar = .whileMoving
            quietMode = false
        case .fit:
            fitByDefault = true
            fitExceptions = []
            sliderBar = .off
            quietMode = false
        case .minimal:
            fitByDefault = false
            fitExceptions = []
            sliderBar = .off
            quietMode = true
            showNavigationArrows = false
            workspaceHUD = false
        }
    }

    /// Whether the slider bar shows on one display.
    public func sliderBar(for displayUUID: String) -> SliderBarMode {
        displayOverrides[displayUUID]?.sliderBar ?? sliderBar
    }

    /// Windows per slide for an app when grouping by app.
    public func tiles(for bundleID: String?) -> Int {
        min(max(rule(for: bundleID)?.tiles ?? tilesPerSlide, 1), Column.maximumWindows)
    }

    /// The name shown for workspace `index` (0-based).
    public func workspaceName(_ index: Int) -> String {
        let name = workspaceNames.indices.contains(index)
            ? workspaceNames[index].trimmingCharacters(in: .whitespaces) : ""
        return name.isEmpty ? "Workspace \(index + 1)" : name
    }

    public mutating func setWorkspaceName(_ name: String, at index: Int) {
        guard index >= 0 else { return }
        while workspaceNames.count <= index { workspaceNames.append("") }
        // Stored as typed (so a text field can hold a trailing space); trimmed when shown.
        workspaceNames[index] = name
    }

    /// Layout for a new slide of an app.
    public func arrangement(for bundleID: String?) -> Arrangement {
        rule(for: bundleID)?.arrangement ?? slideArrangement
    }

    private enum CodingKeys: String, CodingKey {
        case layout, animate, animationDuration, modifierSwipe, scrollModifier, scrollOverMenuBar
        case showNavigationArrows, slideTrigger, swipeFingers, swipeSensitivity, invertSwipe
        case mouseFollowsFocus, focusFollowsMouse, keepHeights, focusBorder, focusBorderWidth
        case focusBorderColor, dimInactive, dimAmount, showColumnIndicator, newWindowPosition
        case appRules, keymap, hasCompletedOnboarding, groupByApp, tilesPerSlide, workspaceCount
        case checkForUpdates, rulesVersion, sliderBar, sliderBarEdge, slideArrangement, iconOpensSlider, pairLoneWindowsOnOpen, keepWindowsInPlace, installUpdatesAutomatically, resizeAssist, workspaceNames, hotEdges, customLayouts, appPairs, profiles, dynamicWorkspaces
        case hapticFeedback, pinchForOverview, attentionMarkers, snapPicker
        case focusMinutes, focusDim, displayOverrides, theme, syncThroughICloud, threeFingerTapOverview
        case peekWithOption, collectStats, autoRules, smartGaps, launchSlots, menuBarShowsApp
        case modifierDrag, titleBarSwipes, focusBorderGradient, focusBorderColor2, workspaceWallpapers
        case liveReloadSettings, publishState, eventScript, followReduceMotion, resizeHUD
        case rememberWidths, centerLoneWindow, autoGrowFocus, projects, templates, meetingHelper, meetingProfile
        case verticalWorkspaceSwipes, pinchZoomsStrip, localAPI, apiPort, scripts, language
        case openNextToSameApp, openIntoFocusedSlide, workspaceHUD, sliderTitles, compactSlider, menuBarStyle, quietMode
        case slideSound, announceChanges, rememberFloatingPositions, autoSnapshot, dailyBackups, skipAnimationsOnBattery
        case cheatSheetOnHold, focusFollowsMouseDelay
        case capsLockKey, fitByDefault, fitExceptions, workspaceNotes, autoNameWorkspaces, betaUpdates, weeklySummary
        case lastSeenVersion
        case hotCorners, mouseButtonsStep, scrollResizes, shiftScrollSwitchesWorkspace, middleClickZoom, focusGlow
        case borderFromAppIcon, focusFlash, sliderOpacity, sliderScale, plainOverview, overviewIconsOnly, menuBarShowsTitle
        case noticePosition, noticeDuration, pomodoroFocus, pomodoroBreak, breakReminderMinutes, dailyFocusGoal
        case workspaceConfigs, autoParkHours, floatSmallerThan, floatSettingsWindows, pauseForApps, retileAfterWake
        case animationCurve, animationFPS, rescueAfterCrash, clickSound, announceWindows, webhookURL, remoteCommands, compactMenuBarApplied, meetingLayout, meetingNotesApp, sidecarFit, seenTips, menuWindowsInline, awakeKeepDisplayOn, awakeAllowScreenSaver, awakeDefaultMinutes, awakeBatteryCutoff, awakeMoveCursor, awakeMoveCursorMinutes, awakeDriveAlive, awakeClosedLid, awakeNotify, awakeSound, awakeShowTime, awakeOnLaunch, awakeTriggers, awakeTriggersOn, awakeLockAfterMinutes, fitMinimumWidth, wholeSlidesOnly, parkInCorner, monorailKeySource, mouseGestures, midiControl, midiMap, gameController, webRemote, webRemoteToken, headFocus, deepWorkApps, deepWorkFromCalendar, safeScreenShare, privateApps, privacyBlur, dimFollowsPointer, energySaver, presenterNotes, workspaceClipboard, driftWallpaper, notchHUD, soundPack, crashReports, confirmDestructiveAPI, stageNextWindow, distractionNudges, contentAwareWidths, pathRules, displayProfiles, agentAlerts, agentBringIntoView, ruleSuggestions, suggestedRules
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        layout = value(.layout, d.layout)
        animate = value(.animate, d.animate)
        animationDuration = value(.animationDuration, d.animationDuration)
        modifierSwipe = value(.modifierSwipe, d.modifierSwipe)
        scrollModifier = value(.scrollModifier, d.scrollModifier)
        scrollOverMenuBar = value(.scrollOverMenuBar, d.scrollOverMenuBar)
        showNavigationArrows = value(.showNavigationArrows, d.showNavigationArrows)
        slideTrigger = value(.slideTrigger, d.slideTrigger)
        swipeFingers = value(.swipeFingers, d.swipeFingers)
        swipeSensitivity = value(.swipeSensitivity, d.swipeSensitivity)
        invertSwipe = value(.invertSwipe, d.invertSwipe)
        mouseFollowsFocus = value(.mouseFollowsFocus, d.mouseFollowsFocus)
        focusFollowsMouse = value(.focusFollowsMouse, d.focusFollowsMouse)
        keepHeights = value(.keepHeights, d.keepHeights)
        focusBorder = value(.focusBorder, d.focusBorder)
        focusBorderWidth = value(.focusBorderWidth, d.focusBorderWidth)
        focusBorderColor = value(.focusBorderColor, d.focusBorderColor)
        dimInactive = value(.dimInactive, d.dimInactive)
        dimAmount = value(.dimAmount, d.dimAmount)
        showColumnIndicator = value(.showColumnIndicator, d.showColumnIndicator)
        newWindowPosition = value(.newWindowPosition, d.newWindowPosition)
        appRules = value(.appRules, d.appRules)
        keymap = value(.keymap, d.keymap)
        // Actions added in an update get their default keys, unless those keys
        // are already taken.
        for (action, shortcuts) in Keymap.default.bindings where keymap.bindings[action] == nil {
            keymap.bindings[action] = shortcuts.filter { keymap.action(for: $0) == nil }
        }
        hasCompletedOnboarding = value(.hasCompletedOnboarding, d.hasCompletedOnboarding)
        groupByApp = value(.groupByApp, d.groupByApp)
        tilesPerSlide = min(max(value(.tilesPerSlide, d.tilesPerSlide), 1), Column.maximumWindows)
        workspaceCount = min(max(value(.workspaceCount, d.workspaceCount), 1), 9)
        checkForUpdates = value(.checkForUpdates, d.checkForUpdates)
        sliderBar = value(.sliderBar, d.sliderBar)
        slideArrangement = value(.slideArrangement, d.slideArrangement)
        sliderBarEdge = value(.sliderBarEdge, d.sliderBarEdge)
        iconOpensSlider = value(.iconOpensSlider, d.iconOpensSlider)
        pairLoneWindowsOnOpen = value(.pairLoneWindowsOnOpen, d.pairLoneWindowsOnOpen)
        keepWindowsInPlace = value(.keepWindowsInPlace, d.keepWindowsInPlace)
        resizeAssist = value(.resizeAssist, d.resizeAssist)
        workspaceNames = value(.workspaceNames, d.workspaceNames)
        hotEdges = value(.hotEdges, d.hotEdges)
        customLayouts = value(.customLayouts, d.customLayouts)
        appPairs = value(.appPairs, d.appPairs)
        profiles = value(.profiles, d.profiles)
        if profiles.isEmpty { profiles = d.profiles }
        dynamicWorkspaces = value(.dynamicWorkspaces, d.dynamicWorkspaces)
        hapticFeedback = value(.hapticFeedback, d.hapticFeedback)
        pinchForOverview = value(.pinchForOverview, d.pinchForOverview)
        attentionMarkers = value(.attentionMarkers, d.attentionMarkers)
        snapPicker = value(.snapPicker, d.snapPicker)
        focusMinutes = value(.focusMinutes, d.focusMinutes)
        focusDim = value(.focusDim, d.focusDim)
        displayOverrides = value(.displayOverrides, d.displayOverrides)
        theme = value(.theme, d.theme)
        syncThroughICloud = value(.syncThroughICloud, d.syncThroughICloud)
        threeFingerTapOverview = value(.threeFingerTapOverview, d.threeFingerTapOverview)
        peekWithOption = value(.peekWithOption, d.peekWithOption)
        collectStats = value(.collectStats, d.collectStats)
        autoRules = value(.autoRules, d.autoRules)
        smartGaps = value(.smartGaps, d.smartGaps)
        launchSlots = value(.launchSlots, d.launchSlots)
        menuBarShowsApp = value(.menuBarShowsApp, d.menuBarShowsApp)
        modifierDrag = value(.modifierDrag, d.modifierDrag)
        titleBarSwipes = value(.titleBarSwipes, d.titleBarSwipes)
        focusBorderGradient = value(.focusBorderGradient, d.focusBorderGradient)
        focusBorderColor2 = value(.focusBorderColor2, d.focusBorderColor2)
        workspaceWallpapers = value(.workspaceWallpapers, d.workspaceWallpapers)
        liveReloadSettings = value(.liveReloadSettings, d.liveReloadSettings)
        publishState = value(.publishState, d.publishState)
        eventScript = value(.eventScript, d.eventScript)
        followReduceMotion = value(.followReduceMotion, d.followReduceMotion)
        resizeHUD = value(.resizeHUD, d.resizeHUD)
        rememberWidths = value(.rememberWidths, d.rememberWidths)
        centerLoneWindow = value(.centerLoneWindow, d.centerLoneWindow)
        autoGrowFocus = value(.autoGrowFocus, d.autoGrowFocus)
        projects = value(.projects, d.projects)
        templates = value(.templates, d.templates)
        meetingHelper = value(.meetingHelper, d.meetingHelper)
        meetingProfile = try? c.decodeIfPresent(Int.self, forKey: .meetingProfile)
        verticalWorkspaceSwipes = value(.verticalWorkspaceSwipes, d.verticalWorkspaceSwipes)
        pinchZoomsStrip = value(.pinchZoomsStrip, d.pinchZoomsStrip)
        localAPI = value(.localAPI, d.localAPI)
        apiPort = value(.apiPort, d.apiPort)
        scripts = value(.scripts, d.scripts)
        language = value(.language, d.language)
        openNextToSameApp = value(.openNextToSameApp, d.openNextToSameApp)
        openIntoFocusedSlide = value(.openIntoFocusedSlide, d.openIntoFocusedSlide)
        workspaceHUD = value(.workspaceHUD, d.workspaceHUD)
        sliderTitles = value(.sliderTitles, d.sliderTitles)
        compactSlider = value(.compactSlider, d.compactSlider)
        menuBarStyle = value(.menuBarStyle, d.menuBarStyle)
        quietMode = value(.quietMode, d.quietMode)
        slideSound = value(.slideSound, d.slideSound)
        announceChanges = value(.announceChanges, d.announceChanges)
        rememberFloatingPositions = value(.rememberFloatingPositions, d.rememberFloatingPositions)
        autoSnapshot = value(.autoSnapshot, d.autoSnapshot)
        dailyBackups = value(.dailyBackups, d.dailyBackups)
        skipAnimationsOnBattery = value(.skipAnimationsOnBattery, d.skipAnimationsOnBattery)
        cheatSheetOnHold = value(.cheatSheetOnHold, d.cheatSheetOnHold)
        focusFollowsMouseDelay = value(.focusFollowsMouseDelay, d.focusFollowsMouseDelay)
        capsLockKey = value(.capsLockKey, d.capsLockKey)
        fitByDefault = value(.fitByDefault, d.fitByDefault)
        fitExceptions = value(.fitExceptions, d.fitExceptions)
        workspaceNotes = value(.workspaceNotes, d.workspaceNotes)
        autoNameWorkspaces = value(.autoNameWorkspaces, d.autoNameWorkspaces)
        betaUpdates = value(.betaUpdates, d.betaUpdates)
        weeklySummary = value(.weeklySummary, d.weeklySummary)
        lastSeenVersion = value(.lastSeenVersion, d.lastSeenVersion)
        hotCorners = value(.hotCorners, d.hotCorners)
        if hotCorners.count != 4 { hotCorners = d.hotCorners }
        mouseButtonsStep = value(.mouseButtonsStep, d.mouseButtonsStep)
        scrollResizes = value(.scrollResizes, d.scrollResizes)
        shiftScrollSwitchesWorkspace = value(.shiftScrollSwitchesWorkspace, d.shiftScrollSwitchesWorkspace)
        middleClickZoom = value(.middleClickZoom, d.middleClickZoom)
        focusGlow = value(.focusGlow, d.focusGlow)
        borderFromAppIcon = value(.borderFromAppIcon, d.borderFromAppIcon)
        focusFlash = value(.focusFlash, d.focusFlash)
        sliderOpacity = value(.sliderOpacity, d.sliderOpacity)
        sliderScale = value(.sliderScale, d.sliderScale)
        plainOverview = value(.plainOverview, d.plainOverview)
        overviewIconsOnly = value(.overviewIconsOnly, d.overviewIconsOnly)
        menuBarShowsTitle = value(.menuBarShowsTitle, d.menuBarShowsTitle)
        noticePosition = value(.noticePosition, d.noticePosition)
        noticeDuration = value(.noticeDuration, d.noticeDuration)
        pomodoroFocus = value(.pomodoroFocus, d.pomodoroFocus)
        pomodoroBreak = value(.pomodoroBreak, d.pomodoroBreak)
        breakReminderMinutes = value(.breakReminderMinutes, d.breakReminderMinutes)
        dailyFocusGoal = value(.dailyFocusGoal, d.dailyFocusGoal)
        workspaceConfigs = value(.workspaceConfigs, d.workspaceConfigs)
        autoParkHours = value(.autoParkHours, d.autoParkHours)
        floatSmallerThan = value(.floatSmallerThan, d.floatSmallerThan)
        floatSettingsWindows = value(.floatSettingsWindows, d.floatSettingsWindows)
        pauseForApps = value(.pauseForApps, d.pauseForApps)
        retileAfterWake = value(.retileAfterWake, d.retileAfterWake)
        animationCurve = value(.animationCurve, d.animationCurve)
        animationFPS = value(.animationFPS, d.animationFPS)
        rescueAfterCrash = value(.rescueAfterCrash, d.rescueAfterCrash)
        clickSound = value(.clickSound, d.clickSound)
        announceWindows = value(.announceWindows, d.announceWindows)
        webhookURL = value(.webhookURL, d.webhookURL)
        remoteCommands = value(.remoteCommands, d.remoteCommands)
        meetingLayout = value(.meetingLayout, d.meetingLayout)
        meetingNotesApp = value(.meetingNotesApp, d.meetingNotesApp)
        sidecarFit = value(.sidecarFit, d.sidecarFit)
        seenTips = value(.seenTips, d.seenTips)
        menuWindowsInline = value(.menuWindowsInline, d.menuWindowsInline)
        awakeKeepDisplayOn = value(.awakeKeepDisplayOn, d.awakeKeepDisplayOn)
        awakeAllowScreenSaver = value(.awakeAllowScreenSaver, d.awakeAllowScreenSaver)
        awakeDefaultMinutes = value(.awakeDefaultMinutes, d.awakeDefaultMinutes)
        awakeBatteryCutoff = value(.awakeBatteryCutoff, d.awakeBatteryCutoff)
        awakeMoveCursor = value(.awakeMoveCursor, d.awakeMoveCursor)
        awakeMoveCursorMinutes = value(.awakeMoveCursorMinutes, d.awakeMoveCursorMinutes)
        awakeDriveAlive = value(.awakeDriveAlive, d.awakeDriveAlive)
        awakeClosedLid = value(.awakeClosedLid, d.awakeClosedLid)
        awakeNotify = value(.awakeNotify, d.awakeNotify)
        awakeSound = value(.awakeSound, d.awakeSound)
        awakeShowTime = value(.awakeShowTime, d.awakeShowTime)
        awakeOnLaunch = value(.awakeOnLaunch, d.awakeOnLaunch)
        awakeTriggers = value(.awakeTriggers, d.awakeTriggers)
        awakeTriggersOn = value(.awakeTriggersOn, d.awakeTriggersOn)
        awakeLockAfterMinutes = value(.awakeLockAfterMinutes, d.awakeLockAfterMinutes)
        fitMinimumWidth = value(.fitMinimumWidth, d.fitMinimumWidth)
        wholeSlidesOnly = value(.wholeSlidesOnly, d.wholeSlidesOnly)
        parkInCorner = value(.parkInCorner, d.parkInCorner)
        monorailKeySource = value(.monorailKeySource, d.monorailKeySource)
        mouseGestures = value(.mouseGestures, d.mouseGestures)
        midiControl = value(.midiControl, d.midiControl)
        midiMap = value(.midiMap, d.midiMap)
        gameController = value(.gameController, d.gameController)
        webRemote = value(.webRemote, d.webRemote)
        webRemoteToken = value(.webRemoteToken, d.webRemoteToken)
        headFocus = value(.headFocus, d.headFocus)
        deepWorkApps = value(.deepWorkApps, d.deepWorkApps)
        deepWorkFromCalendar = value(.deepWorkFromCalendar, d.deepWorkFromCalendar)
        safeScreenShare = value(.safeScreenShare, d.safeScreenShare)
        privateApps = value(.privateApps, d.privateApps)
        privacyBlur = value(.privacyBlur, d.privacyBlur)
        dimFollowsPointer = value(.dimFollowsPointer, d.dimFollowsPointer)
        energySaver = value(.energySaver, d.energySaver)
        presenterNotes = value(.presenterNotes, d.presenterNotes)
        workspaceClipboard = value(.workspaceClipboard, d.workspaceClipboard)
        driftWallpaper = value(.driftWallpaper, d.driftWallpaper)
        notchHUD = value(.notchHUD, d.notchHUD)
        soundPack = value(.soundPack, d.soundPack)
        crashReports = value(.crashReports, d.crashReports)
        confirmDestructiveAPI = value(.confirmDestructiveAPI, d.confirmDestructiveAPI)
        stageNextWindow = value(.stageNextWindow, d.stageNextWindow)
        distractionNudges = value(.distractionNudges, d.distractionNudges)
        contentAwareWidths = value(.contentAwareWidths, d.contentAwareWidths)
        pathRules = value(.pathRules, d.pathRules)
        displayProfiles = value(.displayProfiles, d.displayProfiles)
        agentAlerts = value(.agentAlerts, d.agentAlerts)
        agentBringIntoView = value(.agentBringIntoView, d.agentBringIntoView)
        ruleSuggestions = value(.ruleSuggestions, d.ruleSuggestions)
        suggestedRules = value(.suggestedRules, d.suggestedRules)
        // Settings from before 1.1 get the narrow menu bar once.
        compactMenuBarApplied = (try? c.decodeIfPresent(Bool.self, forKey: .compactMenuBarApplied)) ?? false
        if !compactMenuBarApplied {
            compactMenuBarApplied = true
            showNavigationArrows = false
            if menuBarStyle == .glyph { menuBarStyle = .mini }
        }
        installUpdatesAutomatically = value(.installUpdatesAutomatically, d.installUpdatesAutomatically)
        rulesVersion = value(.rulesVersion, 1)
        if rulesVersion < Self.currentRulesVersion {
            // Version 2 added the terminal rules (four tiles per slide).
            let known = Set(appRules.map(\.bundleID))
            appRules += Self.defaultAppRules.filter { $0.tiles != nil && !known.contains($0.bundleID) }
            rulesVersion = Self.currentRulesVersion
        }
    }
}
