# App compatibility

Monorail moves windows through macOS's Accessibility interface, so it works with any app that
exposes its windows there, which is nearly all of them. This page lists what Monorail does by
default with popular apps, what to expect, and the fix if something looks wrong.

**Help keep it accurate.** If an app misbehaves, use **Settings → Smart → Trust → Report a
Problem…**, or open an issue with the app's name and version. Fixes ship as *app quirks*, which
Monorail downloads without needing a new release.

## Built-in defaults

| App | Default | Why |
|---|---|---|
| System Settings, Calculator, Activity Monitor, Archive Utility | Float | Small fixed-size utility windows |
| Terminal, iTerm, Ghostty, Warp, kitty, Alacritty, WezTerm | Up to 4 per slide | Terminals are useful side by side |
| Any settings or preferences window | Float | Recognised by title (Settings → Apps → Float settings windows) |
| Fixed-size windows (dialogs, Get Info, About boxes) | Float, kept on screen | They can't be resized |

## Popular apps

These apps tile like any other. The notes say what people usually change.

| App | Notes |
|---|---|
| Safari, Chrome, Arc, Brave, Edge, Vivaldi | Snapshots can save and reopen their tabs (Settings → Smart). Firefox tiles too, but has no AppleScript for tabs |
| Slack, Discord, Microsoft Teams, Zoom | A title rule (for example “Zoom Meeting”) can give calls a slide of their own |
| Google Meet in a browser | A title rule for “Meet” gives the call its own slide |
| Mail, Outlook, Spark, Superhuman | Compose windows join the app's slide; turn off grouping for the app to keep them apart |
| VS Code, Cursor, Zed, Xcode, JetBrains IDEs, Sublime Text, Nova | Content-aware widths give about 100 columns (Settings → Smart) |
| Figma, Sketch, Affinity, Adobe apps | Float any palette window that tiles by mistake (⌃⌥F) |
| Notion, Obsidian, Craft, Bear, Notes, Things, Todoist | — |
| Finder | Get Info and other fixed-size windows float and are kept on screen |
| Spotify, Music, Podcasts | Float a mini player with ⌃⌥F if it tiles |
| Preview, Pages, Numbers, Keynote, Word, Excel, PowerPoint | Presentation mode (command palette → “Presentation”) keeps windows still while you present, or add Keynote to “Pause tiling while these apps are in front” in Settings → Apps |
| Calendar, Fantastical, Messages, WhatsApp, Telegram, Signal | — |
| 1Password, Raycast, Alfred, Spotlight | Their pop-up panels aren't normal windows, so they're left alone |
| Games and native full-screen apps | Native full-screen windows live on their own Space and are left alone |
| Simulator, Android Emulator | Fixed-size windows float |

## Common fixes

- **A window keeps jumping back.** The app is resizing itself and Monorail is putting it back. Turn
  off **Settings → Layout → Keep windows in place when an app resizes or moves them itself**, or
  float that app.
- **An app's windows shouldn't tile.** Float one (⌃⌥F) three times and Monorail offers to always
  float that app, or add a rule in Settings → Apps.
- **A window is too narrow.** Some apps have a minimum width. Monorail never squeezes a window below
  it; the slide widens instead.
