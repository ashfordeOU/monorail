# Feature parity

Which features exist on which platform. **Shared** features behave the same everywhere (see the rest
of `spec/`). **Adapted** features do the same job in each platform's own way. **OS-only** features
exist where the platform allows them.

Status: ✅ shipped · 🧪 beta · 🗓 planned · — not applicable

## The strip

| Feature | Kind | Mac | Windows | Linux (GNOME) | Linux (KDE) |
|---|---|:---:|:---:|:---:|:---:|
| Strip of slides that runs past the screen | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Slide arrangements (side by side, grid, main + side…) | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Nested slides, docking, tab groups | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Drag the gap to resize both | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Widths, full width, centring, fit mode | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Workspaces (up to 9 per display) | Adapted: virtual desktops / GNOME workspaces / KDE desktops | ✅ | 🗓 | 🗓 | 🗓 |
| Every display its own strip; display memory | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Saved views, back and forward | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Tags and combined workspaces | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Undo and redo | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Snapshots and saved layouts | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Snapshots save browser tabs | OS-only (needs app scripting) | ✅ | 🗓 (Edge/Chrome via DevTools protocol) | — | — |

## Getting around

| Feature | Kind | Mac | Windows | Linux (GNOME) | Linux (KDE) |
|---|---|:---:|:---:|:---:|:---:|
| Keyboard shortcuts | Adapted: ⌃⌥ on Mac, Win-based on Windows, Super-based on Linux | ✅ | 🗓 | 🗓 | 🗓 |
| A held "Monorail key" (e.g. Caps Lock) | Adapted | ✅ | 🗓 | 🗓 | 🗓 |
| Overview of every workspace | Shared (with live previews where the OS allows) | ✅ | 🗓 | 🗓 | 🗓 |
| Slider bar | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Command palette with plain-language sentences | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Trackpad and mouse gestures | Adapted: precision touchpad / libinput gestures | ✅ | 🗓 | 🗓 | 🗓 |
| Slide mode, Vim mode, window hints | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Voice commands | Adapted: on-device speech per OS | ✅ | 🗓 | 🗓 | 🗓 |

## Fitting in

| Feature | Kind | Mac | Windows | Linux (GNOME) | Linux (KDE) |
|---|---|:---:|:---:|:---:|:---:|
| Menu bar icon / tray icon / panel indicator | Adapted | ✅ | 🗓 | 🗓 | 🗓 |
| Settings window in the platform's design | Adapted: SwiftUI / WinUI 3 / libadwaita / Kirigami | ✅ | 🗓 | 🗓 | 🗓 |
| Works with the OS's own snapping | Adapted: Stage Manager check / Snap Layouts / GNOME and Ubuntu tiling | ✅ | 🗓 | 🗓 | 🗓 |
| Full-screen apps left alone | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Slider bar steps aside for video | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Stay Awake | Adapted: IOKit / power requests / inhibit portal | ✅ | 🗓 | 🗓 | 🗓 |
| Sidecar iPads | OS-only | ✅ | — | — | — |
| Screen reader support | Adapted: VoiceOver / Narrator / Orca | ✅ | 🗓 | 🗓 | 🗓 |
| Themes | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Nine languages | Shared | ✅ | 🗓 | 🗓 | 🗓 |

## Smart features

| Feature | Kind | Mac | Windows | Linux (GNOME) | Linux (KDE) |
|---|---|:---:|:---:|:---:|:---:|
| AI agent alerts (terminal AI coding assistants) | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Safe screen sharing (private windows step aside) | Adapted | ✅ | 🗓 | 🗓 | 🗓 |
| Focus mode, deep work, pomodoro | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Rule and float suggestions | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Optional Claude assistant (your own key) | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Insights and usage stats | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Calendar-aware meeting layouts | Adapted: EventKit / Windows calendar / Evolution data server | ✅ | 🗓 | 🗓 | 🗓 |

## Automation and setup

| Feature | Kind | Mac | Windows | Linux (GNOME) | Linux (KDE) |
|---|---|:---:|:---:|:---:|:---:|
| `monorail://` links | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Command-line tool and live event stream | Adapted: Unix socket / named pipe / D-Bus | ✅ | 🗓 | 🗓 | 🗓 |
| Local API and MCP server | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Scripts (JavaScript) | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| AppleScript | OS-only, counterparts: PowerShell module (Windows), D-Bus (Linux) | ✅ | 🗓 | 🗓 | 🗓 |
| Raycast and Alfred extensions | OS-only, counterpart: PowerToys Run / Command Palette plugin | ✅ | 🗓 | — | — |
| Share links for layouts | Shared | ✅ | 🗓 | 🗓 | 🗓 |
| Import settings from other window managers | Adapted: AeroSpace, yabai, Rectangle / GlazeWM, Komorebi, FancyZones / PaperWM, Pop Shell | ✅ | 🗓 | 🗓 | 🗓 |
| Settings sync between your machines | Shared (settings file); shortcuts stay per OS | ✅ | 🗓 | 🗓 | 🗓 |
| Self-updating | Adapted: built-in / winget + built-in / store and package managers | ✅ | 🗓 | 🗓 | 🗓 |
| Anonymous usage counts (opt-out) | Shared | ✅ | 🗓 | 🗓 | 🗓 |
