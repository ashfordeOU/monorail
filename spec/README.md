# Monorail specification

This folder describes how Monorail behaves, independent of any operating system. The Mac, Windows
and Linux versions all follow it. When behaviour changes, this folder changes first, in the same
pull request as the code.

| File | What it covers |
|---|---|
| [`strip.md`](strip.md) | The strip, slides, widths, focus and scrolling |
| [`docking.md`](docking.md) | Docking windows onto each other, nested splits, tab groups, resizing |
| [`views.md`](views.md) | Saved views, back and forward |
| `actions.json`, `settings.json` | Every action and setting, generated from the Swift sources (coming next) |
| `parity.md` | Which features are shared, adapted per OS, or OS-only (coming next) |

## Rules

- **Words mean one thing.** A *window* is an app window. A *slide* is one stop on the strip and holds
  one or more windows. The *strip* is the row of slides on one workspace of one display. A
  *workspace* is one strip per display; there are up to nine.
- **Coordinates** are in points with the origin at the top left and y growing downwards. *Unit*
  rectangles are fractions (0…1) of their container.
- **Golden tests** in `tests/golden/` turn the rules here into data: inputs and expected results that
  every implementation must reproduce exactly. A rule without a golden test is a rule in waiting.
- **Platform differences** (shortcuts, look, system integration) are not specified here; they live in
  each platform's own docs and in `parity.md`.
