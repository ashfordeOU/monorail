// Generated from spec/actions.json by scripts/gen-defs.py. Don't edit by hand.
#nullable enable
namespace Monorail.Shared;

public sealed record ActionInfo(string Name, string Title, bool DefaultKey, bool Numbered);

/// <summary>Every Monorail action, by its shared name.</summary>
public static class Actions
{
    public const string FocusLeft = "focus-left";
    public const string FocusRight = "focus-right";
    public const string FocusUp = "focus-up";
    public const string FocusDown = "focus-down";
    public const string FocusFirst = "focus-first";
    public const string FocusLast = "focus-last";
    public const string FocusColumn1 = "focus-column-1";
    public const string FocusColumn2 = "focus-column-2";
    public const string FocusColumn3 = "focus-column-3";
    public const string FocusColumn4 = "focus-column-4";
    public const string FocusColumn5 = "focus-column-5";
    public const string FocusColumn6 = "focus-column-6";
    public const string FocusColumn7 = "focus-column-7";
    public const string FocusColumn8 = "focus-column-8";
    public const string FocusColumn9 = "focus-column-9";
    public const string MoveLeft = "move-left";
    public const string MoveRight = "move-right";
    public const string MoveUp = "move-up";
    public const string MoveDown = "move-down";
    public const string CycleWidth = "cycle-width";
    public const string CycleWidthBackward = "cycle-width-backward";
    public const string Narrower = "narrower";
    public const string Wider = "wider";
    public const string FullWidth = "full-width";
    public const string Center = "center";
    public const string StackIntoLeft = "stack-into-left";
    public const string StackIntoRight = "stack-into-right";
    public const string UnstackLeft = "unstack-left";
    public const string Unstack = "unstack";
    public const string ToggleFloat = "toggle-float";
    public const string PinLeft = "pin-left";
    public const string PinRight = "pin-right";
    public const string ToggleTabbed = "toggle-tabbed";
    public const string CycleLayout = "cycle-layout";
    public const string MainLarger = "main-larger";
    public const string MainSmaller = "main-smaller";
    public const string MakeMain = "make-main";
    public const string Regroup = "regroup";
    public const string Overview = "overview";
    public const string ToggleFullscreen = "toggle-fullscreen";
    public const string WindowSwitcher = "window-switcher";
    public const string SendToNextDisplay = "send-to-next-display";
    public const string Workspace1 = "workspace-1";
    public const string Workspace2 = "workspace-2";
    public const string Workspace3 = "workspace-3";
    public const string Workspace4 = "workspace-4";
    public const string Workspace5 = "workspace-5";
    public const string Workspace6 = "workspace-6";
    public const string Workspace7 = "workspace-7";
    public const string Workspace8 = "workspace-8";
    public const string Workspace9 = "workspace-9";
    public const string MoveToWorkspace1 = "move-to-workspace-1";
    public const string MoveToWorkspace2 = "move-to-workspace-2";
    public const string MoveToWorkspace3 = "move-to-workspace-3";
    public const string MoveToWorkspace4 = "move-to-workspace-4";
    public const string MoveToWorkspace5 = "move-to-workspace-5";
    public const string MoveToWorkspace6 = "move-to-workspace-6";
    public const string MoveToWorkspace7 = "move-to-workspace-7";
    public const string MoveToWorkspace8 = "move-to-workspace-8";
    public const string MoveToWorkspace9 = "move-to-workspace-9";
    public const string SnapLeftHalf = "snap-left-half";
    public const string SnapRightHalf = "snap-right-half";
    public const string SnapTopHalf = "snap-top-half";
    public const string SnapBottomHalf = "snap-bottom-half";
    public const string SnapFirstThird = "snap-first-third";
    public const string SnapCenterThird = "snap-center-third";
    public const string SnapLastThird = "snap-last-third";
    public const string SnapFirstTwoThirds = "snap-first-two-thirds";
    public const string SnapLastTwoThirds = "snap-last-two-thirds";
    public const string SnapTopLeft = "snap-top-left";
    public const string SnapTopRight = "snap-top-right";
    public const string SnapBottomLeft = "snap-bottom-left";
    public const string SnapBottomRight = "snap-bottom-right";
    public const string SnapMaximize = "snap-maximize";
    public const string SnapCenter = "snap-center";
    public const string SnapRestore = "snap-restore";
    public const string SetMark = "set-mark";
    public const string JumpToMark = "jump-to-mark";
    public const string Scratchpad = "scratchpad";
    public const string MakeScratchpad = "make-scratchpad";
    public const string NextProfile = "next-profile";
    public const string FocusMode = "focus-mode";
    public const string CommandPalette = "command-palette";
    public const string Snapshot = "snapshot";
    public const string Sticky = "sticky";
    public const string Zoom = "zoom";
    public const string LastWindow = "last-window";
    public const string Launch = "launch";
    public const string PictureInPicture = "picture-in-picture";
    public const string RadialMenu = "radial-menu";
    public const string Balance = "balance";
    public const string WorkspaceBack = "workspace-back";
    public const string MoveToEmptyWorkspace = "move-to-empty-workspace";
    public const string FocusAttention = "focus-attention";
    public const string ShowDesktop = "show-desktop";
    public const string ScreenshotSlide = "screenshot-slide";
    public const string AppOverview = "app-overview";
    public const string Hints = "hints";
    public const string ResizeMode = "resize-mode";
    public const string StripZoom = "strip-zoom";
    public const string PresentationMode = "presentation-mode";
    public const string RecordSlide = "record-slide";
    public const string Redo = "redo";
    public const string NextWorkspace = "next-workspace";
    public const string PreviousWorkspace = "previous-workspace";
    public const string MoveToNextWorkspace = "move-to-next-workspace";
    public const string MoveToPreviousWorkspace = "move-to-previous-workspace";
    public const string FocusNextDisplay = "focus-next-display";
    public const string MoveWorkspaceToNextDisplay = "move-workspace-to-next-display";
    public const string SwapDisplays = "swap-displays";
    public const string MoveToPointerDisplay = "move-to-pointer-display";
    public const string CycleAppWindows = "cycle-app-windows";
    public const string SwapWithRecent = "swap-with-recent";
    public const string RotateSlide = "rotate-slide";
    public const string FlipSlide = "flip-slide";
    public const string ExpandToFill = "expand-to-fill";
    public const string CloseSlide = "close-slide";
    public const string MinimizeSlide = "minimize-slide";
    public const string GatherApp = "gather-app";
    public const string SortSlides = "sort-slides";
    public const string TileFloating = "tile-floating";
    public const string RescueWindows = "rescue-windows";
    public const string Solo = "solo";
    public const string ToggleGaps = "toggle-gaps";
    public const string BiggerGaps = "bigger-gaps";
    public const string SmallerGaps = "smaller-gaps";
    public const string CenterFloating = "center-floating";
    public const string LockSlide = "lock-slide";
    public const string OpenIntoSlide = "open-into-slide";
    public const string CheatSheet = "cheat-sheet";
    public const string NameSlide = "name-slide";
    public const string FitMode = "fit-mode";
    public const string SlideToStart = "slide-to-start";
    public const string SlideToEnd = "slide-to-end";
    public const string SlideToNextWorkspace = "slide-to-next-workspace";
    public const string SlideToPreviousWorkspace = "slide-to-previous-workspace";
    public const string SlideToEmptyWorkspace = "slide-to-empty-workspace";
    public const string UnpairSlide = "unpair-slide";
    public const string MergeNext = "merge-next";
    public const string MergePrevious = "merge-previous";
    public const string NextTile = "next-tile";
    public const string PreviousTile = "previous-tile";
    public const string MainTile = "main-tile";
    public const string WidthQuarter = "width-quarter";
    public const string WidthThird = "width-third";
    public const string WidthHalf = "width-half";
    public const string WidthTwoThirds = "width-two-thirds";
    public const string WidthThreeQuarters = "width-three-quarters";
    public const string ScrollToStart = "scroll-to-start";
    public const string ScrollToEnd = "scroll-to-end";
    public const string LayoutSideBySide = "layout-side-by-side";
    public const string LayoutUpDown = "layout-up-down";
    public const string LayoutGrid = "layout-grid";
    public const string LayoutMainSide = "layout-main-side";
    public const string LayoutMainBottom = "layout-main-bottom";
    public const string LayoutSpiral = "layout-spiral";
    public const string LayoutAccordion = "layout-accordion";
    public const string LayoutTabs = "layout-tabs";
    public const string ResetSplit = "reset-split";
    public const string HideApp = "hide-app";
    public const string MinimizeWorkspace = "minimize-workspace";
    public const string MinimizeOthers = "minimize-others";
    public const string RenameWorkspace = "rename-workspace";
    public const string SwapWorkspaceNext = "swap-workspace-next";
    public const string SwapWorkspacePrevious = "swap-workspace-previous";
    public const string MergeWorkspacePrevious = "merge-workspace-previous";
    public const string LaunchBeside = "launch-beside";
    public const string OpenLinkBeside = "open-link-beside";
    public const string CopyLayout = "copy-layout";
    public const string PasteLayout = "paste-layout";
    public const string NoteWindow = "note-window";
    public const string LocatePointer = "locate-pointer";
    public const string FlashFocus = "flash-focus";
    public const string ToggleDim = "toggle-dim";
    public const string ToggleBorder = "toggle-border";
    public const string ToggleSliderBar = "toggle-slider-bar";
    public const string ToggleAnimations = "toggle-animations";
    public const string Pomodoro = "pomodoro";
    public const string ToggleQuiet = "toggle-quiet";
    public const string Restart = "restart";
    public const string OpenSettings = "open-settings";
    public const string CheckUpdates = "check-updates";
    public const string SortIntoProjects = "sort-into-projects";
    public const string GoToPredicted = "go-to-predicted";
    public const string StartIntent = "start-intent";
    public const string ElasticFocus = "elastic-focus";
    public const string AddBookmark = "add-bookmark";
    public const string NextBookmark = "next-bookmark";
    public const string ForkLayout = "fork-layout";
    public const string KeepFork = "keep-fork";
    public const string DiscardFork = "discard-fork";
    public const string GroupWindow = "group-window";
    public const string MoveGroupNext = "move-group-next";
    public const string Timeline = "timeline";
    public const string TallSlide = "tall-slide";
    public const string ArchiveWorkspace = "archive-workspace";
    public const string ShareWorkspace = "share-workspace";
    public const string VimMode = "vim-mode";
    public const string SearchWindowText = "search-window-text";
    public const string VoiceCommand = "voice-command";
    public const string DeepWork = "deep-work";
    public const string ReadingMode = "reading-mode";
    public const string MarkPrivate = "mark-private";
    public const string ShareSlide = "share-slide";
    public const string DemoZoom = "demo-zoom";
    public const string ShowKeystrokes = "show-keystrokes";
    public const string Annotate = "annotate";
    public const string PresenterNotes = "presenter-notes";
    public const string MirrorWindow = "mirror-window";
    public const string GuestMode = "guest-mode";
    public const string UltrawideCenter = "ultrawide-center";
    public const string LinkAcrossDisplays = "link-across-displays";
    public const string CameraTile = "camera-tile";
    public const string PairSync = "pair-sync";
    public const string Handoff = "handoff";
    public const string WorkspaceClipboard = "workspace-clipboard";
    public const string StayAwake = "stay-awake";
    public const string StayAwake30 = "stay-awake-30";
    public const string StayAwake60 = "stay-awake-60";
    public const string StayAwake120 = "stay-awake-120";
    public const string StayAwakeDownloading = "stay-awake-downloading";
    public const string StayAwakeDisplay = "stay-awake-display";
    public const string DockLeft = "dock-left";
    public const string DockRight = "dock-right";
    public const string DockUp = "dock-up";
    public const string DockDown = "dock-down";
    public const string TearOff = "tear-off";
    public const string BalanceSplits = "balance-splits";
    public const string NestSlide = "nest-slide";
    public const string ViewBack = "view-back";
    public const string ViewForward = "view-forward";
    public const string View1 = "view-1";
    public const string View2 = "view-2";
    public const string View3 = "view-3";
    public const string View4 = "view-4";
    public const string View5 = "view-5";
    public const string View6 = "view-6";
    public const string View7 = "view-7";
    public const string View8 = "view-8";
    public const string View9 = "view-9";
    public const string SaveView1 = "save-view-1";
    public const string SaveView2 = "save-view-2";
    public const string SaveView3 = "save-view-3";
    public const string SaveView4 = "save-view-4";
    public const string SaveView5 = "save-view-5";
    public const string SaveView6 = "save-view-6";
    public const string SaveView7 = "save-view-7";
    public const string SaveView8 = "save-view-8";
    public const string SaveView9 = "save-view-9";
    public const string Tag1 = "tag-1";
    public const string Tag2 = "tag-2";
    public const string Tag3 = "tag-3";
    public const string Tag4 = "tag-4";
    public const string Tag5 = "tag-5";
    public const string Tag6 = "tag-6";
    public const string Tag7 = "tag-7";
    public const string Tag8 = "tag-8";
    public const string Tag9 = "tag-9";
    public const string Combine1 = "combine-1";
    public const string Combine2 = "combine-2";
    public const string Combine3 = "combine-3";
    public const string Combine4 = "combine-4";
    public const string Combine5 = "combine-5";
    public const string Combine6 = "combine-6";
    public const string Combine7 = "combine-7";
    public const string Combine8 = "combine-8";
    public const string Combine9 = "combine-9";
    public const string Retile = "retile";
    public const string Undo = "undo";
    public const string TogglePause = "toggle-pause";

