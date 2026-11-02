# Monorail on Windows and Linux

Monorail is a Mac app today. This is the plan for Windows and Linux versions that feel made for
each system, built and maintained together with the Mac app so the three stay aligned.

## Principles

1. **Same Monorail everywhere:** the strip, slides, docking, saved views, actions, settings and the
   layout and share-link formats behave the same on every OS.
2. **Native on each OS:** shortcuts, look, integration with the system's own desktops and snapping,
   energy use, accessibility and installers follow each platform's conventions.
3. **One source of truth:** behaviour is written down once (`spec/`), shared definitions are
   generated for each language, and the same golden tests run on every implementation.
4. **Nothing ships untested:** Windows and Linux stay on the beta channel until people have used them
   on real machines.

## Decisions (defaults until changed)

| Question | Decision |
|---|---|
| Order | Windows first, then Linux (GNOME), then KDE |
| Windows technology | Swift engine (shares MonorailCore) + C# WinUI 3 interface talking to it over the local API |
| Linux technology | GNOME Shell extension and KWin script sharing a TypeScript port of the core, plus a GTK 4 companion app over D-Bus |
| Releases | Every two weeks, all platforms together; urgent fixes per platform any time |
| Price | Free on every platform, every feature |
| Licence and brand | FSL-1.1-ALv2 and TRADEMARKS.md, unchanged |

## Architecture

```
spec/                      written behaviour + shared definitions (settings, actions, formats, events)
MonorailCore (Swift)       strip, splits, rules, keymap, sentence parser, import, file formats
MonorailEngine (Swift)     the platform-free half of today's Engine: placement, history, views, tags, docking
WindowSystem protocol      list windows, frames, focus, batched move/resize, events, displays, desktops
  ├─ macOS backend         from today's Engine (Accessibility API)
  └─ Windows backend       Win32 + DWM (SetWinEventHook, DeferWindowPos, DWM thumbnails)
Interfaces                 SwiftUI (Mac) · WinUI 3 over the local API (Windows) · GTK + extension (Linux)
core-ts (TypeScript)       for GNOME and KDE, checked against the same golden tests
```

## Per-OS fit

**Windows:** Win-key shortcuts that avoid the system's own (Win+Ctrl+arrows, Win+arrows); Fluent design
with Mica, accent colour and dark mode; tray icon; workspaces as virtual desktops; replace or coexist
with Snap Layouts; batched moves with DWM thumbnails for animation; per-monitor DPI; EcoQoS when idle;
ARM64 builds; Stay Awake through the power API; Narrator through UI Automation; full-screen games and
elevated windows left alone; recovery when Explorer restarts. Installs: signed MSIX/EXE, winget,
Scoop, Microsoft Store, MSI for Intune.

**Linux:** Super-key shortcuts that avoid GNOME's and KDE's own; libadwaita on GNOME and Breeze on
KDE; workspaces as GNOME's dynamic workspaces or KDE's virtual desktops; alongside the Activities
overview; conflict checks for the tiling extensions GNOME and Ubuntu ship; frame-accurate moves
inside the compositor; Stay Awake through the inhibit portal; Orca through AT-SPI; D-Bus commands;
settings as a text file. Installs: extensions.gnome.org, KDE Store, Flathub, AUR, Nix, .deb and .rpm.

**Mac-only features** (Sidecar, Stage Manager checks, AppleScript) get native counterparts where they
make sense (PowerShell, PowerToys Run plugins, D-Bus) and are marked OS-only in the parity table.

## Keeping the platforms aligned

- **Spec first:** every feature change starts with a short update to `spec/`.
- **Generated definitions:** action names, settings keys and defaults, keymap names, file formats and
  events are defined once in `spec/` and generated as Swift, C# and TypeScript. CI fails if they are
  out of date.
- **Golden tests:** `tests/golden/*.json` hold inputs and expected results (strip moves, docking,
  splits, the sentence parser, settings import). Every implementation runs them.
