// Strip geometry (src/layout.ts): widths, reveal, parking and frames, worked out by hand from
// MonorailCore's LayoutConfig and Strip.layout for a 1280 × 800 display with a 32-point top bar.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { rect } from '../src/geometry.ts';
import { Strip } from '../src/strip.ts';
import {
  clampScroll, columnWidth, defaultLayoutConfig, fractionForColumnWidth, layout, revealFocused, roundAway,
  sanitizedPresets, tileFrame, totalWidth,
} from '../src/layout.ts';

const config = defaultLayoutConfig();
const viewport = rect(0, 32, 1280, 768);
const frames = (strip: Strip) => {
  revealFocused(strip, config, viewport.width);
  return Object.fromEntries(layout(strip, config, viewport).map((p) => [p.window, { ...p.frame, parked: p.isParked }]));
};

test('layout: defaults match the Swift core', () => {
  assert.equal(config.gap, 8);
  assert.equal(config.edgeGap, 8);
  assert.equal(config.defaultWidth, 0.5);
  assert.deepEqual(sanitizedPresets(config), [0.25, 1 / 3, 0.5, 2 / 3, 0.75]);
});

test('layout: two halves exactly fill the usable width, gaps included', () => {
  assert.equal(columnWidth(config, 0.5, 1280), 628);
  assert.equal(columnWidth(config, 1, 1280), 1264);
  assert.equal(fractionForColumnWidth(config, 628, 1280), 0.5);
});

test('layout: one window takes its share at full usable height', () => {
  const strip = new Strip();
  strip.insert(1, config.defaultWidth);
  assert.deepEqual(frames(strip)[1], { x: 8, y: 40, width: 628, height: 752, parked: false });
});

test('layout: two windows sit side by side with one gap between them', () => {
  const strip = new Strip();
  strip.insert(1, 0.5);
  strip.insert(2, 0.5);
  const f = frames(strip);
  assert.deepEqual(f[1], { x: 8, y: 40, width: 628, height: 752, parked: false });
  assert.deepEqual(f[2], { x: 644, y: 40, width: 628, height: 752, parked: false });
  assert.equal(strip.scroll, 0);
});

test('layout: a third window scrolls the strip just enough and parks the first', () => {
  const strip = new Strip();
  for (const w of [1, 2, 3]) strip.insert(w, 0.5);
  const f = frames(strip);
  assert.equal(strip.scroll, 636);
  assert.deepEqual(f[1], { x: -624, y: 40, width: 628, height: 752, parked: true });
  assert.deepEqual(f[2], { x: 8, y: 40, width: 628, height: 752, parked: false });
  assert.deepEqual(f[3], { x: 644, y: 40, width: 628, height: 752, parked: false });
  assert.equal(totalWidth(strip, config, 1280), 1900);
});

test('layout: focusing back to the first slide scrolls back and parks the last on the right', () => {
  const strip = new Strip();
  for (const w of [1, 2, 3]) strip.insert(w, 0.5);
  frames(strip);
  strip.moveFocus('left');
  assert.equal(frames(strip)[2].x, 8, 'the middle slide is already whole: no scroll');
  assert.equal(strip.scroll, 636);
  strip.moveFocus('left');
  const f = frames(strip);
  assert.equal(strip.scroll, 0);
  assert.deepEqual(f[1], { x: 8, y: 40, width: 628, height: 752, parked: false });
  assert.deepEqual(f[3], { x: 1276, y: 40, width: 628, height: 752, parked: true });
});

test('layout: closing a window closes the gap', () => {
  const strip = new Strip();
  for (const w of [1, 2, 3]) strip.insert(w, 0.5);
  frames(strip);
  strip.remove(2);
  clampScroll(strip, config, 1280);
  const f = frames(strip);
  assert.deepEqual(f[1], { x: 8, y: 40, width: 628, height: 752, parked: false });
  assert.deepEqual(f[3], { x: 644, y: 40, width: 628, height: 752, parked: false });
});

test('layout: cycle width and full width', () => {
  const strip = new Strip();
  strip.insert(1, 0.5);
  strip.cycleWidth(config.widthPresets);
  assert.equal(frames(strip)[1].width, 840);
  strip.cycleWidth(config.widthPresets);
  assert.equal(frames(strip)[1].width, 946);
  strip.cycleWidth(config.widthPresets);
  assert.equal(frames(strip)[1].width, 310, 'wraps round to the smallest');
  strip.cycleWidth(config.widthPresets, false);
  assert.equal(frames(strip)[1].width, 946, 'and back');
  strip.toggleFullWidth();
  assert.equal(frames(strip)[1].width, 1264);
  strip.toggleFullWidth();
  assert.equal(frames(strip)[1].width, 946, 'full width remembers the width to go back to');
});

test('layout: windows of a slide share it with a gap between them', () => {
  assert.deepEqual(tileFrame(rect(0, 0, 1, 0.5), rect(8, 40, 628, 752), 8), { x: 8, y: 40, width: 628, height: 372 });
  assert.deepEqual(tileFrame(rect(0, 0.5, 1, 0.5), rect(8, 40, 628, 752), 8), { x: 8, y: 420, width: 628, height: 372 });
});

test('layout: rounding matches Swift (halves away from zero)', () => {
  assert.equal(roundAway(2.5), 3);
  assert.equal(roundAway(-2.5), -3);
  assert.equal(roundAway(-0.4), -0);
});
