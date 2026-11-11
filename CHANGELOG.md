# Changelog

All notable changes to Monorail by Ashforde® are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **AI agents can drive Monorail.** Settings → Automation now has **Copy Agent Instructions** and **Save Agent Skill…** next to the MCP config: Claude Desktop, Cursor, Hermes Agent, OpenClaw and other MCP clients connect through MCP, agents that load skills get a ready-made `SKILL.md`, and any bot or computer-use agent that can run commands uses the `monorail` command. The skill is also on the website, with a guide at monorail.ashforde.org/docs/agents.
- **`monorail say "…"`** does what a sentence asks from the command line: “Slack and Mail side by side on 2”.
- **Choose the assistant's provider.** Besides Anthropic (Claude): OpenAI, Google Gemini, xAI (Grok), OpenRouter, a model in Ollama on this Mac (nothing leaves the Mac, and Settings lists the installed models), or any OpenAI-compatible server such as LM Studio. Each key is kept in your Keychain.
- **See what's draining your battery, right on the window.** On battery, the windows of apps using the most power get a small ⚡ in the overview and the window switcher; hover it for an estimate like “about 6% of the battery an hour”, and right-click to hide or quit the app. Measured once a minute and only on battery, counting each app's helper processes too. Estimates in battery per hour need an Apple silicon Mac; Intel Macs show how busy the app is.
- **A full battery panel**, from ⚡ in the slider popover or its own menu bar item (turn on “Show the battery in the menu bar”):
  - Charge, time left at the current rate, and the watts the whole Mac draws right now.
  - Low Power Mode on or off in one click.
  - A day of battery history, pink on battery and green while charging, with battery health and charge cycles.
  - **Needs your attention:** the app using the most, with Quit, Pause, Hide or Keep, and what quitting gives you back (“If you quit: 5 hr 52 min → 5 hr 58 min”).
  - Every app with its watts, battery per hour, processor share and number of processes, Top or All, with search (⌘F).
  - **AI agents** running on the Mac (Claude Code, Codex, Gemini CLI, Aider, Ollama and more), even inside a terminal or editor.
  - **Pause** freezes a power-hungry app (and its helpers) without losing anything; it wakes when you open it, plug in, or quit Monorail.
