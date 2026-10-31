/// Everything Monorail can do from a shortcut or a `monorail://` URL.
/// Raw values are stable: they are stored in the config file and used as URL hosts.
public enum Action: String, Codable, CaseIterable, Sendable {
    case focusLeft = "focus-left"
    case focusRight = "focus-right"
    case focusUp = "focus-up"
    case focusDown = "focus-down"
    case focusFirst = "focus-first"
    case focusLast = "focus-last"
    case focusColumn1 = "focus-column-1"
    case focusColumn2 = "focus-column-2"
    case focusColumn3 = "focus-column-3"
    case focusColumn4 = "focus-column-4"
    case focusColumn5 = "focus-column-5"
    case focusColumn6 = "focus-column-6"
    case focusColumn7 = "focus-column-7"
    case focusColumn8 = "focus-column-8"
    case focusColumn9 = "focus-column-9"
    case moveLeft = "move-left"
    case moveRight = "move-right"
    case moveUp = "move-up"
    case moveDown = "move-down"
    case cycleWidth = "cycle-width"
    case cycleWidthBackward = "cycle-width-backward"
    case narrower
    case wider
    case toggleFullWidth = "full-width"
    case center
    case consumeIntoLeft = "stack-into-left"
    case consumeIntoRight = "stack-into-right"
    case expelLeft = "unstack-left"
    case expel = "unstack"
    case toggleFloat = "toggle-float"
    case pinLeft = "pin-left"
    case pinRight = "pin-right"
    case toggleTabbed = "toggle-tabbed"
    case cycleLayout = "cycle-layout"
    case mainLarger = "main-larger"
    case mainSmaller = "main-smaller"
    case makeMain = "make-main"
    case regroup
    case overview
    case toggleNativeFullScreen = "toggle-fullscreen"
    case windowSwitcher = "window-switcher"
    case sendToNextDisplay = "send-to-next-display"
    case workspace1 = "workspace-1"
    case workspace2 = "workspace-2"
    case workspace3 = "workspace-3"
    case workspace4 = "workspace-4"
    case workspace5 = "workspace-5"
    case workspace6 = "workspace-6"
    case workspace7 = "workspace-7"
    case workspace8 = "workspace-8"
    case workspace9 = "workspace-9"
    case moveToWorkspace1 = "move-to-workspace-1"
    case moveToWorkspace2 = "move-to-workspace-2"
    case moveToWorkspace3 = "move-to-workspace-3"
    case moveToWorkspace4 = "move-to-workspace-4"
    case moveToWorkspace5 = "move-to-workspace-5"
    case moveToWorkspace6 = "move-to-workspace-6"
    case moveToWorkspace7 = "move-to-workspace-7"
    case moveToWorkspace8 = "move-to-workspace-8"
    case moveToWorkspace9 = "move-to-workspace-9"
    case snapLeftHalf = "snap-left-half"
    case snapRightHalf = "snap-right-half"
    case snapTopHalf = "snap-top-half"
    case snapBottomHalf = "snap-bottom-half"
    case snapFirstThird = "snap-first-third"
    case snapCenterThird = "snap-center-third"
    case snapLastThird = "snap-last-third"
    case snapFirstTwoThirds = "snap-first-two-thirds"
    case snapLastTwoThirds = "snap-last-two-thirds"
    case snapTopLeft = "snap-top-left"
    case snapTopRight = "snap-top-right"
    case snapBottomLeft = "snap-bottom-left"
    case snapBottomRight = "snap-bottom-right"
    case snapMaximize = "snap-maximize"
    case snapCenter = "snap-center"
    case snapRestore = "snap-restore"
    case setMark = "set-mark"
    case jumpToMark = "jump-to-mark"
    case toggleScratchpad = "scratchpad"
    case makeScratchpad = "make-scratchpad"
    case nextProfile = "next-profile"
    case toggleFocusMode = "focus-mode"
    case commandPalette = "command-palette"
    case takeSnapshot = "snapshot"
    case toggleSticky = "sticky"
    case zoomTile = "zoom"
    case lastWindow = "last-window"
    case quickLaunch = "launch"
    case pictureInPicture = "picture-in-picture"
    case radialMenu = "radial-menu"
    case balanceSizes = "balance"
    case workspaceBackAndForth = "workspace-back"
    case moveToEmptyWorkspace = "move-to-empty-workspace"
    case focusAttention = "focus-attention"
    case showDesktop = "show-desktop"
    case screenshotSlide = "screenshot-slide"
    case appOverview = "app-overview"
    case windowHints = "hints"
    case resizeMode = "resize-mode"
    case stripZoom = "strip-zoom"
    case presentationMode = "presentation-mode"
    case recordSlide = "record-slide"
    case redo = "redo"
    case nextWorkspace = "next-workspace"
    case previousWorkspace = "previous-workspace"
    case moveToNextWorkspace = "move-to-next-workspace"
    case moveToPreviousWorkspace = "move-to-previous-workspace"
    case focusNextDisplay = "focus-next-display"
    case moveWorkspaceToNextDisplay = "move-workspace-to-next-display"
    case swapDisplays = "swap-displays"
    case moveToPointerDisplay = "move-to-pointer-display"
    case cycleAppWindows = "cycle-app-windows"
    case swapWithRecent = "swap-with-recent"
    case rotateSlide = "rotate-slide"
    case flipSlide = "flip-slide"
    case expandToFill = "expand-to-fill"
    case closeSlide = "close-slide"
    case minimizeSlide = "minimize-slide"
    case gatherApp = "gather-app"
    case sortSlides = "sort-slides"
    case tileAllFloating = "tile-floating"
    case rescueWindows = "rescue-windows"
    case soloMode = "solo"
    case toggleGaps = "toggle-gaps"
    case biggerGaps = "bigger-gaps"
    case smallerGaps = "smaller-gaps"
    case centerFloating = "center-floating"
    case lockSlide = "lock-slide"
    case openIntoSlide = "open-into-slide"
    case cheatSheet = "cheat-sheet"
    case nameSlide = "name-slide"
    case toggleFitMode = "fit-mode"
    case slideToStart = "slide-to-start"
    case slideToEnd = "slide-to-end"
    case slideToNextWorkspace = "slide-to-next-workspace"
    case slideToPreviousWorkspace = "slide-to-previous-workspace"
    case slideToEmptyWorkspace = "slide-to-empty-workspace"
    case unpairSlide = "unpair-slide"
    case mergeNext = "merge-next"
    case mergePrevious = "merge-previous"
    case nextTile = "next-tile"
    case previousTile = "previous-tile"
    case mainTile = "main-tile"
    case widthQuarter = "width-quarter"
    case widthThird = "width-third"
    case widthHalf = "width-half"
    case widthTwoThirds = "width-two-thirds"
    case widthThreeQuarters = "width-three-quarters"
    case scrollToStart = "scroll-to-start"
    case scrollToEnd = "scroll-to-end"
    case layoutSideBySide = "layout-side-by-side"
    case layoutUpDown = "layout-up-down"
    case layoutGrid = "layout-grid"
    case layoutMainSide = "layout-main-side"
    case layoutMainBottom = "layout-main-bottom"
    case layoutSpiral = "layout-spiral"
    case layoutAccordion = "layout-accordion"
    case layoutTabs = "layout-tabs"
    case resetSplit = "reset-split"
    case hideApp = "hide-app"
    case minimizeWorkspace = "minimize-workspace"
    case minimizeOthers = "minimize-others"
    case renameWorkspace = "rename-workspace"
    case swapWorkspaceNext = "swap-workspace-next"
    case swapWorkspacePrevious = "swap-workspace-previous"
    case mergeWorkspacePrevious = "merge-workspace-previous"
    case quickLaunchBeside = "launch-beside"
    case openLinkBeside = "open-link-beside"
    case copyLayout = "copy-layout"
    case pasteLayout = "paste-layout"
    case noteWindow = "note-window"
    case locatePointer = "locate-pointer"
    case flashFocus = "flash-focus"
    case toggleDim = "toggle-dim"
    case toggleBorder = "toggle-border"
    case toggleSliderBar = "toggle-slider-bar"
    case toggleAnimations = "toggle-animations"
    case pomodoro = "pomodoro"
    case toggleQuietMode = "toggle-quiet"
    case restart = "restart"
    case openSettings = "open-settings"
    case checkForUpdates = "check-updates"
    case sortIntoProjects = "sort-into-projects"
    case goToPredicted = "go-to-predicted"
    case startIntent = "start-intent"
    case toggleElasticFocus = "elastic-focus"
    case addBookmark = "add-bookmark"
    case nextBookmark = "next-bookmark"
    case forkLayout = "fork-layout"
    case keepFork = "keep-fork"
    case discardFork = "discard-fork"
    case groupWindow = "group-window"
    case moveGroupToNextWorkspace = "move-group-next"
    case showTimeline = "timeline"
    case toggleTallColumn = "tall-slide"
    case archiveWorkspace = "archive-workspace"
    case shareWorkspace = "share-workspace"
    case toggleVimMode = "vim-mode"
    case searchWindowText = "search-window-text"
    case voiceCommand = "voice-command"
    case toggleDeepWork = "deep-work"
    case toggleReadingMode = "reading-mode"
    case markPrivate = "mark-private"
    case shareSlide = "share-slide"
    case demoZoom = "demo-zoom"
    case toggleKeystrokes = "show-keystrokes"
    case toggleAnnotate = "annotate"
    case presenterNotes = "presenter-notes"
    case mirrorWindow = "mirror-window"
    case guestMode = "guest-mode"
    case ultrawideCenter = "ultrawide-center"
    case retile
    case undo
    case togglePause = "toggle-pause"

