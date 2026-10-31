# Changelog

All notable changes to Monorail by Ashforde® are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [1.3.0] - 2026-10-31

Stay Awake, and lighter on energy.

### Added
- **Stay Awake**, built in, like Amphetamine:
  - **Sessions:** until you end it, for 15 minutes up to 12 hours, until a time, while an app is open, or while downloading.
  - **Display:** keep it on or let it sleep, allow the screen saver, and lock after a set idle time.
  - **Battery cut-off.**
  - **Pointer nudges** so chat apps don't mark you away.
  - **Drive Alive** for external disks.
  - **Closed-lid mode** (asks for your password).
  - **Automatic triggers:** app open or in front, external display, Wi-Fi network, charging, schedule, busy CPU, downloading, external drive.
  - **Feedback:** notices and sounds, and ☕ with the time left in the menu bar.
  - **Ways to start it:** a Stay Awake submenu and settings pane, palette actions, `monorail awake`, `monorail://awake`, `POST /awake`, the `stay_awake` MCP tool, and webhooks.
- **A measuring script**, `scripts/measure-performance.sh`, that measures Monorail's own CPU, wake-ups, energy and memory, while idle and in use.

### Changed
- **Timers can be grouped:** every repeating timer gives macOS some leeway, so its wake-ups are grouped with other apps' instead of waking the Mac separately.
- **Monorail rests:** watching for screen sharing, AI agents, the clipboard and the Dock pauses completely while the screen is asleep or locked, or the screen saver is on.
- **Half-rate on low power:** in Low Power Mode, or on battery with the energy saver on, those checks run half as often, animation drops to 30 fps and live previews pause.
- **Fewer checks after layouts:** only windows that actually moved are checked to see whether they landed where they should, instead of every visible window.
- **Cheaper menu bar title:** showing the window title in the menu bar no longer looks up every window.
- **Energy report:** Settings → About shows how much CPU time and memory Monorail has used since it opened.

## [1.2.0] - 2026-10-31

Monorail understands what you want, learns how you work, knows when your AI agent needs you, keeps private windows out of screen shares, and comes in 27 themes.

### Added
- **Smart:**
  - **Sentences** in the command palette and by voice: “Slack and Mail side by side on 3”, “Safari two thirds”, “move Mail to workspace two”.
  - **Intent workspaces:** **Start working on…** opens the template, layout, pair or workspace that fits what you're about to do.
  - **AI agent alerts** for Claude Code, Codex, Aider, Gemini and other terminal agents waiting for approval, with a palette shortcut to the agent.
  - **Learning on your Mac:** stage the window you usually go to next, go straight to it, rule suggestions from widths you keep choosing, and a nudge towards focus mode when you're switching a lot.
  - **Content-aware widths** for new slides.
  - **Sort windows into project workspaces** from their titles.
  - **Folders to workspaces:** documents open in the workspace for their folder.
- **The strip:**
  - **Tall slides** that scroll up and down.
  - **Elastic focus.**
  - **Whole slides only.**
  - **Bookmarked views.**
  - **Try a layout** (fork, then keep or discard).
  - **Window groups.**
  - A **layout timeline.**
  - **Slides linked across displays.**
  - **Reading mode.**
  - **Centre the main slide** for ultrawide displays.
- **Displays:**
  - A disconnected display's slides come back when it returns.
  - **Display profiles** keep a layout for each set of displays.
  - Apps that won't shrink as far as asked get the width they need, so they never overlap their neighbours.
- **Focus and privacy:**
  - **Deep work**, also from calendar events.
  - **Safe screen sharing**, private apps and windows, and a **privacy blur** in the overview.
  - **Contexts:** a Shortcut runs when you arrive on a workspace.
  - Daily **time budgets** per workspace.
  - A **flow score** and **daily focus goal** in Insights.
  - A **clipboard history for each workspace.**
  - **Guest mode.**
- **Presenting:**
  - **Share one slide.**
  - **Mirror a window.**
  - **Demo zoom.**
  - **Draw on the screen.**
  - **Show keystrokes and clicks.**
  - **Presenter notes** hidden from screen shares.
  - A **camera tile.**
  - **Layout sync with a nearby Mac.**
  - **Continue on my other Mac.**
