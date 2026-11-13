// Generated from spec/settings.json by scripts/gen-defs.py. Don't edit by hand.

/** Every setting, with its type where it's a plain value (structured ones are JSON objects). */
export interface Settings {
  layout: unknown;
  /** Animate windows into place instead of jumping. */
  animate: boolean;
  /** Animation length in seconds. */
  animationDuration: number;
  /** Scroll the strip with the mouse wheel or trackpad while holding `scrollModifier`. */
  modifierSwipe: boolean;
  /** Keys to hold while scrolling to move the strip instead of the app under the pointer. */
  scrollModifier: unknown;
  /** Scrolling over the menu bar moves the strip, no keys needed. */
  scrollOverMenuBar: boolean;
  /** Show clickable ‹ › buttons in the menu bar. */
  showNavigationArrows: boolean;
  /** Tapping this key on its own turns on slide mode. */
  slideTrigger: unknown;
  /** Scroll the strip with a three- or four-finger swipe. */
  swipeFingers: unknown;
  /** Multiplier applied to swipe distance. */
  swipeSensitivity: number;
  /** Flip the swipe direction. */
  invertSwipe: boolean;
  /** Move the mouse pointer to the centre of a window focused from the keyboard. */
  mouseFollowsFocus: boolean;
  /** Focus the window under the mouse pointer. */
  focusFollowsMouse: boolean;
  /** Windows in single-window columns keep their own height, top aligned. */
  keepHeights: boolean;
  /** Draw a coloured border around the focused window. */
  focusBorder: boolean;
  focusBorderWidth: number;
  /** Hex colour of the focus border, e.g. "#4C8DFF". */
  focusBorderColor: string;
  /** Darken tiled windows that do not have focus. */
  dimInactive: boolean;
  /** Opacity of the dimming overlay, 0...1. */
  dimAmount: number;
  /** Show "3/8" (focused column / columns) next to the menu bar icon. */
  showColumnIndicator: boolean;
  /** Where newly opened windows join the strip. */
  newWindowPosition: unknown;
  /** Per-app rules. */
  appRules: unknown;
  keymap: unknown;
  /** The slider bar: a mini-map of the strip you can drag to slide. */
  sliderBar: unknown;
  sliderBarEdge: unknown;
  /** Clicking the menu bar icon shows the slider; right-click shows the menu. */
  iconOpensSlider: boolean;
  /** Group windows into full-screen slides by app as they open. */
  groupByApp: boolean;
  /** Windows per slide when grouping, unless an app rule says otherwise. */
  tilesPerSlide: number;
  /** Push the pointer against the left or right screen edge to slide. */
  hotEdges: boolean;
  /** Slide layouts designed in Settings. */
  customLayouts: unknown;
  /** Saved app pairs. */
  appPairs: unknown;
  /** Profiles: whole sets of workspaces ("Work", "Home"). */
  profiles: string[];
  /** Show only the workspaces in use, plus one empty one. */
  dynamicWorkspaces: boolean;
  /** A light tap on Force Touch trackpads when the strip settles. */
  hapticFeedback: boolean;
  /** Hold ⌥ and pinch on the trackpad to open (pinch in) or close the overview. */
  pinchForOverview: boolean;
  /** Red dots on slides whose apps show a badge in the Dock. */
  attentionMarkers: boolean;
  /** Dragging a window to the top of the screen shows layouts to drop it into. */
  snapPicker: boolean;
  /** Focus mode: how long it lasts (0 = until turned off) and how dark the rest gets. */
  focusMinutes: number;
  focusDim: number;
  /** Overrides per display, by display UUID. */
  displayOverrides: unknown;
  theme: unknown;
  /** Keep settings, layouts and app pairs in iCloud Drive, shared by your Macs. */
  syncThroughICloud: boolean;
  /** A three-finger tap on the trackpad opens the overview. */
  threeFingerTapOverview: boolean;
  /** Hold ⌥ while hovering a slide in the slider to peek at it full size. */
  peekWithOption: boolean;
  /** Count switches and pairings on this Mac, for Insights and suggestions. */
  collectStats: boolean;
  /** Profile and layout changes by time of day or Wi-Fi network. */
  autoRules: unknown;
  /** No gaps around a lone window; wider gaps on big displays. */
  smartGaps: boolean;
  /** Quick launch: a letter opens or focuses an app (by bundle ID). */
  launchSlots: Record<string, string>;
  /** The menu bar shows the focused app's name next to the position. */
  menuBarShowsApp: boolean;
  /** Hold ⌃⌥ and drag anywhere in a window to move it; right-drag to resize. */
  modifierDrag: boolean;
  /** Two-finger swipes on a window's title bar: left and right move its slide, up toggles full width, down minimises. */
  titleBarSwipes: boolean;
  /** The focus border fades from its colour into a second one. */
  focusBorderGradient: boolean;
  focusBorderColor2: string;
  /** A desktop picture per workspace (index → file path). */
  workspaceWallpapers: Record<string, string>;
  /** Watch settings.json and pick up changes made in a text editor. */
  liveReloadSettings: boolean;
  /** Write state.json and post a notification on changes, for SketchyBar and other status bars. */
  publishState: boolean;
  /** A script run on events (workspace and focus changes), with details in environment variables. */
  eventScript: string;
  /** Skip animations when macOS's Reduce Motion or Low Power Mode is on. */
  followReduceMotion: boolean;
  /** While resizing by hand, show the window's size. */
  resizeHUD: boolean;
  /** New windows of an app open at the width you last gave it. */
  rememberWidths: boolean;
  /** A lone window sits centred at this share of the screen (0 = off). */
  centerLoneWindow: number;
  /** The focused one of two windows in a slide grows to this share (0 = off). */
  autoGrowFocus: number;
  /** Windows whose titles name one of these projects gather in one workspace. */
  projects: string[];
  /** Workspace templates. */
  templates: unknown;
  /** Before a calendar event with a meeting link: open it and switch profile. */
  meetingHelper: boolean;
  meetingProfile: number | null;
  /** Three- or four-finger vertical swipes switch workspace (sliding up or down). */
  verticalWorkspaceSwipes: boolean;
  /** ⌥ + pinch zooms out on the strip (instead of opening the overview). */
  pinchZoomsStrip: boolean;
  /** A local API (and MCP server) for other apps and AI assistants. */
  localAPI: boolean;
  apiPort: number;
  /** Run JavaScript plugins from the Scripts folder. */
  scripts: boolean;
  /** Interface language: empty follows macOS. */
  language: string;
  /** New windows open right after their app's other windows. */
  openNextToSameApp: boolean;
  /** New windows join the focused slide (toggled by an action). */
  openIntoFocusedSlide: boolean;
  /** Show the workspace's name in the middle of the screen when switching. */
  workspaceHUD: boolean;
  /** Window titles on the slider bar's tiles, and a smaller bar. */
  sliderTitles: boolean;
  compactSlider: boolean;
  menuBarStyle: unknown;
  /** Set once the narrower 1.1 menu bar has been applied to older settings. */
  compactMenuBarApplied: boolean;
  /** No pop-up notices (confirmations, tips). */
  quietMode: boolean;
  /** A soft click as the strip lands on a slide. */
  slideSound: boolean;
  /** VoiceOver says which slide and workspace you moved to. */
  announceChanges: boolean;
  /** Floating windows go back where you last put them, per app. */
  rememberFloatingPositions: boolean;
  /** Take a "Last session" snapshot on quit and before sleep. */
  autoSnapshot: boolean;
  /** Keep a copy of the settings each day (the last seven). */
  dailyBackups: boolean;
  /** Skip animations while running on battery. */
  skipAnimationsOnBattery: boolean;
  /** Hold ⌃⌥ for a moment to see a cheat sheet of shortcuts. */
  cheatSheetOnHold: boolean;
  /** Focus follows mouse waits this long (seconds) before switching. */
  focusFollowsMouseDelay: number;
  /** Caps Lock becomes the Monorail key: hold it instead of ⌃⌥. */
  capsLockKey: boolean;
  /** Fit mode: every slide shares the screen. On for all workspaces, or just some; `fitExceptions` lists workspaces (absolute numbers) that differ. */
  fitByDefault: boolean;
  fitExceptions: number[];
  /** A line of notes per workspace (by its number from 0). */
  workspaceNotes: Record<string, string>;
  /** Workspaces without a name take their apps' names. */
  autoNameWorkspaces: boolean;
  /** Get early (beta) versions as well as final ones. */
  betaUpdates: boolean;
  /** A notification on Monday mornings with last week's Insights. */
  weeklySummary: boolean;
  /** The version whose What's New was last shown. */
  lastSeenVersion: string;
  /** Screen corners: top-left, top-right, bottom-left, bottom-right. */
  hotCorners: unknown;
  /** Mouse buttons 4 and 5 (back and forward) step through slides. */
  mouseButtonsStep: boolean;
  /** ⌃⌥ + scroll over a window changes its slide's width. */
  scrollResizes: boolean;
  /** ⇧ + scroll over the slider bar switches workspace. */
  shiftScrollSwitchesWorkspace: boolean;
  /** ⌥ + middle-click a window zooms it. */
  middleClickZoom: boolean;
  /** The focus border glows, and can take the app icon's colour. */
  focusGlow: boolean;
  borderFromAppIcon: boolean;
  /** Monorail pauses while Stage Manager is on and carries on when it's turned off. */
  pauseForStageManager: boolean;
  /** On a display taller than it is wide, slides stack top to bottom and the main window goes on top. */
  portraitStacks: boolean;
  /** Restoring a saved layout or snapshot hides (never quits) the apps that aren't in it. */
  restoreHidesOthers: boolean;
  /** Space kept clear at each screen edge for another app's bar or dock. */
  reservedEdges: unknown;
  /** Monorail's own windows in light or dark, or following the Mac. */
  appAppearance: unknown;
  /** On battery, ⚡ marks the windows of apps using the most power, and ⚡ in the popover lists them. */
  powerMarkers: boolean;
  /** On battery, hide (never quit) power-hungry apps left alone for an hour; they come back when plugged in. */
  parkPowerHogs: boolean;
  /** A battery item in the menu bar (charge or time left), opening the battery panel. */
  batteryMenuBar: boolean;
  /** The battery panel's cards, in the order you arranged them, and the ones you hid. */
  batteryCards: string[];
  batteryHiddenCards: string[];
  /** Keep the Mac and its display awake while the microphone or camera is in use. */
  awakeDuringCalls: boolean;
  /** Movie mode turns on by itself when a video plays full screen. */
  movieAuto: boolean;
  /** While charging, a notice once the battery reaches `chargeLimit` (100 = off). */
  chargeLimit: number;
  /** World clocks on the Today page: time zone identifiers ("Europe/London"). */
  worldClocks: string[];
  /** Remember what you copy, for the Clipboard page. Passwords and other concealed copies are never kept. */
  clipboardHistory: boolean;
  /** How many clips to remember (pinned ones don't count). */
  clipboardKeep: number;
  /** Focus sessions: length in minutes, background sound ("none", "brown", "pink", "rain") and, in Monorail, hiding your distracting apps while one runs. */
  sessionMinutes: number;
  focusSound: string;
  focusHidesApps: boolean;
  /** A reminder every 20 minutes at the screen to look into the distance for 20 seconds. */
  eyeBreaks: boolean;
  /** A quick highlight of the focused window when focus moves by keyboard. */
  focusFlash: boolean;
  /** The slider bar's opacity and size (0.8, 1 or 1.25). */
  sliderOpacity: number;
  sliderScale: number;
  /** The overview's backdrop: colourful, or plain. */
  plainOverview: boolean;
  /** The overview with app icons only (no live previews). */
  overviewIconsOnly: boolean;
  /** The menu bar shows the focused window's title. */
  menuBarShowsTitle: boolean;
  /** Where notices appear and for how long (seconds). */
  noticePosition: unknown;
  noticeDuration: number;
  /** Pomodoro: focus and break lengths in minutes. */
  pomodoroFocus: number;
  pomodoroBreak: number;
  /** Remind to rest your eyes every so many minutes (0 = off). */
  breakReminderMinutes: number;
  /** A daily focus goal in minutes (0 = none), shown in Insights. */
  dailyFocusGoal: number;
  /** Settings per workspace, by absolute workspace number. */
  workspaceConfigs: unknown;
  /** Park a workspace you haven't visited for this many hours (0 = never). */
  autoParkHours: number;
  /** Windows smaller than this (points, either side) float on their own (0 = off). */
  floatSmallerThan: number;
  /** Settings and preferences windows float. */
  floatSettingsWindows: boolean;
  /** Tiling pauses while one of these apps (bundle IDs) is in front. */
  pauseForApps: string[];
  /** Lay everything out again after the Mac wakes. */
  retileAfterWake: boolean;
  animationCurve: unknown;
  /** Animation frames per second: 30, 60 or 120. */
  animationFPS: number;
  /** Bring every window back after Monorail quit unexpectedly. */
  rescueAfterCrash: boolean;
  /** The click sound for slide changes. */
  clickSound: string;
  /** VoiceOver also says which window got focus. */
  announceWindows: boolean;
  /** POST events as JSON to this address (empty = off). */
  webhookURL: string;
  /** Let other apps run actions with the org.ashforde.monorail.perform distributed notification. */
  remoteCommands: boolean;
  /** Bring the window you usually go to next right beside the one you are in. */
  stageNextWindow: boolean;
  /** Suggest focus mode when you switch windows very often. */
  distractionNudges: boolean;
  /** New slides get a width that suits the app: ~100 columns of code, a page of text, a web page. */
  contentAwareWidths: boolean;
  /** Documents from these folders open in these workspaces. */
  pathRules: unknown;
  /** Remember the layout for each set of displays and bring it back when they connect again. */
  displayProfiles: boolean;
  /** Tell me when an AI coding agent in a terminal is waiting for me. */
  agentAlerts: boolean;
  /** Slide a waiting agent's window into view. */
  agentBringIntoView: boolean;
  /** Suggest rules from the fixes you keep making. */
  ruleSuggestions: boolean;
  /** Widths Monorail noticed you keep giving apps (bundle ID → share), waiting to become rules. */
  suggestedRules: Record<string, number>;
  /** The key that acts as the Monorail key. */
  monorailKeySource: unknown;
  /** ⌃⌥⇧ + drag left, right, up or down for workspaces, the overview and the desktop. */
  mouseGestures: boolean;
  /** Run actions from a MIDI controller. */
  midiControl: boolean;
  /** MIDI note number → action name. */
  midiMap: Record<string, string>;
  /** Drive Monorail with a game controller. */
  gameController: boolean;
  /** A remote control page for your phone on the local network. */
  webRemote: boolean;
  /** The secret in the remote page link. */
  webRemoteToken: string;
  /** Experimental: turn your head towards a display to focus it (uses the camera). */
  headFocus: boolean;
  /** Apps hidden during deep work (bundle IDs). */
  deepWorkApps: string[];
  /** Calendar events called Focus or Deep work turn deep work on. */
  deepWorkFromCalendar: boolean;
  /** Hide private apps while you share your screen. */
  safeScreenShare: boolean;
  /** Apps whose windows count as private (bundle IDs). */
  privateApps: string[];
  /** Blur private windows in the overview and previews. */
  privacyBlur: boolean;
  /** Dimming follows the pointer instead of focus. */
  dimFollowsPointer: boolean;
  /** On battery, animate at 30 fps and pause live previews. */
  energySaver: boolean;
  /** Your presenter notes (never shown in screen shares). */
  presenterNotes: string;
  /** Keep a clipboard history for each workspace. */
  workspaceClipboard: boolean;
  /** A picture that drifts gently behind the strip as it scrolls (empty = off). */
  driftWallpaper: string;
  /** Show slides and workspaces around the MacBook notch as you move. */
  notchHUD: boolean;
  /** The sounds Monorail plays. */
  soundPack: unknown;
  /** Keep crash and hang reports on this Mac so you can send them. */
  crashReports: boolean;
  /** After Monorail quits unexpectedly, ask (once per version) what happened. */
  askAfterCrash: boolean;
  /** Ask before an assistant or script closes windows. */
  confirmDestructiveAPI: boolean;
  /** Slides off screen wait hidden in the corner (no slivers at the screen edges). */
  parkInCorner: boolean;
  /** Hide slides that only partly fit on screen, instead of showing them cut off at the edge. */
  wholeSlidesOnly: boolean;
  /** Fit mode never makes a window narrower than this (points; a pair needs twice as much); extra slides scroll. */
  fitMinimumWidth: number;
  /** Stay Awake keeps the display on too (otherwise only the Mac stays awake and the display may sleep). */
  awakeKeepDisplayOn: boolean;
  /** Let the screen saver start during a Stay Awake session (the Mac still stays awake). */
  awakeAllowScreenSaver: boolean;
  /** How long Stay Awake lasts when toggled on (0 = until you end it). */
  awakeDefaultMinutes: number;
  /** End Stay Awake when the battery drops to this percent on battery power (0 = never). */
  awakeBatteryCutoff: number;
  /** During Stay Awake, nudge the pointer now and then so chat apps don’t mark you away. */
  awakeMoveCursor: boolean;
  /** Keep me Available: keep the Mac awake and keep chat apps such as Teams and Slack showing you as available, by telling macOS you're active when it has been idle (no permission needed). */
  keepAvailable: boolean;
  /** Arrange scriptable apps (Safari, Finder, Terminal…) with Apple Events while Accessibility isn't allowed. */
  arrangeScriptableApps: boolean;
  /** How often the pointer is nudged (minutes). */
  awakeMoveCursorMinutes: number;
  /** During Stay Awake, keep external drives from spinning down. */
  awakeDriveAlive: boolean;
  /** During Stay Awake, keep running with the lid closed, even without an external display (asks for your password). */
  awakeClosedLid: boolean;
  /** Lid-closed mode only while plugged in (on battery, closing the lid puts the Mac to sleep). */
  awakeClosedLidOnlyOnPower: boolean;
  /** Settings shows every section; off, only the essential ones (search still finds everything). */
  showAllSettings: boolean;
  /** Evening Mode: a warmer screen with less blue light. How strong, 0–1. */
  eveningStrength: number;
  /** Turned on by hand (from the menu bar or Settings). */
  eveningOn: boolean;
  /** By hand only, or every day on a schedule. */
  eveningSchedule: unknown;
  /** The schedule, in minutes after midnight (it may run past midnight). */
  eveningStart: unknown;
  eveningEnd: unknown;
  /** Evening Mode rests while one of these apps (bundle IDs) is in front, for work where colour matters. */
  eveningPausedApps: string[];
  /** Evening Mode goes red: green and blue fade out as well, down to red light only at full strength. */
  eveningRed: boolean;
  /** Software brightness for each display (by UUID), 0.1–1, on top of its own: dims below its lowest setting. */
  displayBrightness: Record<string, number>;
  /** Hold a modifier and press Tab for a grid of every window, let go to switch (⌘Tab replaces the app switcher). */
  windowSwitcherShortcut: unknown;
  /** Drag a floating window to a screen edge for a half, a corner for a quarter, or the top to maximise. */
  edgeSnapping: boolean;
  /** Leave edge drags to macOS when its own tiling by dragging to screen edges is on (macOS 15 and later). */
  edgeSnappingDefersToMacOS: boolean;
  /** Show a notice when Stay Awake starts and ends. */
  awakeNotify: boolean;
  /** Play a sound when Stay Awake starts and ends. */
  awakeSound: boolean;
  /** Show the time left in the menu bar. */
  awakeShowTime: boolean;
  /** Start Stay Awake when Monorail opens. */
  awakeOnLaunch: boolean;
  /** Things that start Stay Awake by themselves. */
  awakeTriggers: unknown;
  /** Automatic Stay Awake triggers are on. */
  awakeTriggersOn: boolean;
  /** During Stay Awake, still lock the screen after this many idle minutes (0 = never). */
  awakeLockAfterMinutes: number;
  /** List the workspace’s windows right in the menu bar menu (otherwise they are in a Windows submenu). */
  menuWindowsInline: boolean;
  /** When a call opens from your calendar, put your notes app beside it (and keep your layout to bring back afterwards). */
  meetingLayout: boolean;
  /** The notes app put beside calls (bundle ID). */
  meetingNotesApp: string;
  /** On a Sidecar iPad, every slide fits on screen. */
  sidecarFit: boolean;
  /** Tips already shown. */
  seenTips: string[];
  /** Send anonymous daily usage counts (version, macOS, Mac model, features on). Never titles, apps or files. */
  shareUsageStats: boolean;
  /** Whether the one-time notice about anonymous usage counts was shown. */
  usageNoticeShown: boolean;
  /** Snapshots also save and reopen browser tabs (Safari, Chrome, Arc, Brave, Edge) and Finder windows. */
  restoreBrowserTabs: boolean;
  /** Suggest always floating an app after you float its windows by hand a few times. */
  floatSuggestions: boolean;
  /** The Claude model the optional assistant uses, with your own API key. */
  assistantModel: string;
  /** Who the assistant asks: Anthropic, OpenAI, Gemini, xAI, OpenRouter, Ollama on this Mac, or any OpenAI-compatible server. */
  assistantProvider: unknown;
  /** The model for each provider other than Anthropic, as the provider names it. */
  assistantModels: Record<string, string>;
  /** The address of an OpenAI-compatible server (Other), or a different address for Ollama. */
  assistantBaseURL: string;
  /** Drag a window onto another window: near an edge docks it beside, the middle makes a tab group (any apps). */
  dragToDock: boolean;
  /** Drag the gap between two windows to resize both at once. */
  gapHandles: boolean;
  /** The slider bar steps aside for full-screen apps and for a playing video underneath it. */
  sliderBarStepsAside: boolean;
  /** Floating windows and dialogs that end up off screen (a display unplugged, a size saved on a bigger screen, waking from sleep) come back into view on their own. */
  keepEverythingOnScreen: boolean;
  /** macOS permission, password and security prompts always come to the front, centred on your screen, and Monorail holds focus changes until they are answered. */
  systemPromptsInFront: boolean;
  /** Snap windows back when an app moves or resizes one by itself. */
  keepWindowsInPlace: boolean;
  /** After resizing a window in a slide, offer to rearrange the slide. */
  resizeAssist: boolean;
  /** Put a newly opened lone window into a slide with another app's lone window. When off, that only happens when regrouping (⌃⌥A). */
  pairLoneWindowsOnOpen: boolean;
  /** Terminal apps (Terminal, iTerm, Ghostty, Warp, kitty, Alacritty, WezTerm) share slides with each other, as if they were one app. */
  groupTerminals: boolean;
  /** Layout of new slides, unless an app rule says otherwise. */
  slideArrangement: unknown;
  /** Workspaces per display (1...9). Each has its own strip. */
  workspaceCount: number;
  /** Names for workspaces, by index; empty or missing means "Workspace N". */
  workspaceNames: string[];
  /** Look for new versions on monorail.ashforde.org once a day. */
  checkForUpdates: boolean;
  /** Install new versions without asking (Monorail relaunches itself). */
  installUpdatesAutomatically: boolean;
  /** Bumped when new default app rules ship, so existing settings pick them up once. */
  rulesVersion: unknown;
  /** Set once the welcome tour has been shown. */
  hasCompletedOnboarding: boolean;
}

