# Monorail for Windows

The Windows version (docs/PLATFORMS.md, Phase 1) will live here: the shared Swift engine on Win32
with a WinUI 3 interface. So far:

- `Monorail.Shared/`: action names and titles, setting keys and defaults, generated from `spec/`
  by `scripts/gen-defs.py` (don't edit `Generated/` by hand). CI builds it on Windows.
- `MonorailWindows` (the Swift package's Windows executable, alpha): the shared engine on the
  Win32 backend, with a tray icon and shortcuts.

## The portable build: no installer, no admin

For PCs where you can't install anything or aren't an administrator (IT-managed work PCs): unzip
and run, like Caffeine. CI builds it on every push (`.github/workflows/platforms.yml`, job
"Portable package (Windows)"):

1. Open the latest **Platforms** run on the repository's Actions tab and download the
   `Monorail-Windows-portable` artifact (kept for 30 days; GitHub wraps it in a zip of its own, so
   unzip that to get `Monorail-Windows-portable.zip`).
2. Unzip `Monorail-Windows-portable.zip` anywhere, such as Downloads, and double-click
   `Monorail.exe`. Keep the DLLs next to it: they're the Swift and Visual C++ runtimes.
3. SmartScreen may warn, because the beta isn't code-signed yet: **More info**, then **Run anyway**.

The zip holds `Monorail.exe` (the release build of `MonorailWindows`), every DLL it loads that
Windows doesn't have (found by `dumpbin /dependents`, file by file, in `windows/portable/package.ps1`),
`README.txt` (`windows/portable/README.txt`) and `LICENSE.txt`. CI proves it's portable: it runs
the unzipped `Monorail.exe --self-check` and `--ci-test` with only `C:\Windows\System32` and
`C:\Windows` on PATH from a folder nobody can write to, checks a copy without `swiftCore.dll`
fails (so the toolchain really is out of reach), and runs the self-check again with a standard
user's token (`runas /trustlevel:0x20000`). Settings stay in `%APPDATA%\Monorail`; nothing is
written next to the exe or to the registry. Apps running as administrator can't be moved by a
standard user's Monorail (Windows doesn't allow it), so they're left where they are.

## Stay Awake (like Caffeine)

The tray menu's **Stay Awake** keeps the PC and its display awake: **Off**, **For 1 Hour** or
**Until Turned Off** (`SetThreadExecutionState`, which any user may call). **Keep Chat Apps Showing
Me as Available** (on by default) presses F15, a key no app uses, whenever the PC has been idle
for 50 seconds, so Teams and Slack don't mark you away; it works without administrator rights.
The choice is kept in `settings.json` under `"stayAwake"` (`on`, `until` in seconds since 1970,
`keepChatAvailable`), so it carries on after a restart. The timing is `AwakeNudge` in
MonorailCore and the file handling `StayAwakeSettings` in MonorailEngine, both tested on every
platform; the self-check and UI test turn it on and off on Windows.

## Trying the alpha (developers)

Build on Windows with Swift 6.1: `swift build --product MonorailWindows`, then run
`.build\debug\MonorailWindows.exe`. It tiles your windows on a scrolling strip per display.

- **Shortcuts:** Win+Alt (or Ctrl+Win+Alt, when Windows keeps Win+Alt for itself) with
  Left/Right/Up/Down to focus, Home/End for the first and last, Shift+arrows to move, W to cycle
  widths (Shift+W back), F for full width, comma to stack into the left slide, full stop to unstack.
  The ones in use are printed at start.
- **Tray icon:** pause and resume, Stay Awake, open or reload the settings file, quit.
- **Settings:** `%APPDATA%\Monorail\settings.json`, the same format as the Mac app's (a file copied
  from a Mac works). Edits apply as soon as you save. Gaps, widths and app rules set to float
  are used so far; a rule's app can be written as `notepad.exe`.
- `MonorailWindows --ci-test` is what CI runs on GitHub's Windows machines: it opens Notepad
  windows and checks tiling, shortcuts, settings, pause, Stay Awake and the tray.
- `MonorailWindows --self-check` starts far enough to prove this copy runs here (every DLL loads,
  displays, per-user settings, Stay Awake), moves nothing and exits 0.
