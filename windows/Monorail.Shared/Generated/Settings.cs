// Generated from spec/settings.json by scripts/gen-defs.py. Don't edit by hand.
#nullable enable
namespace Monorail.Shared;

/// <summary>Every setting's key, as saved in settings.json.</summary>
public static class SettingKeys
{
    public const string Layout = "layout";
    public const string Animate = "animate";
    public const string AnimationDuration = "animationDuration";
    public const string ModifierSwipe = "modifierSwipe";
    public const string ScrollModifier = "scrollModifier";
    public const string ScrollOverMenuBar = "scrollOverMenuBar";
    public const string ShowNavigationArrows = "showNavigationArrows";
    public const string SlideTrigger = "slideTrigger";
    public const string SwipeFingers = "swipeFingers";
    public const string SwipeSensitivity = "swipeSensitivity";
    public const string InvertSwipe = "invertSwipe";
    public const string MouseFollowsFocus = "mouseFollowsFocus";
    public const string FocusFollowsMouse = "focusFollowsMouse";
    public const string KeepHeights = "keepHeights";
    public const string FocusBorder = "focusBorder";
    public const string FocusBorderWidth = "focusBorderWidth";
    public const string FocusBorderColor = "focusBorderColor";
    public const string DimInactive = "dimInactive";
    public const string DimAmount = "dimAmount";
    public const string ShowColumnIndicator = "showColumnIndicator";
    public const string NewWindowPosition = "newWindowPosition";
    public const string AppRules = "appRules";
    public const string Keymap = "keymap";
    public const string SliderBar = "sliderBar";
    public const string SliderBarEdge = "sliderBarEdge";
    public const string IconOpensSlider = "iconOpensSlider";
    public const string GroupByApp = "groupByApp";
    public const string TilesPerSlide = "tilesPerSlide";
    public const string HotEdges = "hotEdges";
    public const string CustomLayouts = "customLayouts";
    public const string AppPairs = "appPairs";
    public const string Profiles = "profiles";
    public const string DynamicWorkspaces = "dynamicWorkspaces";
    public const string HapticFeedback = "hapticFeedback";
    public const string PinchForOverview = "pinchForOverview";
    public const string AttentionMarkers = "attentionMarkers";
    public const string SnapPicker = "snapPicker";
    public const string FocusMinutes = "focusMinutes";
    public const string FocusDim = "focusDim";
    public const string DisplayOverrides = "displayOverrides";
    public const string Theme = "theme";
    public const string SyncThroughICloud = "syncThroughICloud";
    public const string ThreeFingerTapOverview = "threeFingerTapOverview";
    public const string PeekWithOption = "peekWithOption";
    public const string CollectStats = "collectStats";
    public const string AutoRules = "autoRules";
    public const string SmartGaps = "smartGaps";
    public const string LaunchSlots = "launchSlots";
    public const string MenuBarShowsApp = "menuBarShowsApp";
    public const string ModifierDrag = "modifierDrag";
    public const string TitleBarSwipes = "titleBarSwipes";
    public const string FocusBorderGradient = "focusBorderGradient";
    public const string FocusBorderColor2 = "focusBorderColor2";
    public const string WorkspaceWallpapers = "workspaceWallpapers";
    public const string LiveReloadSettings = "liveReloadSettings";
    public const string PublishState = "publishState";
    public const string EventScript = "eventScript";
    public const string FollowReduceMotion = "followReduceMotion";
    public const string ResizeHUD = "resizeHUD";
    public const string RememberWidths = "rememberWidths";
    public const string CenterLoneWindow = "centerLoneWindow";
    public const string AutoGrowFocus = "autoGrowFocus";
    public const string Projects = "projects";
    public const string Templates = "templates";
    public const string MeetingHelper = "meetingHelper";
    public const string MeetingProfile = "meetingProfile";
    public const string VerticalWorkspaceSwipes = "verticalWorkspaceSwipes";
    public const string PinchZoomsStrip = "pinchZoomsStrip";
    public const string LocalAPI = "localAPI";
    public const string ApiPort = "apiPort";
    public const string Scripts = "scripts";
    public const string Language = "language";
    public const string OpenNextToSameApp = "openNextToSameApp";
    public const string OpenIntoFocusedSlide = "openIntoFocusedSlide";
    public const string WorkspaceHUD = "workspaceHUD";
    public const string SliderTitles = "sliderTitles";
    public const string CompactSlider = "compactSlider";
    public const string MenuBarStyle = "menuBarStyle";
    public const string CompactMenuBarApplied = "compactMenuBarApplied";
    public const string QuietMode = "quietMode";
    public const string SlideSound = "slideSound";
    public const string AnnounceChanges = "announceChanges";
    public const string RememberFloatingPositions = "rememberFloatingPositions";
    public const string AutoSnapshot = "autoSnapshot";
    public const string DailyBackups = "dailyBackups";
    public const string SkipAnimationsOnBattery = "skipAnimationsOnBattery";
    public const string CheatSheetOnHold = "cheatSheetOnHold";
    public const string FocusFollowsMouseDelay = "focusFollowsMouseDelay";
    public const string CapsLockKey = "capsLockKey";
    public const string FitByDefault = "fitByDefault";
    public const string FitExceptions = "fitExceptions";
    public const string WorkspaceNotes = "workspaceNotes";
    public const string AutoNameWorkspaces = "autoNameWorkspaces";
    public const string BetaUpdates = "betaUpdates";
    public const string WeeklySummary = "weeklySummary";
    public const string LastSeenVersion = "lastSeenVersion";
    public const string HotCorners = "hotCorners";
    public const string MouseButtonsStep = "mouseButtonsStep";
    public const string ScrollResizes = "scrollResizes";
    public const string ShiftScrollSwitchesWorkspace = "shiftScrollSwitchesWorkspace";
    public const string MiddleClickZoom = "middleClickZoom";
    public const string FocusGlow = "focusGlow";
    public const string BorderFromAppIcon = "borderFromAppIcon";
    public const string PauseForStageManager = "pauseForStageManager";
    public const string PortraitStacks = "portraitStacks";
    public const string RestoreHidesOthers = "restoreHidesOthers";
    public const string ReservedEdges = "reservedEdges";
    public const string AppAppearance = "appAppearance";
    public const string PowerMarkers = "powerMarkers";
    public const string ParkPowerHogs = "parkPowerHogs";
    public const string BatteryMenuBar = "batteryMenuBar";
    public const string BatteryCards = "batteryCards";
    public const string BatteryHiddenCards = "batteryHiddenCards";
    public const string AwakeDuringCalls = "awakeDuringCalls";
    public const string MovieAuto = "movieAuto";
    public const string ChargeLimit = "chargeLimit";
    public const string WorldClocks = "worldClocks";
    public const string ClipboardHistory = "clipboardHistory";
    public const string ClipboardKeep = "clipboardKeep";
    public const string FocusFlash = "focusFlash";
    public const string SliderOpacity = "sliderOpacity";
    public const string SliderScale = "sliderScale";
    public const string PlainOverview = "plainOverview";
    public const string OverviewIconsOnly = "overviewIconsOnly";
    public const string MenuBarShowsTitle = "menuBarShowsTitle";
    public const string NoticePosition = "noticePosition";
    public const string NoticeDuration = "noticeDuration";
    public const string PomodoroFocus = "pomodoroFocus";
    public const string PomodoroBreak = "pomodoroBreak";
    public const string BreakReminderMinutes = "breakReminderMinutes";
    public const string DailyFocusGoal = "dailyFocusGoal";
    public const string WorkspaceConfigs = "workspaceConfigs";
    public const string AutoParkHours = "autoParkHours";
    public const string FloatSmallerThan = "floatSmallerThan";
    public const string FloatSettingsWindows = "floatSettingsWindows";
    public const string PauseForApps = "pauseForApps";
    public const string RetileAfterWake = "retileAfterWake";
    public const string AnimationCurve = "animationCurve";
    public const string AnimationFPS = "animationFPS";
    public const string RescueAfterCrash = "rescueAfterCrash";
    public const string ClickSound = "clickSound";
    public const string AnnounceWindows = "announceWindows";
    public const string WebhookURL = "webhookURL";
    public const string RemoteCommands = "remoteCommands";
    public const string StageNextWindow = "stageNextWindow";
    public const string DistractionNudges = "distractionNudges";
    public const string ContentAwareWidths = "contentAwareWidths";
    public const string PathRules = "pathRules";
    public const string DisplayProfiles = "displayProfiles";
    public const string AgentAlerts = "agentAlerts";
    public const string AgentBringIntoView = "agentBringIntoView";
    public const string RuleSuggestions = "ruleSuggestions";
    public const string SuggestedRules = "suggestedRules";
    public const string MonorailKeySource = "monorailKeySource";
    public const string MouseGestures = "mouseGestures";
    public const string MidiControl = "midiControl";
    public const string MidiMap = "midiMap";
    public const string GameController = "gameController";
    public const string WebRemote = "webRemote";
    public const string WebRemoteToken = "webRemoteToken";
    public const string HeadFocus = "headFocus";
    public const string DeepWorkApps = "deepWorkApps";
    public const string DeepWorkFromCalendar = "deepWorkFromCalendar";
    public const string SafeScreenShare = "safeScreenShare";
    public const string PrivateApps = "privateApps";
    public const string PrivacyBlur = "privacyBlur";
    public const string DimFollowsPointer = "dimFollowsPointer";
    public const string EnergySaver = "energySaver";
    public const string PresenterNotes = "presenterNotes";
    public const string WorkspaceClipboard = "workspaceClipboard";
    public const string DriftWallpaper = "driftWallpaper";
    public const string NotchHUD = "notchHUD";
    public const string SoundPack = "soundPack";
    public const string CrashReports = "crashReports";
    public const string AskAfterCrash = "askAfterCrash";
    public const string ConfirmDestructiveAPI = "confirmDestructiveAPI";
    public const string ParkInCorner = "parkInCorner";
    public const string WholeSlidesOnly = "wholeSlidesOnly";
    public const string FitMinimumWidth = "fitMinimumWidth";
    public const string AwakeKeepDisplayOn = "awakeKeepDisplayOn";
    public const string AwakeAllowScreenSaver = "awakeAllowScreenSaver";
    public const string AwakeDefaultMinutes = "awakeDefaultMinutes";
    public const string AwakeBatteryCutoff = "awakeBatteryCutoff";
    public const string AwakeMoveCursor = "awakeMoveCursor";
    public const string KeepAvailable = "keepAvailable";
    public const string ArrangeScriptableApps = "arrangeScriptableApps";
    public const string AwakeMoveCursorMinutes = "awakeMoveCursorMinutes";
    public const string AwakeDriveAlive = "awakeDriveAlive";
    public const string AwakeClosedLid = "awakeClosedLid";
    public const string AwakeClosedLidOnlyOnPower = "awakeClosedLidOnlyOnPower";
    public const string ShowAllSettings = "showAllSettings";
    public const string EveningStrength = "eveningStrength";
    public const string EveningOn = "eveningOn";
    public const string EveningSchedule = "eveningSchedule";
    public const string EveningStart = "eveningStart";
    public const string EveningEnd = "eveningEnd";
    public const string EveningPausedApps = "eveningPausedApps";
    public const string EveningRed = "eveningRed";
    public const string DisplayBrightness = "displayBrightness";
    public const string WindowSwitcherShortcut = "windowSwitcherShortcut";
    public const string EdgeSnapping = "edgeSnapping";
    public const string EdgeSnappingDefersToMacOS = "edgeSnappingDefersToMacOS";
    public const string AwakeNotify = "awakeNotify";
    public const string AwakeSound = "awakeSound";
    public const string AwakeShowTime = "awakeShowTime";
    public const string AwakeOnLaunch = "awakeOnLaunch";
    public const string AwakeTriggers = "awakeTriggers";
    public const string AwakeTriggersOn = "awakeTriggersOn";
    public const string AwakeLockAfterMinutes = "awakeLockAfterMinutes";
    public const string MenuWindowsInline = "menuWindowsInline";
    public const string MeetingLayout = "meetingLayout";
    public const string MeetingNotesApp = "meetingNotesApp";
    public const string SidecarFit = "sidecarFit";
    public const string SeenTips = "seenTips";
    public const string ShareUsageStats = "shareUsageStats";
    public const string UsageNoticeShown = "usageNoticeShown";
    public const string RestoreBrowserTabs = "restoreBrowserTabs";
    public const string FloatSuggestions = "floatSuggestions";
    public const string AssistantModel = "assistantModel";
    public const string AssistantProvider = "assistantProvider";
    public const string AssistantModels = "assistantModels";
    public const string AssistantBaseURL = "assistantBaseURL";
    public const string DragToDock = "dragToDock";
    public const string GapHandles = "gapHandles";
    public const string SliderBarStepsAside = "sliderBarStepsAside";
    public const string KeepEverythingOnScreen = "keepEverythingOnScreen";
    public const string SystemPromptsInFront = "systemPromptsInFront";
    public const string KeepWindowsInPlace = "keepWindowsInPlace";
    public const string ResizeAssist = "resizeAssist";
    public const string PairLoneWindowsOnOpen = "pairLoneWindowsOnOpen";
    public const string GroupTerminals = "groupTerminals";
    public const string SlideArrangement = "slideArrangement";
    public const string WorkspaceCount = "workspaceCount";
    public const string WorkspaceNames = "workspaceNames";
    public const string CheckForUpdates = "checkForUpdates";
    public const string InstallUpdatesAutomatically = "installUpdatesAutomatically";
    public const string RulesVersion = "rulesVersion";
    public const string HasCompletedOnboarding = "hasCompletedOnboarding";
}

