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
    case linkAcrossDisplays = "link-across-displays"
    case cameraTile = "camera-tile"
    case pairSync = "pair-sync"
    case handoff = "handoff"
    case clipboardHistory = "workspace-clipboard"
    case toggleAwake = "stay-awake"
    case awake30 = "stay-awake-30"
    case awake60 = "stay-awake-60"
    case awake120 = "stay-awake-120"
    case awakeWhileDownloading = "stay-awake-downloading"
    case toggleAwakeDisplay = "stay-awake-display"
    // 1.7: nested slides, docking, saved views, tags.
    case dockLeft = "dock-left"
    case dockRight = "dock-right"
    case dockUp = "dock-up"
    case dockDown = "dock-down"
    case tearOff = "tear-off"
    case balanceSplits = "balance-splits"
    case nestSlide = "nest-slide"
    case viewBack = "view-back"
    case viewForward = "view-forward"
    case view1 = "view-1"
    case view2 = "view-2"
    case view3 = "view-3"
    case view4 = "view-4"
    case view5 = "view-5"
    case view6 = "view-6"
    case view7 = "view-7"
    case view8 = "view-8"
    case view9 = "view-9"
    case saveView1 = "save-view-1"
    case saveView2 = "save-view-2"
    case saveView3 = "save-view-3"
    case saveView4 = "save-view-4"
    case saveView5 = "save-view-5"
    case saveView6 = "save-view-6"
    case saveView7 = "save-view-7"
    case saveView8 = "save-view-8"
    case saveView9 = "save-view-9"
    case tag1 = "tag-1"
    case tag2 = "tag-2"
    case tag3 = "tag-3"
    case tag4 = "tag-4"
    case tag5 = "tag-5"
    case tag6 = "tag-6"
    case tag7 = "tag-7"
    case tag8 = "tag-8"
    case tag9 = "tag-9"
    case combine1 = "combine-1"
    case combine2 = "combine-2"
    case combine3 = "combine-3"
    case combine4 = "combine-4"
    case combine5 = "combine-5"
    case combine6 = "combine-6"
    case combine7 = "combine-7"
    case combine8 = "combine-8"
    case combine9 = "combine-9"
    case retile
    case undo
    case togglePause = "toggle-pause"
    // 2.x: displays, stash and Evening Mode.
    case focusDisplayLeft = "focus-display-left"
    case focusDisplayRight = "focus-display-right"
    case focusDisplayUp = "focus-display-up"
    case focusDisplayDown = "focus-display-down"
    case sendToDisplayLeft = "send-to-display-left"
    case sendToDisplayRight = "send-to-display-right"
    case sendToDisplayUp = "send-to-display-up"
    case sendToDisplayDown = "send-to-display-down"
    case focusDisplay1 = "focus-display-1"
    case focusDisplay2 = "focus-display-2"
    case focusDisplay3 = "focus-display-3"
    case focusDisplay4 = "focus-display-4"
    case focusDisplay5 = "focus-display-5"
    case focusDisplay6 = "focus-display-6"
    case focusDisplay7 = "focus-display-7"
    case focusDisplay8 = "focus-display-8"
    case focusDisplay9 = "focus-display-9"
    case sendToDisplay1 = "send-to-display-1"
    case sendToDisplay2 = "send-to-display-2"
    case sendToDisplay3 = "send-to-display-3"
    case sendToDisplay4 = "send-to-display-4"
    case sendToDisplay5 = "send-to-display-5"
    case sendToDisplay6 = "send-to-display-6"
    case sendToDisplay7 = "send-to-display-7"
    case sendToDisplay8 = "send-to-display-8"
    case sendToDisplay9 = "send-to-display-9"
    case displayBrighter = "display-brighter"
    case displayDimmer = "display-dimmer"
    case displayMoreSpace = "display-more-space"
    case displayLargerText = "display-larger-text"
    case displayDefaultResolution = "display-default-resolution"
    case stashWindow = "stash-window"
    case unstashAll = "unstash-all"
    case toggleEvening = "evening-mode"
    case keepAvailable = "keep-available"

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
        case .linkAcrossDisplays: return "Link this slide with the one on the other display"
        case .cameraTile: return "Camera preview tile"
        case .pairSync: return "Sync layout with a nearby Mac"
        case .handoff: return "Continue this workspace on my other Mac"
        case .clipboardHistory: return "This workspace’s clipboard"
        case .toggleAwake: return "Stay Awake on or off"
        case .awake30: return "Stay awake for 30 minutes"
        case .awake60: return "Stay awake for 1 hour"
        case .awake120: return "Stay awake for 2 hours"
        case .awakeWhileDownloading: return "Stay awake while downloading"
        case .toggleAwakeDisplay: return "Stay Awake: keep the display on or let it sleep"
        case .dockLeft: return "Dock onto the window on the left"
        case .dockRight: return "Dock onto the window on the right"
        case .dockUp: return "Dock onto the window above"
        case .dockDown: return "Dock onto the window below"
        case .tearOff: return "Tear off into a slide of its own"
        case .balanceSplits: return "Even out the splits in this slide"
        case .nestSlide: return "Split this slide freely (nested)"
        case .viewBack: return "Back to the previous view"
        case .viewForward: return "Forward to the next view"
        case .retile: return "Retile everything"
        case .undo: return "Undo last layout change"
        case .togglePause: return "Pause / resume"
        case .focusDisplayLeft: return "Focus the display on the left"
        case .focusDisplayRight: return "Focus the display on the right"
        case .focusDisplayUp: return "Focus the display above"
        case .focusDisplayDown: return "Focus the display below"
        case .sendToDisplayLeft: return "Send window to the display on the left"
        case .sendToDisplayRight: return "Send window to the display on the right"
        case .sendToDisplayUp: return "Send window to the display above"
        case .sendToDisplayDown: return "Send window to the display below"
        case .focusDisplay1: return "Focus display 1"
        case .focusDisplay2: return "Focus display 2"
        case .focusDisplay3: return "Focus display 3"
        case .focusDisplay4: return "Focus display 4"
        case .focusDisplay5: return "Focus display 5"
        case .focusDisplay6: return "Focus display 6"
        case .focusDisplay7: return "Focus display 7"
        case .focusDisplay8: return "Focus display 8"
        case .focusDisplay9: return "Focus display 9"
        case .sendToDisplay1: return "Send window to display 1"
        case .sendToDisplay2: return "Send window to display 2"
        case .sendToDisplay3: return "Send window to display 3"
        case .sendToDisplay4: return "Send window to display 4"
        case .sendToDisplay5: return "Send window to display 5"
        case .sendToDisplay6: return "Send window to display 6"
        case .sendToDisplay7: return "Send window to display 7"
        case .sendToDisplay8: return "Send window to display 8"
        case .sendToDisplay9: return "Send window to display 9"
        case .displayBrighter: return "Brighter display (software brightness)"
        case .displayDimmer: return "Dimmer display (below the lowest brightness)"
        case .displayMoreSpace: return "Display resolution: more space"
        case .displayLargerText: return "Display resolution: larger text"
        case .displayDefaultResolution: return "Display resolution: back to default"
        case .stashWindow: return "Stash the window at the screen edge (again to bring it back)"
        case .unstashAll: return "Bring back every stashed window"
        case .toggleEvening: return "Evening Mode on or off"
        case .keepAvailable: return "Keep me Available on or off (Teams, Slack)"
        default:
            if let n = columnNumber { return "Focus column \(n)" }
            if let n = workspaceNumber { return "Switch to workspace \(n)" }
            if let n = moveToWorkspaceNumber { return "Move window to workspace \(n)" }
            if let n = viewNumber { return "Go to saved view \(n)" }
            if let n = saveViewNumber { return "Save this view as \(n)" }
            if let n = tagNumber { return "Also keep this window on workspace \(n)" }
            if let n = combineNumber { return "Show workspace \(n) alongside this one" }
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

    private func number(after prefix: String) -> Int? {
        guard rawValue.hasPrefix(prefix) else { return nil }
        return Int(rawValue.dropFirst(prefix.count))
    }

    /// 1...9 for "go to saved view N", "save view N", "tag N" and "combine N".
    public var viewNumber: Int? { number(after: "view-") }
    public var saveViewNumber: Int? { number(after: "save-view-") }
    public var tagNumber: Int? { number(after: "tag-") }
    public var combineNumber: Int? { number(after: "combine-") }

    /// The direction of the "focus / send to the display on the left…" actions.
    public var displayDirection: DisplayDirection? {
        switch self {
        case .focusDisplayLeft, .sendToDisplayLeft: return .left
        case .focusDisplayRight, .sendToDisplayRight: return .right
        case .focusDisplayUp, .sendToDisplayUp: return .up
        case .focusDisplayDown, .sendToDisplayDown: return .down
        default: return nil
        }
    }

    /// 1...9 for "focus display N" and "send window to display N".
    public var displayNumber: Int? { number(after: "focus-display-") ?? number(after: "send-to-display-") }

    /// True for the display actions that move the focused window (rather than focus).
    public var sendsToDisplay: Bool { rawValue.hasPrefix("send-to-display-") }

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
    public static let unboundByDefault: Set<Action> = Set(Action.allCases.filter { $0.tagNumber != nil || $0.combineNumber != nil })
        .union([.dockLeft, .dockRight, .dockUp, .dockDown, .tearOff, .balanceSplits, .nestSlide]).union([
        .swapDisplays, .moveToPointerDisplay, .expandToFill, .closeSlide, .minimizeSlide, .gatherApp, .sortSlides,
        .tileAllFloating, .rescueWindows, .biggerGaps, .smallerGaps, .centerFloating, .lockSlide, .openIntoSlide,
        .nameSlide, .toggleFitMode,
        .slideToStart, .slideToEnd, .slideToNextWorkspace, .slideToPreviousWorkspace, .slideToEmptyWorkspace, .unpairSlide, .mergeNext, .mergePrevious, .nextTile, .previousTile, .mainTile, .widthQuarter, .widthThird, .widthHalf, .widthTwoThirds, .widthThreeQuarters, .scrollToStart, .scrollToEnd, .layoutSideBySide, .layoutUpDown, .layoutGrid, .layoutMainSide, .layoutMainBottom, .layoutSpiral, .layoutAccordion, .layoutTabs, .resetSplit, .hideApp, .minimizeWorkspace, .minimizeOthers, .renameWorkspace, .swapWorkspaceNext, .swapWorkspacePrevious, .mergeWorkspacePrevious, .quickLaunchBeside, .openLinkBeside, .copyLayout, .pasteLayout, .noteWindow, .locatePointer, .flashFocus, .toggleDim, .toggleBorder, .toggleSliderBar, .toggleAnimations, .pomodoro, .toggleQuietMode, .restart, .openSettings, .checkForUpdates,
        .sortIntoProjects, .goToPredicted, .startIntent, .toggleElasticFocus, .addBookmark, .nextBookmark, .forkLayout, .keepFork, .discardFork, .groupWindow, .moveGroupToNextWorkspace, .showTimeline, .toggleTallColumn, .archiveWorkspace, .shareWorkspace, .toggleVimMode, .searchWindowText, .voiceCommand, .toggleDeepWork, .toggleReadingMode, .markPrivate, .shareSlide, .demoZoom, .toggleKeystrokes, .toggleAnnotate, .presenterNotes, .mirrorWindow, .guestMode, .ultrawideCenter, .linkAcrossDisplays, .cameraTile, .pairSync, .handoff, .clipboardHistory, .toggleAwake, .awake30, .awake60, .awake120, .awakeWhileDownloading, .toggleAwakeDisplay,
        .focusDisplayLeft, .focusDisplayRight, .focusDisplayUp, .focusDisplayDown, .sendToDisplayLeft, .sendToDisplayRight, .sendToDisplayUp, .sendToDisplayDown,
        .focusDisplay1, .focusDisplay2, .focusDisplay3, .focusDisplay4, .focusDisplay5, .focusDisplay6, .focusDisplay7, .focusDisplay8, .focusDisplay9,
        .sendToDisplay1, .sendToDisplay2, .sendToDisplay3, .sendToDisplay4, .sendToDisplay5, .sendToDisplay6, .sendToDisplay7, .sendToDisplay8, .sendToDisplay9,
        .displayBrighter, .displayDimmer, .displayMoreSpace, .displayLargerText, .displayDefaultResolution,
        .stashWindow, .unstashAll, .toggleEvening, .keepAvailable,
    ])

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
