// How the windows of one slide share its space. A port of MonorailCore's Arrangement.

import { type Rect, maxX, maxY, rect } from './geometry.ts';

export type Direction = 'left' | 'right' | 'up' | 'down';
export type Arrangement = 'stack' | 'grid' | 'columns' | 'mainLeft' | 'mainTop' | 'custom' | 'accordion' | 'spiral';

export const splitRange = { lower: 0.12, upper: 0.88 } as const;
export const defaultSplit = 0.6;
export const accordionStep = 0.06;

const midX = (r: Rect) => r.x + r.width / 2;
const midY = (r: Rect) => r.y + r.height / 2;

export function gridColumns(count: number): number {
  if (count <= 1) return 1;
  if (count <= 4) return 2;
  if (count <= 9) return 3;
  return 4;
}

export function customFrames(count: number, rows: number[]): Rect[] {
  const spec = rows.map((r) => Math.max(r, 1));
  const cells = spec.reduce((a, b) => a + b, 0);
  if (count > cells) {
    spec[spec.length - 1] += count - cells;
  } else {
    let excess = cells - count;
    while (excess > 0 && spec.length > 0) {
      const last = spec.length - 1;
      const take = Math.min(excess, spec[last]);
      spec[last] -= take;
      excess -= take;
      if (spec[last] === 0) spec.pop();
    }
  }
  const width = 1 / spec.length;
  const frames: Rect[] = [];
  spec.forEach((rowCount, c) => {
    const height = 1 / rowCount;
    for (let r = 0; r < rowCount; r++) frames.push(rect(c * width, r * height, width, height));
  });
  return frames;
}

/** Tile rectangles in unit coordinates (y down) for `count` windows. */
export function unitFrames(arrangement: Arrangement, count: number, split = defaultSplit, rows?: number[]): Rect[] {
  if (count <= 0) return [];
  if (count === 1) return [rect(0, 0, 1, 1)];
  if (arrangement === 'custom' && rows && rows.length > 0) return customFrames(count, rows);
  const n = count;
  const main = Math.min(Math.max(split, splitRange.lower), splitRange.upper);
  const range = (from: number, to: number) => Array.from({ length: Math.max(to - from, 0) }, (_, i) => from + i);
  switch (arrangement) {
    case 'stack':
      return range(0, count).map((i) => rect(0, i / n, 1, 1 / n));
    case 'columns':
      return range(0, count).map((i) => rect(i / n, 0, 1 / n, 1));
    case 'grid':
    case 'custom': {
      const across = gridColumns(count);
      const rowCount = Math.floor((count + across - 1) / across);
      return range(0, count).map((index) => {
        const row = Math.floor(index / across);
        // The last row stretches its tiles to fill the width.
        const inRow = Math.min(across, count - row * across);
        const col = index - row * across;
        return rect(col / inRow, row / rowCount, 1 / inRow, 1 / rowCount);
      });
    }
    case 'mainLeft': {
      const rest = count - 1;
      return [rect(0, 0, main, 1), ...range(1, count).map((i) => rect(main, (i - 1) / rest, 1 - main, 1 / rest))];
    }
    case 'mainTop': {
      const rest = count - 1;
      return [rect(0, 0, 1, main), ...range(1, count).map((i) => rect((i - 1) / rest, main, 1 / rest, 1 - main))];
    }
    case 'accordion': {
      const step = Math.min(accordionStep, 0.5 / (count - 1));
      const width = 1 - step * (count - 1);
      return range(0, count).map((i) => rect(i * step, 0, width, 1));
    }
    case 'spiral': {
      const frames: Rect[] = [];
      let area = rect(0, 0, 1, 1);
      for (let i = 0; i < count; i++) {
        if (i === count - 1) {
          frames.push(area);
          break;
        }
        const share = i === 0 ? main : 0.5;
        switch (i % 4) {
          case 0:
            frames.push(rect(area.x, area.y, area.width * share, area.height));
            area = rect(area.x + area.width * share, area.y, area.width * (1 - share), area.height);
            break;
          case 1:
            frames.push(rect(area.x, area.y, area.width, area.height * share));
            area = rect(area.x, area.y + area.height * share, area.width, area.height * (1 - share));
            break;
          case 2:
            frames.push(rect(area.x + area.width * (1 - share), area.y, area.width * share, area.height));
            area = rect(area.x, area.y, area.width * (1 - share), area.height);
            break;
          default:
            frames.push(rect(area.x, area.y + area.height * (1 - share), area.width, area.height * share));
            area = rect(area.x, area.y, area.width, area.height * (1 - share));
        }
      }
      return frames;
    }
  }
}

/** The tile next to `index` in `direction`, using the tiles' positions. */
export function neighbour(arrangement: Arrangement, index: number, count: number, split: number, rows: number[] | undefined, direction: Direction): number | undefined {
  const frames = unitFrames(arrangement, count, split, rows);
  if (index < 0 || index >= frames.length) return undefined;
  const current = frames[index];
  const epsilon = 0.001;
  let best: { index: number; score: number } | undefined;
  frames.forEach((frame, candidate) => {
    if (candidate === index) return;
    let gap: number;
    let cross: number;
    switch (direction) {
      case 'right':
        if (!(frame.x >= maxX(current) - epsilon)) return;
        gap = frame.x - maxX(current);
        cross = Math.abs(midY(frame) - midY(current));
        break;
      case 'left':
        if (!(maxX(frame) <= current.x + epsilon)) return;
        gap = current.x - maxX(frame);
        cross = Math.abs(midY(frame) - midY(current));
        break;
      case 'down':
        if (!(frame.y >= maxY(current) - epsilon)) return;
        gap = frame.y - maxY(current);
        cross = Math.abs(midX(frame) - midX(current));
        break;
      case 'up':
        if (!(maxY(frame) <= current.y + epsilon)) return;
        gap = current.y - maxY(frame);
        cross = Math.abs(midX(frame) - midX(current));
        break;
    }
    const score = gap * 10 + cross;
    if (!best || score < best.score - epsilon) best = { index: candidate, score };
  });
  return best?.index;
}

/** The tile to land on when focus enters the slide from one side. */
export function entryTile(arrangement: Arrangement, count: number, split: number, rows: number[] | undefined, fromRight: boolean, preferred: number, crossY: number): number {
  const frames = unitFrames(arrangement, count, split, rows);
  const onEdge = frames.map((_, i) => i).filter((i) => (fromRight ? maxX(frames[i]) >= 1 - 0.001 : frames[i].x <= 0.001));
  if (onEdge.includes(preferred)) return preferred;
  let best: number | undefined;
  for (const i of onEdge) if (best === undefined || Math.abs(midY(frames[i]) - crossY) < Math.abs(midY(frames[best]) - crossY)) best = i;
  return best ?? 0;
}