- **Battery for AI agents.** `monorail battery`, `GET /battery` and the MCP tools `battery_status` and `save_battery` give assistants the same figures, and let them hide, pause or (with your OK) quit the hungriest apps.
- **Park power-hungry apps on battery** (off unless you turn it on): apps using a lot of power that you haven't touched for an hour are hidden, never quit, and come back when you plug in.
- **More in the slider popover.** A row under the slides shows your battery level and its biggest user, applies a saved layout or restores a snapshot, turns focus mode on or off, and tells you about shortcut clashes or a pause for Stage Manager, each one click away.
- **Shortcut clash check.** Settings → Shortcuts lists any Monorail shortcut that macOS also uses (Mission Control, Spotlight, screenshots, input sources, switching desktops and more), says what uses it, and swaps it for a free combination in one click. **Change in macOS…** opens the Mac's own shortcut settings instead.
- **Portrait displays.** On a display taller than it is wide, new slides stack their windows top to bottom and the main window goes on top. Turn it off in Settings → Layout → Spacing.
- **Keep screen edges clear.** Settings → Layout keeps any edge free for another app's bar or dock, like SketchyBar. Windows, and floating windows you snap, stay out of it.
- **Restoring a setup can hide the other apps.** Turn on “Restoring a layout or snapshot hides the other apps” in Settings → General, and only that layout's apps stay in front. The others are hidden, never quit.
- **Light or dark for Monorail's own windows.** Settings → Appearance → Monorail's windows: match the Mac, always light or always dark.
- **On the website:** a [performance page](https://monorail.ashforde.org/performance/) with how Monorail is measured and checked on every build, the 85-second film in the hero, and an automatic tiling window manager in the list of paid apps Monorail replaces.

### Fixed
- **Settings → About → Usage shows the right numbers.** “This session” counts from when Monorail started, not from when you first opened Settings (it could show 0.0 h and over 100% CPU). Slide and workspace switches count however you move: the slider, swipes, clicks and the overview, not only the keyboard.
- **Check Energy measures Monorail, not Settings.** Settings steps aside for the 30 seconds and comes back with the result, so the figure is what Monorail costs while you work.

### Changed
- **Stage Manager no longer gets in the way.** Monorail pauses while Stage Manager is on (windows stay where they are) and carries on by itself when you turn it off, instead of asking you to turn it off. Switch this off in Settings → Apps.

## [1.7.28] - 2026-11-11

### Added
- **Stay Awake in the slider popover.** The cup button turns it on or off, keeps the Mac awake for 15 minutes to 8 hours, until you end it or while something downloads, and switches the display, Keep me Available and lid-closed options. It glows orange while your Mac is kept awake.
- **Themes in the slider popover.** The palette button shows every theme with its colours; one click switches.

## [1.7.27] - 2026-11-11

### Changed
- **Usage counts keep arriving.** Monorail reads where to send its anonymous daily counts, the list of app quirks and the script gallery from monorail.ashforde.org, and falls back to a built-in address, so they keep working wherever the project lives.
- **No pop-up about usage counts.** They're anonymous and on from the start, as the privacy policy says; switch them off any time in Settings → Devices & Sharing → Trust, where **What's Sent…** shows them in full.

## [1.7.26] - 2026-11-09

### Added
- **Evening Mode in the slider popover.** The moon button next to the wand turns it on or off and sets the warmth, when it comes on and red light, without opening Settings. It glows orange while the screen is warmer.

## [1.7.25] - 2026-11-09

### Changed
- **Updates come from monorail.ashforde.org.** Monorail checks Ashforde's own site for new versions, and still checks the download's checksum and Apple signature before installing it. If the site can't be reached, it tries the previous address.
- **Report a Problem, Send Feedback and the after-crash prompt start an email** to contact@ashforde.org, with the same details filled in as before (no window titles, files or names). You see everything before you send it.
- **The changelog, the guide for IT and the About links open on monorail.ashforde.org.**

### Fixed
- **The beta channel only offers Mac versions,** never the Windows and Linux betas that share the release list.

## [1.7.24] - 2026-11-04

### Changed
- **Even lighter while you're away.** Measured with a profile on a MacBook Pro: the checks for system prompts, screen sharing and the slider bar now run a fifth to a third as often when nobody is at the Mac, and stashed windows cost nothing while the pointer is still.
- **Fewer calls to other apps.** Monorail recognises a window it already manages without asking the app, which makes moving and resizing windows cheaper too.

### Fixed
- **Lock after idle works with Keep me Available.** Monorail's own tiny pointer moves no longer count as you being at the Mac.
- **The performance check measures the copy that's running,** and asks you to reopen Monorail if it was updated since it started.

## [1.7.23] - 2026-11-04

### Changed
- **Lighter while you're away.** When nobody has touched the Mac for a minute, Monorail checks the Dock and terminal windows a quarter as often, so it uses even less of your battery when idle.

## [1.7.22] - 2026-11-04

### Fixed
- **Keep me Available now keeps Teams and Slack on Available.** Tested on a Mac: only a tiny pointer move resets the idle time chat apps read, so Keep me Available makes one about once a minute while you're away, also where Accessibility isn't allowed.

## [1.7.21] - 2026-11-04

### Fixed
- **Live previews:** asking for them now always adds Monorail to Screen & System Audio Recording in System Settings, so it can be switched on there.

### Added
- **Keep me Available.** A new item next to Stay Awake keeps your Mac awake and keeps Teams, Slack and other chat apps showing you as Available. While you're away from the keyboard it tells macOS you're active about once a minute, which needs no permission; with Accessibility it can also nudge the pointer. It's an action you can give a key, and a choice in the welcome tour's extras.
- **Monorail on Macs where you can't allow Accessibility.** Stay Awake, Keep me Available, Evening Mode, display brightness and resolution, the command palette, What's New and Settings now work straight away, before Accessibility is allowed or without it. The menu says once that window arranging needs Accessibility, offers **Grant Accessibility Access…** and **Using Monorail Without It…**, and no longer opens the welcome tour at every launch.
- **Arrange scriptable apps without Accessibility.** Until Accessibility is allowed, the menu and command palette can put Safari, Google Chrome, Finder, Terminal, Notes, Mail, TextEdit, Pages, Numbers, Keynote, Preview and iTerm2 in the left or right half, fill the screen or centre them, place the last two side by side, and switch between an app's windows. macOS asks once for each app, and you can answer without an administrator. Not in the App Store edition.
- **A guide for IT** ([docs/IT.md](docs/IT.md)) and a configuration profile that allows Accessibility for Monorail in one step through an MDM (`packaging/mdm/Monorail-Accessibility.mobileconfig`).

### Changed
- The install script puts Monorail in your own Applications folder (`~/Applications`) when `/Applications` needs an administrator, and says so. Updates work from there too.
- The pointer nudge in Stay Awake is now **Also move the pointer now and then (needs Accessibility)**; without Accessibility, Monorail keeps you available by telling macOS you're active instead.

## [1.7.20] - 2026-11-04

### Fixed
- **Practice with demo windows no longer quits Monorail.** Monorail's own practice windows are now moved on the main thread, as macOS requires.
- **The welcome tour and What's New stay in front** of other windows and never end up in a tab group.

## [1.7.19] - 2026-11-04

### Changed
- **Monorail now uses its own identifier, org.ashforde.monorail**, instead of the one from its first name. Your settings, layouts and workspaces come with you. macOS sees the new identifier as a new app, so it asks you once to allow Accessibility again.

### Fixed
- **If Accessibility is switched on but Monorail still can't move windows** (macOS's stored answer belonged to an earlier copy), the welcome tour offers **Reset and ask again**, which clears it and asks afresh.

