# Golden tests

Each file is a list of cases: a starting state, a series of operations, and the expected result.
Every Monorail implementation (Swift on Mac and Windows, TypeScript on Linux) must reproduce these
exactly. Rectangles are `[x, y, width, height]` in unit coordinates; compare with a tolerance of 1e-6.

| File | Covers | Spec |
|---|---|---|
| `dock-zones.json` | Which zone a pointer over a window chooses | `spec/docking.md` |
| `split-tree.json` | Docking, tabs, removing, resizing and evening out nested slides | `spec/docking.md` |
| `sentences.json` | What typed sentences mean (workspaces counted from 1) | the command palette |
| `import-aerospace.toml` + `.expect.json` | Importing an AeroSpace setup: gaps, floating apps, workspace rules, shortcuts (key codes are macOS virtual key codes) | settings import |

Operations in `split-tree.json`:

- `{"dock": [window, onto, edge]}` with edge `left`, `right`, `top`, `bottom` or `center`
- `{"remove": window}`
- `{"activate": window}` (bring a tab to the front)
- `{"resize": [window, [x, y, w, h]]}` (the window's new unit frame after dragging an edge)
- `{"adjust": [window, axis, delta]}` with axis `horizontal` or `vertical`
- `{"balance": true}`

The expected `tiles` list every window in reading order with its frame and whether it is a hidden tab.