- **Devices:**
  - Choose the **Monorail key** (Caps Lock or right ⌘, ⌥ or ⌃).
  - **Vim mode** with counts.
  - **Mouse gestures.**
  - **MIDI** with learn mode.
  - **Game controllers.**
  - A **phone remote** with a QR code.
  - Experimental **head focus.**
  - **Find a window by what's in it.**
- **Platform:**
  - Script commands in the palette, `setWidths` for layouts as code, and `say`.
  - New API endpoints (`say`, `agents`, `predict`, `context`) and MCP tools (`say`, `get_waiting_agents`).
  - Confirmation before assistants close windows.
  - Browser, VS Code, Stream Deck and SketchyBar companions.
  - Managed settings (MDM).
  - **Safe mode** (hold ⌥ at launch).
  - Opt-in local crash reports.
  - App quirks that update themselves.
  - **Show Log** in About.
  - Notarisation in the release pipeline, ready for a Developer ID.
- **Themes and delight:**
  - **20 new themes:**
    - Ten more classics: Aurora, Nord, Dracula, Solarized, Rosé Pine, Mint, Lavender, Ember, Glacier and Desert Sand.
    - Five seasonal: Spring Bloom, Summer Sun, Autumn Leaves, Winter Frost and Festive.
    - Five unique: Synthwave, Phosphor Terminal, Ink & Paper, Nebula and Holographic.
  - **Seasons**, which follows the time of year.
  - Themes shown as swatches in Settings.
  - **Template gallery** with ten ready-made workspaces.
  - Sound packs.
  - A drifting wallpaper.
  - A notch HUD.
  - Animation synced to the display, up to 120 Hz.
  - Live previews in the overview.
- **New settings panes:** Smart, and Devices & Sharing.
- **Generated references** of every action (docs/ACTIONS.md) and every setting (docs/SETTINGS.md), checked in CI.

### Changed
- Off-screen slides now wait hidden in the corner by default, and slides that would be cut off at the edge wait too. Strips of other windows no longer show at the screen edges. Both are options in Settings → Smart.
- Firefox, Chrome and more Electron apps are known to resist parking and go to the corner straight away.
- The overview has a close button, and the overview, palette and switcher show their keys, including esc to close.
- Hovering a workspace dot shows its name inside the slider bar and the menu bar panel.

### Fixed
- **Fit on screen** with many slides no longer piles windows on top of each other. A window is never squeezed below 480 pt (a pair needs twice that), or below the width an app insists on; the extra slides scroll instead. Reset to smart pairs regroups windows but never changed fit mode, which is why it didn't help.
- The “And a lot more” illustration in the README didn't display, because of an unescaped character.

## [1.1.0] - 2026-10-31

A hundred new capabilities, and a much narrower menu bar.

### Changed
- The menu bar takes far less room. The new default draws your position into the icon itself: a pip per slide, the focused one tall, and a dot per workspace. There's no text. The ‹ › arrows are now one narrow item (click its left or right half) and are off by default, because scrolling over the menu bar already slides. Older settings switch to the narrow look once; you can pick the old styles again in Settings → General.

### Fixed
- Windows of some apps (often Electron apps) that refuse to park almost off the edge no longer leave a strip showing over the next window. Monorail notices and parks that app's windows in the corner instead.

### Added
- **Slides:**
  - Move a slide to the start or end of the strip, or to the next, previous or first empty workspace.
  - Unpair a slide, and merge it into the next or previous one.
  - Cycle tiles inside a slide, jump to its main tile, and reset its split.
  - Jump to the start or end of the strip.
- **Exact widths and layouts:**
  - One key per width: ¼, ⅓, ½, ⅔ and ¾.
  - One key per layout: side by side, up and down, grid, main + side, main + bottom, spiral, accordion and tabs.
- **Workspaces:**
  - Rename a workspace with a key.
  - Swap a workspace with its neighbour, or merge it into the previous one.
  - Minimise a whole workspace, or everything but the slide you're in.
  - Hide the app.
  - Each workspace can have its own colour, slide layout and gap. It can also turn focus mode on when you arrive, or be closed to new windows.
  - Workspaces you haven't visited for hours can park themselves in the Dock.