## [1.7.18] - 2026-11-04

### Fixed
- The welcome tour fits the screen on smaller Macs: it scrolls inside its window instead of running under the Dock.

## [1.7.17] - 2026-11-03

### Added
- **A window switcher with live previews.** Hold ⌘ (or ⌥) and press Tab for a grid of every window, most recent first, in every workspace. Tab or the arrow keys move, W closes a window, M minimises it, Q quits its app, and letting go switches. Off until you choose ⌘Tab or ⌥Tab in Settings → Motion & Input; ⌘Tab replaces the macOS app switcher while it's chosen, and gets it back when you switch it off or quit. Not in the App Store edition.
- **Snap by dragging to screen edges.** Drag a floating window to the left or right edge for a half, a corner for a quarter, or the top to maximise, with a preview of where it will go. Windows on the strip aren't affected. When macOS's own edge tiling is on (macOS 15 and later), Monorail leaves edge drags to it unless you choose otherwise. Settings → Layout.
- **Displays by direction and by number**: focus a display, or send a window to it, to the left, right, above or below, or by number from 1 to 9 (numbered left to right). Floating windows keep their place and size in proportion.
- **Evening Mode from sunset to sunrise**, worked out on your Mac from its time zone, with no location access and nothing sent. Also **Deep red**, where green and blue fade out too, down to red light only, and **apps where Evening Mode rests**, such as photo and video editors.
- **Dimmer than the lowest brightness.** A brightness slider for each display in the new Displays menu dims it in software, below its own lowest setting, and works with Evening Mode. Brighter and Dimmer are also actions you can give keys.
- **Resolution and refresh rate** for each display in the Displays menu, including sharp (HiDPI) scaled sizes, plus actions for More Space, Larger Text and the display's default.
- **Stash a window at the screen edge.** It slides out of view leaving a sliver; point at the sliver and it slides out, and back again when you move away. Run the action again, or **Bring back every stashed window**, to put it back where it was.
- **Pick your extras** in the welcome tour: a short checklist, ticked to suit the starter setup you choose. People updating see this version's new features as switches in What's New, all off until ticked.
- **Keep terminals together.** Terminal, iTerm, Ghostty, Warp, kitty, Alacritty and WezTerm windows share slides with each other (up to four), as if they were one app. On by default; switch it off under grouping in Settings.

### Fixed
- Monorail and Keeper find each other as soon as Monorail opens, before Accessibility is allowed, so Stay Awake hand-over works from the first minute.
- The shared folder Monorail and Keeper talk through is rewritten correctly on Windows.

## [1.7.16] - 2026-11-03

