<div align="center">

<img src="assets/readme/banner.svg" alt="Monorail by Ashforde® — every window rides one rail" width="100%">

<br>

[![Download Monorail by Ashforde®](https://img.shields.io/badge/Download-Monorail%20by%20Ashforde%C2%AE-F66270?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/ashfordeOU/monorail/releases/latest)

[![Latest release](https://img.shields.io/github/v/release/ashfordeOU/monorail?label=version&color=F66270)](https://github.com/ashfordeOU/monorail/releases/latest)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-2A1430?logo=apple)
![Universal](https://img.shields.io/badge/Apple%20silicon%20%2B%20Intel-universal-D63A80)
![License: FSL-1.1-ALv2](https://img.shields.io/badge/license-FSL--1.1--ALv2-FF9E62)
[![CI](https://github.com/ashfordeOU/monorail/actions/workflows/ci.yml/badge.svg)](https://github.com/ashfordeOU/monorail/actions/workflows/ci.yml)

[Install](#install) · [Safe to install](#safe-to-install) · [Features](#features) · [Getting started](#getting-started) · [Shortcuts](#keyboard-shortcuts) · [Settings](#settings) · [Automation](#automation) · [Privacy](#privacy) · [FAQ](#faq)

</div>

---

**Monorail by Ashforde®** is a scrolling window manager for your Mac.

Other tilers squeeze every new window into the space you already have. Monorail puts each window
on a strip that runs past the edges of your display, so nothing shrinks. Open a window and it
slides in next to the one you're using. Move focus and the strip glides just far enough to show it.

<p align="center"><img src="assets/readme/how-it-works.svg" alt="How Monorail works: windows on a strip that runs past the screen" width="100%"></p>

## Install

| Download | Homebrew | Terminal |
| --- | --- | --- |
| [Monorail-x.y.z.dmg](https://github.com/ashfordeOU/monorail/releases/latest) | `brew tap ashfordeOU/monorail https://github.com/ashfordeOU/monorail && brew install --cask monorail` | `curl -fsSL https://raw.githubusercontent.com/ashfordeOU/monorail/main/scripts/install.sh \| bash` |

1. Open the DMG and drag Monorail onto Applications. (The Terminal script downloads the latest release, installs it in `/Applications` and opens it for you.)
2. Open Monorail and allow **Accessibility** when asked. The welcome tour shows you where.
3. Press <kbd>⌃⌥←</kbd> <kbd>⌃⌥→</kbd> to slide, <kbd>⌃⌥O</kbd> for the overview, and <kbd>⌃⌥/</kbd> to type what you want.

<p align="center"><img src="assets/readme/installer.png" alt="The Monorail installer: drag Monorail into Applications" width="560"></p>

You need macOS 13 Ventura or later, on Apple silicon or Intel. A trackpad is only needed for swipe gestures.

### More ways to install

Nix: `nix profile install github:ashfordeOU/monorail`. MacPorts: a
Portfile in [`packaging/macports`](packaging/macports), to use as a local port until it's accepted
upstream. IT teams: every release has a signed `.pkg` for Jamf, Kandji, Mosyle, Intune and Munki,
plus an [Installomator label](packaging/installomator) and [AutoPkg recipes](packaging/autopkg).
A lighter, sandboxed Mac App Store edition is coming ([what's different](docs/APP-STORE.md)).

### Updates

Monorail checks GitHub once a day. When a new version is out, its menu shows
**Update to Monorail …**, and **Install and Relaunch** downloads it, checks it against the published
SHA-256 checksum and Monorail's code signature, and reopens with your windows where they were.
Turn on **Install updates automatically** in Settings → General to skip the question.

## Safe to install

- **Notarised by Apple.** From 1.7.16, every release is signed with Ashforde OÜ's Apple Developer ID (Team `D69G45342Y`) and notarised by Apple, so it opens without a warning. To check a download yourself, run `spctl -a -vvv -t open --context context:primary-signature Monorail-x.y.z.dmg`; it reports `source=Notarized Developer ID`.
- **Open source.** Every line is on GitHub under the [Functional Source License](LICENSE). Build it yourself if you like.
- **Private.** No account. Everything Monorail learns stays on your Mac. The only data it sends is anonymous usage counts, which you can turn off. [Details](#privacy).
- **One permission.** Accessibility, which macOS requires before any app can move windows. Others are asked for only when you turn on a feature that needs them.

> [!NOTE]
> Updating from 1.7.15 or earlier? The new signature means macOS asks once more for Accessibility.
> In System Settings → Privacy & Security → Accessibility, remove Monorail with **–**, then open it again.
> Later updates keep the permission.

What's new in each version: [CHANGELOG.md](CHANGELOG.md). Help: [monorail.ashforde.org/support](https://monorail.ashforde.org/support/).

## Features

### One strip. Nothing shrinks.

Every display, Space and workspace has its own strip. Windows of the same app share a full-screen
slide: two side by side, or four terminals in a grid. Choose a layout for any slide (grid, columns,
rows, main + side, main + bottom or tabs), up to six windows each, or draw your own. Resize one
window and its neighbours follow. Apps that move themselves are put back.

<p align="center"><img src="assets/readme/layouts.svg" alt="Slide layouts: side by side, up and down, grids of four and six, main + side, main + bottom, columns and tabs" width="100%"></p>

### Dock windows and make tab groups.

Drag a window by its title bar onto another. Drop it near an edge and it docks on that side; drop
it in the middle and the two become a tab group, even if they're different apps. Dock again inside
a docked window, as deep as you like, and drag the gap between two windows to resize both. Choose
**Tear off** in the command palette to give a window its own slide again.

### See everything at once.

The overview (<kbd>⌃⌥O</kbd>, or <kbd>⌥</kbd> + pinch) shows every slide of every workspace. Drag
windows between slides, displays and workspaces, rename workspaces in place, or drop a window on
the bin to close it. The slider bar glides in as the strip moves, with a live preview of each
slide. Save where you are as a view with <kbd>⌃⌥⌘⇧1</kbd>…<kbd>9</kbd> and come back with <kbd>⌃⌥⌘1</kbd>…<kbd>9</kbd>.

<p align="center"><img src="assets/readme/overview.svg" alt="The overview: workspaces Work, Chat and Design, each with its slides of windows" width="100%"></p>
<p align="center"><img src="assets/readme/slider.svg" alt="A desktop with a pair of windows and the slider bar, with a live preview of a slide" width="100%"></p>

### Move the way you like.

Tap the right <kbd>⌥</kbd> key for slide mode, then use plain arrow keys. Or hold <kbd>⌥</kbd> and
scroll, swipe on the trackpad, scroll over the menu bar, or drag a window to the top of the screen
to snap it into place. In the command palette (<kbd>⌃⌥/</kbd>) you can type a sentence such as
“Slack and Mail side by side on 3” or “Safari two thirds”, and Monorail does it, on your Mac.

<p align="center"><img src="assets/readme/palette.svg" alt="The command palette with results for pair saf" width="100%"></p>

### Workspaces and displays.

Each display has four workspaces (up to nine), each with its own name and colour. Give an app a
home workspace, keep work and home apart with profiles, and save a whole setup as a layout or a
snapshot that survives a restart. Unplug a display and its slides wait for it; plug it back in and
they return as they were.

### Focus, Evening Mode and Stay Awake.

- **Focus mode** (<kbd>⌃⌥B</kbd>) dims everything but the slide you're in, for 25 minutes or as long as you choose.
- **Evening Mode** warms every display at night, with a slider that changes the screen as you drag. Turn it on from the menu bar or on a daily schedule that fades in and out over 20 minutes. Screenshots and recordings keep their normal colours.
- **Stay Awake** keeps your Mac awake for a set time, until a clock time, while an app is open or while something downloads. In the download version, it can also keep a MacBook running with the lid closed. It asks for your password, and stops on its own if the Mac gets hot, in Low Power Mode, or on battery (unless you allow it, and then below 20%).

<p align="center"><img src="assets/readme/focus.svg" alt="Focus mode: the current slide bright, the windows on either side dimmed" width="100%"></p>

### Private when it matters.

When you share your screen in Zoom, Teams, Meet, Webex, Slack or FaceTime, apps and windows you've
marked private step aside, and they're blurred in the overview. You can share a single slide
instead of your whole screen. Deep work hides distracting apps until you're done.

### Works with your tools.

- **Coming from another window manager?** Settings → Basics → **Import Settings…** reads your AeroSpace, yabai and skhd, or Rectangle settings.
- **AI coding agents.** Monorail hears when Claude Code, Codex, Aider or Gemini is waiting for your approval in a terminal, plays a chime and takes you there.
- **Keeper.** Monorail and [Keeper](https://github.com/ashfordeOU/keeper) by Ashforde work together with nothing to set up. Monorail leaves Keeper's Island, widgets and panels where Keeper puts them, they share focus, presentation and Stay Awake, and only one of them keeps your Mac awake at a time. [How they work together](https://monorail.ashforde.org/keeper/).
- **Scripts and automation.** Every action has a `monorail://` link and a `monorail` command, and there's a local API, an MCP server for AI assistants, AppleScript and JavaScript scripts. See [Automation](#automation).

Plus 27 themes, nine languages, Insights into how you work (kept on your Mac), and undo for every layout change with <kbd>⌃⌥Z</kbd>.

<p align="center"><img src="assets/readme/themes.svg" alt="27 themes: classic, seasonal and unique" width="100%"></p>

## Getting started

When Monorail first opens, the welcome tour helps you allow Accessibility and choose a style:
**Simple**, **Power user** or **Coming from another app**.

### Slide mode

Tap the **right ⌥ Option** key on its own. A cheat sheet appears at the bottom of the screen, and
plain keys drive Monorail until you press <kbd>Esc</kbd> or pause for a few seconds.

| Key | What it does |
| --- | --- |
| <kbd>←</kbd> <kbd>→</kbd> | Slide to the previous or next window. |
| <kbd>⇧←</kbd> <kbd>⇧→</kbd> | Move the window along the strip. |
| <kbd>↑</kbd> <kbd>↓</kbd> | Move between windows stacked in a column (add <kbd>⇧</kbd> to reorder). |
| <kbd>R</kbd> | Step through preset widths. |
| <kbd>F</kbd> | Fill the screen. Press again to go back. |
| <kbd>C</kbd> | Centre the window. |
| <kbd>1</kbd>–<kbd>9</kbd> | Jump to a column. |
| <kbd>-</kbd> <kbd>=</kbd> | Narrower or wider. |
| <kbd>G</kbd> · <kbd>O</kbd> · <kbd>Z</kbd> | Next slide layout · overview · undo. |
| <kbd>T</kbd> <kbd>W</kbd> <kbd>P</kbd> <kbd>D</kbd> | Float, tabs, pin, send to the next display. |
| <kbd>Esc</kbd> <kbd>Return</kbd> | Done. Any other key ends slide mode and goes to your app. |

You can use right ⌘, ⌃ or ⇧ instead in Settings → Motion & Input. Holding the key as a normal
modifier never turns slide mode on; only a tap does.

### The menu bar

Click the Monorail icon for the slider, with every slide as a card. Right-click it for the full
menu: Saved Layouts, Snapshots, App Pairs, Evening Mode, Stay Awake, Undo History and more.
**Rescue Windows** brings every window back on screen if anything ever goes astray.

### When things don't tile

Dialogs, file pickers and fixed-size windows float on purpose. Press <kbd>⌃⌥T</kbd> to tile one
anyway, or add a rule for the app in Settings → Apps.

## Keyboard shortcuts

All shortcuts start with <kbd>⌃⌥</kbd>. In Settings → Shortcuts you can change the prefix to
<kbd>⌥</kbd>, <kbd>⌘⌥</kbd> or <kbd>⌃⌘</kbd>, rebind any action and give an action more than one
key. Shortcuts follow the physical key, so they stay put with AZERTY, QWERTZ, Dvorak and other
layouts. Hold <kbd>⌃⌥</kbd> for a moment to see them all.

| Action | Shortcut |
| --- | --- |
| Focus left / right | <kbd>⌃⌥H</kbd> <kbd>⌃⌥L</kbd> · <kbd>⌃⌥←</kbd> <kbd>⌃⌥→</kbd> |
| Focus up / down in a stack | <kbd>⌃⌥K</kbd> <kbd>⌃⌥J</kbd> · <kbd>⌃⌥↑</kbd> <kbd>⌃⌥↓</kbd> |
| Move window left / right | <kbd>⌃⌥⇧H</kbd> <kbd>⌃⌥⇧L</kbd> · <kbd>⌃⌥⇧←</kbd> <kbd>⌃⌥⇧→</kbd> |
| Overview | <kbd>⌃⌥O</kbd> · <kbd>⌃⌥Tab</kbd> |
| Command palette | <kbd>⌃⌥/</kbd> |
| Search windows | <kbd>⌃⌥Space</kbd> |
| Window hints | <kbd>⌃⌥V</kbd> then a letter |
| Go to workspace 1–9 | <kbd>⌃⌥1</kbd> … <kbd>⌃⌥9</kbd> |
| Move window to workspace 1–9 | <kbd>⌃⌥⇧1</kbd> … <kbd>⌃⌥⇧9</kbd> |
| Next / previous workspace | <kbd>⌃⌥PageDown</kbd> <kbd>⌃⌥PageUp</kbd> |
| Send window to the next display | <kbd>⌃⌥D</kbd> · <kbd>⌃⌥N</kbd> |
| Cycle width | <kbd>⌃⌥R</kbd> (<kbd>⌃⌥⇧R</kbd> backwards) |
| Narrower / wider | <kbd>⌃⌥-</kbd> <kbd>⌃⌥=</kbd> |
| Full width | <kbd>⌃⌥F</kbd> |
| Centre | <kbd>⌃⌥C</kbd> |
| Next slide layout | <kbd>⌃⌥G</kbd> |
| Reset to smart pairs | <kbd>⌃⌥A</kbd> |
| Stack into the column left / right | <kbd>⌃⌥[</kbd> <kbd>⌃⌥]</kbd> |
| Float or tile | <kbd>⌃⌥T</kbd> |
| Radial menu | <kbd>⌃⌥E</kbd> |
| Snap to a half | <kbd>⌃⌥⌘←</kbd> <kbd>⌃⌥⌘→</kbd> <kbd>⌃⌥⌘↑</kbd> <kbd>⌃⌥⌘↓</kbd> |
| Maximise · restore | <kbd>⌃⌥⌘↩</kbd> · <kbd>⌃⌥⌘⌫</kbd> |
| Save a view · go to it | <kbd>⌃⌥⌘⇧1</kbd>…<kbd>9</kbd> · <kbd>⌃⌥⌘1</kbd>…<kbd>9</kbd> |
| Back · forward through views | <kbd>⌃⌥⌘[</kbd> · <kbd>⌃⌥⌘]</kbd> |
| Focus mode | <kbd>⌃⌥B</kbd> |
| Scratchpad | <kbd>⌃⌥`</kbd> |
| Take a snapshot | <kbd>⌃⌥⇧S</kbd> |
| Undo · redo | <kbd>⌃⌥Z</kbd> · <kbd>⌃⌥Y</kbd> |
| Retile everything | <kbd>⌃⌥Esc</kbd> |
| Pause or resume | <kbd>⌃⌥Q</kbd> |

That's a selection. All 270 actions, and which have a key out of the box, are in
[docs/ACTIONS.md](docs/ACTIONS.md), generated from the source. **Keyboard Shortcuts** in the menu
bar lists every shortcut, and choosing one runs it.

## Settings

Settings opens on the essentials: **Basics**, **Shortcuts**, **Appearance**, **Evening Mode**,
**Stay Awake** and **About**. Turn on **Show all settings** at the bottom of the sidebar for the
rest: General, Layout, Motion & Input, Apps, Smart, Automation, Devices & Sharing and Insights.
Search at the top always finds every setting, wherever it is. Changes apply immediately.

[Every setting, with its default](docs/SETTINGS.md) is listed in docs/SETTINGS.md, generated from
the source. Settings are saved in `~/Library/Application Support/Monorail/settings.json`, which you
can also edit by hand. Organisations can manage any setting with a configuration profile.

## Automation

Every action has a `monorail://` link (older `macslider://` links still work):

```bash
open -g monorail://focus-right
```

Some take a name or a number:

| Link | Does |
| --- | --- |
| `monorail://layout/Coding` | Apply a saved layout |
| `monorail://pair/Safari + Notes` | Open an app pair |
| `monorail://snapshot/Friday` · `monorail://save-snapshot/Friday` | Restore or take a snapshot |
| `monorail://template/Coding` | Start a workspace template |
| `monorail://profile/Work` · `monorail://workspace/2` | Switch profile or workspace |
| `monorail://focus-mode/on` · `monorail://presentation-mode/off` | Focus or presentation mode on or off |
| `monorail://focus-app/Safari` | Go to an app's window, or open the app |
| `monorail://awake` · `awake/60` · `awake/off` · `awake/downloading` | Stay Awake: toggle, minutes, off, while downloading |
| `monorail://notify/Hello` | Show a notice |

Use them from Shortcuts (**Open URLs**), Raycast, Alfred, Keyboard Maestro or Stream Deck.

**Command line.** The app includes a `monorail` tool. Link it onto your `PATH`:

```bash
sudo ln -sf /Applications/Monorail.app/Contents/Resources/monorail /usr/local/bin/monorail
monorail focus-left
monorail layout Coding
monorail subscribe    # live events, one JSON object per line
```

`monorail --help` shows the usage. With the local API on, `monorail windows`, `state` and
`actions` print JSON.

**Local API and MCP.** Turn on **Local API** in Settings → Automation. It listens only on this Mac
(`http://127.0.0.1:4767`), and every request needs the token in
`~/Library/Application Support/Monorail/api-token`. Click **Copy MCP Server Config** to add
Monorail to Claude Desktop or any MCP client, then ask things like “put my editor and browser side
by side”. Monorail asks you before an assistant closes a window.

```bash
curl -H "Authorization: Bearer $(cat ~/Library/Application\ Support/Monorail/api-token)" http://127.0.0.1:4767/windows
```

**AppleScript and JavaScript.** `tell application "Monorail" to perform "focus-left"` works, and
with **Scripts** on in Settings → Automation, `.js` files in the Scripts folder can react to
events and add their own commands to the palette:

```js
monorail.on("windowOpened", w => {
  if (w.app === "zoom.us") monorail.moveToWorkspace(w.id, 3)
})
monorail.addCommand("IDE layout", () => monorail.setWidths([0.6, 0.2, 0.2]))
```

Ready-made companions: [Raycast](extensions/raycast), [Alfred](extensions/alfred),
[Stream Deck](extensions/streamdeck), [a browser companion](extensions/browser),
[VS Code and Cursor](extensions/vscode) and [SketchyBar](extensions/sketchybar).

## Privacy

Monorail needs one permission, **Accessibility**, to move other apps' windows. You can revoke it
any time in System Settings → Privacy & Security → Accessibility. macOS asks for the others only
when you turn on a feature that needs one:

| Permission | Only for |
| --- | --- |
| Screen Recording | Live previews, sharing one slide, mirrors, the demo zoom, finding a window by its contents |
| Calendars | Opening video calls before they start; *Focus* events starting deep work |
| Microphone and Speech Recognition | Voice commands, recognised on your Mac where supported |
| Camera | The camera tile, and head focus if you turn it on |
| Local Network | The phone remote and layout sync with a nearby Mac |

Window pictures and text are read on your Mac and never stored or sent. Monorail has no account,
and makes only these network requests:

- a daily check for a new version, and the download when you accept one
- the list of known app quirks
- **anonymous usage counts**, once a day

The usage counts hold a random install ID (not tied to you, your Apple ID or your Mac), the
Monorail and macOS versions, the Mac model, chip and core count, a memory range, the number of
displays, the system language, how Monorail was installed and which features are on. They never
contain window titles, app names, file names, anything you type or say, or anything from your
screen, and the server doesn't store IP addresses. **What's sent…** in the app shows exactly what
goes. Turn them off with **Share anonymous usage counts** in Settings → Basics, or with
`defaults write org.ashforde.monorail MonorailNoUsageCounts -bool YES`.

Everything else, such as webhooks, the phone remote, layout sync and iCloud sync, happens only if
you turn it on. If you add your own Anthropic API key in Settings → Smart → Assistant, sentences
Monorail doesn't understand go to Claude, and you confirm each command before it runs. The full
policy: [monorail.ashforde.org/privacy](https://monorail.ashforde.org/privacy/).

## Troubleshooting

- **Shortcuts do nothing.** Check that Monorail is on in System Settings → Privacy & Security → Accessibility, then click **Check again** in Settings → General → Mac setup.
- **Windows jumped after a display change.** Press <kbd>⌃⌥Esc</kbd> to retile.
- **A sliver of another window shows at the screen edge.** Some apps won't move almost off screen. Turn on **Whole slides only** and **Hide off-screen slides in the corner** in Settings → Smart.
- **Something misbehaves after a settings change.** Hold <kbd>⌥</kbd> while opening Monorail for safe mode: rules, scripts and automations stay off until the next launch. **Show Log** in Settings → About shows what happened.
- **Everything's in a mess.** Pause with <kbd>⌃⌥Q</kbd>. Every window comes back on screen.

## FAQ

**Does Monorail replace Spaces or Mission Control?**
No. It works alongside them. Each Space keeps its own strip, and full-screen apps are left alone.

**Will it fight with my other window tools?**
Turn off other window managers (Rectangle, Magnet and the like) and Stage Manager. Settings → General → Mac setup checks for these.

**What happens to my windows if I quit?**
Every window is put back fully on screen. When Monorail starts again, it restores your layout.

**Does it use AI in the cloud?**
Not unless you ask it to. Sentences, predictions and suggestions run on your Mac, with no account and no network. The optional Assistant sends only the sentence, the names of open apps and Monorail's command list to Claude.

**Is it free?**
Yes, with no trial or subscription. You can read, build, change and use the source for anything except a competing product or service. Each release becomes Apache 2.0 two years after it ships. See [docs/LICENSING.md](docs/LICENSING.md).

## Build from source

You need Xcode 15 or later (or the matching Swift toolchain) on macOS 13 or later.

```bash
git clone https://github.com/ashfordeOU/monorail.git
cd monorail
make test      # run the unit tests
make app       # build dist/Monorail.app (universal, ad-hoc signed)
make package   # also build the .zip, .dmg and SHA256SUMS
make run       # build and open the app
```

Local builds are signed ad hoc unless you set `SIGN_IDENTITY` to a code-signing identity before
running `scripts/build-app.sh`. After installing an ad-hoc build, switch Monorail off and on in
Privacy & Security → Accessibility. Release signing and notarisation are described in
[docs/NOTARISATION.md](docs/NOTARISATION.md); the real-Mac test checklist is in
[docs/TESTING.md](docs/TESTING.md).

The layout model (`Sources/MonorailCore`) is plain Swift with no AppKit, so it's unit-tested on
macOS and Linux. The app (`Sources/Monorail`) applies it to real windows through the Accessibility
API, and reacts to macOS notifications instead of polling. Measure its energy use on your own Mac
with `scripts/measure-performance.sh`.

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Monorail by Ashforde®. Copyright © 2026 Ashforde OÜ. Ashforde® is a registered trademark of
Ashforde OÜ.

From version 1.6.0, Monorail is licensed under the [Functional Source License (FSL-1.1-ALv2)](LICENSE).
You may use, copy, modify and redistribute it for any purpose **other than a competing use**:
selling it, or offering it or a derivative as a product or service that competes with Monorail.
Two years after each version is released, that version is also available under the Apache
License 2.0. Versions up to 1.5.2 remain available under the GNU AGPL v3.0 they were released
with. Details: [docs/LICENSING.md](docs/LICENSING.md).

The names “Monorail by Ashforde” and “Ashforde®”, and the Monorail icon, are trademarks of
Ashforde OÜ and are not licensed for use by forks or redistributions. See [TRADEMARKS.md](TRADEMARKS.md).
