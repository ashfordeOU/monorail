# core-ts

Monorail's core in TypeScript, for the GNOME Shell extension and the KDE (KWin) script
(docs/PLATFORMS.md). It's a port of `Sources/MonorailCore`, and the same golden tests
(`tests/golden`) prove the two behave identically.

So far: split trees and dock zones (`src/split-tree.ts`), slide layouts (`src/arrangement.ts`), the strip (`src/strip.ts`), where its windows go on screen (`src/layout.ts`: widths, gaps, scrolling to reveal the focused slide, parking, frames) and the sentence parser (`src/sentences.ts`, with actions from `spec/actions.json`). Every golden file except settings import passes.

The GNOME extension (`linux/gnome`) runs this core: `linux/gnome/build.sh` turns it into plain JavaScript for GJS.

```bash
cd core-ts && npm test
```

Node 22.6 or later, no dependencies: the tests run the TypeScript directly
(`--experimental-strip-types`), so only type syntax that can be erased is used (no enums or
namespaces).
