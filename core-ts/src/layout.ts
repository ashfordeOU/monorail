// Where the strip's windows go on screen (spec/strip.md): widths in points, scrolling so the
// focused slide shows (reveal), parking slides that are off screen, and each window's frame.
// A port of MonorailCore's LayoutConfig and the geometry half of Strip; it must give the same
// frames. Pinned slides aren't ported yet (no TypeScript strip pins a slide).

import { type Rect, maxX, rect } from './geometry.ts';
import { type Strip, type Column, maximumWidth, minimumWidth } from './strip.ts';
import type { WindowID } from './split-tree.ts';
import * as trees from './split-tree.ts';
import { unitFrames } from './arrangement.ts';

export type CenterMode = 'never' | 'onOverflow' | 'always';
export type StripDirection = 'leftToRight' | 'rightToLeft';

export interface LayoutConfig {
  /** Space between neighbouring slides and between the windows of a slide. */
  gap: number;
  /** Space between the strip and the edges of the display's usable area. */
  edgeGap: number;
  /** How much of a parked (off-screen) slide stays showing. */
  parkSliver: number;
  /** Width presets (shares of the usable width) that "Cycle width" steps through. */
  widthPresets: number[];
  /** Width given to newly tiled windows. */
  defaultWidth: number;
  centerMode: CenterMode;
  /** Height kept above tabbed slides for their tab bar. */
  tabBarHeight: number;
  direction: StripDirection;
  /** Elastic focus: how much the focused slide grows (0 = off). */
  elasticFocus: number;
  /** Slides that don't fit entirely on screen are parked instead of cut off. */
  wholeSlidesOnly: boolean;
}

/** The same defaults as MonorailCore's `LayoutConfig()`. */
export const defaultLayoutConfig = (): LayoutConfig => ({
  gap: 8,
  edgeGap: 8,
  parkSliver: 4,
  widthPresets: [0.25, 1 / 3, 0.5, 2 / 3, 0.75],
  defaultWidth: 0.5,
  centerMode: 'never',
  tabBarHeight: 28,
  direction: 'leftToRight',
  elasticFocus: 0,
  wholeSlidesOnly: false,
});

export const clampWidth = (w: number) => Math.min(Math.max(w, minimumWidth), maximumWidth);

/** Swift's `rounded()`: halves round away from zero (JavaScript's Math.round rounds them up). */
export const roundAway = (v: number) => Math.sign(v) * Math.round(Math.abs(v));
const rounded = (r: Rect): Rect => rect(roundAway(r.x), roundAway(r.y), roundAway(r.width), roundAway(r.height));

/** Presets sorted, de-duplicated and clamped. */
export function sanitizedPresets(config: LayoutConfig): number[] {
  const result: number[] = [];
  for (const value of config.widthPresets.map(clampWidth).sort((a, b) => a - b)) {
    if (!result.some((r) => Math.abs(r - value) < 0.001)) result.push(value);
  }
  return result.length === 0 ? [0.5] : result;
}

/** The width slides are laid out in, for a viewport `viewportWidth` wide. */
export const usableWidth = (config: LayoutConfig, viewportWidth: number) => Math.max(viewportWidth - 2 * config.edgeGap, 1);

/** A width share in points; shares adding up to 1 exactly fill the usable width, gaps included. */
export const columnWidth = (config: LayoutConfig, fraction: number, viewportWidth: number) =>
  Math.max(fraction * (usableWidth(config, viewportWidth) + config.gap) - config.gap, 1);

/** The inverse of `columnWidth`. */
export const fractionForColumnWidth = (config: LayoutConfig, width: number, viewportWidth: number) =>
  clampWidth((width + config.gap) / (usableWidth(config, viewportWidth) + config.gap));

export const effectiveWidth = (col: Column) => (col.isFullWidth ? 1 : col.width);