/// <summary>Defaults of the plain settings.</summary>
public static class SettingDefaults
{
    /// <summary>Animate windows into place instead of jumping.</summary>
    public const bool Animate = true;
    /// <summary>Animation length in seconds.</summary>
    public const double AnimationDuration = 0.2;
    /// <summary>Scroll the strip with the mouse wheel or trackpad while holding `scrollModifier`.</summary>
    public const bool ModifierSwipe = true;
    /// <summary>Scrolling over the menu bar moves the strip, no keys needed.</summary>
    public const bool ScrollOverMenuBar = true;
    /// <summary>Show clickable ‹ › buttons in the menu bar.</summary>
    public const bool ShowNavigationArrows = false;
    /// <summary>Multiplier applied to swipe distance.</summary>
    public const double SwipeSensitivity = 1.0;
    /// <summary>Flip the swipe direction.</summary>
    public const bool InvertSwipe = false;
    /// <summary>Move the mouse pointer to the centre of a window focused from the keyboard.</summary>
    public const bool MouseFollowsFocus = false;
    /// <summary>Focus the window under the mouse pointer.</summary>
    public const bool FocusFollowsMouse = false;
    /// <summary>Windows in single-window columns keep their own height, top aligned.</summary>
    public const bool KeepHeights = false;
    /// <summary>Draw a coloured border around the focused window.</summary>
    public const bool FocusBorder = false;
    public const double FocusBorderWidth = 3.0;
    /// <summary>Hex colour of the focus border, e.g. "#4C8DFF".</summary>
    public const string FocusBorderColor = "#4C8DFF";
    /// <summary>Darken tiled windows that do not have focus.</summary>
    public const bool DimInactive = false;
    /// <summary>Opacity of the dimming overlay, 0...1.</summary>
    public const double DimAmount = 0.2;
    /// <summary>Show "3/8" (focused column / columns) next to the menu bar icon.</summary>
    public const bool ShowColumnIndicator = true;
    /// <summary>Clicking the menu bar icon shows the slider; right-click shows the menu.</summary>
    public const bool IconOpensSlider = true;
    /// <summary>Group windows into full-screen slides by app as they open.</summary>
    public const bool GroupByApp = true;
    /// <summary>Windows per slide when grouping, unless an app rule says otherwise.</summary>
    public const int TilesPerSlide = 2;
    /// <summary>Push the pointer against the left or right screen edge to slide.</summary>
    public const bool HotEdges = false;
    /// <summary>Show only the workspaces in use, plus one empty one.</summary>
    public const bool DynamicWorkspaces = false;
    /// <summary>A light tap on Force Touch trackpads when the strip settles.</summary>
    public const bool HapticFeedback = true;
    /// <summary>Hold ⌥ and pinch on the trackpad to open (pinch in) or close the overview.</summary>
    public const bool PinchForOverview = true;
    /// <summary>Red dots on slides whose apps show a badge in the Dock.</summary>
    public const bool AttentionMarkers = true;
    /// <summary>Dragging a window to the top of the screen shows layouts to drop it into.</summary>
    public const bool SnapPicker = true;
    /// <summary>Focus mode: how long it lasts (0 = until turned off) and how dark the rest gets.</summary>
    public const int FocusMinutes = 25;
    public const double FocusDim = 0.6;
    /// <summary>Keep settings, layouts and app pairs in iCloud Drive, shared by your Macs.</summary>
    public const bool SyncThroughICloud = false;
    /// <summary>A three-finger tap on the trackpad opens the overview.</summary>
    public const bool ThreeFingerTapOverview = false;
    /// <summary>Hold ⌥ while hovering a slide in the slider to peek at it full size.</summary>
    public const bool PeekWithOption = true;
    /// <summary>Count switches and pairings on this Mac, for Insights and suggestions.</summary>
    public const bool CollectStats = true;
    /// <summary>No gaps around a lone window; wider gaps on big displays.</summary>
    public const bool SmartGaps = false;
    /// <summary>The menu bar shows the focused app's name next to the position.</summary>
    public const bool MenuBarShowsApp = false;
    /// <summary>Hold ⌃⌥ and drag anywhere in a window to move it; right-drag to resize.</summary>
    public const bool ModifierDrag = true;
    /// <summary>Two-finger swipes on a window's title bar: left and right move its slide, up toggles full width, down minimises.</summary>
    public const bool TitleBarSwipes = false;
    /// <summary>The focus border fades from its colour into a second one.</summary>
    public const bool FocusBorderGradient = false;
    public const string FocusBorderColor2 = "#FF5F9E";
    /// <summary>Watch settings.json and pick up changes made in a text editor.</summary>
    public const bool LiveReloadSettings = true;
    /// <summary>Write state.json and post a notification on changes, for SketchyBar and other status bars.</summary>
    public const bool PublishState = false;
    /// <summary>A script run on events (workspace and focus changes), with details in environment variables.</summary>
    public const string EventScript = "";
    /// <summary>Skip animations when macOS's Reduce Motion or Low Power Mode is on.</summary>
    public const bool FollowReduceMotion = true;
    /// <summary>While resizing by hand, show the window's size.</summary>
    public const bool ResizeHUD = true;
    /// <summary>New windows of an app open at the width you last gave it.</summary>
    public const bool RememberWidths = true;
    /// <summary>A lone window sits centred at this share of the screen (0 = off).</summary>
    public const double CenterLoneWindow = 0.0;
    /// <summary>The focused one of two windows in a slide grows to this share (0 = off).</summary>
    public const double AutoGrowFocus = 0.0;
    /// <summary>Before a calendar event with a meeting link: open it and switch profile.</summary>
    public const bool MeetingHelper = false;
    /// <summary>Three- or four-finger vertical swipes switch workspace (sliding up or down).</summary>
    public const bool VerticalWorkspaceSwipes = false;
    /// <summary>⌥ + pinch zooms out on the strip (instead of opening the overview).</summary>
    public const bool PinchZoomsStrip = true;
    /// <summary>A local API (and MCP server) for other apps and AI assistants.</summary>
    public const bool LocalAPI = false;
    public const int ApiPort = 4767;
    /// <summary>Run JavaScript plugins from the Scripts folder.</summary>
    public const bool Scripts = false;
    /// <summary>Interface language: empty follows macOS.</summary>
    public const string Language = "";
    /// <summary>New windows open right after their app's other windows.</summary>
    public const bool OpenNextToSameApp = false;
    /// <summary>New windows join the focused slide (toggled by an action).</summary>
    public const bool OpenIntoFocusedSlide = false;
    /// <summary>Show the workspace's name in the middle of the screen when switching.</summary>
    public const bool WorkspaceHUD = true;
    /// <summary>Window titles on the slider bar's tiles, and a smaller bar.</summary>
    public const bool SliderTitles = false;
    public const bool CompactSlider = false;
    /// <summary>Set once the narrower 1.1 menu bar has been applied to older settings.</summary>
    public const bool CompactMenuBarApplied = true;
    /// <summary>No pop-up notices (confirmations, tips).</summary>
    public const bool QuietMode = false;
    /// <summary>A soft click as the strip lands on a slide.</summary>
    public const bool SlideSound = false;
    /// <summary>VoiceOver says which slide and workspace you moved to.</summary>
    public const bool AnnounceChanges = true;
    /// <summary>Floating windows go back where you last put them, per app.</summary>
    public const bool RememberFloatingPositions = true;
    /// <summary>Take a "Last session" snapshot on quit and before sleep.</summary>
    public const bool AutoSnapshot = true;
    /// <summary>Keep a copy of the settings each day (the last seven).</summary>
    public const bool DailyBackups = true;
    /// <summary>Skip animations while running on battery.</summary>
    public const bool SkipAnimationsOnBattery = false;
    /// <summary>Hold ⌃⌥ for a moment to see a cheat sheet of shortcuts.</summary>
    public const bool CheatSheetOnHold = true;
    /// <summary>Focus follows mouse waits this long (seconds) before switching.</summary>
    public const double FocusFollowsMouseDelay = 0.15;
    /// <summary>Caps Lock becomes the Monorail key: hold it instead of ⌃⌥.</summary>
    public const bool CapsLockKey = false;
    /// <summary>Fit mode: every slide shares the screen. On for all workspaces, or just some; `fitExceptions` lists workspaces (absolute numbers) that differ.</summary>
    public const bool FitByDefault = false;
    /// <summary>Workspaces without a name take their apps' names.</summary>
    public const bool AutoNameWorkspaces = true;
    /// <summary>Get early (beta) versions as well as final ones.</summary>
    public const bool BetaUpdates = false;
    /// <summary>A notification on Monday mornings with last week's Insights.</summary>
    public const bool WeeklySummary = false;
    /// <summary>The version whose What's New was last shown.</summary>
    public const string LastSeenVersion = "";
    /// <summary>Mouse buttons 4 and 5 (back and forward) step through slides.</summary>
    public const bool MouseButtonsStep = false;
    /// <summary>⌃⌥ + scroll over a window changes its slide's width.</summary>
    public const bool ScrollResizes = true;
    /// <summary>⇧ + scroll over the slider bar switches workspace.</summary>
    public const bool ShiftScrollSwitchesWorkspace = true;
    /// <summary>⌥ + middle-click a window zooms it.</summary>
    public const bool MiddleClickZoom = true;
    /// <summary>The focus border glows, and can take the app icon's colour.</summary>
    public const bool FocusGlow = false;
    public const bool BorderFromAppIcon = false;
    /// <summary>Monorail pauses while Stage Manager is on and carries on when it's turned off.</summary>
    public const bool PauseForStageManager = true;
    /// <summary>On a display taller than it is wide, slides stack top to bottom and the main window goes on top.</summary>
    public const bool PortraitStacks = true;
    /// <summary>Restoring a saved layout or snapshot hides (never quits) the apps that aren't in it.</summary>
    public const bool RestoreHidesOthers = false;
    /// <summary>On battery, ⚡ marks the windows of apps using the most power, and ⚡ in the popover lists them.</summary>
    public const bool PowerMarkers = true;
    /// <summary>On battery, hide (never quit) power-hungry apps left alone for an hour; they come back when plugged in.</summary>
    public const bool ParkPowerHogs = false;
    /// <summary>A battery item in the menu bar (charge or time left), opening the battery panel.</summary>
    public const bool BatteryMenuBar = false;
    /// <summary>Keep the Mac and its display awake while the microphone or camera is in use.</summary>
    public const bool AwakeDuringCalls = true;
    /// <summary>Movie mode turns on by itself when a video plays full screen.</summary>
    public const bool MovieAuto = false;
    /// <summary>While charging, a notice once the battery reaches `chargeLimit` (100 = off).</summary>
    public const int ChargeLimit = 100;
    /// <summary>Remember what you copy, for the Clipboard page. Passwords and other concealed copies are never kept.</summary>
    public const bool ClipboardHistory = true;
    /// <summary>How many clips to remember (pinned ones don't count).</summary>
    public const int ClipboardKeep = 50;
    /// <summary>A quick highlight of the focused window when focus moves by keyboard.</summary>
    public const bool FocusFlash = false;
    /// <summary>The slider bar's opacity and size (0.8, 1 or 1.25).</summary>
    public const double SliderOpacity = 1.0;
    public const double SliderScale = 1.0;
    /// <summary>The overview's backdrop: colourful, or plain.</summary>
    public const bool PlainOverview = false;
    /// <summary>The overview with app icons only (no live previews).</summary>
    public const bool OverviewIconsOnly = false;
    /// <summary>The menu bar shows the focused window's title.</summary>
    public const bool MenuBarShowsTitle = false;
    public const double NoticeDuration = 1.8;
    /// <summary>Pomodoro: focus and break lengths in minutes.</summary>
    public const int PomodoroFocus = 25;
    public const int PomodoroBreak = 5;
    /// <summary>Remind to rest your eyes every so many minutes (0 = off).</summary>
    public const int BreakReminderMinutes = 0;
    /// <summary>A daily focus goal in minutes (0 = none), shown in Insights.</summary>
    public const int DailyFocusGoal = 0;
    /// <summary>Park a workspace you haven't visited for this many hours (0 = never).</summary>
    public const int AutoParkHours = 0;
    /// <summary>Windows smaller than this (points, either side) float on their own (0 = off).</summary>
    public const double FloatSmallerThan = 0.0;
    /// <summary>Settings and preferences windows float.</summary>
    public const bool FloatSettingsWindows = true;
    /// <summary>Lay everything out again after the Mac wakes.</summary>
    public const bool RetileAfterWake = true;
    /// <summary>Animation frames per second: 30, 60 or 120.</summary>
    public const int AnimationFPS = 60;
    /// <summary>Bring every window back after Monorail quit unexpectedly.</summary>
    public const bool RescueAfterCrash = true;
    /// <summary>The click sound for slide changes.</summary>
    public const string ClickSound = "Tink";
    /// <summary>VoiceOver also says which window got focus.</summary>
    public const bool AnnounceWindows = false;
    /// <summary>POST events as JSON to this address (empty = off).</summary>
    public const string WebhookURL = "";
    /// <summary>Let other apps run actions with the org.ashforde.monorail.perform distributed notification.</summary>
    public const bool RemoteCommands = false;
    /// <summary>Bring the window you usually go to next right beside the one you are in.</summary>
    public const bool StageNextWindow = false;
    /// <summary>Suggest focus mode when you switch windows very often.</summary>
    public const bool DistractionNudges = false;
    /// <summary>New slides get a width that suits the app: ~100 columns of code, a page of text, a web page.</summary>
    public const bool ContentAwareWidths = false;
    /// <summary>Remember the layout for each set of displays and bring it back when they connect again.</summary>
    public const bool DisplayProfiles = false;
    /// <summary>Tell me when an AI coding agent in a terminal is waiting for me.</summary>
    public const bool AgentAlerts = true;
    /// <summary>Slide a waiting agent's window into view.</summary>
    public const bool AgentBringIntoView = false;
    /// <summary>Suggest rules from the fixes you keep making.</summary>
    public const bool RuleSuggestions = true;
    /// <summary>⌃⌥⇧ + drag left, right, up or down for workspaces, the overview and the desktop.</summary>
    public const bool MouseGestures = false;
    /// <summary>Run actions from a MIDI controller.</summary>
    public const bool MidiControl = false;
    /// <summary>Drive Monorail with a game controller.</summary>
    public const bool GameController = false;
    /// <summary>A remote control page for your phone on the local network.</summary>
    public const bool WebRemote = false;
    /// <summary>The secret in the remote page link.</summary>
    public const string WebRemoteToken = "";
    /// <summary>Experimental: turn your head towards a display to focus it (uses the camera).</summary>
    public const bool HeadFocus = false;
    /// <summary>Calendar events called Focus or Deep work turn deep work on.</summary>
    public const bool DeepWorkFromCalendar = false;
    /// <summary>Hide private apps while you share your screen.</summary>
    public const bool SafeScreenShare = true;
    /// <summary>Blur private windows in the overview and previews.</summary>
    public const bool PrivacyBlur = true;
    /// <summary>Dimming follows the pointer instead of focus.</summary>
    public const bool DimFollowsPointer = false;
    /// <summary>On battery, animate at 30 fps and pause live previews.</summary>
    public const bool EnergySaver = true;
    /// <summary>Your presenter notes (never shown in screen shares).</summary>
    public const string PresenterNotes = "";
    /// <summary>Keep a clipboard history for each workspace.</summary>
    public const bool WorkspaceClipboard = false;
    /// <summary>A picture that drifts gently behind the strip as it scrolls (empty = off).</summary>
    public const string DriftWallpaper = "";
    /// <summary>Show slides and workspaces around the MacBook notch as you move.</summary>
    public const bool NotchHUD = false;
    /// <summary>Keep crash and hang reports on this Mac so you can send them.</summary>
    public const bool CrashReports = false;
    /// <summary>After Monorail quits unexpectedly, ask (once per version) what happened.</summary>
    public const bool AskAfterCrash = true;
    /// <summary>Ask before an assistant or script closes windows.</summary>
    public const bool ConfirmDestructiveAPI = true;
    /// <summary>Slides off screen wait hidden in the corner (no slivers at the screen edges).</summary>
    public const bool ParkInCorner = true;
    /// <summary>Hide slides that only partly fit on screen, instead of showing them cut off at the edge.</summary>
    public const bool WholeSlidesOnly = true;
    /// <summary>Fit mode never makes a window narrower than this (points; a pair needs twice as much); extra slides scroll.</summary>
    public const double FitMinimumWidth = 480.0;
    /// <summary>Stay Awake keeps the display on too (otherwise only the Mac stays awake and the display may sleep).</summary>
    public const bool AwakeKeepDisplayOn = true;
    /// <summary>Let the screen saver start during a Stay Awake session (the Mac still stays awake).</summary>
    public const bool AwakeAllowScreenSaver = false;
    /// <summary>How long Stay Awake lasts when toggled on (0 = until you end it).</summary>
    public const int AwakeDefaultMinutes = 0;
    /// <summary>End Stay Awake when the battery drops to this percent on battery power (0 = never).</summary>
    public const int AwakeBatteryCutoff = 10;
    /// <summary>During Stay Awake, nudge the pointer now and then so chat apps don’t mark you away.</summary>
    public const bool AwakeMoveCursor = false;
    /// <summary>Keep me Available: keep the Mac awake and keep chat apps such as Teams and Slack showing you as available, by telling macOS you're active when it has been idle (no permission needed).</summary>
    public const bool KeepAvailable = false;
    /// <summary>Arrange scriptable apps (Safari, Finder, Terminal…) with Apple Events while Accessibility isn't allowed.</summary>
    public const bool ArrangeScriptableApps = true;
    /// <summary>How often the pointer is nudged (minutes).</summary>
    public const int AwakeMoveCursorMinutes = 4;
    /// <summary>During Stay Awake, keep external drives from spinning down.</summary>
    public const bool AwakeDriveAlive = false;
    /// <summary>During Stay Awake, keep running with the lid closed, even without an external display (asks for your password).</summary>
    public const bool AwakeClosedLid = false;
    /// <summary>Lid-closed mode only while plugged in (on battery, closing the lid puts the Mac to sleep).</summary>
    public const bool AwakeClosedLidOnlyOnPower = true;
    /// <summary>Settings shows every section; off, only the essential ones (search still finds everything).</summary>
    public const bool ShowAllSettings = false;
    /// <summary>Evening Mode: a warmer screen with less blue light. How strong, 0–1.</summary>
    public const double EveningStrength = 0.5;
    /// <summary>Turned on by hand (from the menu bar or Settings).</summary>
    public const bool EveningOn = false;
    /// <summary>Evening Mode goes red: green and blue fade out as well, down to red light only at full strength.</summary>
    public const bool EveningRed = false;
    /// <summary>Drag a floating window to a screen edge for a half, a corner for a quarter, or the top to maximise.</summary>
    public const bool EdgeSnapping = false;
    /// <summary>Leave edge drags to macOS when its own tiling by dragging to screen edges is on (macOS 15 and later).</summary>
    public const bool EdgeSnappingDefersToMacOS = true;
    /// <summary>Show a notice when Stay Awake starts and ends.</summary>
    public const bool AwakeNotify = true;
    /// <summary>Play a sound when Stay Awake starts and ends.</summary>
    public const bool AwakeSound = false;
    /// <summary>Show the time left in the menu bar.</summary>
    public const bool AwakeShowTime = true;
    /// <summary>Start Stay Awake when Monorail opens.</summary>
    public const bool AwakeOnLaunch = false;
    /// <summary>Automatic Stay Awake triggers are on.</summary>
    public const bool AwakeTriggersOn = true;
    /// <summary>During Stay Awake, still lock the screen after this many idle minutes (0 = never).</summary>
    public const int AwakeLockAfterMinutes = 0;
    /// <summary>List the workspace’s windows right in the menu bar menu (otherwise they are in a Windows submenu).</summary>
    public const bool MenuWindowsInline = false;
    /// <summary>When a call opens from your calendar, put your notes app beside it (and keep your layout to bring back afterwards).</summary>
    public const bool MeetingLayout = false;
    /// <summary>The notes app put beside calls (bundle ID).</summary>
    public const string MeetingNotesApp = "com.apple.Notes";
    /// <summary>On a Sidecar iPad, every slide fits on screen.</summary>
    public const bool SidecarFit = true;
    /// <summary>Send anonymous daily usage counts (version, macOS, Mac model, features on). Never titles, apps or files.</summary>
    public const bool ShareUsageStats = true;
    /// <summary>Whether the one-time notice about anonymous usage counts was shown.</summary>
    public const bool UsageNoticeShown = false;
    /// <summary>Snapshots also save and reopen browser tabs (Safari, Chrome, Arc, Brave, Edge) and Finder windows.</summary>
    public const bool RestoreBrowserTabs = false;
    /// <summary>Suggest always floating an app after you float its windows by hand a few times.</summary>
    public const bool FloatSuggestions = true;
    /// <summary>The Claude model the optional assistant uses, with your own API key.</summary>
    public const string AssistantModel = "claude-opus-5-5";
    /// <summary>The address of an OpenAI-compatible server (Other), or a different address for Ollama.</summary>
    public const string AssistantBaseURL = "";
    /// <summary>Drag a window onto another window: near an edge docks it beside, the middle makes a tab group (any apps).</summary>
    public const bool DragToDock = true;
    /// <summary>Drag the gap between two windows to resize both at once.</summary>
    public const bool GapHandles = true;
    /// <summary>The slider bar steps aside for full-screen apps and for a playing video underneath it.</summary>
    public const bool SliderBarStepsAside = true;
    /// <summary>Floating windows and dialogs that end up off screen (a display unplugged, a size saved on a bigger screen, waking from sleep) come back into view on their own.</summary>
    public const bool KeepEverythingOnScreen = true;
    /// <summary>macOS permission, password and security prompts always come to the front, centred on your screen, and Monorail holds focus changes until they are answered.</summary>
    public const bool SystemPromptsInFront = true;
    /// <summary>Snap windows back when an app moves or resizes one by itself.</summary>
    public const bool KeepWindowsInPlace = true;
    /// <summary>After resizing a window in a slide, offer to rearrange the slide.</summary>
    public const bool ResizeAssist = true;
    /// <summary>Put a newly opened lone window into a slide with another app's lone window. When off, that only happens when regrouping (⌃⌥A).</summary>
    public const bool PairLoneWindowsOnOpen = false;
    /// <summary>Terminal apps (Terminal, iTerm, Ghostty, Warp, kitty, Alacritty, WezTerm) share slides with each other, as if they were one app.</summary>
    public const bool GroupTerminals = true;
    /// <summary>Workspaces per display (1...9). Each has its own strip.</summary>
    public const int WorkspaceCount = 4;
    /// <summary>Look for new versions on monorail.ashforde.org once a day.</summary>
    public const bool CheckForUpdates = true;
    /// <summary>Install new versions without asking (Monorail relaunches itself).</summary>
    public const bool InstallUpdatesAutomatically = false;
    /// <summary>Set once the welcome tour has been shown.</summary>
    public const bool HasCompletedOnboarding = false;
}