    public var title: String {
        switch self {
        case .focusLeft: return "Focus left"
        case .focusRight: return "Focus right"
        case .focusUp: return "Focus up in stack"
        case .focusDown: return "Focus down in stack"
        case .focusFirst: return "Focus first column"
        case .focusLast: return "Focus last column"
        case .moveLeft: return "Move column left"
        case .moveRight: return "Move column right"
        case .moveUp: return "Move window up in stack"
        case .moveDown: return "Move window down in stack"
        case .cycleWidth: return "Cycle width"
        case .cycleWidthBackward: return "Cycle width backward"
        case .narrower: return "Narrower"
        case .wider: return "Wider"
        case .toggleFullWidth: return "Toggle full width"
        case .center: return "Centre column"
        case .consumeIntoLeft: return "Stack into left column"
        case .consumeIntoRight: return "Stack into right column"
        case .expelLeft: return "Pop out of stack to the left"
        case .expel: return "Pop out of stack to the right"
        case .toggleFloat: return "Float / tile window"
        case .pinLeft: return "Pin column to left edge"
        case .pinRight: return "Pin column to right edge"
        case .toggleTabbed: return "Tabbed column on / off"
        case .cycleLayout: return "Next slide layout"
        case .mainLarger: return "Main window larger"
        case .mainSmaller: return "Main window smaller"
        case .makeMain: return "Make main window"
        case .regroup: return "Reset to smart pairs"
        case .overview: return "Overview of all windows"
        case .toggleNativeFullScreen: return "macOS full screen"
        case .windowSwitcher: return "Search windows"
        case .sendToNextDisplay: return "Send to next display"
        case .snapLeftHalf: return "Snap: left half"
        case .snapRightHalf: return "Snap: right half"
        case .snapTopHalf: return "Snap: top half"
        case .snapBottomHalf: return "Snap: bottom half"
        case .snapFirstThird: return "Snap: first third"
        case .snapCenterThird: return "Snap: centre third"
        case .snapLastThird: return "Snap: last third"
        case .snapFirstTwoThirds: return "Snap: first two thirds"
        case .snapLastTwoThirds: return "Snap: last two thirds"
        case .snapTopLeft: return "Snap: top-left quarter"
        case .snapTopRight: return "Snap: top-right quarter"
        case .snapBottomLeft: return "Snap: bottom-left quarter"
        case .snapBottomRight: return "Snap: bottom-right quarter"
        case .snapMaximize: return "Snap: maximise"
        case .snapCenter: return "Snap: centre"
        case .snapRestore: return "Snap: restore"
        case .setMark: return "Mark window (then a letter)"
        case .jumpToMark: return "Jump to mark (then a letter)"
        case .toggleScratchpad: return "Show / hide scratchpad"
        case .makeScratchpad: return "Make this window the scratchpad"
        case .nextProfile: return "Next profile"
        case .toggleFocusMode: return "Focus mode on / off"
        case .commandPalette: return "Command palette"
        case .takeSnapshot: return "Take a session snapshot"
        case .toggleSticky: return "Show window on every workspace"
        case .zoomTile: return "Zoom tile to fill the slide"
        case .lastWindow: return "Back to the last window"
        case .quickLaunch: return "Quick launch (then a letter)"
        case .pictureInPicture: return "Picture in picture"
        case .radialMenu: return "Radial menu (move the pointer, then let go)"
        case .balanceSizes: return "Even out widths and splits"
        case .workspaceBackAndForth: return "Back to the last workspace"
        case .moveToEmptyWorkspace: return "Move window to an empty workspace"
        case .focusAttention: return "Go to the window that wants attention"
        case .showDesktop: return "Show desktop"
        case .screenshotSlide: return "Screenshot the slide"
        case .appOverview: return "Overview of this app’s windows"
        case .windowHints: return "Window hints (then a letter)"
        case .resizeMode: return "Resize mode (arrows, 1–9, esc)"
        case .stripZoom: return "Zoom out on the strip"
        case .presentationMode: return "Presentation mode"
        case .recordSlide: return "Record the slide (again to stop)"
        case .redo: return "Redo layout change"
        case .nextWorkspace: return "Next workspace"
        case .previousWorkspace: return "Previous workspace"
        case .moveToNextWorkspace: return "Move window to the next workspace"
        case .moveToPreviousWorkspace: return "Move window to the previous workspace"
        case .focusNextDisplay: return "Focus the next display"
        case .moveWorkspaceToNextDisplay: return "Move the workspace to the next display"
        case .swapDisplays: return "Swap the workspaces on two displays"
        case .moveToPointerDisplay: return "Move window to the display under the pointer"
        case .cycleAppWindows: return "Next window of the same app"
        case .swapWithRecent: return "Swap with the last window"
        case .rotateSlide: return "Rotate the windows in the slide"
        case .flipSlide: return "Flip the slide"
        case .expandToFill: return "Widen the slide to fill the screen’s free space"
        case .closeSlide: return "Close every window in the slide"
        case .minimizeSlide: return "Minimise the slide"
        case .gatherApp: return "Gather this app’s windows into one slide"
        case .sortSlides: return "Sort slides by app"
        case .tileAllFloating: return "Tile every floating window"
        case .rescueWindows: return "Rescue windows (bring everything on screen)"
        case .soloMode: return "Solo: hide other apps"
        case .toggleGaps: return "Gaps on / off"
        case .biggerGaps: return "Bigger gaps"
        case .smallerGaps: return "Smaller gaps"
        case .centerFloating: return "Centre the floating window"
        case .lockSlide: return "Lock / unlock the slide"
        case .openIntoSlide: return "New windows join the focused slide (on / off)"
        case .cheatSheet: return "Show the shortcut cheat sheet"
        case .nameSlide: return "Name the slide…"
        case .toggleFitMode: return "Fit mode on / off (every slide on screen)"
        case .slideToStart: return "Move the slide to the start"
        case .slideToEnd: return "Move the slide to the end"
        case .slideToNextWorkspace: return "Move the slide to the next workspace"
        case .slideToPreviousWorkspace: return "Move the slide to the previous workspace"
        case .slideToEmptyWorkspace: return "Move the slide to an empty workspace"
        case .unpairSlide: return "Give every window in the slide its own slide"
        case .mergeNext: return "Merge with the next slide"
        case .mergePrevious: return "Merge with the previous slide"
        case .nextTile: return "Next window in the slide"
        case .previousTile: return "Previous window in the slide"
        case .mainTile: return "Go to the slide’s main window"
        case .widthQuarter: return "Width: a quarter"
        case .widthThird: return "Width: a third"
        case .widthHalf: return "Width: half"
        case .widthTwoThirds: return "Width: two thirds"
        case .widthThreeQuarters: return "Width: three quarters"
        case .scrollToStart: return "Look at the start of the strip"
        case .scrollToEnd: return "Look at the end of the strip"
        case .layoutSideBySide: return "Slide layout: side by side"
        case .layoutUpDown: return "Slide layout: up and down"
        case .layoutGrid: return "Slide layout: grid"
        case .layoutMainSide: return "Slide layout: main + side"
        case .layoutMainBottom: return "Slide layout: main + bottom"
        case .layoutSpiral: return "Slide layout: spiral"
        case .layoutAccordion: return "Slide layout: accordion"
        case .layoutTabs: return "Slide layout: tabs"
        case .resetSplit: return "Reset the main window’s share"
        case .hideApp: return "Hide the focused app"
        case .minimizeWorkspace: return "Minimise every window in the workspace"
        case .minimizeOthers: return "Minimise everything but this slide"
        case .renameWorkspace: return "Rename the workspace…"
        case .swapWorkspaceNext: return "Swap the workspace with the next one"
        case .swapWorkspacePrevious: return "Swap the workspace with the previous one"
        case .mergeWorkspacePrevious: return "Merge the workspace into the previous one"
        case .quickLaunchBeside: return "Quick launch beside this window (then a letter)"
        case .openLinkBeside: return "Open the copied link beside this window"
        case .copyLayout: return "Copy the workspace’s layout"
        case .pasteLayout: return "Paste a copied layout"
        case .noteWindow: return "Add a note to the window…"
        case .locatePointer: return "Show where the pointer is"
        case .flashFocus: return "Show which window has focus"
        case .toggleDim: return "Dimming on / off"
        case .toggleBorder: return "Focus border on / off"
        case .toggleSliderBar: return "Slider bar on / off"
        case .toggleAnimations: return "Animations on / off"
        case .pomodoro: return "Pomodoro: focus and break cycles"
        case .toggleQuietMode: return "Quiet mode on / off"
        case .restart: return "Restart Monorail"
        case .openSettings: return "Open Settings"
        case .checkForUpdates: return "Check for updates"
        case .sortIntoProjects: return "Sort windows into project workspaces"
        case .goToPredicted: return "Go to the window you usually go to next"
        case .startIntent: return "Start working on…"
        case .toggleElasticFocus: return "Elastic focus on or off"
        case .addBookmark: return "Bookmark this view"
        case .nextBookmark: return "Go to the next bookmarked view"
        case .forkLayout: return "Try a new layout (fork this workspace)"
        case .keepFork: return "Keep the layout you tried"
        case .discardFork: return "Back to the layout before trying"
        case .groupWindow: return "Add to or remove from the window group"
        case .moveGroupToNextWorkspace: return "Move the window group to the next workspace"
        case .showTimeline: return "Layout timeline"
        case .toggleTallColumn: return "Tall slide: windows full height, scroll up and down"
        case .archiveWorkspace: return "Archive this workspace (save and close its windows)"
        case .shareWorkspace: return "Share this workspace’s setup"
        case .toggleVimMode: return "Vim mode on or off"
        case .searchWindowText: return "Find a window by what’s in it"
        case .voiceCommand: return "Voice command"
        case .toggleDeepWork: return "Deep work on or off"
        case .toggleReadingMode: return "Reading mode"
        case .markPrivate: return "Mark this window private"
        case .shareSlide: return "Share this slide as one window"
        case .demoZoom: return "Demo zoom"
        case .toggleKeystrokes: return "Show keystrokes and clicks"
        case .toggleAnnotate: return "Draw on the screen"
        case .presenterNotes: return "Presenter notes"
        case .mirrorWindow: return "Mirror this window on another display"
        case .guestMode: return "Guest mode"
        case .ultrawideCenter: return "Centre the main slide"
        case .retile: return "Retile everything"
        case .undo: return "Undo last layout change"
        case .togglePause: return "Pause / resume"
        default:
            if let n = columnNumber { return "Focus column \(n)" }
            if let n = workspaceNumber { return "Switch to workspace \(n)" }
            if let n = moveToWorkspaceNumber { return "Move window to workspace \(n)" }
            return rawValue
        }
    }