### Added
- **Start as Simple, Power user or Coming from another app**, in the welcome tour and Settings → Basics. Coming from another app opens the importer for AeroSpace, yabai and Rectangle.
- **Show all settings**, at the bottom of the Settings sidebar. Off (the default for new installs), the sidebar shows the essentials: Basics, Shortcuts, Appearance, Evening Mode, Stay Awake and About. Search always finds every setting.
- **After an unexpected quit, Monorail asks what happened** (once per version, and you can turn it off). **Tell Us…** opens a problem report filled in with the Monorail and macOS versions and a short summary of where it crashed, from macOS's own crash report: no window titles, files, paths or names, and nothing is sent until you submit it.
- **Also from Ashforde** in the menu bar menu: while Keeper runs, it shows what Keeper is doing (keeping your Mac awake or not) with **Open Keeper**; with Keeper installed but closed, **Open Keeper**. And a joint page on the website, **Monorail + Keeper**, on how the two work together.

### Changed
- **Signed with Ashforde's Apple Developer ID and notarised by Apple.** Monorail now opens without the "can't verify the developer" warning, and the pkg installer is signed for MDM tools (Jamf, Kandji, Intune) and Installomator.
- Because the signature changed, macOS asks you once to allow Accessibility again after this update (System Settings → Privacy & Security → Accessibility: remove Monorail, then open it again). Updates after this one keep the permission.
- Monorail and Keeper also talk through a folder only Ashforde's apps share (an App Group), so they keep working together in their App Store editions, where the local network API isn't allowed.
- The Mac App Store edition leaves out lid-closed mode and event scripts (the sandbox doesn't allow them), sets the App Store's encryption declaration, and signs with the App Store's app identity when it has the profile.
- **VoiceOver reads every icon button**: Remove, Delete, Clear, Edit, Overview, Settings, Pause, Undo and the rest in Settings, the menu bar popover, the overview and the resize popup now have spoken names. A test keeps new icon buttons from shipping without one.

## [1.7.15] - 2026-11-03

### Changed
- Getting ready for notarised releases: updates signed with Ashforde's Apple Developer ID are now accepted, so the next releases can open without the "can't verify the developer" warning and still update automatically.

## [1.7.14] - 2026-11-03

### Added
- **Evening Mode**: less blue light from every display, easier on the eyes at night. Choose how warm with a slider (the screen changes as you drag), turn it on from the menu bar, or have it come on every evening on a schedule, fading in over 20 minutes. Screenshots and recordings keep their normal colours, and your displays' own calibration is kept. Settings → Evening Mode.
- **Stay awake with the lid closed is safer.** It turns off by itself if your Mac gets hot and stays off for the rest of that session; with the lid closed, the Mac then goes to sleep. New **Only while plugged in** option, on by default: unplug with the lid closed and the Mac sleeps (turned off, it runs closed on battery down to 20%). Low Power Mode also ends it. Once it has stopped for safety, it stays off until the next Stay Awake session, so no password prompt appears when the power comes back. If you'd already turned sleep off yourself, Monorail leaves that setting alone. Keeper follows the same rules, and when Keeper is running and set up for it, Keeper keeps the Mac running closed (with Monorail taking over if Keeper can't).

### Changed
- Lid-closed mode asks for your password once, when it starts. Turning it off no longer asks, so it can turn off with the lid closed. It also turns off within seconds if Monorail quits or crashes, instead of waiting until Monorail opens again.

## [1.7.13] - 2026-11-02

### Fixed
- `--shared-engine`: screen changes macOS makes by itself (the Dock, the menu bar) no longer make it re-place every window, it only moves windows whose place changed, and its log leaves out the echoes of its own moves.

## [1.7.12] - 2026-11-02

### Added
- **`Monorail --shared-engine`**, for trying the engine the Windows and Linux versions will share on your Mac's real windows. Quit Monorail first, then run `/Applications/Monorail.app/Contents/MacOS/Monorail --shared-engine` in Terminal; it prints every window event and stops with Ctrl-C. Normal use is unchanged.

### Changed
- Groundwork for Windows and Linux: keeping windows on screen, focus history, back and forward, workspace tags, saved views and where returning windows go now come from the shared engine. Monorail behaves the same, and saved views keep their format.
- Every change in Monorail's history is signed and verified.

## [1.7.11] - 2026-11-01

