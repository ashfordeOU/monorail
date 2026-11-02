# core-ts

Monorail's core in TypeScript, for the GNOME Shell extension and the KDE (KWin) script
(docs/PLATFORMS.md). It's a port of `Sources/MonorailCore`, and the same golden tests
(`tests/golden`) prove the two behave identically.

So far: split trees and dock zones (`src/split-tree.ts`). The strip and the sentence parser follow.

```bash
cd core-ts && npm test
```

Node 22.6 or later, no dependencies: the tests run the TypeScript directly
(`--experimental-strip-types`), so only type syntax that can be erased is used (no enums or
namespaces).
