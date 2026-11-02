# Monorail for Windows

The Windows version (docs/PLATFORMS.md, Phase 1) will live here: the shared Swift engine on Win32
with a WinUI 3 interface. So far:

- `Monorail.Shared/`: action names and titles, setting keys and defaults, generated from `spec/`
  by `scripts/gen-defs.py` (don't edit `Generated/` by hand). CI builds it on Windows.