### Fixed
- **Installer windows keep their size.** The window a downloaded disk image opens in Finder (an app next to an Applications shortcut, like Keeper's or Monorail's own installer) was tiled and stretched around its fixed-size background. Finder windows of mounted read-only disk images now float at the size they open with. ⌃⌥T still tiles one if you want it.

## [1.7.10] - 2026-11-01

### Fixed
- **The app icon fills its shape on macOS 26.** macOS Tahoe draws app icons itself and put Monorail's on a grey plate. Monorail now ships its icon in Apple's new format as well (built from `assets/AppIcon.icon`), so it takes the full rounded-square shape and the system's light and depth like other apps. macOS 13 to 15 keep the same icon as before.

## [1.7.9] - 2026-11-01

### Added
- **Monorail and Keeper talk to each other.** Keeper says hello through the local API (`POST /peer`, answered by `GET /hello`), and `state.json` now includes presentation mode, Stay Awake and pause as well as focus mode, so Keeper follows along.
- **One owner per mode.** Focus and presentation mode started by Keeper (`monorail://focus-mode/on?from=keeper`) run without Monorail's own timer, notices or sounds; they end when Keeper ends them or you turn them off in Monorail.
- **One Stay Awake hold.** While Keeper keeps your Mac awake, a Stay Awake session you start in Monorail (for a while, or until you end it) goes to Keeper instead of adding a second hold. Sessions tied to an app or a download stay with Monorail.
- Keeper's overlays (the Island, Glance, Voice, cues, the launcher, Stage, widgets, the wallpaper, Quick Connect, the guide and the sharing bar) are never managed by their titles too, and so is any other window Keeper announces.

## [1.7.8] - 2026-11-01

### Added
- **Works hand in hand with Keeper.** Monorail recognises Keeper by Ashforde and leaves everything Keeper places itself exactly where Keeper puts it: the Island at the notch, desktop widgets, Quick Search, Quick Terminal, Capture, the tray popover, guides and HUDs. They're never tiled, centred, moved or snapped back. Keeper's main window tiles like any other app's.

### Fixed
- **Menu bar and notch apps are left alone.** Since 1.7.7, keeping windows on screen could move the panel of a notch or menu bar app (one that tucks under the camera at the top of the screen) into the middle of the screen. Now only ordinary apps' ordinary windows and dialogs are brought back into view; floating panels, HUDs and widgets are never moved. The same goes for placing new dialogs: panels above the normal window layer, and small panels without a title bar that sit against the menu bar, stay exactly where their app puts them.
- **macOS prompts always come to the front.** Permission prompts ("… would like to access…"), password and Touch ID prompts, and "Are you sure you want to open…" now come in front of every window, centred on the screen you're using. If another app covers one, it's brought back on top. Until you answer, Monorail doesn't move focus to other windows and hides its window borders and tab bars. Turn it off with "Keep macOS permission and password prompts in front, centred" in Settings.

### Changed
- The rules for keeping windows on screen now live in the shared engine that the Windows and Linux versions will use.

## [1.7.7] - 2026-11-01

### Added
- **Every window and dialog stays reachable.** Floating windows and dialogs that end up off screen come back into view by themselves: after a display is unplugged or rearranged, after the Mac wakes, and whenever an app comes forward. Tiled windows waiting in other workspaces are left where the layout puts them. Turn it off with "Keep every window and dialog on screen" in Settings. Monorail's own windows refit too when displays change.
- **Press kit** on the website (`/press`): fact sheet, a description to copy, screenshots, the icon, the demo video and one zip with everything.
- **Download stats** on the website (`/stats`): live download counts per release and per file type. The anonymous usage counts stay private.
- Launch-day answers for common questions, in `docs/launch/REPLIES.md`.

## [1.7.6] - 2026-11-01

### Fixed
- **The slider bar shows again.** Since 1.7.2 it could stay hidden, mostly in "Only while sliding" mode: the rule that made it step aside for windows in front of it also counted your tiled windows, which sit under the bar by design.
- **The slider bar steps aside only for full-screen apps and videos.** It hides while any app fills the whole screen (including a player's or browser's own full screen) and while a playing video's window is under it; at all other times it shows. Native macOS full screen never shows it. The setting is now called "Step aside for full-screen apps and videos".

## [1.7.5] - 2026-11-01