/** Defaults of the plain settings (the rest start empty or come from the platform). */
export const DEFAULTS: Partial<Settings> = {
  animate: true,
  animationDuration: 0.2,
  modifierSwipe: true,
  scrollOverMenuBar: true,
  showNavigationArrows: false,
  swipeSensitivity: 1.0,
  invertSwipe: false,
  mouseFollowsFocus: false,
  focusFollowsMouse: false,
  keepHeights: false,
  focusBorder: false,
  focusBorderWidth: 3.0,
  focusBorderColor: "#4C8DFF",
  dimInactive: false,
  dimAmount: 0.2,
  showColumnIndicator: true,
  iconOpensSlider: true,
  groupByApp: true,
  tilesPerSlide: 2,
  hotEdges: false,
  dynamicWorkspaces: false,
  hapticFeedback: true,
  pinchForOverview: true,
  attentionMarkers: true,
  snapPicker: true,
  focusMinutes: 25,
  focusDim: 0.6,
  syncThroughICloud: false,
  threeFingerTapOverview: false,
  peekWithOption: true,
  collectStats: true,
  smartGaps: false,
  menuBarShowsApp: false,
  modifierDrag: true,
  titleBarSwipes: false,
  focusBorderGradient: false,
  focusBorderColor2: "#FF5F9E",
  liveReloadSettings: true,
  publishState: false,
  eventScript: "",
  followReduceMotion: true,
  resizeHUD: true,
  rememberWidths: true,
  centerLoneWindow: 0.0,
  autoGrowFocus: 0.0,
  meetingHelper: false,
  verticalWorkspaceSwipes: false,
  pinchZoomsStrip: true,
  localAPI: false,
  apiPort: 4767,
  scripts: false,
  language: "",
  openNextToSameApp: false,
  openIntoFocusedSlide: false,
  workspaceHUD: true,
  sliderTitles: false,
  compactSlider: false,
  compactMenuBarApplied: true,
  quietMode: false,
  slideSound: false,
  announceChanges: true,
  rememberFloatingPositions: true,
  autoSnapshot: true,
  dailyBackups: true,
  skipAnimationsOnBattery: false,
  cheatSheetOnHold: true,
  focusFollowsMouseDelay: 0.15,
  capsLockKey: false,
  fitByDefault: false,
  autoNameWorkspaces: true,
  betaUpdates: false,
  weeklySummary: false,
  lastSeenVersion: "",
  mouseButtonsStep: false,
  scrollResizes: true,
  shiftScrollSwitchesWorkspace: true,
  middleClickZoom: true,
  focusGlow: false,
  borderFromAppIcon: false,
  pauseForStageManager: true,
  portraitStacks: true,
  restoreHidesOthers: false,
  powerMarkers: true,
  parkPowerHogs: false,
  batteryMenuBar: false,
  awakeDuringCalls: true,
  movieAuto: false,
  chargeLimit: 100,
  clipboardHistory: true,
  clipboardKeep: 50,
  sessionMinutes: 25,
  focusSound: "none",
  focusHidesApps: true,
  eyeBreaks: false,
  focusFlash: false,
  sliderOpacity: 1.0,
  sliderScale: 1.0,
  plainOverview: false,
  overviewIconsOnly: false,
  menuBarShowsTitle: false,
  noticeDuration: 1.8,
  pomodoroFocus: 25,
  pomodoroBreak: 5,
  breakReminderMinutes: 0,
  dailyFocusGoal: 0,
  autoParkHours: 0,
  floatSmallerThan: 0.0,
  floatSettingsWindows: true,
  retileAfterWake: true,
  animationFPS: 60,
  rescueAfterCrash: true,
  clickSound: "Tink",
  announceWindows: false,
  webhookURL: "",
  remoteCommands: false,
  stageNextWindow: false,
  distractionNudges: false,
  contentAwareWidths: false,
  displayProfiles: false,
  agentAlerts: true,
  agentBringIntoView: false,
  ruleSuggestions: true,
  mouseGestures: false,
  midiControl: false,
  gameController: false,
  webRemote: false,
  webRemoteToken: "",
  headFocus: false,
  deepWorkFromCalendar: false,
  safeScreenShare: true,
  privacyBlur: true,
  dimFollowsPointer: false,
  energySaver: true,
  presenterNotes: "",
  workspaceClipboard: false,
  driftWallpaper: "",
  notchHUD: false,
  crashReports: false,
  askAfterCrash: true,
  confirmDestructiveAPI: true,
  parkInCorner: true,
  wholeSlidesOnly: true,
  fitMinimumWidth: 480.0,
  awakeKeepDisplayOn: true,
  awakeAllowScreenSaver: false,
  awakeDefaultMinutes: 0,
  awakeBatteryCutoff: 10,
  awakeMoveCursor: false,
  keepAvailable: false,
  arrangeScriptableApps: true,
  awakeMoveCursorMinutes: 4,
  awakeDriveAlive: false,
  awakeClosedLid: false,
  awakeClosedLidOnlyOnPower: true,
  showAllSettings: false,
  eveningStrength: 0.5,
  eveningOn: false,
  eveningRed: false,
  edgeSnapping: false,
  edgeSnappingDefersToMacOS: true,
  awakeNotify: true,
  awakeSound: false,
  awakeShowTime: true,
  awakeOnLaunch: false,
  awakeTriggersOn: true,
  awakeLockAfterMinutes: 0,
  menuWindowsInline: false,
  meetingLayout: false,
  meetingNotesApp: "com.apple.Notes",
  sidecarFit: true,
  shareUsageStats: true,
  usageNoticeShown: false,
  restoreBrowserTabs: false,
  floatSuggestions: true,
  assistantModel: "claude-opus-5-5",
  assistantBaseURL: "",
  dragToDock: true,
  gapHandles: true,
  sliderBarStepsAside: true,
  keepEverythingOnScreen: true,
  systemPromptsInFront: true,
  keepWindowsInPlace: true,
  resizeAssist: true,
  pairLoneWindowsOnOpen: false,
  groupTerminals: true,
  workspaceCount: 4,
  checkForUpdates: true,
  installUpdatesAutomatically: false,
  hasCompletedOnboarding: false,
};