/** With elastic focus the focused slide grows and the others give way. */
export function elasticWidth(strip: Strip, index: number, config: LayoutConfig): number {
  const col = strip.columns[index];
  const base = effectiveWidth(col);
  const e = Math.min(Math.max(config.elasticFocus, 0), 0.6);
  if (!(e > 0) || strip.columns.length <= 1 || col.isFullWidth) return base;
  return index === strip.focusedColumn ? Math.min(base * (1 + e), 1) : Math.max(base * (1 - e * 0.5), minimumWidth);
}

/** Width of slide `index` in points. */
export const widthOfColumn = (strip: Strip, index: number, config: LayoutConfig, viewportWidth: number) =>
  columnWidth(config, elasticWidth(strip, index, config), viewportWidth);

/** Strip-space x of each slide's left edge. */
export function columnOffsets(strip: Strip, config: LayoutConfig, viewportWidth: number): number[] {
  const offsets: number[] = [];
  let x = 0;
  strip.columns.forEach((_, i) => {
    offsets.push(x);
    x += widthOfColumn(strip, i, config, viewportWidth) + config.gap;
  });
  return offsets;
}

/** Width of every slide and the gaps between them. */
export function totalWidth(strip: Strip, config: LayoutConfig, viewportWidth: number): number {
  if (strip.columns.length === 0) return 0;
  const widths = strip.columns.reduce((sum, _, i) => sum + widthOfColumn(strip, i, config, viewportWidth), 0);
  return widths + config.gap * (strip.columns.length - 1);
}

/** No blank space on the left, and none on the right while slides are hidden on the left. */
export function clampScroll(strip: Strip, config: LayoutConfig, viewportWidth: number) {
  const usable = usableWidth(config, viewportWidth);
  const total = totalWidth(strip, config, viewportWidth);
  strip.scroll = Math.max(Math.min(strip.scroll, Math.max(0, total - usable)), 0);
}

/** Scrolls only as far as needed to show the focused slide completely (or centres it, per `centerMode`). */
export function revealFocused(strip: Strip, config: LayoutConfig, viewportWidth: number) {
  if (strip.focusedColumn < 0 || strip.focusedColumn >= strip.columns.length) {
    strip.scroll = 0;
    return;
  }
  const usable = usableWidth(config, viewportWidth);
  const x = columnOffsets(strip, config, viewportWidth)[strip.focusedColumn];
  const w = widthOfColumn(strip, strip.focusedColumn, config, viewportWidth);
  const epsilon = 0.5;
  if (config.centerMode === 'always') {
    strip.scroll = w >= usable ? x : x + w / 2 - usable / 2;
    return;
  }
  if (x >= strip.scroll - epsilon && x + w <= strip.scroll + usable + epsilon) return;
  if (w >= usable) strip.scroll = x;
  else if (config.centerMode === 'onOverflow') strip.scroll = x + w / 2 - usable / 2;
  else if (x < strip.scroll) strip.scroll = x;
  else strip.scroll = x + w - usable;
  clampScroll(strip, config, viewportWidth);
}

export interface ColumnFrame {
  frame: Rect;
  isParked: boolean;
}

/** Where each slide sits in viewport coordinates; slides entirely off screen are parked at the edge. */
export function columnFrames(strip: Strip, config: LayoutConfig, viewport: Rect): ColumnFrame[] {
  const offsets = columnOffsets(strip, config, viewport.width);
  const usableHeight = Math.max(viewport.height - 2 * config.edgeGap, 1);
  const areaMinX = viewport.x + config.edgeGap;
  const areaMaxX = areaMinX + usableWidth(config, viewport.width);
  const y = viewport.y + config.edgeGap;
  return strip.columns.map((_, index) => {
    const w = widthOfColumn(strip, index, config, viewport.width);
    let x = areaMinX + offsets[index] - strip.scroll;
    let parked = false;
    const others = index !== strip.focusedColumn;
    if (x + w <= areaMinX || (config.wholeSlidesOnly && others && x < areaMinX - 1)) {
      x = viewport.x - w + config.parkSliver;
      parked = true;
    } else if (x >= areaMaxX || (config.wholeSlidesOnly && others && x + w > areaMaxX + 1)) {
      x = maxX(viewport) - config.parkSliver;
      parked = true;
    }
    if (config.direction === 'rightToLeft') x = viewport.x + maxX(viewport) - x - w;
    return { frame: rect(x, y, w, usableHeight), isParked: parked };
  });
}