### Fixed
- **File pickers stay on screen.** "Choose Files to Upload" and other open and save panels that an app opens bigger than the screen (often a size remembered from a larger display) are now shrunk to fit and kept fully visible, including when the app reopens the same panel or moves it a moment after it appears.
- **Monorail's Settings window fits your screen.** It opens at a size that fits the display it appears on, centred, and can now be resized (down to 640 × 440). Its other windows are kept on screen the same way.
- Importing settings from a file saved on Windows (with Windows line endings) now works.

## [1.7.4] - 2026-11-01

### Added
- **More ways to install:** every release now includes a `.pkg` installer for MDM tools (Jamf, Kandji, Mosyle, Intune, Munki), and there are an Installomator label and AutoPkg recipes for IT. Their versions and checksums update with each release.
- **The Mac App Store edition** can now be built (`scripts/build-appstore.sh`): sandboxed, with its own identifier, leaving out what the sandbox doesn't allow. See docs/APP-STORE.md.

## [1.7.3] - 2026-11-01

### Added
- **The welcome tour ends with docking:** a sixth practice step, "Dock a window onto another".
- **Send Feedback…** in the menu bar opens a short feedback form with your versions filled in.
- Labels for VoiceOver on the gap handles and the zone editor, and the new menu items in all nine languages.
- A launch test checklist in `docs/LAUNCH-QA.md`.

### Changed
- **Your mouse's Back and Forward buttons belong to your apps again.** They used to step through slides everywhere, which got in the way of Back in browsers and Finder. Turn it back on in Settings → Motion & Input. (Monorail switches it off once after updating, and tells you.)
- The Monday summary notification is off for new installs (Settings → General).
- Website: a welcome for visitors from Product Hunt, a comparison table, and download buttons that go straight to the latest DMG with its version and size.

## [1.7.2] - 2026-11-01

### Fixed
- **The slider bar no longer covers video controls.** It steps aside while a video plays, and while the window in front (a video player, a floating window) covers its spot, then comes back. Turn it off in Settings → Appearance → Slider bar.
- **New Terminal windows are tiled right away.** Some apps (Terminal among them) announce a window before it's finished, so it briefly looks like a dialog and was left floating, outside the strip and the overview, until you clicked elsewhere. Monorail now looks again a moment later and tiles it.
- **Full-screen apps stay clear.** The slider bar and its preview no longer appear over apps in native full screen.

## [1.7.1] - 2026-11-01

### Changed
- **Bigger docking zones.** Dropping a window anywhere in the outer 40% of another window's side docks it there; only the middle fifth makes a tab group, so docking beside is easy to hit.

### Added
- The website has an interactive docking playground with a guided demo, and the README explains docking and undocking.
- The website has a light, dark or automatic switch and a text-size control (remembered on your device), fits phones without sideways scrolling, and says what's coming for Windows and Linux.
- A new Product Hunt gallery and an 85-second demo video in `assets/launch/v17`.

## [1.7.0] - 2026-11-01

### Added
- **Nested slides.** A slide can now be split inside splits, as deep as you like. Drag a window onto another window: near an edge it docks beside it (left, right, above or below), in the middle the two become a tab group, whatever the apps. A highlight shows where it will land. It works from floating windows too, and Undo puts things back. **⌃⌥G** returns a slide to the standard layouts.
- **Tab groups inside slides**, with their own tab bar. Drag a tab out to tear it off; **Tear off** gives a window a slide of its own.
- **Drag the gap between two windows** to resize both at once, inside a slide or between slides.
- **Saved views.** **⌃⌥⌘⇧1…9** saves where you are on a display (workspace, position and window), **⌃⌥⌘1…9** comes back. Nine per display, kept across restarts.
- **Back and forward** through where you've been, like a browser: **⌃⌥⌘[** and **⌃⌥⌘]**. Also in the menu bar under **Views**.
- **Zone editor.** Settings → Apps → Custom slide layouts → **Design Zones…**: split any zone side by side or up and down, resize, remove, then use the layout on any slide.
- **Import your settings** from AeroSpace, yabai and skhd, or Rectangle (Settings → Basics): shortcuts, gaps, floating apps and workspace rules.
- **Tags.** Keep a window on several chosen workspaces (it follows you between them), and show another workspace's windows alongside this one until you switch away. Both are in the palette and Shortcuts.
- **Live event stream.** `monorail subscribe` prints focus, workspace, action and alert events as JSON lines, for SketchyBar and scripts. It's a private socket in Monorail's folder; nothing listens on the network.
- **App-colour tiles.** Without Screen Recording, the overview fills each window's tile with its app's own colour and icon.
- **Basics in Settings**: one page with the options most people change.
- **`Monorail --ui-test`** and a UI-test workflow for a self-hosted Mac.

