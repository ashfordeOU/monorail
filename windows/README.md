# Monorail for Windows

The Windows version (docs/PLATFORMS.md, Phase 1) will live here: the shared Swift engine on Win32
with a WinUI 3 interface. So far:

- `Monorail.Shared/`: action names and titles, setting keys and defaults, generated from `spec/`
  by `scripts/gen-defs.py` (don't edit `Generated/` by hand). CI builds it on Windows.
- `MonorailWindows` (the Swift package's Windows executable, alpha): the shared engine on the
  Win32 backend, with a tray icon and shortcuts.

## Trying the alpha (developers)

Build on Windows with Swift 6.1: `swift build --product MonorailWindows`, then run
`.build\debug\MonorailWindows.exe`. It tiles your windows on a scrolling strip per display.

- **Shortcuts:** Win+Alt (or Ctrl+Win+Alt, when Windows keeps Win+Alt for itself) with
  Left/Right/Up/Down to focus, Home/End for the first and last, Shift+arrows to move, W to cycle
  widths (Shift+W back), F for full width, comma to stack into the left slide, full stop to unstack.
  The ones in use are printed at start.
- **Tray icon:** pause and resume, open or reload the settings file, quit.
- **Settings:** `%APPDATA%\Monorail\settings.json`, the same format as the Mac app's (a file copied
  from a Mac works). Edits apply as soon as you save. Gaps, widths and app rules set to float
  are used so far; a rule's app can be written as `notepad.exe`.
- `MonorailWindows --ci-test` is what CI runs on GitHub's Windows machines: it opens Notepad
  windows and checks tiling, shortcuts, settings, pause and the tray.