    public static readonly ActionInfo[] All =
    {
        new("focus-left", "Focus left", true, false),
        new("focus-right", "Focus right", true, false),
        new("focus-up", "Focus up in stack", true, false),
        new("focus-down", "Focus down in stack", true, false),
        new("focus-first", "Focus first column", true, false),
        new("focus-last", "Focus last column", true, false),
        new("focus-column-1", "Focus column 1", true, true),
        new("focus-column-2", "Focus column 2", true, true),
        new("focus-column-3", "Focus column 3", true, true),
        new("focus-column-4", "Focus column 4", true, true),
        new("focus-column-5", "Focus column 5", true, true),
        new("focus-column-6", "Focus column 6", true, true),
        new("focus-column-7", "Focus column 7", true, true),
        new("focus-column-8", "Focus column 8", true, true),
        new("focus-column-9", "Focus column 9", true, true),
        new("move-left", "Move column left", true, false),
        new("move-right", "Move column right", true, false),
        new("move-up", "Move window up in stack", true, false),
        new("move-down", "Move window down in stack", true, false),
        new("cycle-width", "Cycle width", true, false),
        new("cycle-width-backward", "Cycle width backward", true, false),
        new("narrower", "Narrower", true, false),
        new("wider", "Wider", true, false),
        new("full-width", "Toggle full width", true, false),
        new("center", "Centre column", true, false),
        new("stack-into-left", "Stack into left column", true, false),
        new("stack-into-right", "Stack into right column", true, false),
        new("unstack-left", "Pop out of stack to the left", true, false),
        new("unstack", "Pop out of stack to the right", true, false),
        new("toggle-float", "Float / tile window", true, false),
        new("pin-left", "Pin column to left edge", true, false),
        new("pin-right", "Pin column to right edge", true, false),
        new("toggle-tabbed", "Tabbed column on / off", true, false),
        new("cycle-layout", "Next slide layout", true, false),
        new("main-larger", "Main window larger", true, false),
        new("main-smaller", "Main window smaller", true, false),
        new("make-main", "Make main window", true, false),
        new("regroup", "Reset to smart pairs", true, false),
        new("overview", "Overview of all windows", true, false),
        new("toggle-fullscreen", "macOS full screen", true, false),
        new("window-switcher", "Search windows", true, false),
        new("send-to-next-display", "Send to next display", true, false),
        new("workspace-1", "Switch to workspace 1", true, true),
        new("workspace-2", "Switch to workspace 2", true, true),
        new("workspace-3", "Switch to workspace 3", true, true),
        new("workspace-4", "Switch to workspace 4", true, true),
        new("workspace-5", "Switch to workspace 5", true, true),
        new("workspace-6", "Switch to workspace 6", true, true),
        new("workspace-7", "Switch to workspace 7", true, true),
        new("workspace-8", "Switch to workspace 8", true, true),
        new("workspace-9", "Switch to workspace 9", true, true),
        new("move-to-workspace-1", "Move window to workspace 1", true, true),
        new("move-to-workspace-2", "Move window to workspace 2", true, true),
        new("move-to-workspace-3", "Move window to workspace 3", true, true),
        new("move-to-workspace-4", "Move window to workspace 4", true, true),
        new("move-to-workspace-5", "Move window to workspace 5", true, true),
        new("move-to-workspace-6", "Move window to workspace 6", true, true),
        new("move-to-workspace-7", "Move window to workspace 7", true, true),
        new("move-to-workspace-8", "Move window to workspace 8", true, true),
        new("move-to-workspace-9", "Move window to workspace 9", true, true),
        new("snap-left-half", "Snap: left half", true, false),
        new("snap-right-half", "Snap: right half", true, false),
        new("snap-top-half", "Snap: top half", true, false),
        new("snap-bottom-half", "Snap: bottom half", true, false),
        new("snap-first-third", "Snap: first third", true, false),
        new("snap-center-third", "Snap: centre third", true, false),
        new("snap-last-third", "Snap: last third", true, false),
        new("snap-first-two-thirds", "Snap: first two thirds", true, false),
        new("snap-last-two-thirds", "Snap: last two thirds", true, false),
        new("snap-top-left", "Snap: top-left quarter", true, false),
        new("snap-top-right", "Snap: top-right quarter", true, false),
        new("snap-bottom-left", "Snap: bottom-left quarter", true, false),
        new("snap-bottom-right", "Snap: bottom-right quarter", true, false),
        new("snap-maximize", "Snap: maximise", true, false),
        new("snap-center", "Snap: centre", true, false),
        new("snap-restore", "Snap: restore", true, false),
        new("set-mark", "Mark window (then a letter)", true, false),
        new("jump-to-mark", "Jump to mark (then a letter)", true, false),
        new("scratchpad", "Show / hide scratchpad", true, false),
        new("make-scratchpad", "Make this window the scratchpad", true, false),
        new("next-profile", "Next profile", true, false),
        new("focus-mode", "Focus mode on / off", true, false),
        new("command-palette", "Command palette", true, false),
        new("snapshot", "Take a session snapshot", true, false),
        new("sticky", "Show window on every workspace", true, false),
        new("zoom", "Zoom tile to fill the slide", true, false),
        new("last-window", "Back to the last window", true, false),
        new("launch", "Quick launch (then a letter)", true, false),
        new("picture-in-picture", "Picture in picture", true, false),
        new("radial-menu", "Radial menu (move the pointer, then let go)", true, false),
        new("balance", "Even out widths and splits", true, false),
        new("workspace-back", "Back to the last workspace", true, false),
        new("move-to-empty-workspace", "Move window to an empty workspace", true, false),
        new("focus-attention", "Go to the window that wants attention", true, false),
        new("show-desktop", "Show desktop", true, false),
        new("screenshot-slide", "Screenshot the slide", true, false),
        new("app-overview", "Overview of this app’s windows", true, false),
        new("hints", "Window hints (then a letter)", true, false),
        new("resize-mode", "Resize mode (arrows, 1–9, esc)", true, false),
        new("strip-zoom", "Zoom out on the strip", true, false),
        new("presentation-mode", "Presentation mode", true, false),
        new("record-slide", "Record the slide (again to stop)", true, false),
        new("redo", "Redo layout change", true, false),
        new("next-workspace", "Next workspace", true, false),
        new("previous-workspace", "Previous workspace", true, false),
        new("move-to-next-workspace", "Move window to the next workspace", true, false),
        new("move-to-previous-workspace", "Move window to the previous workspace", true, false),
        new("focus-next-display", "Focus the next display", true, false),
        new("move-workspace-to-next-display", "Move the workspace to the next display", true, false),
        new("swap-displays", "Swap the workspaces on two displays", false, false),
        new("move-to-pointer-display", "Move window to the display under the pointer", false, false),
        new("cycle-app-windows", "Next window of the same app", true, false),
        new("swap-with-recent", "Swap with the last window", true, false),
        new("rotate-slide", "Rotate the windows in the slide", true, false),
        new("flip-slide", "Flip the slide", true, false),
        new("expand-to-fill", "Widen the slide to fill the screen’s free space", false, false),
        new("close-slide", "Close every window in the slide", false, false),
        new("minimize-slide", "Minimise the slide", false, false),
        new("gather-app", "Gather this app’s windows into one slide", false, false),
        new("sort-slides", "Sort slides by app", false, false),
        new("tile-floating", "Tile every floating window", false, false),
        new("rescue-windows", "Rescue windows (bring everything on screen)", false, false),
        new("solo", "Solo: hide other apps", true, false),
        new("toggle-gaps", "Gaps on / off", true, false),
        new("bigger-gaps", "Bigger gaps", false, false),
        new("smaller-gaps", "Smaller gaps", false, false),
        new("center-floating", "Centre the floating window", false, false),
        new("lock-slide", "Lock / unlock the slide", false, false),
        new("open-into-slide", "New windows join the focused slide (on / off)", false, false),
        new("cheat-sheet", "Show the shortcut cheat sheet", true, false),
        new("name-slide", "Name the slide…", false, false),
        new("fit-mode", "Fit mode on / off (every slide on screen)", false, false),
        new("slide-to-start", "Move the slide to the start", false, false),
        new("slide-to-end", "Move the slide to the end", false, false),
        new("slide-to-next-workspace", "Move the slide to the next workspace", false, false),
        new("slide-to-previous-workspace", "Move the slide to the previous workspace", false, false),
        new("slide-to-empty-workspace", "Move the slide to an empty workspace", false, false),
        new("unpair-slide", "Give every window in the slide its own slide", false, false),
        new("merge-next", "Merge with the next slide", false, false),
        new("merge-previous", "Merge with the previous slide", false, false),
        new("next-tile", "Next window in the slide", false, false),
        new("previous-tile", "Previous window in the slide", false, false),
        new("main-tile", "Go to the slide’s main window", false, false),
        new("width-quarter", "Width: a quarter", false, false),
        new("width-third", "Width: a third", false, false),
        new("width-half", "Width: half", false, false),
        new("width-two-thirds", "Width: two thirds", false, false),
        new("width-three-quarters", "Width: three quarters", false, false),
        new("scroll-to-start", "Look at the start of the strip", false, false),
        new("scroll-to-end", "Look at the end of the strip", false, false),
        new("layout-side-by-side", "Slide layout: side by side", false, false),
        new("layout-up-down", "Slide layout: up and down", false, false),
        new("layout-grid", "Slide layout: grid", false, false),
        new("layout-main-side", "Slide layout: main + side", false, false),
        new("layout-main-bottom", "Slide layout: main + bottom", false, false),
        new("layout-spiral", "Slide layout: spiral", false, false),
        new("layout-accordion", "Slide layout: accordion", false, false),
        new("layout-tabs", "Slide layout: tabs", false, false),
        new("reset-split", "Reset the main window’s share", false, false),
        new("hide-app", "Hide the focused app", false, false),
        new("minimize-workspace", "Minimise every window in the workspace", false, false),
        new("minimize-others", "Minimise everything but this slide", false, false),
        new("rename-workspace", "Rename the workspace…", false, false),
        new("swap-workspace-next", "Swap the workspace with the next one", false, false),
        new("swap-workspace-previous", "Swap the workspace with the previous one", false, false),
        new("merge-workspace-previous", "Merge the workspace into the previous one", false, false),
        new("launch-beside", "Quick launch beside this window (then a letter)", false, false),
        new("open-link-beside", "Open the copied link beside this window", false, false),
        new("copy-layout", "Copy the workspace’s layout", false, false),
        new("paste-layout", "Paste a copied layout", false, false),
        new("note-window", "Add a note to the window…", false, false),
        new("locate-pointer", "Show where the pointer is", false, false),
        new("flash-focus", "Show which window has focus", false, false),
        new("toggle-dim", "Dimming on / off", false, false),
        new("toggle-border", "Focus border on / off", false, false),
        new("toggle-slider-bar", "Slider bar on / off", false, false),
        new("toggle-animations", "Animations on / off", false, false),
        new("pomodoro", "Pomodoro: focus and break cycles", false, false),
        new("toggle-quiet", "Quiet mode on / off", false, false),
        new("restart", "Restart Monorail", false, false),
        new("open-settings", "Open Settings", false, false),
        new("check-updates", "Check for updates", false, false),
        new("sort-into-projects", "Sort windows into project workspaces", false, false),
        new("go-to-predicted", "Go to the window you usually go to next", false, false),
        new("start-intent", "Start working on…", false, false),
        new("elastic-focus", "Elastic focus on or off", false, false),
        new("add-bookmark", "Bookmark this view", false, false),
        new("next-bookmark", "Go to the next bookmarked view", false, false),
        new("fork-layout", "Try a new layout (fork this workspace)", false, false),
        new("keep-fork", "Keep the layout you tried", false, false),
        new("discard-fork", "Back to the layout before trying", false, false),
        new("group-window", "Add to or remove from the window group", false, false),
        new("move-group-next", "Move the window group to the next workspace", false, false),
        new("timeline", "Layout timeline", false, false),
        new("tall-slide", "Tall slide: windows full height, scroll up and down", false, false),
        new("archive-workspace", "Archive this workspace (save and close its windows)", false, false),
        new("share-workspace", "Share this workspace’s setup", false, false),
        new("vim-mode", "Vim mode on or off", false, false),
        new("search-window-text", "Find a window by what’s in it", false, false),
        new("voice-command", "Voice command", false, false),
        new("deep-work", "Deep work on or off", false, false),
        new("reading-mode", "Reading mode", false, false),
        new("mark-private", "Mark this window private", false, false),
        new("share-slide", "Share this slide as one window", false, false),
        new("demo-zoom", "Demo zoom", false, false),
        new("show-keystrokes", "Show keystrokes and clicks", false, false),
        new("annotate", "Draw on the screen", false, false),
        new("presenter-notes", "Presenter notes", false, false),
        new("mirror-window", "Mirror this window on another display", false, false),
        new("guest-mode", "Guest mode", false, false),
        new("ultrawide-center", "Centre the main slide", false, false),
        new("link-across-displays", "Link this slide with the one on the other display", false, false),
        new("camera-tile", "Camera preview tile", false, false),
        new("pair-sync", "Sync layout with a nearby Mac", false, false),
        new("handoff", "Continue this workspace on my other Mac", false, false),
        new("workspace-clipboard", "This workspace’s clipboard", false, false),
        new("stay-awake", "Stay Awake on or off", false, false),
        new("stay-awake-30", "Stay awake for 30 minutes", false, false),
        new("stay-awake-60", "Stay awake for 1 hour", false, false),
        new("stay-awake-120", "Stay awake for 2 hours", false, false),
        new("stay-awake-downloading", "Stay awake while downloading", false, false),
        new("stay-awake-display", "Stay Awake: keep the display on or let it sleep", false, false),
        new("dock-left", "Dock onto the window on the left", false, false),
        new("dock-right", "Dock onto the window on the right", false, false),
        new("dock-up", "Dock onto the window above", false, false),
        new("dock-down", "Dock onto the window below", false, false),
        new("tear-off", "Tear off into a slide of its own", false, false),
        new("balance-splits", "Even out the splits in this slide", false, false),
        new("nest-slide", "Split this slide freely (nested)", false, false),
        new("view-back", "Back to the previous view", true, false),
        new("view-forward", "Forward to the next view", true, false),
        new("view-1", "Go to saved view 1", true, true),
        new("view-2", "Go to saved view 2", true, true),
        new("view-3", "Go to saved view 3", true, true),
        new("view-4", "Go to saved view 4", true, true),
        new("view-5", "Go to saved view 5", true, true),
        new("view-6", "Go to saved view 6", true, true),
        new("view-7", "Go to saved view 7", true, true),
        new("view-8", "Go to saved view 8", true, true),
        new("view-9", "Go to saved view 9", true, true),
        new("save-view-1", "Save this view as 1", true, true),
        new("save-view-2", "Save this view as 2", true, true),
        new("save-view-3", "Save this view as 3", true, true),
        new("save-view-4", "Save this view as 4", true, true),
        new("save-view-5", "Save this view as 5", true, true),
        new("save-view-6", "Save this view as 6", true, true),
        new("save-view-7", "Save this view as 7", true, true),
        new("save-view-8", "Save this view as 8", true, true),
        new("save-view-9", "Save this view as 9", true, true),
        new("tag-1", "Also keep this window on workspace 1", false, true),
        new("tag-2", "Also keep this window on workspace 2", false, true),
        new("tag-3", "Also keep this window on workspace 3", false, true),
        new("tag-4", "Also keep this window on workspace 4", false, true),
        new("tag-5", "Also keep this window on workspace 5", false, true),
        new("tag-6", "Also keep this window on workspace 6", false, true),
        new("tag-7", "Also keep this window on workspace 7", false, true),
        new("tag-8", "Also keep this window on workspace 8", false, true),
        new("tag-9", "Also keep this window on workspace 9", false, true),
        new("combine-1", "Show workspace 1 alongside this one", false, true),
        new("combine-2", "Show workspace 2 alongside this one", false, true),
        new("combine-3", "Show workspace 3 alongside this one", false, true),
        new("combine-4", "Show workspace 4 alongside this one", false, true),
        new("combine-5", "Show workspace 5 alongside this one", false, true),
        new("combine-6", "Show workspace 6 alongside this one", false, true),
        new("combine-7", "Show workspace 7 alongside this one", false, true),
        new("combine-8", "Show workspace 8 alongside this one", false, true),
        new("combine-9", "Show workspace 9 alongside this one", false, true),
        new("retile", "Retile everything", true, false),
        new("undo", "Undo last layout change", true, false),
        new("toggle-pause", "Pause / resume", true, false),
    };
}