    /// Where a "snap" action puts a floating window.
    public var snapPosition: SnapPosition? {
        switch self {
        case .snapLeftHalf: return .leftHalf
        case .snapRightHalf: return .rightHalf
        case .snapTopHalf: return .topHalf
        case .snapBottomHalf: return .bottomHalf
        case .snapFirstThird: return .firstThird
        case .snapCenterThird: return .centerThird
        case .snapLastThird: return .lastThird
        case .snapFirstTwoThirds: return .firstTwoThirds
        case .snapLastTwoThirds: return .lastTwoThirds
        case .snapTopLeft: return .topLeft
        case .snapTopRight: return .topRight
        case .snapBottomLeft: return .bottomLeft
        case .snapBottomRight: return .bottomRight
        case .snapMaximize: return .maximize
        case .snapCenter: return .center
        default: return nil
        }
    }

    /// 1...9 for the "focus column N" actions.
    public var columnNumber: Int? {
        let prefix = "focus-column-"
        guard rawValue.hasPrefix(prefix) else { return nil }
        return Int(rawValue.dropFirst(prefix.count))
    }

    /// 1...9 for the "switch to workspace N" actions.
    public var workspaceNumber: Int? {
        let prefix = "workspace-"
        guard rawValue.hasPrefix(prefix) else { return nil }
        return Int(rawValue.dropFirst(prefix.count))
    }