- **Opening things beside you:** quick launch an app or open the copied link right next to the window you're in, paired in one slide.
- **Per-app rules:** open full width, tabbed or pinned left or right; show on every workspace; become the scratchpad.
- **Partner apps:** mark an app pair as partners and a new window of one joins the other's window by itself.
- **Automatic floating:** small windows and Settings or Preferences windows float on their own.
- **Pause for apps:** tiling pauses while a game, a video player or a presentation app is in front.
- **Mouse:**
  - Buttons 4 and 5 step through slides.
  - ⌥ + middle-click zooms a window.
  - ⌃⌥ + scroll resizes a slide.
  - ⇧ + scroll over the menu bar or slider switches workspace.
- **Hot corners** for the overview, Show Desktop, the command palette, focus mode, the cheat sheet or strip zoom.
- **Slider bar:**
  - Opacity and size settings.
  - Double-click it for the overview.
  - Drop a dragged window on a slide in the bar to put it there.
- **Overview:**
  - A plain backdrop, which is also used with Reduce Transparency.
  - An icons-only mode.
- **Window notes:** shown in the overview and found by the command palette.
- **Copy and paste layouts:** copy a workspace's layout as text and paste it on another workspace or Mac.
- **Finding your place:**
  - Find the pointer.
  - Flash the focused window, or have it flash every time focus moves.
  - A glowing focus border, or one in the app icon's colour.
  - A thicker, solid border with Increase Contrast.
- **New look options:**
  - The Ashforde theme.
  - Animation curves and frame rates (30, 60 or 120 fps).
  - A choice of click sound.
  - Where notices appear and how long they stay.
  - The focused window's title in the menu bar.
- **Focus and breaks:**
  - A pomodoro timer in the menu bar that turns focus mode on for each focus block.
  - Break reminders.
  - A daily focus goal in Insights.
- **Quick toggles** for dimming, the border, the slider bar, animations and quiet mode, plus keys for Settings, Check for Updates and restarting Monorail.
- **Reliability:**
  - If Monorail quits unexpectedly, every window comes back on screen at the next launch.
  - Windows are laid out again after the Mac wakes.
- **Accessibility:** VoiceOver can also say which window got focus.
- **Automation:**
  - Webhooks for workspace, focus, window-closed and pomodoro events.
  - Remote commands through the `org.ashforde.monorail.perform` distributed notification.
  - `slideChanged` and `windowClosed` script events.
- **API, MCP and command line:**
  - New local API endpoints and MCP tools: undo, redo, history, name a slide, set a slide's layout, close a window, note a window, notify and insights.
  - New URLs: `monorail://focus-app/NAME`, `notify/TEXT` and `pomodoro`.
  - New `monorail` commands: `focus-app`, `notify`, `history` and `insights`.
- **Log viewer:** Settings → About → Show Log.

## [1.0.0] - 2026-10-31

Monorail by Ashforde® 1.0.

### Added
- Caps Lock as the Monorail key: hold it instead of ⌃⌥ for every shortcut, tap it for the command palette.
- Fit mode: every slide shares the screen, for all workspaces or just some.
- Start-up styles: Scrolling strip, Fit on screen or Minimal, in the welcome tour and Settings.
- Undo History in the menu bar: jump back to just before any recent change.
- What's New after each update.
- A beta update channel.
- Workspace notes, shown in the overview and as you switch.
- Auto-named workspaces, from their apps.
- Pick several windows in the overview (⌘-click) and put them together, move, minimise or close them at once.
- A weekly summary notification on Monday mornings.

### Changed
- Versions with beta tags compare correctly, so a final release is always offered over its betas.

## [0.9.0] - 2026-10-31

