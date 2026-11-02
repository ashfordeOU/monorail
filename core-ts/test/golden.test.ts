// Runs tests/golden (shared by every Monorail implementation) against the TypeScript core.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { rect, type Rect } from '../src/geometry.ts';
import * as tree from '../src/split-tree.ts';

const golden = (name: string) =>
  JSON.parse(readFileSync(fileURLToPath(new URL(`../../tests/golden/${name}`, import.meta.url)), 'utf8'));
const toRect = (a: number[]): Rect => rect(a[0], a[1], a[2], a[3]);
const close = (a: number, b: number, what: string) => assert.ok(Math.abs(a - b) < 1e-6, `${what}: ${a} ≠ ${b}`);

for (const c of golden('dock-zones.json')) {
  test(`dock zones: ${c.name}`, () => {
    const zone = tree.dockZone(c.point[0], c.point[1], toRect(c.frame));
    assert.equal(zone ?? null, c.expect);
  });
}

for (const c of golden('split-tree.json')) {
  test(`split trees: ${c.name}`, () => {
    let t: tree.SplitTree = tree.single(c.start ?? 1);
    for (const op of c.ops) {
      if (op.dock) t = tree.docking(t, op.dock[0], op.dock[1], op.dock[2]);
      else if (op.remove !== undefined) {
        const next = tree.removing(t, op.remove);
        assert.ok(next, `${c.name}: removed the last window`);
        t = next;
      } else if (op.activate !== undefined) t = tree.activating(t, op.activate);
      else if (op.resize) t = tree.resizing(t, op.resize[0], toRect(op.resize[1]));
      else if (op.adjust) t = tree.adjusting(t, op.adjust[0], op.adjust[1], op.adjust[2]);
      else if (op.balance) t = tree.balanced(t);
      else assert.fail(`${c.name}: unknown operation ${JSON.stringify(op)}`);
    }
    const tiles = tree.tiles(t);
    const want = c.expect.tiles as { window: number; frame: number[]; hidden: boolean }[];
    assert.deepEqual(tiles.map((x) => x.window), want.map((w) => w.window), `${c.name}: windows in reading order`);
    tiles.forEach((tile, i) => {
      const f = toRect(want[i].frame);
      close(tile.frame.x, f.x, `${c.name} ${tile.window} x`);
      close(tile.frame.y, f.y, `${c.name} ${tile.window} y`);
      close(tile.frame.width, f.width, `${c.name} ${tile.window} width`);
      close(tile.frame.height, f.height, `${c.name} ${tile.window} height`);
      assert.equal(tile.isHiddenTab, want[i].hidden ?? false, `${c.name}: hidden for ${tile.window}`);
    });
  });
}
