// The generated definitions say exactly what spec/ says.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { ACTIONS } from '../src/generated/actions.ts';
import { DEFAULTS, SETTING_KEYS } from '../src/generated/settings.ts';

const spec = (name: string) => JSON.parse(readFileSync(fileURLToPath(new URL(`../../spec/${name}`, import.meta.url)), 'utf8'));

test('actions match spec/actions.json', () => {
  assert.deepEqual(ACTIONS.map((a) => ({ ...a })), spec('actions.json').actions);
});

test('setting keys match spec/settings.json, and plain defaults come through', () => {
  const settings = spec('settings.json').settings as { key: string; type: string; default: string }[];
  assert.deepEqual([...SETTING_KEYS], settings.map((s) => s.key));
  const animate = settings.find((s) => s.key === 'animate')!;
  assert.equal(DEFAULTS.animate, animate.default === 'true');
  for (const [key, value] of Object.entries(DEFAULTS)) {
    const s = settings.find((x) => x.key === key)!;
    if (s.type === 'Bool') assert.equal(value, s.default === 'true', key);
    if (s.type === 'Double' || s.type === 'Int') assert.equal(value, Number(s.default), key);
  }
});