### Added
- A cheat sheet of every shortcut while you hold ⌃⌥ (or ⌃⌥⇧/).
- Redo (⌃⌥Y).
- Next and previous workspace (⌃⌥PageDown/PageUp), and moving a window there (add ⇧).
- Focus the next display (⌃⌥⇧.), move the whole workspace to the next display (⌃⌥⇧,), swap the two displays' workspaces, and move a window to the display under the pointer.
- Next window of the same app (⌃⌥\\) and swap with the window you were just on (⌃⌥⇧Tab).
- Rotate (⌃⌥⇧G) and flip (⌃⌥⇧M) a slide, sort slides by app, and widen a slide to fill the free space.
- Close or minimise a whole slide, and gather an app's windows into one slide.
- Name a slide and lock a slide, from its right-click menu.
- Tile every floating window, and Rescue Windows to bring everything back on screen.
- Solo mode (⌃⌥⇧B): hide every other app, then bring them back.
- Gaps on or off (⌃⌥⇧0), bigger and smaller gaps.
- Centre a floating window, and sizes for recordings (1280 × 720, 1920 × 1080 and more).
- New windows can open in the focused slide, or next to their app's other windows.
- Per-app home display, Never Manage This App, and remembered floating window positions.
- Settings lists the apps that need a whole slide, with a way to let one share again.
- The workspace's name as you switch, overview search and card size, window titles on slider tiles, a compact slider bar, menu bar styles (dots or workspace number), quiet mode, a soft click on slide changes, and VoiceOver announcements.
- Focus follows mouse delay, and no animations on battery.
- A "Last session" snapshot on quit and before sleep, daily settings backups with restore, Copy Diagnostics, and Insights as CSV.
- AppleScript (perform, apply layout, open pair, start template, restore snapshot, current state, window list) and a richer `monorail` command line.

## [0.8.0] - 2026-10-31

### Added
- Window hints (⌃⌥V): a letter on every window on screen; type one to go there.
- Resize mode (⌃⌥⇧E): arrows, 1–9 and 0 resize the focused slide without the mouse.
- Zoom out on the strip with ⌥ + pinch (or ⌃⌥⇧Z), live under your fingers; click a slide to go there.
- Vertical workspace swipes: workspaces slide up and down.
- Recent slides in the menu bar and the command palette.
- Remembered widths per app, a centred lone window, and the focused one of two windows growing a little.
- Projects: windows whose titles name a project gather in its workspace.
- App icons on tabs, and dragging a tab onto another slide.
- Workspace templates: apps with their files and links, started together in one slide.
- Meetings: video calls from your calendar open a minute early, optionally switching profile.
- Presentation mode (⌃⌥⇧Y) and recording the slide (⌃⌥⇧V).
- Time per workspace and app in Insights.
- Share layouts, templates and app pairs as .monorail files.
- A local API and an MCP server (`Monorail --mcp`) so AI assistants can arrange your windows.
- JavaScript plugins in the Scripts folder.
- A Raycast extension and an Alfred workflow.
- Deutsch, Français, Español and 日本語 for the menu bar menu, Settings tabs and welcome tour.
- Practice windows in the welcome tour.

## [0.7.0] - 2026-10-31

### Added
- Radial menu (⌃⌥E): point towards a side or corner, see where the window goes, let go to snap it.
- Hold ⌃⌥ and drag anywhere in a window to move it; right-drag to resize.
- Two-finger swipes on title bars: left and right move the window's slide, up makes it full width, down minimises.
- Spiral and accordion slide layouts.
- Even out widths and splits (⌃⌥⇧=), back to the last workspace (⌃⌥⇧⌫), move a window to an empty workspace (⌃⌥⇧N), go to the window that wants attention (⌃⌥⇧A), show desktop (⌃⌥⇧D), screenshot the slide (⌃⌥⇧C), and an overview of one app's windows (⌃⌥⇧O).
- A size label while resizing, a gradient focus border, and a desktop picture per workspace.
- Auto rules that run when a display is connected.
- For status bars and scripts: state.json, a distributed notification, an event script, and live reload of settings.json.
- New README tour with pictures of the overview, slider, menu bar panel, command palette, focus mode, snap picker, themes and Insights.

### Changed
- Branded as Monorail by Ashforde® in the app, menus, Settings, welcome tour, overview, installer and README.
- Animations step aside when Reduce Motion or Low Power Mode is on.