- **Parity table:** `spec/parity.md` marks each feature shared, adapted or OS-only, with its status
  per OS, and is shown on the website. "Done" means done on every OS the table says.
- **One repository, one CI:** core tests on macOS, Windows and Linux; golden tests in each language;
  every platform built and self-tested on each change; weekly real-machine UI and energy tests on
  self-hosted runners.
- **One release:** shared version numbers, one changelog with per-OS markers, one workflow that
  builds, signs, publishes and updates every package channel. Beta first on every OS.
- **Upkeep:** test against each OS's betas before it ships (GNOME every six months); one feedback form
  with an OS field; usage counts by OS; docs and the website generated per OS (⌃⌥ on Mac, Win keys on
  Windows); scheduled toolchain updates.

## Phases

| Phase | Scope | Estimate |
|---|---|---|
| 0. Groundwork | Spec, shared definitions, golden tests, three-OS CI, engine split, WindowSystem protocol | 3–4 weeks |
| 1. Windows alpha | Win32 backend: strip, slides, workspaces, shortcuts, tray, basic settings, signed installer, winget | 8–10 weeks with OS fit |
| 2. Windows beta | Docking, saved views, palette, themes, DPI, virtual desktops, importers (GlazeWM, Komorebi, FancyZones), Store | 6 weeks |
| 3. Linux: GNOME | Extension on core-ts, companion app, extensions.gnome.org | 8–10 weeks with OS fit |
| 4. Linux: KDE | KWin script on core-ts | 3–4 weeks |

## What needs the owner

- Windows code signing (Azure Trusted Signing, about $10 a month) and a Microsoft Store account.
- GNOME Extensions and KDE Store accounts.
- A Windows PC and a Linux machine (or VMs) for testing, ideally as self-hosted CI runners, and a
  1–2 hour test at each alpha.
- Approval before anything leaves beta.

## Phase 0 checklist

The scheduled check-ins work through this list in order and tick items off.

- [x] Write this plan
- [x] `spec/README.md`: how the spec works, and the first behaviour pages (strip, slides, docking, saved views)
- [x] `tests/golden/`: format and the first files (split trees and dock zones), run by the Swift tests
- [x] CI: build and test MonorailCore on Windows (`.github/workflows/platforms.yml`; all 147 tests pass on Windows, after fixing Windows line endings in settings import)
- [x] `spec/actions.json` and `spec/settings.json` generated from the Swift sources, with a CI check
- [x] `spec/parity.md`: every feature marked shared, adapted or OS-only
- [x] More golden files: strip moves, the sentence parser, AeroSpace import
- [x] `WindowSystem` protocol in a new MonorailEngine module, with a fake implementation for tests
- [x] Move platform-free engine logic into MonorailEngine (in small, tested steps; the Mac app keeps working). The rest of today's engine is tied to Accessibility and moves with the backend work below.
  - [x] Step 1: keeping floating windows and dialogs on screen (`OnScreen`), used by the Mac app, with tests
  - [x] Step 2: focus history (`FocusHistory`: back to the last window, quick launch, where focus goes next), with tests
  - [x] Step 3: back and forward through views (`NavigationHistory`), with tests
  - [x] Step 4: windows kept on several workspaces (`WorkspaceTags`), with tests
  - [x] Step 5: saved views, nine per display (`SavedViews`, same saved format), with tests
  - [x] Step 6: where returning windows and reopened apps go back to (`ReturnMemory`), with tests
- [ ] macOS backend implements WindowSystem
  - [x] `AXWindowSystem`: displays, windows, focus, batched moves, minimise, close, and app and display events through Accessibility; checked by the self-test on every build
  - [x] Window events (created, destroyed, moved, focused, minimised, restored, title on request) from Accessibility observers, started and stopped by the self-test
  - [ ] The shared engine drives the Mac through it, behind a setting, before it becomes the default
- [ ] `core-ts/`: TypeScript project skeleton running the golden tests (split trees first)
- [ ] Generators for C# and TypeScript definitions
- [ ] Phase 0 review: report to the owner, decide on Phase 1 start
