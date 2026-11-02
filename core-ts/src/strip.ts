// The strip: slides side by side, one of them focused (spec/strip.md). A port of the parts of
// MonorailCore's Strip that tests/golden/strip.json covers; it must behave exactly the same.

import { type Arrangement, type Direction, defaultSplit, entryTile, neighbour, unitFrames } from './arrangement.ts';
import * as trees from './split-tree.ts';
import type { Edge, SplitTree, WindowID } from './split-tree.ts';

export const maximumWindows = 6;
export const minimumWidth = 0.1;
export const maximumWidth = 1.0;
const clampWidth = (w: number) => Math.min(Math.max(w, minimumWidth), maximumWidth);

export interface Column {
  windows: WindowID[];
  active: number;
  width: number;
  isTabbed: boolean;
  isTall: boolean;
  arrangement: Arrangement;
  split: number;
  customRows?: number[];
  isCustom: boolean;
  tree?: SplitTree;
}

export const column = (windows: WindowID[], width: number, extra: Partial<Column> = {}): Column => ({
  windows, active: 0, width: clampWidth(width), isTabbed: false, isTall: false, arrangement: 'stack',
  split: defaultSplit, isCustom: false, ...extra,
});

/** Sets a column's windows; a nested slide keeps its shape as windows come and go. */
function setWindows(col: Column, list: WindowID[]) {
  const changed = list.length !== col.windows.length || list.some((w, i) => w !== col.windows[i]);
  col.windows = list;
  if (col.tree && changed) col.tree = trees.reconciled(col.tree, list);
}

const activeWindow = (col: Column) => col.windows[col.active];
const isFull = (col: Column) => col.windows.length >= maximumWindows;
const isNested = (col: Column) => col.tree !== undefined && !col.isTabbed;

function columnUnitFrames(col: Column) {
  if (isNested(col) && col.tree) {
    const tiles = new Map(trees.tiles(col.tree).map((t) => [t.window, t.frame] as const));
    if (tiles.size === col.windows.length && col.windows.every((w) => tiles.has(w))) return col.windows.map((w) => tiles.get(w)!);
  }
  return unitFrames(col.arrangement, col.windows.length, col.split, col.customRows);
}

export type InsertPosition = 'afterFocused' | 'start' | 'end';

export class Strip {
  columns: Column[] = [];
  focusedColumn = 0;
  scroll = 0;
  /** The layout a single-window slide takes when a second window joins it. */
  pairingArrangement: Arrangement = 'grid';

  get isEmpty() { return this.columns.length === 0; }
  get allWindows(): WindowID[] { return this.columns.flatMap((c) => c.windows); }
  get focusedWindow(): WindowID | undefined {
    const col = this.columns[this.focusedColumn];
    return col ? activeWindow(col) : undefined;
  }

  locate(window: WindowID): { column: number; row: number } | undefined {
    for (let c = 0; c < this.columns.length; c++) {
      const r = this.columns[c].windows.indexOf(window);
      if (r >= 0) return { column: c, row: r };
    }
    return undefined;
  }

  contains(window: WindowID) { return this.locate(window) !== undefined; }

  /** Adds `window` as a new slide. False when it's already on the strip. */
  insert(window: WindowID, width: number, position: InsertPosition = 'afterFocused', focus = true): boolean {
    if (this.contains(window)) return false;
    const col = column([window], width);
    let index: number;
    switch (position) {
      case 'afterFocused': index = this.columns.length === 0 ? 0 : this.focusedColumn + 1; break;
      case 'start': index = 0; break;
      case 'end': index = this.columns.length; break;
    }
    this.columns.splice(index, 0, col);
    if (focus || this.columns.length === 1) this.focusedColumn = index;
    else if (index <= this.focusedColumn) this.focusedColumn += 1;
    return true;
  }

  /** Removes `window`; focus moves to the slide on the left (or the right when there's none). */
  remove(window: WindowID): boolean {
    const at = this.locate(window);
    if (!at) return false;
    const { column: c, row: r } = at;
    const col = this.columns[c];
    setWindows(col, col.windows.filter((_, i) => i !== r));
    if (col.windows.length === 0) {
      this.columns.splice(c, 1);
      if (c < this.focusedColumn || (c === this.focusedColumn && c > 0)) this.focusedColumn -= 1;
      this.focusedColumn = this.columns.length === 0 ? 0 : Math.min(this.focusedColumn, this.columns.length - 1);
    } else {
      if (r < col.active) col.active -= 1;
      col.active = Math.min(col.active, col.windows.length - 1);
    }
    return true;
  }

  focus(window: WindowID): boolean {
    const at = this.locate(window);
    if (!at) return false;
    this.focusedColumn = at.column;
    const col = this.columns[at.column];
    col.active = at.row;
    if (col.tree) col.tree = trees.activating(col.tree, window);
    return true;
  }

  private tileNextTo(index: number, col: Column, direction: Direction): number | undefined {
    if (col.isTabbed) {
      if (direction !== 'up' && direction !== 'down') return undefined;
      const target = index + (direction === 'up' ? -1 : 1);
      return target >= 0 && target < col.windows.length ? target : undefined;
    }
    return neighbour(col.arrangement, index, col.windows.length, col.split, col.customRows, direction);
  }

  private enter(fromRight: boolean, crossY: number) {
    const col = this.columns[this.focusedColumn];
    if (col.isTabbed || col.windows.length <= 1) return;
    col.active = entryTile(col.arrangement, col.windows.length, col.split, col.customRows, fromRight, col.active, crossY);
  }