### Fixed
- Restore defaults in Settings → Shortcuts now works every time. Recording a shortcut no longer leaves Monorail's shortcuts paused if you restore defaults or close Settings before typing one. Each changed shortcut can also go back on its own, and General has Restore All Settings to Defaults.

## [0.6.0] - 2026-10-31

### Added
- Focus mode (⌃⌥B): everything but the slide you're in fades away, for 15–90 minutes or until you turn it off.
- Per-display settings: each display can have its own gaps, new-window width and slider bar.
- Smart gaps: no gaps around a lone window, wider gaps on big displays.
- Session snapshots (⌃⌥⇧S): every workspace of every profile and the apps that are open; restoring reopens the apps and puts their windows back.
- Rules by window title, like a browser window titled "Meet" floating or getting its own slide, applied even when the title changes after the window opens.
- Peek: hold ⌥ over a slide in the slider and the strip slides to show it; let go to slide back, or click to stay.
- Three-finger tap for the overview; swipe up on the slider bar to park the workspace, down to bring it back.
- Themes: Vivid, Ocean, Sunset, Forest and Monochrome for the overview, slider and workspace dots.
- Export and import settings as one file, or sync them between Macs through iCloud Drive.
- Command palette (⌃⌥/): type to go to windows and workspaces, open app pairs, park, restore snapshots, switch profiles or run any action.
- Insights: counts of switches, windows and pairings, kept on your Mac, and suggestions for app pairs you use often.
- Show a window on every workspace (⌃⌥S), like a chat or music app.
- Auto rules: switch profile or apply a layout at a time of day or when you join a Wi-Fi network.
- Picture in picture (⌃⌥I): a small live view of a window in a screen corner.
- Zoom a tile to fill its slide (⌃⌥X), and go back to the last window (⌃⌥⌫).
- Quick launch: ⌃⌥U then a letter opens an app or goes to its window.
- The menu bar can show the focused app's name.
- Automation URLs for the Shortcuts app and scripts: layouts, pairs, snapshots, profiles, workspaces, focus mode.
- Drag a slide onto another display's or workspace's strip in the overview.
- The welcome tour asks how you want to see your slides: slider bar plus menu bar icon, or the menu bar icon only.

### Changed
- The slider bar is a simple on/off switch in Settings → Appearance, with its options under it.
- The menu bar slider hangs right under its icon and closes when you click anywhere else.
- Windows that can't shrink as far as their tile get the room they need from their slide-mates; only one that needs nearly the whole slide gets a slide of its own.

### Fixed
- Shortcuts for actions added in an update now work for people upgrading, not only for new installs.

## [0.5.0] - 2026-10-30

