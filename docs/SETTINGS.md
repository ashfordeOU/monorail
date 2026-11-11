# Every Monorail setting

Generated from `Sources/MonorailCore/AppSettings.swift` by `scripts/gen-docs.py`. Don't edit by hand.

Settings live in `~/Library/Application Support/Monorail/settings.json`. Every one can be changed in the
Settings window; organisations can enforce any of them with a configuration profile (MDM) using these keys.

230 settings.

| Key | What it does | Default |
| --- | --- | --- |
| `layout` |  | `LayoutConfig()` |
| `animate` | Animate windows into place instead of jumping. | `true` |
| `animationDuration` | Animation length in seconds. | `0.2` |
| `modifierSwipe` | Scroll the strip with the mouse wheel or trackpad while holding `scrollModifier`. | `true` |
| `scrollModifier` | Keys to hold while scrolling to move the strip instead of the app under the pointer. | `[.option]` |
| `scrollOverMenuBar` | Scrolling over the menu bar moves the strip, no keys needed. | `true` |
| `showNavigationArrows` | Show clickable ‹ › buttons in the menu bar. | `false` |
| `slideTrigger` | Tapping this key on its own turns on slide mode. | `.rightOption` |
| `swipeFingers` | Scroll the strip with a three- or four-finger swipe. | `.off` |
| `swipeSensitivity` | Multiplier applied to swipe distance. | `1.0` |
| `invertSwipe` | Flip the swipe direction. | `false` |
| `mouseFollowsFocus` | Move the mouse pointer to the centre of a window focused from the keyboard. | `false` |
| `focusFollowsMouse` | Focus the window under the mouse pointer. | `false` |
| `keepHeights` | Windows in single-window columns keep their own height, top aligned. | `false` |
| `focusBorder` | Draw a coloured border around the focused window. | `false` |
| `focusBorderWidth` |  | `3.0` |
| `focusBorderColor` | Hex colour of the focus border, e.g. "#4C8DFF". | `"#4C8DFF"` |
| `dimInactive` | Darken tiled windows that do not have focus. | `false` |
| `dimAmount` | Opacity of the dimming overlay, 0...1. | `0.2` |
| `showColumnIndicator` | Show "3/8" (focused column / columns) next to the menu bar icon. | `true` |
| `newWindowPosition` | Where newly opened windows join the strip. | `.afterFocused` |
| `appRules` | Per-app rules. | `AppSettings.defaultAppRules` |
| `keymap` |  | `.default` |
| `sliderBar` | The slider bar: a mini-map of the strip you can drag to slide. | `.whileMoving` |
| `sliderBarEdge` |  | `.bottom` |
| `iconOpensSlider` | Clicking the menu bar icon shows the slider; right-click shows the menu. | `true` |
| `groupByApp` | Group windows into full-screen slides by app as they open. | `true` |
| `tilesPerSlide` | Windows per slide when grouping, unless an app rule says otherwise. | `2` |
| `hotEdges` | Push the pointer against the left or right screen edge to slide. | `false` |
| `customLayouts` | Slide layouts designed in Settings. | `[` |
| `appPairs` | Saved app pairs. | `[]` |
| `profiles` | Profiles: whole sets of workspaces ("Work", "Home"). | `["Default"]` |
| `dynamicWorkspaces` | Show only the workspaces in use, plus one empty one. | `false` |
| `hapticFeedback` | A light tap on Force Touch trackpads when the strip settles. | `true` |
| `pinchForOverview` | Hold ⌥ and pinch on the trackpad to open (pinch in) or close the overview. | `true` |
| `attentionMarkers` | Red dots on slides whose apps show a badge in the Dock. | `true` |
| `snapPicker` | Dragging a window to the top of the screen shows layouts to drop it into. | `true` |
| `focusMinutes` | Focus mode: how long it lasts (0 = until turned off) and how dark the rest gets. | `25` |
| `focusDim` |  | `0.6` |
| `displayOverrides` | Overrides per display, by display UUID. | `[:]` |
| `theme` |  | `.vivid` |
| `syncThroughICloud` | Keep settings, layouts and app pairs in iCloud Drive, shared by your Macs. | `false` |
| `threeFingerTapOverview` | A three-finger tap on the trackpad opens the overview. | `false` |
| `peekWithOption` | Hold ⌥ while hovering a slide in the slider to peek at it full size. | `true` |
| `collectStats` | Count switches and pairings on this Mac, for Insights and suggestions. | `true` |
| `autoRules` | Profile and layout changes by time of day or Wi-Fi network. | `[]` |
| `smartGaps` | No gaps around a lone window; wider gaps on big displays. | `false` |
| `launchSlots` | Quick launch: a letter opens or focuses an app (by bundle ID). | `[:]` |
| `menuBarShowsApp` | The menu bar shows the focused app's name next to the position. | `false` |
| `modifierDrag` | Hold ⌃⌥ and drag anywhere in a window to move it; right-drag to resize. | `true` |
| `titleBarSwipes` | Two-finger swipes on a window's title bar: left and right move its slide, up toggles full width, down minimises. | `false` |
| `focusBorderGradient` | The focus border fades from its colour into a second one. | `false` |
| `focusBorderColor2` |  | `"#FF5F9E"` |
| `workspaceWallpapers` | A desktop picture per workspace (index → file path). | `[:]` |
| `liveReloadSettings` | Watch settings.json and pick up changes made in a text editor. | `true` |
| `publishState` | Write state.json and post a notification on changes, for SketchyBar and other status bars. | `false` |
| `eventScript` | A script run on events (workspace and focus changes), with details in environment variables. | `""` |
| `followReduceMotion` | Skip animations when macOS's Reduce Motion or Low Power Mode is on. | `true` |
| `resizeHUD` | While resizing by hand, show the window's size. | `true` |
| `rememberWidths` | New windows of an app open at the width you last gave it. | `true` |
| `centerLoneWindow` | A lone window sits centred at this share of the screen (0 = off). | `0.0` |
| `autoGrowFocus` | The focused one of two windows in a slide grows to this share (0 = off). | `0.0` |
| `projects` | Windows whose titles name one of these projects gather in one workspace. | `[]` |
| `templates` | Workspace templates. | `[]` |
| `meetingHelper` | Before a calendar event with a meeting link: open it and switch profile. | `false` |
| `meetingProfile` |  | |
| `verticalWorkspaceSwipes` | Three- or four-finger vertical swipes switch workspace (sliding up or down). | `false` |
| `pinchZoomsStrip` | ⌥ + pinch zooms out on the strip (instead of opening the overview). | `true` |
| `localAPI` | A local API (and MCP server) for other apps and AI assistants. | `false` |
| `apiPort` |  | `4767` |
| `scripts` | Run JavaScript plugins from the Scripts folder. | `false` |
| `language` | Interface language: empty follows macOS. | `""` |
| `openNextToSameApp` | New windows open right after their app's other windows. | `false` |
| `openIntoFocusedSlide` | New windows join the focused slide (toggled by an action). | `false` |
| `workspaceHUD` | Show the workspace's name in the middle of the screen when switching. | `true` |
| `sliderTitles` | Window titles on the slider bar's tiles, and a smaller bar. | `false` |
| `compactSlider` |  | `false` |
| `menuBarStyle` |  | `.mini` |
| `compactMenuBarApplied` | Set once the narrower 1.1 menu bar has been applied to older settings. | `true` |
| `quietMode` | No pop-up notices (confirmations, tips). | `false` |
| `slideSound` | A soft click as the strip lands on a slide. | `false` |
| `announceChanges` | VoiceOver says which slide and workspace you moved to. | `true` |
| `rememberFloatingPositions` | Floating windows go back where you last put them, per app. | `true` |
| `autoSnapshot` | Take a "Last session" snapshot on quit and before sleep. | `true` |
| `dailyBackups` | Keep a copy of the settings each day (the last seven). | `true` |
| `skipAnimationsOnBattery` | Skip animations while running on battery. | `false` |
| `cheatSheetOnHold` | Hold ⌃⌥ for a moment to see a cheat sheet of shortcuts. | `true` |
| `focusFollowsMouseDelay` | Focus follows mouse waits this long (seconds) before switching. | `0.15` |
| `capsLockKey` | Caps Lock becomes the Monorail key: hold it instead of ⌃⌥. | `false` |
| `fitByDefault` | Fit mode: every slide shares the screen. On for all workspaces, or just some; `fitExceptions` lists workspaces (absolute numbers) that differ. | `false` |
| `fitExceptions` |  | `[]` |
| `workspaceNotes` | A line of notes per workspace (by its number from 0). | `[:]` |
| `autoNameWorkspaces` | Workspaces without a name take their apps' names. | `true` |
| `betaUpdates` | Get early (beta) versions as well as final ones. | `false` |
| `weeklySummary` | A notification on Monday mornings with last week's Insights. | `false` |
| `lastSeenVersion` | The version whose What's New was last shown. | `""` |
| `hotCorners` | Screen corners: top-left, top-right, bottom-left, bottom-right. | `[.none, .none, .none, .none]` |
| `mouseButtonsStep` | Mouse buttons 4 and 5 (back and forward) step through slides. | `false` |
| `scrollResizes` | ⌃⌥ + scroll over a window changes its slide's width. | `true` |
| `shiftScrollSwitchesWorkspace` | ⇧ + scroll over the slider bar switches workspace. | `true` |
| `middleClickZoom` | ⌥ + middle-click a window zooms it. | `true` |
| `focusGlow` | The focus border glows, and can take the app icon's colour. | `false` |
| `borderFromAppIcon` |  | `false` |
| `pauseForStageManager` | Monorail pauses while Stage Manager is on and carries on when it's turned off. | `true` |
| `portraitStacks` | On a display taller than it is wide, slides stack top to bottom and the main window goes on top. | `true` |
| `restoreHidesOthers` | Restoring a saved layout or snapshot hides (never quits) the apps that aren't in it. | `false` |
| `reservedEdges` | Space kept clear at each screen edge for another app's bar or dock. | `ReservedEdges()` |
| `appAppearance` | Monorail's own windows in light or dark, or following the Mac. | `.system` |
| `powerMarkers` | On battery, ⚡ marks the windows of apps using the most power, and ⚡ in the popover lists them. | `true` |
| `parkPowerHogs` | On battery, hide (never quit) power-hungry apps left alone for an hour; they come back when plugged in. | `false` |
| `batteryMenuBar` | A battery item in the menu bar (charge or time left), opening the battery panel. | `false` |
| `focusFlash` | A quick highlight of the focused window when focus moves by keyboard. | `false` |
| `sliderOpacity` | The slider bar's opacity and size (0.8, 1 or 1.25). | `1.0` |
| `sliderScale` |  | `1.0` |
| `plainOverview` | The overview's backdrop: colourful, or plain. | `false` |
| `overviewIconsOnly` | The overview with app icons only (no live previews). | `false` |
| `menuBarShowsTitle` | The menu bar shows the focused window's title. | `false` |
| `noticePosition` | Where notices appear and for how long (seconds). | `.top` |
| `noticeDuration` |  | `1.8` |
| `pomodoroFocus` | Pomodoro: focus and break lengths in minutes. | `25` |
| `pomodoroBreak` |  | `5` |
| `breakReminderMinutes` | Remind to rest your eyes every so many minutes (0 = off). | `0` |
| `dailyFocusGoal` | A daily focus goal in minutes (0 = none), shown in Insights. | `0` |
| `workspaceConfigs` | Settings per workspace, by absolute workspace number. | `[:]` |
| `autoParkHours` | Park a workspace you haven't visited for this many hours (0 = never). | `0` |
| `floatSmallerThan` | Windows smaller than this (points, either side) float on their own (0 = off). | `0.0` |
| `floatSettingsWindows` | Settings and preferences windows float. | `true` |
| `pauseForApps` | Tiling pauses while one of these apps (bundle IDs) is in front. | `[]` |
| `retileAfterWake` | Lay everything out again after the Mac wakes. | `true` |
| `animationCurve` |  | `.smooth` |
| `animationFPS` | Animation frames per second: 30, 60 or 120. | `60` |
| `rescueAfterCrash` | Bring every window back after Monorail quit unexpectedly. | `true` |
| `clickSound` | The click sound for slide changes. | `"Tink"` |
| `announceWindows` | VoiceOver also says which window got focus. | `false` |
| `webhookURL` | POST events as JSON to this address (empty = off). | `""` |
| `remoteCommands` | Let other apps run actions with the org.ashforde.monorail.perform distributed notification. | `false` |
| `stageNextWindow` | Bring the window you usually go to next right beside the one you are in. | `false` |
| `distractionNudges` | Suggest focus mode when you switch windows very often. | `false` |
| `contentAwareWidths` | New slides get a width that suits the app: ~100 columns of code, a page of text, a web page. | `false` |
| `pathRules` | Documents from these folders open in these workspaces. | `[]` |
| `displayProfiles` | Remember the layout for each set of displays and bring it back when they connect again. | `false` |
| `agentAlerts` | Tell me when an AI coding agent in a terminal is waiting for me. | `true` |
| `agentBringIntoView` | Slide a waiting agent's window into view. | `false` |
| `ruleSuggestions` | Suggest rules from the fixes you keep making. | `true` |
| `suggestedRules` | Widths Monorail noticed you keep giving apps (bundle ID → share), waiting to become rules. | `[:]` |
| `monorailKeySource` | The key that acts as the Monorail key. | `.capsLock` |
| `mouseGestures` | ⌃⌥⇧ + drag left, right, up or down for workspaces, the overview and the desktop. | `false` |
| `midiControl` | Run actions from a MIDI controller. | `false` |
| `midiMap` | MIDI note number → action name. | `[:]` |
| `gameController` | Drive Monorail with a game controller. | `false` |
| `webRemote` | A remote control page for your phone on the local network. | `false` |
| `webRemoteToken` | The secret in the remote page link. | `""` |
| `headFocus` | Experimental: turn your head towards a display to focus it (uses the camera). | `false` |
| `deepWorkApps` | Apps hidden during deep work (bundle IDs). | `["com.tinyspeck.slackmacgap", "com.apple.MobileSMS", "com.hnc.Discord", "com.apple.mail"]` |
| `deepWorkFromCalendar` | Calendar events called Focus or Deep work turn deep work on. | `false` |
| `safeScreenShare` | Hide private apps while you share your screen. | `true` |
| `privateApps` | Apps whose windows count as private (bundle IDs). | `["com.apple.MobileSMS", "net.whatsapp.WhatsApp", "com.apple.mail", "com.apple.Passwords", "com.1password.1password"]` |
| `privacyBlur` | Blur private windows in the overview and previews. | `true` |
| `dimFollowsPointer` | Dimming follows the pointer instead of focus. | `false` |
| `energySaver` | On battery, animate at 30 fps and pause live previews. | `true` |
| `presenterNotes` | Your presenter notes (never shown in screen shares). | `""` |
| `workspaceClipboard` | Keep a clipboard history for each workspace. | `false` |
| `driftWallpaper` | A picture that drifts gently behind the strip as it scrolls (empty = off). | `""` |
| `notchHUD` | Show slides and workspaces around the MacBook notch as you move. | `false` |
| `soundPack` | The sounds Monorail plays. | `.classic` |
| `crashReports` | Keep crash and hang reports on this Mac so you can send them. | `false` |
| `askAfterCrash` | After Monorail quits unexpectedly, ask (once per version) what happened. | `true` |
| `confirmDestructiveAPI` | Ask before an assistant or script closes windows. | `true` |
| `parkInCorner` | Slides off screen wait hidden in the corner (no slivers at the screen edges). | `true` |
| `wholeSlidesOnly` | Hide slides that only partly fit on screen, instead of showing them cut off at the edge. | `true` |
| `fitMinimumWidth` | Fit mode never makes a window narrower than this (points; a pair needs twice as much); extra slides scroll. | `480.0` |
| `awakeKeepDisplayOn` | Stay Awake keeps the display on too (otherwise only the Mac stays awake and the display may sleep). | `true` |
| `awakeAllowScreenSaver` | Let the screen saver start during a Stay Awake session (the Mac still stays awake). | `false` |
| `awakeDefaultMinutes` | How long Stay Awake lasts when toggled on (0 = until you end it). | `0` |
| `awakeBatteryCutoff` | End Stay Awake when the battery drops to this percent on battery power (0 = never). | `10` |
| `awakeMoveCursor` | During Stay Awake, nudge the pointer now and then so chat apps don’t mark you away. | `false` |
| `keepAvailable` | Keep me Available: keep the Mac awake and keep chat apps such as Teams and Slack showing you as available, by telling macOS you're active when it has been idle (no permission needed). | `false` |
| `arrangeScriptableApps` | Arrange scriptable apps (Safari, Finder, Terminal…) with Apple Events while Accessibility isn't allowed. | `true` |
| `awakeMoveCursorMinutes` | How often the pointer is nudged (minutes). | `4` |
| `awakeDriveAlive` | During Stay Awake, keep external drives from spinning down. | `false` |
| `awakeClosedLid` | During Stay Awake, keep running with the lid closed, even without an external display (asks for your password). | `false` |
| `awakeClosedLidOnlyOnPower` | Lid-closed mode only while plugged in (on battery, closing the lid puts the Mac to sleep). | `true` |
| `showAllSettings` | Settings shows every section; off, only the essential ones (search still finds everything). | `false` |
| `eveningStrength` | Evening Mode: a warmer screen with less blue light. How strong, 0–1. | `0.5` |
| `eveningOn` | Turned on by hand (from the menu bar or Settings). | `false` |
| `eveningSchedule` | By hand only, or every day on a schedule. | `EveningSchedule.manual` |
| `eveningStart` | The schedule, in minutes after midnight (it may run past midnight). | `20 * 60` |
| `eveningEnd` |  | `7 * 60` |
| `eveningPausedApps` | Evening Mode rests while one of these apps (bundle IDs) is in front, for work where colour matters. | `[]` |
| `eveningRed` | Evening Mode goes red: green and blue fade out as well, down to red light only at full strength. | `false` |
| `displayBrightness` | Software brightness for each display (by UUID), 0.1–1, on top of its own: dims below its lowest setting. | `[:]` |
| `windowSwitcherShortcut` | Hold a modifier and press Tab for a grid of every window, let go to switch (⌘Tab replaces the app switcher). | `.off` |
| `edgeSnapping` | Drag a floating window to a screen edge for a half, a corner for a quarter, or the top to maximise. | `false` |
| `edgeSnappingDefersToMacOS` | Leave edge drags to macOS when its own tiling by dragging to screen edges is on (macOS 15 and later). | `true` |
| `awakeNotify` | Show a notice when Stay Awake starts and ends. | `true` |
| `awakeSound` | Play a sound when Stay Awake starts and ends. | `false` |
| `awakeShowTime` | Show the time left in the menu bar. | `true` |
| `awakeOnLaunch` | Start Stay Awake when Monorail opens. | `false` |
| `awakeTriggers` | Things that start Stay Awake by themselves. | `[]` |
| `awakeTriggersOn` | Automatic Stay Awake triggers are on. | `true` |
| `awakeLockAfterMinutes` | During Stay Awake, still lock the screen after this many idle minutes (0 = never). | `0` |
| `menuWindowsInline` | List the workspace’s windows right in the menu bar menu (otherwise they are in a Windows submenu). | `false` |
| `meetingLayout` | When a call opens from your calendar, put your notes app beside it (and keep your layout to bring back afterwards). | `false` |
| `meetingNotesApp` | The notes app put beside calls (bundle ID). | `"com.apple.Notes"` |
| `sidecarFit` | On a Sidecar iPad, every slide fits on screen. | `true` |
| `seenTips` | Tips already shown. | `[]` |
| `shareUsageStats` | Send anonymous daily usage counts (version, macOS, Mac model, features on). Never titles, apps or files. | `true` |
| `usageNoticeShown` | Whether the one-time notice about anonymous usage counts was shown. | `false` |
| `restoreBrowserTabs` | Snapshots also save and reopen browser tabs (Safari, Chrome, Arc, Brave, Edge) and Finder windows. | `false` |
| `floatSuggestions` | Suggest always floating an app after you float its windows by hand a few times. | `true` |
| `assistantModel` | The Claude model the optional assistant uses, with your own API key. | `"claude-opus-5-5"` |
| `assistantProvider` | Who the assistant asks: Anthropic, OpenAI, Gemini, xAI, OpenRouter, Ollama on this Mac, or any OpenAI-compatible server. | `.anthropic` |
| `assistantModels` | The model for each provider other than Anthropic, as the provider names it. | `[:]` |
| `assistantBaseURL` | The address of an OpenAI-compatible server (Other), or a different address for Ollama. | `""` |
| `dragToDock` | Drag a window onto another window: near an edge docks it beside, the middle makes a tab group (any apps). | `true` |
| `gapHandles` | Drag the gap between two windows to resize both at once. | `true` |
| `sliderBarStepsAside` | The slider bar steps aside for full-screen apps and for a playing video underneath it. | `true` |
| `keepEverythingOnScreen` | Floating windows and dialogs that end up off screen (a display unplugged, a size saved on a bigger screen, waking from sleep) come back into view on their own. | `true` |
| `systemPromptsInFront` | macOS permission, password and security prompts always come to the front, centred on your screen, and Monorail holds focus changes until they are answered. | `true` |
| `keepWindowsInPlace` | Snap windows back when an app moves or resizes one by itself. | `true` |
| `resizeAssist` | After resizing a window in a slide, offer to rearrange the slide. | `true` |
| `pairLoneWindowsOnOpen` | Put a newly opened lone window into a slide with another app's lone window. When off, that only happens when regrouping (⌃⌥A). | `false` |
| `groupTerminals` | Terminal apps (Terminal, iTerm, Ghostty, Warp, kitty, Alacritty, WezTerm) share slides with each other, as if they were one app. | `true` |
| `slideArrangement` | Layout of new slides, unless an app rule says otherwise. | `.grid` |
| `workspaceCount` | Workspaces per display (1...9). Each has its own strip. | `4` |
| `workspaceNames` | Names for workspaces, by index; empty or missing means "Workspace N". | `[]` |
| `checkForUpdates` | Look for new versions on monorail.ashforde.org once a day. | `true` |
| `installUpdatesAutomatically` | Install new versions without asking (Monorail relaunches itself). | `false` |
| `rulesVersion` | Bumped when new default app rules ship, so existing settings pick them up once. | `AppSettings.currentRulesVersion` |
| `hasCompletedOnboarding` | Set once the welcome tour has been shown. | `false` |