  /** Moves focus one step: between the tiles of a slide first, then to the next slide. */
  moveFocus(direction: Direction): boolean {
    if (this.isEmpty) return false;
    const col = this.columns[this.focusedColumn];
    const target = this.tileNextTo(col.active, col, direction);
    if (target !== undefined) {
      col.active = target;
      return true;
    }
    if (direction !== 'left' && direction !== 'right') return false;
    const next = this.focusedColumn + (direction === 'left' ? -1 : 1);
    if (next < 0 || next >= this.columns.length) return false;
    const frame = columnUnitFrames(col)[col.active];
    const crossY = col.isTabbed ? 0.5 : frame.y + frame.height / 2;
    this.focusedColumn = next;
    this.enter(direction === 'left', crossY);
    return true;
  }

  /** Moves the focused window within its slide, or the whole slide along the strip. */
  moveFocused(direction: Direction): boolean {
    if (this.isEmpty) return false;
    const col = this.columns[this.focusedColumn];
    const target = this.tileNextTo(col.active, col, direction);
    if (target !== undefined) {
      const list = [...col.windows];
      [list[col.active], list[target]] = [list[target], list[col.active]];
      setWindows(col, list);
      col.active = target;
      return true;
    }
    if (direction === 'left') {
      if (this.focusedColumn === 0) return false;
      this.swap(this.focusedColumn, this.focusedColumn - 1);
      this.focusedColumn -= 1;
      return true;
    }
    if (direction === 'right') {
      if (this.focusedColumn >= this.columns.length - 1) return false;
      this.swap(this.focusedColumn, this.focusedColumn + 1);
      this.focusedColumn += 1;
      return true;
    }
    return false;
  }

  private swap(i: number, j: number) {
    [this.columns[i], this.columns[j]] = [this.columns[j], this.columns[i]];
  }

  private adoptPairingLayout(index: number) {
    const col = this.columns[index];
    if (!col || col.windows.length !== 2 || col.arrangement !== 'stack' || col.isTabbed) return;
    col.arrangement = this.pairingArrangement;
  }

  private consumeInto(towards: -1 | 1): boolean {
    const target0 = this.focusedColumn + towards;
    const window = this.focusedWindow;
    if (target0 < 0 || target0 >= this.columns.length || isFull(this.columns[target0]) || window === undefined) return false;
    const source = this.columns[this.focusedColumn];
    setWindows(source, source.windows.filter((_, i) => i !== source.active));
    let target = target0;
    if (source.windows.length === 0) {
      this.columns.splice(this.focusedColumn, 1);
      if (towards === 1) target -= 1;
    } else {
      source.active = Math.min(source.active, source.windows.length - 1);
    }
    const into = this.columns[target];
    setWindows(into, [...into.windows, window]);
    into.active = into.windows.length - 1;
    into.isCustom = true;
    this.adoptPairingLayout(target);
    this.focusedColumn = target;
    return true;
  }

  /** Moves the focused window into the bottom of the slide on its left. */
  consumeIntoLeft() { return this.consumeInto(-1); }
  /** Moves the focused window into the bottom of the slide on its right. */
  consumeIntoRight() { return this.consumeInto(1); }

  /** Takes the focused window out of its slide into a slide of its own on the right. */
  expel(): boolean {
    const source = this.columns[this.focusedColumn];
    if (!source || source.windows.length <= 1) return false;
    const window = source.windows[source.active];
    setWindows(source, source.windows.filter((_, i) => i !== source.active));
    source.active = Math.min(source.active, source.windows.length - 1);
    source.isCustom = true;
    this.columns.splice(this.focusedColumn + 1, 0, column([window], source.width, { isCustom: true }));
    this.focusedColumn += 1;
    return true;
  }

  /** Puts `window` into a new slide at `index`. */
  moveWindowToNewColumn(window: WindowID, index: number, width: number) {
    const at = this.locate(window);
    if (!at) return;
    const sourceVanishes = this.columns[at.column].windows.length === 1;
    let target = Math.min(Math.max(index, 0), this.columns.length);
    if (sourceVanishes && at.column < target) target -= 1;
    const keepWidth = sourceVanishes ? this.columns[at.column].width : width;
    this.remove(window);
    target = Math.min(target, this.columns.length);
    this.columns.splice(target, 0, column([window], keepWidth, { isCustom: true }));
    this.focusedColumn = target;
  }

  /** Docks `window` onto `target`'s edge (or into its tab group): the target's slide becomes nested. */
  dock(window: WindowID, target: WindowID, edge: Edge): boolean {
    if (window === target || !this.locate(target)) return false;
    const from = this.locate(window);
    const onto = this.locate(target);
    if (from && onto && from.column !== onto.column) this.remove(window);
    const t = this.locate(target);
    if (!t) return false;
    const col = this.columns[t.column];
    const base =
      col.tree ??
      trees.fromArrangement(col.windows.filter((w) => w !== window), col.isTabbed ? 'columns' : col.arrangement) ??
      trees.single(target);
    const tree = trees.docking(base, window, target, edge);
    col.isTabbed = false;
    col.isTall = false;
    col.isCustom = true;
    col.tree = tree;
    col.windows = trees.windows(tree);
    col.active = Math.max(col.windows.indexOf(window), 0);
    this.focusedColumn = t.column;
    return true;
  }

  /** Takes `window` out of its tab group or nested split into a slide of its own beside it. */
  tearOff(window: WindowID, width: number): boolean {
    const at = this.locate(window);
    if (!at || this.columns[at.column].windows.length <= 1) return false;
    this.moveWindowToNewColumn(window, at.column + 1, width);
    return true;
  }
}