### Added
- Snap layouts picker: drag a window towards the top of the screen and drop it on a zone.
- Swap inside a slide: drag a window over a slide-mate and they trade places live.
- Custom slide layouts, designed in Settings (columns, each split into rows).
- App pairs: save a slide's apps and open them together from the menu bar.
- Profiles: separate sets of workspaces, switched with ⌃⌥0 or the menu bar.
- Dynamic workspaces: show only the workspaces in use, plus one.
- Marks (⌃⌥⇧; then a letter, ⌃⌥; then the letter to jump back).
- Scratchpad: one floating window that drops in and hides with ⌃⌥`.
- Park a workspace's windows in the Dock and bring them back to the same slides.
- Attention markers: red dots on windows whose apps show a Dock badge.
- ⌥ + pinch opens the overview; arrow keys, return and delete work there, and a bin closes windows dropped on it.
- Live previews in window search.
- Haptic taps as the strip settles on a slide, and VoiceOver labels for window tiles.

### Changed
- Workspaces are renamed in place in the overview: the name becomes a text field right where it is; no more dialogs.
- The overview's header clears the menu bar with even spacing, and its hint sits on its own line.

### Fixed
- Apps whose windows can't shrink to half the screen (like the App Store) no longer spill off the edge or over their neighbour: Monorail notices, gives the window a slide of its own, and remembers the app for next time.
- Previews and the overview leave gaps between windows.

## [0.4.0] - 2026-10-30

### Added
- Saved layouts: save the current arrangement under a name and bring it back from the menu; windows are matched by app and title.
- Restore after restart: windows go back to their slide and workspace when apps reopen them after the Mac restarts.
- Snapping for floating windows (⌃⌥⌘ + a key): halves, thirds, two thirds, quarters, maximise, centre, and restore.
- Home workspaces per app in Settings → Apps.
- Coach tips: during the welcome tour a card at the bottom of the screen shows the next step to try and ticks along.
- Hot edges (optional): rest the pointer on a screen edge to slide.
- An update waiting shows as a dot on the menu bar icon and an "Update to …" item at the top of the menu.

### Changed
- Much faster: windows are moved and resized in the background, one lane per app, so a busy app can never slow Monorail down; window titles are cached; live previews are captured in parallel.
- Releases publish automatically when the version changes.

## [0.3.1] - 2026-10-30

### Added
- A proper installer: the disk image opens to Monorail beside your Applications folder, over a background that shows you to drag it across.
- A new README with an animated banner, a how-it-works diagram, a guide to slide layouts, a comparison and an FAQ.

### Changed
- Links point to the repository's new home, github.com/ashfordeOU/monorail.

### Fixed
- Clicking a slide on the slider bar always jumps to it, even if the pointer moves a little while clicking. Clicking one half of a pair (or one cell of a grid) jumps straight to that window.

## [0.3.0] - 2026-10-30

### Changed
- MacSlider is now **Monorail**. The app, its menus, downloads, the `monorail` command-line tool and `monorail://` links all use the new name; old `macslider://` links keep working.
- Windows dragged into a single-window slide now follow your slide layout (side by side by default) instead of stacking. Right-click a window, or a slide's handle in the overview, for Slide Layout: side by side, up and down, grid, main + side, main + bottom or tabs.
- The app icon fills macOS's icon shape exactly, so newer macOS shows it full size instead of on a grey plate.
- Built with the newest Xcode available.
- Updating keeps everything: the app's identity and signature are unchanged, so Accessibility and Screen Recording stay granted, and settings and layouts move over automatically. The app is installed as Monorail.app on update.

### Fixed
- Menu bar menu commands (Reset to Smart Pairs, Undo Layout Change and the rest) now always run: the menu opens in a way that delivers the chosen item reliably.
- Reset to smart pairs and Undo confirm what they did with a short message.

## [0.2.5] - 2026-10-30

### Fixed
- File pickers, save panels and other dialogs are no longer tiled into slides. They float, centred over the window that opened them, and the strip doesn't scroll away when one opens.

## [0.2.4] - 2026-10-30

### Added
- Window controls in previews and the overview: close, minimise and full-screen buttons on every window tile.
- Right-click a window tile to rename it (MacSlider shows your name everywhere), give it its own slide, or move it to another workspace.
- Workspace names: set them in Settings, or right-click a dot on the slider bar or a workspace in the overview. Hovering a dot shows its name.
- A colourful overview: gradient backdrop with soft glows and a dot pattern, and a coloured card per workspace.
- New app icon (the "offset M") and a matching menu bar icon.

## [0.2.3] - 2026-10-30

### Fixed
- Live previews now use ScreenCaptureKit on macOS 14 and later, so window images show on current macOS versions.
- After allowing Screen Recording, MacSlider offers to relaunch itself, which macOS needs before the permission applies.

## [0.2.2] - 2026-10-30

### Added
- Resize assist: resizing a window in a slide resizes its neighbours live, then offers Keep, Own slide, Move others out or Undo.
- Undo (⌃⌥Z): step back through recent layout changes.
- Live previews: hover a slide on the slider bar to see its windows live, and click one to jump to it. Scrolling over the bar slides the strip.
- One-click updates: MacSlider downloads, verifies (checksum and code signature), installs and relaunches itself. Optional fully automatic installs, and an Update button in the menu bar slider.

### Fixed
- The overview now sits on a frosted, blurred backdrop, so windows behind it no longer show through the text.