/** Maps a unit tile into `frame`, with `gap` between tiles but none at the slide's outer edges. */
export function tileFrame(u: Rect, frame: Rect, gap: number): Rect {
  const epsilon = 0.0001;
  let minX = frame.x + u.x * frame.width;
  let maxXv = frame.x + (u.x + u.width) * frame.width;
  let minY = frame.y + u.y * frame.height;
  let maxYv = frame.y + (u.y + u.height) * frame.height;
  if (u.x > epsilon) minX += gap / 2;
  if (u.x + u.width < 1 - epsilon) maxXv -= gap / 2;
  if (u.y > epsilon) minY += gap / 2;
  if (u.y + u.height < 1 - epsilon) maxYv -= gap / 2;
  return rounded(rect(minX, minY, Math.max(maxXv - minX, 1), Math.max(maxYv - minY, 1)));
}

export interface Placement {
  window: WindowID;
  frame: Rect;
  /** The slide is entirely off screen, parked at the edge. */
  isParked: boolean;
  /** Behind the front window of a tabbed slide or tab group. */
  isHiddenTab: boolean;
}

function unitFramesOf(col: Column): Rect[] {
  if (col.tree && !col.isTabbed) {
    const tiles = new Map(trees.tiles(col.tree).map((t) => [t.window, t.frame] as const));
    if (tiles.size === col.windows.length && col.windows.every((w) => tiles.has(w))) return col.windows.map((w) => tiles.get(w)!);
  }
  return unitFrames(col.arrangement, col.windows.length, col.split, col.customRows);
}

/** Frames for every window on the strip, in viewport coordinates. */
export function layout(strip: Strip, config: LayoutConfig, viewport: Rect): Placement[] {
  const frames = columnFrames(strip, config, viewport);
  const placements: Placement[] = [];
  strip.columns.forEach((col, index) => {
    const { frame: cf, isParked } = frames[index];
    if (col.isTabbed) {
      const bar = Math.min(config.tabBarHeight, cf.height / 2);
      const frame = rounded(rect(cf.x, cf.y + bar, cf.width, cf.height - bar));
      col.windows.forEach((window, row) => placements.push({ window, frame, isParked, isHiddenTab: row !== col.active }));
      return;
    }
    if (col.isTall && col.windows.length > 1) {
      const peek = roundAway(cf.height * 0.14);
      const height = cf.height - peek - config.gap;
      const top = rounded(rect(cf.x, cf.y, cf.width, height));
      const below = rounded(rect(cf.x, cf.y + height + config.gap, cf.width, height));
      col.windows.forEach((window, row) =>
        placements.push({ window, frame: row > col.active ? below : top, isParked, isHiddenTab: row < col.active || row > col.active + 1 }),
      );
      return;
    }
    const mirrored = config.direction === 'rightToLeft';
    const nested = col.tree !== undefined && !col.isTabbed;
    const tiles = nested && col.tree ? trees.tiles(col.tree) : [];
    const hidden = new Set(tiles.filter((t) => t.isHiddenTab).map((t) => t.window));
    const groups = new Set(nested && col.tree ? trees.tabGroups(col.tree).flat() : []);
    unitFramesOf(col).forEach((u, i) => {
      const tile = mirrored ? rect(1 - (u.x + u.width), u.y, u.width, u.height) : u;
      let frame = tileFrame(tile, cf, config.gap);
      const window = col.windows[i];
      if (groups.has(window)) {
        const bar = Math.min(config.tabBarHeight, frame.height / 3);
        frame = rounded(rect(frame.x, frame.y + bar, frame.width, frame.height - bar));
      }
      placements.push({ window, frame, isParked, isHiddenTab: hidden.has(window) });
    });
  });
  return placements;
}
