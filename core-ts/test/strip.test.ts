// tests/golden/strip.json against the TypeScript strip (slides compared as sets of windows).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Strip } from '../src/strip.ts';

const cases = JSON.parse(readFileSync(fileURLToPath(new URL('../../tests/golden/strip.json', import.meta.url)), 'utf8'));
const sorted = (a: number[]) => [...a].sort((x, y) => x - y);

for (const c of cases) {
  test(`strip: ${c.name}`, () => {
    const strip = new Strip();
    for (const op of c.ops) {
      if (op.insert) strip.insert(op.insert[0], op.insert[1], op.insert[2] ?? 'afterFocused');
      else if (op.focus !== undefined) strip.focus(op.focus);
      else if (op.moveFocus) strip.moveFocus(op.moveFocus);
      else if (op.moveFocused) strip.moveFocused(op.moveFocused);
      else if (op.consumeIntoLeft) strip.consumeIntoLeft();
      else if (op.consumeIntoRight) strip.consumeIntoRight();
      else if (op.expel) strip.expel();
      else if (op.remove !== undefined) strip.remove(op.remove);
      else if (op.dock) strip.dock(op.dock[0], op.dock[1], op.dock[2]);
      else if (op.tearOff !== undefined) strip.tearOff(op.tearOff, 0.5);
      else assert.fail(`${c.name}: unknown operation ${JSON.stringify(op)}`);
    }
    assert.deepEqual(strip.columns.map((col) => sorted(col.windows)), c.expect.slides.map(sorted), `${c.name}: slides`);
    if (c.expect.focused !== undefined) assert.equal(strip.focusedWindow, c.expect.focused, `${c.name}: focused`);
  });
}