### Changed
- Releases are signed with MacSlider's own certificate, so macOS keeps the Accessibility permission across updates. Updating from an earlier version needs one last re-grant.

## [0.2.1] - 2026-10-30

### Added
- A new app icon, and a matching menu bar icon.
- Your own pairings stick: slides you arrange by hand are kept as they are and saved, until you reset.
- Reset to smart pairs (⌃⌥A, the menu, the menu bar slider or the overview) regroups every workspace by app in one step.
- Layouts stay put: when an app resizes or moves its own window (as Firefox sometimes does), MacSlider snaps it back.

### Changed
- A slide holds at most six windows; a seventh gets a slide of its own.

### Fixed
- Clicking an app in the Dock no longer rearranges the strip: hidden, minimised and reopened windows, and relaunched apps, return to exactly where they were.
- New windows no longer get paired with another app's window as they open; lone windows pair up only when you regroup (⌃⌥A), unless you turn pairing on in Settings.

## [0.2.0] - 2026-10-30

Slides, overview and workspaces, and much easier to drive with or without the keyboard.

### Added
- Slides grouped by app: same-app windows share a full-screen slide (four per slide for terminals), single-window apps pair up.
- Slide layouts: grid (2×2, 3×2), columns, rows, main + side and main + bottom.
- Resize the main window (⌃⌥. / ⌃⌥,) and make any window the main one (⌃⌥M); per-app slide layouts.
- Right-to-left strip direction, mirroring layout, keys, swipes, the slider bar and the overview.
- Click the menu bar icon for a slider popover with slide cards; right-click for the menu.
- Slider bar: a mini-map of the strip that glides in while you move; drag it to slide, click a slide to jump.
- Overview (⌃⌥O): every slide of every workspace at once; click to jump, drag to group or reorder.
- Workspaces: up to nine per display, ⌃⌥1–9 to switch, ⌃⌥⇧1–9 to move a window.
- Stack into the right column (⌃⌥]) and pop out of a stack to either side (⌃⌥⇧[ / ⌃⌥⇧]).
- Per-app windows-per-slide setting.
- Full shortcut list in the menu bar, and a practice pad in the welcome tour.
- Optional daily update check, and Check for Updates… in the menu bar.
- Slide mode: tap the right ⌥ key, then use plain keys (← → to slide, ⇧← ⇧→ to move, R, F, C, 1–9 …). A cheat sheet shows while it is on.
- Mouse wheel support: hold ⌥ and scroll to move one window per notch.
- Scroll over the menu bar to move the strip, no keys needed.
- ‹ › buttons in the menu bar to step between windows.
- Settings for the slide mode key, the scroll modifier, menu bar scrolling and the ‹ › buttons.

### Changed
- Scrolling the strip now uses ⌥ alone instead of ⌃⌥ (configurable).
- ⌃⌥1–9 now switch workspaces. Jumping to a slide by number moved to slide mode (1–9) and can be bound in Settings.
- ⌃⌥] now stacks into the right column; unstacking moved to ⌃⌥⇧].
- The welcome tour teaches slide mode and mouse scrolling first.

## [0.1.0] - 2026-10-30

First public release.

### Added
- Scrolling strip layout with one strip per display and per Space.
- New windows open next to the focused window; existing windows keep their size.
- Keyboard focus, move, width cycling, narrower/wider, full width, centring and jump-to-column.
- Stacks, tabbed columns with a clickable tab bar, and columns pinned to the left or right edge.
- Two-finger swipe with modifier keys, and optional three- or four-finger swipe.
- Click to reveal, drag to reorder, and resize a window to set its column width.
- Automatic floating for dialogs, panels and fixed-size windows; float/tile on demand.
- Per-app rules for floating, default width and opening position.
- Focus border, inactive-window dimming, focus follows mouse and mouse follows focus.
- Window search (⌃⌥Space) and a menu bar indicator with the windows on the current strip.
- Settings window with rebindable shortcuts, a one-step modifier prefix switch, and Mac setup checks.
- Welcome tour, launch at login, `macslider://` URL scheme and a `macslider` command-line tool.
- Windows are put back on screen when MacSlider pauses or quits; layouts are restored on relaunch.