export const SETTING_KEYS = ["layout", "animate", "animationDuration", "modifierSwipe", "scrollModifier", "scrollOverMenuBar", "showNavigationArrows", "slideTrigger", "swipeFingers", "swipeSensitivity", "invertSwipe", "mouseFollowsFocus", "focusFollowsMouse", "keepHeights", "focusBorder", "focusBorderWidth", "focusBorderColor", "dimInactive", "dimAmount", "showColumnIndicator", "newWindowPosition", "appRules", "keymap", "sliderBar", "sliderBarEdge", "iconOpensSlider", "groupByApp", "tilesPerSlide", "hotEdges", "customLayouts", "appPairs", "profiles", "dynamicWorkspaces", "hapticFeedback", "pinchForOverview", "attentionMarkers", "snapPicker", "focusMinutes", "focusDim", "displayOverrides", "theme", "syncThroughICloud", "threeFingerTapOverview", "peekWithOption", "collectStats", "autoRules", "smartGaps", "launchSlots", "menuBarShowsApp", "modifierDrag", "titleBarSwipes", "focusBorderGradient", "focusBorderColor2", "workspaceWallpapers", "liveReloadSettings", "publishState", "eventScript", "followReduceMotion", "resizeHUD", "rememberWidths", "centerLoneWindow", "autoGrowFocus", "projects", "templates", "meetingHelper", "meetingProfile", "verticalWorkspaceSwipes", "pinchZoomsStrip", "localAPI", "apiPort", "scripts", "language", "openNextToSameApp", "openIntoFocusedSlide", "workspaceHUD", "sliderTitles", "compactSlider", "menuBarStyle", "compactMenuBarApplied", "quietMode", "slideSound", "announceChanges", "rememberFloatingPositions", "autoSnapshot", "dailyBackups", "skipAnimationsOnBattery", "cheatSheetOnHold", "focusFollowsMouseDelay", "capsLockKey", "fitByDefault", "fitExceptions", "workspaceNotes", "autoNameWorkspaces", "betaUpdates", "weeklySummary", "lastSeenVersion", "hotCorners", "mouseButtonsStep", "scrollResizes", "shiftScrollSwitchesWorkspace", "middleClickZoom", "focusGlow", "borderFromAppIcon", "pauseForStageManager", "portraitStacks", "restoreHidesOthers", "reservedEdges", "appAppearance", "powerMarkers", "parkPowerHogs", "batteryMenuBar", "batteryCards", "batteryHiddenCards", "awakeDuringCalls", "movieAuto", "chargeLimit", "worldClocks", "clipboardHistory", "clipboardKeep", "sessionMinutes", "focusSound", "focusHidesApps", "eyeBreaks", "focusFlash", "sliderOpacity", "sliderScale", "plainOverview", "overviewIconsOnly", "menuBarShowsTitle", "noticePosition", "noticeDuration", "pomodoroFocus", "pomodoroBreak", "breakReminderMinutes", "dailyFocusGoal", "workspaceConfigs", "autoParkHours", "floatSmallerThan", "floatSettingsWindows", "pauseForApps", "retileAfterWake", "animationCurve", "animationFPS", "rescueAfterCrash", "clickSound", "announceWindows", "webhookURL", "remoteCommands", "stageNextWindow", "distractionNudges", "contentAwareWidths", "pathRules", "displayProfiles", "agentAlerts", "agentBringIntoView", "ruleSuggestions", "suggestedRules", "monorailKeySource", "mouseGestures", "midiControl", "midiMap", "gameController", "webRemote", "webRemoteToken", "headFocus", "deepWorkApps", "deepWorkFromCalendar", "safeScreenShare", "privateApps", "privacyBlur", "dimFollowsPointer", "energySaver", "presenterNotes", "workspaceClipboard", "driftWallpaper", "notchHUD", "soundPack", "crashReports", "askAfterCrash", "confirmDestructiveAPI", "parkInCorner", "wholeSlidesOnly", "fitMinimumWidth", "awakeKeepDisplayOn", "awakeAllowScreenSaver", "awakeDefaultMinutes", "awakeBatteryCutoff", "awakeMoveCursor", "keepAvailable", "arrangeScriptableApps", "awakeMoveCursorMinutes", "awakeDriveAlive", "awakeClosedLid", "awakeClosedLidOnlyOnPower", "showAllSettings", "eveningStrength", "eveningOn", "eveningSchedule", "eveningStart", "eveningEnd", "eveningPausedApps", "eveningRed", "displayBrightness", "windowSwitcherShortcut", "edgeSnapping", "edgeSnappingDefersToMacOS", "awakeNotify", "awakeSound", "awakeShowTime", "awakeOnLaunch", "awakeTriggers", "awakeTriggersOn", "awakeLockAfterMinutes", "menuWindowsInline", "meetingLayout", "meetingNotesApp", "sidecarFit", "seenTips", "shareUsageStats", "usageNoticeShown", "restoreBrowserTabs", "floatSuggestions", "assistantModel", "assistantProvider", "assistantModels", "assistantBaseURL", "dragToDock", "gapHandles", "sliderBarStepsAside", "keepEverythingOnScreen", "systemPromptsInFront", "keepWindowsInPlace", "resizeAssist", "pairLoneWindowsOnOpen", "groupTerminals", "slideArrangement", "workspaceCount", "workspaceNames", "checkForUpdates", "installUpdatesAutomatically", "rulesVersion", "hasCompletedOnboarding"] as const;