### Changed
- Keyboard docking (**Dock onto the window on the left/right/above/below**) and **Even out the splits** can be bound in Settings → Shortcuts.
- Nested slides keep their shape after Monorail or the Mac restarts.

## [1.6.0] - 2026-11-01

### Added
- **Settings has a sidebar.** The twelve panes are grouped into Essentials, Make it yours, Power and Monorail, with search at the top.
- **Snapshots can save browser tabs and Finder windows** (Settings → Smart). Safari, Chrome, Arc, Brave, Edge, Vivaldi and Finder. Restoring a snapshot reopens them if the app wasn't already open. Off by default; macOS asks once per app.
- **Share links for layouts.** Layouts → Copy Share Link gives a link that opens a preview of the layout on the web, with **Open in Monorail**. Window titles and tabs are never included, and Monorail asks before adding a shared layout.
- **Assistant (optional).** Add your own Anthropic API key in Settings → Smart → Assistant. Sentences Monorail doesn't understand go to Claude, which turns them into Monorail commands. You see them and confirm before anything runs. The key stays in your Keychain.
- **Float suggestions.** Float an app's windows by hand three times and Monorail offers to always float that app.
- **Anonymous usage counts** (on by default, easy to turn off). Once a day: Monorail and macOS versions, Mac model, chip, memory range, displays, language, install source and which features are on. Never window titles, app names, files or anything you type. Monorail tells you the first time, and **What's Sent…** in Settings → Devices & Sharing → Trust shows the exact data.
- Smoke test script, app compatibility guide and beta-testing guide in `docs/`.

### Changed
- **New licence.** From 1.6.0 Monorail is under the Functional Source License (FSL-1.1-ALv2): free to use, read and change, but not to sell or offer as a competing product. Each release becomes Apache 2.0 after two years. Versions up to 1.5.2 stay under the AGPL. The Monorail name and icon are trademarks; see TRADEMARKS.md.
- Quieter defaults: focus-mode nudges and the workspace clipboard are now off for new installs.
- The updater accepts builds with the upcoming `org.ashforde.monorail` identifier, so a later release can switch to it without breaking automatic updates.
- The website has a proper favicon and app icons.

## [1.5.2] - 2026-10-31

### Fixed
- **Resizing a window in a shared slide no longer hides its neighbour.**
  - A window used to stop at 80% of its slide, then cover the window beside it.
  - Now it can take up to 88%, squeezing the other window as far as it will go.
  - If that window won't get narrower (many apps have a minimum width), the slide widens, up to the full screen, so both stay side by side.
  - When even the full screen isn't enough, the resize toast offers **Own slide**.

## [1.5.1] - 2026-10-31

### Changed
- **Stay Awake's menu bar cup matches the rest of the icon.** It's a small monochrome cup with a wisp of steam, drawn into the Monorail icon like the slide markers, instead of a colour emoji. It follows light and dark menu bars, and the time left stays beside it.

## [1.5.0] - 2026-10-31

### Added
- **Ask Monorail.** Type a question in the command palette (“how do I keep my Mac awake?”) and get the answer, with a button to the right action or setting.
- **Search in Settings.** A search field at the top of Settings finds any option and takes you to its pane. The index is generated from the Settings source, so it covers every option.
- **Check Energy** (Settings → About): a 30-second measurement of Monorail's own CPU, wake-ups and power, from macOS's per-process counters.
- **Session timeline in Insights.** Today on one line, coloured by workspace.
- **Meeting layout.** When a call opens from your calendar, your notes app goes beside it, and **After the meeting** in the palette puts your layout back.
- **Sidecar.** On a Sidecar iPad, every slide fits on screen.
- **Script gallery** (Settings → Automation): install ready-made scripts with one click. It starts with an IDE layout, halves and thirds, calls getting their own workspace, focus hours and a morning setup.
- **Tips** that show once, at the moment they're useful: slide mode, dragging in the overview, sentences in the palette, Stay Awake and agent alerts.
- **Homebrew:** a cask that updates itself with every release.
- **A website**, published by its own workflow.
- **Self-test.** `Monorail --self-test` builds every Settings pane and checks every action, theme, language and default. CI runs it on every build.

