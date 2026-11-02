# Phase 0 review: groundwork for Windows and Linux

The plan is in [PLATFORMS.md](PLATFORMS.md). Phase 0 had to make three things true before any
Windows or Linux code is written: behaviour is written down once, the same tests prove every
implementation behaves alike, and the window manager's logic doesn't depend on macOS. This page
says what was built, what it proves, what's still open, and what Phase 1 needs from the owner.

## What was built

| Piece | Where | Proven by |
|---|---|---|
| Behaviour, written once | `spec/` (strip, docking, views, parity table) | — |
| Shared definitions | `spec/actions.json` (270 actions), `spec/settings.json` (202 settings), generated from the Swift sources | A Swift test that the spec matches the Swift core exactly (it caught 9 wrong titles) |
| Golden tests | `tests/golden/`: dock zones, split trees, the strip, sentences, settings import | Run by both cores |
| Swift core on Windows | `MonorailCore` and `MonorailEngine` build and pass on Windows | Windows CI on every change |
| The platform-free engine | `MonorailEngine`: `WindowSystem` interface, `SharedEngine`, and six pieces moved out of the Mac app (keeping windows on screen, focus history, back and forward, workspace tags, saved views, where returning windows go) | 38 engine tests against a fake window system; the Mac app uses them and behaves the same |
| The Mac backend | `AXWindowSystem`: displays, windows, focus, batched moves, minimise, close, window events | The self-test on every Mac build; `Monorail --shared-engine` on a real Mac |
| TypeScript core (GNOME, KDE) | `core-ts/`: split trees, dock zones, slide layouts, the strip, the sentence parser | 48 tests including every golden file but settings import, in CI on Linux |
| C# definitions (Windows) | `windows/Monorail.Shared/` | Built in Windows CI, warnings as errors |
| Generators | `scripts/gen-docs.py` (Swift → `spec/`), `scripts/gen-defs.py` (`spec/` → TypeScript and C#) | CI fails if anything is out of date |

Totals: 198 Swift tests (Linux and Windows), 48 TypeScript tests, all passing. CI runs on macOS,
Windows and Linux for every commit, and every commit is signed.

## The real-Mac test so far

`Monorail --shared-engine` (1.7.12 and later) ran the shared engine on the owner's MacBook Pro:

- **First run (1.7.12):** it took over 11 windows on one display, applied layouts in batches and saw
  the owner's drags. It also showed a loop: macOS's own screen notifications made it re-place every
  window about seven times a minute. **Fixed in 1.7.13** (ignore screen changes that change nothing;
  move only windows whose place changed), with tests.
- **Second and third runs (1.7.13):** 10 windows, no loop, clean stop. No window events were printed,
  probably because no windows were touched during the run. **Still to confirm:** focus, open, close
  and minimise events on a real Mac.

## What's open

1. **Real-Mac events** (needs the owner, 2 minutes): click another app, open a window, close it,
   minimise one, while `--shared-engine` runs.
2. **Settings import in TypeScript**: only needed when the Linux companion app imports AeroSpace or
   yabai setups, so it waits for Phase 3.
3. **The shared engine is a core, not the product**: it tiles, follows focus, and handles minimise,
   hidden apps and unplugged displays. Workspaces, slides with several windows, docking by drag,
   shortcuts and the rest are in MonorailCore already, and Phase 1 wires them through it.

## Recommendation

**Start Phase 1 (Windows alpha)** once the real-Mac event check passes. The shared core, its tests,
the definitions and three-platform CI are in place, so Windows work can start from the Win32
backend rather than from rewriting logic.

Phase 1 is 8–10 weeks: a Win32 `WindowSystem` (SetWinEventHook, DeferWindowPos), the strip, slides,
workspaces as virtual desktops, Win-key shortcuts, a tray icon, basic settings, a signed installer
and winget. It stays in beta until it has been used on real PCs.

## What Phase 1 needs from the owner

- **A decision**: go, or wait.
- **A Windows PC or VM** for testing, ideally also as a CI runner, and about an hour at the alpha.
- **Code signing for Windows**: Azure Trusted Signing (about $10 a month) before the first public build.
- Later, for Phase 2: a Microsoft Store account.