    /// 1...9 for the "move window to workspace N" actions.
    public var moveToWorkspaceNumber: Int? {
        let prefix = "move-to-workspace-"
        guard rawValue.hasPrefix(prefix) else { return nil }
        return Int(rawValue.dropFirst(prefix.count))
    }

    /// Parses `monorail://<action>` (or the older `macslider://<action>`, or a bare name).
    public init?(url: String) {
        var name = Substring(url)
        if let scheme = url.firstIndex(of: ":"), url[scheme...].hasPrefix("://") {
            name = url[url.index(scheme, offsetBy: 3)...]
        }
        while name.hasSuffix("/") { name.removeLast() }
        self.init(rawValue: name.lowercased())
    }

    /// Actions without a default shortcut (bind one in Settings, or use the
    /// menu, command palette, a window's right-click menu or a URL).
    public static let unboundByDefault: Set<Action> = [
        .swapDisplays, .moveToPointerDisplay, .expandToFill, .closeSlide, .minimizeSlide, .gatherApp, .sortSlides,
        .tileAllFloating, .rescueWindows, .biggerGaps, .smallerGaps, .centerFloating, .lockSlide, .openIntoSlide,
        .nameSlide, .toggleFitMode,
        .slideToStart, .slideToEnd, .slideToNextWorkspace, .slideToPreviousWorkspace, .slideToEmptyWorkspace, .unpairSlide, .mergeNext, .mergePrevious, .nextTile, .previousTile, .mainTile, .widthQuarter, .widthThird, .widthHalf, .widthTwoThirds, .widthThreeQuarters, .scrollToStart, .scrollToEnd, .layoutSideBySide, .layoutUpDown, .layoutGrid, .layoutMainSide, .layoutMainBottom, .layoutSpiral, .layoutAccordion, .layoutTabs, .resetSplit, .hideApp, .minimizeWorkspace, .minimizeOthers, .renameWorkspace, .swapWorkspaceNext, .swapWorkspacePrevious, .mergeWorkspacePrevious, .quickLaunchBeside, .openLinkBeside, .copyLayout, .pasteLayout, .noteWindow, .locatePointer, .flashFocus, .toggleDim, .toggleBorder, .toggleSliderBar, .toggleAnimations, .pomodoro, .toggleQuietMode, .restart, .openSettings, .checkForUpdates,
        .sortIntoProjects, .goToPredicted, .startIntent, .toggleElasticFocus, .addBookmark, .nextBookmark, .forkLayout, .keepFork, .discardFork, .groupWindow, .moveGroupToNextWorkspace, .showTimeline, .toggleTallColumn, .archiveWorkspace, .shareWorkspace, .toggleVimMode, .searchWindowText, .voiceCommand, .toggleDeepWork, .toggleReadingMode, .markPrivate, .shareSlide, .demoZoom, .toggleKeystrokes, .toggleAnnotate, .presenterNotes, .mirrorWindow, .guestMode, .ultrawideCenter,
    ]

    /// The slide layout a "Slide layout: …" action sets (nil for tabs).
    public var directLayout: Arrangement?? {
        switch self {
        case .layoutSideBySide: return .columns
        case .layoutUpDown: return .stack
        case .layoutGrid: return .grid
        case .layoutMainSide: return .mainLeft
        case .layoutMainBottom: return .mainTop
        case .layoutSpiral: return .spiral
        case .layoutAccordion: return .accordion
        case .layoutTabs: return .some(nil)
        default: return nil
        }
    }

    /// The width a "Width: …" action sets, as a share of the screen.
    public var directWidth: Double? {
        switch self {
        case .widthQuarter: return 0.25
        case .widthThird: return 1.0 / 3.0
        case .widthHalf: return 0.5
        case .widthTwoThirds: return 2.0 / 3.0
        case .widthThreeQuarters: return 0.75
        default: return nil
        }
    }
}