### Changed
- **Lighter launch.** Voice commands, the phone remote, layout sync, head focus, the camera tile and the screen mirrors are created only when first used.
- **The overview opens with last time's previews** and replaces them as fresh ones arrive.
- **Stay Awake triggers** are checked half as often in Low Power Mode or on battery when no session is running.

### Fixed
- **Screenshots don't hide your windows.** Taking a screenshot (⌘⇧5) or viewing another Mac with Screen Sharing no longer counts as sharing your screen, so private windows are no longer hidden.

## [1.4.0] - 2026-10-31

### Added
- **Usage in About.** Launches, running time, average CPU, memory, windows managed, slide and workspace switches, time kept awake, and your most used actions. It's all kept on your Mac, and Copy and Reset are there too.
- **What's New tour:** feature cards with a **Try it** button each, for sentences, Stay Awake, safe screen sharing and AI agent alerts. **What's New…** is in the menu bar menu too.
- **Report a Problem…** (Settings → Devices & Sharing) opens a problem report filled in with your version, macOS and usage counts, and opens the folder of crash reports to attach.
- **Four more languages:** Chinese (Simplified), Portuguese, Korean and Italian, alongside German, French, Spanish and Japanese. The newer labels (Smart, Devices & Sharing, Stay Awake…) are translated into all of them.
- **docs/TESTING.md:** a real-Mac checklist, including the first-hour energy check. **docs/NOTARISATION.md:** one-time steps to ship notarised builds.

### Changed
- **Floating windows never stay out of view:**
  - They open where macOS or the app puts them.
  - If that's off screen, they move over the app's own window, or to the middle of the display.
  - Several opened at once are staggered.
  - If an app or a drag later leaves one mostly off screen, it comes back once it stops moving.
  - Positions are remembered per kind of window (settings, panels, other windows), and Get Info windows are never piled into one remembered spot.
- **A tidier About pane.** Copy Diagnostics, Show Log and Reveal Settings File are in a collapsed **Advanced** section.
- **A shorter menu bar menu.** Windows are listed in a **Windows** submenu, and long titles are shortened. Settings → General → **List windows right in the menu** brings back the inline list.
- **Fewer redraws:** the focus border, dimming and tab bars are redrawn only when something about them changed.


### Fixed
- **Get Info and other floating windows no longer open out of view.**
  - Apps open these panels next to their main window, which may be waiting off screen. A floating window that doesn't fit on screen is now centred on the display you're working on, and windows that open together are staggered.
  - A floating window that already fits stays exactly where the app put it.
  - A remembered position is only reused if it fits on screen, and never for fixed-size panels.

### Changed
- **The overview uses less energy.** Window previews are captured at the size the cards show (about a third fewer pixels), and the colourful backdrop is drawn once instead of on every frame.
- **Measured on a MacBook (1.2.0 → 1.3.0, idle):** CPU went from 0.33% to 0.09% of one core, wake-ups from 18 to 0 per second, and memory from 272 MB to 47 MB.

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
- **Animate Windows** in the menu bar menu: switch animation off in one click. Windows then move instantly, everything else works the same, and it uses less energy. (Also in Settings → Motion & Input and the command palette.)
- **A measuring script**, `scripts/measure-performance.sh`, that measures Monorail's own CPU, wake-ups, energy and memory, while idle and in use.

### Changed
- **Far fewer wake-ups from window titles.** Terminals running AI agents, and browsers, animate their window titles many times a second, and Monorail used to wake for every change.
  - Now it follows titles live only where they matter: apps with title rules, project grouping and tabbed slides.
  - Other windows have their title read when you focus them or open the overview, palette or switcher.
  - Live title changes are batched to at most one update a second.
  - Measured on 1.2.0, with several terminals open, Monorail woke 18 times a second while idle.
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
  - **AI agent alerts** for AI coding assistants in a terminal waiting for approval, with a palette shortcut to the agent.
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
- Links point to Monorail's new home.

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
