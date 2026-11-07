# Monorail for GNOME (beta)

Monorail's scrolling tiling as a GNOME Shell extension, for GNOME 45 and later (tested on GNOME 46,
Ubuntu 24.04). It's a beta: it does the core of what Monorail does, and not much more yet.

- New windows open as columns side by side in a strip, at the full height of the screen (less the
  top bar), half the screen wide by default, with 8-pixel gaps: the same rules as the Mac and
  Windows versions (`spec/strip.md`).
- The strip scrolls just far enough to show the focused window whole. Windows scrolled off screen
  wait just past the edge, hidden, until you come back to them.
- Closing a window closes the gap.
- Each workspace has its own strip, on each monitor.
- Dialogs, windows that can't be resized and windows kept out of the taskbar are left floating.
- Turning it off (or locking the screen) puts every window back on screen; turning it on again
  puts them back in the same order and widths.

The decisions (order, focus, widths, scrolling, frames) are made by Monorail's shared core
(`core-ts`, checked against the same golden tests as the Mac app), built into the extension.

## Shortcuts

| Shortcut | Action |
|---|---|
| Super+Alt+Left / Right | Focus the column on the left / right |
| Super+Alt+Home / End | Focus the first / last column |
| Super+Alt+Shift+Left / Right | Move the column left / right |
| Super+Alt+W (Shift for backwards) | Cycle the column's width: ¼, ⅓, ½, ⅔, ¾ |
| Super+Alt+F | Full width, and back |

GNOME itself uses Super+Alt+Left/Right to switch workspace and Super+Shift+Alt+Left/Right to move a
window to another workspace. While Monorail is on it takes over just those keys (GNOME still has
Super+Page Up/Down and Ctrl+Alt+arrows for them) and gives them back exactly as they were when it's
turned off. To leave GNOME's keys alone:

```bash
gsettings --schemadir ~/.local/share/gnome-shell/extensions/monorail@ashforde.org/schemas \
  set org.gnome.shell.extensions.monorail take-over-gnome-shortcuts false
```

The shortcuts, gaps and default width are settings in the same schema
(`org.gnome.shell.extensions.monorail`); there's no preferences window yet.

## Install

Download `monorail@ashforde.org.shell-extension.zip` (from the latest run of the Platforms workflow,
artefact "monorail-gnome-extension"), or build it (below), then:

```bash
gnome-extensions install monorail@ashforde.org.shell-extension.zip
```

Log out and back in (on Wayland GNOME Shell only finds new extensions when it starts; on X11,
Alt+F2 then `r` is enough), then turn it on:

```bash
gnome-extensions enable monorail@ashforde.org
```

or in the Extensions app. To remove it: `gnome-extensions uninstall monorail@ashforde.org`.

Turn off other tiling extensions first (Ubuntu's own tiling, Pop Shell, PaperWM,
Forge): they would fight over the same windows.

## Build

Needs Node 22.13 or later, `glib-compile-schemas` and `zip`:

```bash
linux/gnome/build.sh      # → linux/gnome/dist/monorail@ashforde.org.shell-extension.zip
```

`tools/core-to-js.mjs` turns the shared core's TypeScript into plain JavaScript modules for GJS
(Node's own type stripping, no dependencies) and puts them in the extension's `core/` folder.

## Tests

`test/run-ci.sh` (after `build.sh`) installs the zip for a throwaway home folder, starts a real GNOME
Shell headless (Wayland, one 1280×800 virtual monitor, Xwayland for X11 apps) on its own D-Bus
session with `MONORAIL_TEST=1`, and runs `test/run-tests.js`: it opens real GTK 4 windows
(`test/window.js`), presses the real shortcuts through a virtual keyboard, and reads every window's
frame from inside the shell through a test-only D-Bus interface (`org.ashforde.Monorail.Test`,
only there when `MONORAIL_TEST=1`). Expected frames are worked out from the work area and the
spec's rules, not from the core. It checks, among others, that windows tile side by side without
overlap at full work-area height, focus moves and scrolls, columns move, widths cycle, closing a
window closes the gap, dialogs and fixed-size and skip-taskbar windows float, workspaces keep their
own strips, X11 windows tile too, GNOME's shortcuts are given back, and turning the extension off
and on keeps the strip. Any error from the extension in GNOME Shell's log fails it too.

It needs `gnome-shell`, `xwayland`, `gjs` with `gir1.2-gtk-4.0`, `dbus` and a world-writable
`/tmp/.X11-unix`. GitHub runs it on Ubuntu 24.04 for every push (`.github/workflows/platforms.yml`,
job "GNOME extension"), and keeps the report, GNOME Shell's log and the zip as artefacts.

Locally, `MONORAIL_CHECK_TIMEOUT=3000 MONORAIL_FAIL_FAST=1 linux/gnome/test/run-ci.sh /tmp/out`
gives quicker answers while trying things out.

## Not yet

Slides with several windows, docking, saved views, animations, a preferences window, a panel
indicator, touchpad gestures, several monitors tested on real hardware, and extensions.gnome.org.
