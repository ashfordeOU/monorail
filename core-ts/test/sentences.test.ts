// tests/golden/sentences.json against the TypeScript sentence parser (compared as JSON).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/sentences.ts';

const file = JSON.parse(readFileSync(fileURLToPath(new URL('../../tests/golden/sentences.json', import.meta.url)), 'utf8'));

for (const c of file.cases) {
  test(`sentences: ${c.text}`, () => {
    assert.deepEqual(parse(c.text, file.apps), c.expect ?? null);
  });
}
