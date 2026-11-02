// A slide divided into splits inside splits (spec/docking.md). A port of MonorailCore's SplitTree:
// every behaviour here must match it exactly, which tests/golden/split-tree.json checks.

import { type Rect, maxX, maxY, rect, unit, containsPoint } from './geometry.ts';

export type WindowID = number;
export type Axis = 'horizontal' | 'vertical';
export type Edge = 'left' | 'right' | 'top' | 'bottom' | 'center';

export type SplitTree =
  | { kind: 'leaf'; windows: WindowID[]; active: number }
  | { kind: 'split'; axis: Axis; ratio: number; a: SplitTree; b: SplitTree };

export interface Tile {
  window: WindowID;
  frame: Rect;
  /** A tab behind the front one of its group. */
  isHiddenTab: boolean;
  group: WindowID[];
  front: WindowID;
}

export const ratioRange = { lower: 0.1, upper: 0.9 } as const;
const clamp = (ratio: number) => Math.min(Math.max(ratio, ratioRange.lower), ratioRange.upper);

const edgeAxis = (edge: Edge): Axis => (edge === 'left' || edge === 'right' ? 'horizontal' : 'vertical');
const goesFirst = (edge: Edge) => edge === 'left' || edge === 'top';

export const single = (window: WindowID): SplitTree => ({ kind: 'leaf', windows: [window], active: 0 });
const leaf = (windows: WindowID[], active: number): SplitTree => ({ kind: 'leaf', windows, active });
const split = (axis: Axis, ratio: number, a: SplitTree, b: SplitTree): SplitTree => ({ kind: 'split', axis, ratio, a, b });

// MARK: Reading

/** Every window, in reading order (left to right, top to bottom; tabs in tab order). */
export function windows(tree: SplitTree): WindowID[] {
  return tree.kind === 'leaf' ? [...tree.windows] : [...windows(tree.a), ...windows(tree.b)];
}

export const contains = (tree: SplitTree, window: WindowID) => windows(tree).includes(window);

export function depth(tree: SplitTree): number {
  return tree.kind === 'leaf' ? 0 : 1 + Math.max(depth(tree.a), depth(tree.b));
}

export function tabGroups(tree: SplitTree): WindowID[][] {
  if (tree.kind === 'leaf') return tree.windows.length > 1 ? [[...tree.windows]] : [];
  return [...tabGroups(tree.a), ...tabGroups(tree.b)];
}

export function divide(frame: Rect, axis: Axis, ratio: number): [Rect, Rect] {
  const r = clamp(ratio);
  if (axis === 'horizontal') {
    const w = frame.width * r;
    return [rect(frame.x, frame.y, w, frame.height), rect(frame.x + w, frame.y, frame.width - w, frame.height)];
  }
  const h = frame.height * r;
  return [rect(frame.x, frame.y, frame.width, h), rect(frame.x, frame.y + h, frame.width, frame.height - h)];
}

/** Where every window goes, in unit coordinates of `frame`. */
export function tiles(tree: SplitTree, frame: Rect = unit): Tile[] {
  if (tree.kind === 'leaf') {
    const ids = tree.windows;
    const front = tree.active >= 0 && tree.active < ids.length ? ids[tree.active] : (ids[0] ?? 0);
    return ids.map((window) => ({ window, frame, isHiddenTab: window !== front, group: [...ids], front }));
  }
  const [first, second] = divide(frame, tree.axis, tree.ratio);
  return [...tiles(tree.a, first), ...tiles(tree.b, second)];
}

export const frameOf = (tree: SplitTree, window: WindowID): Rect | undefined => tiles(tree).find((t) => t.window === window)?.frame;

// MARK: Changing

function replacingLeaf(tree: SplitTree, window: WindowID, change: (leaf: SplitTree) => SplitTree): SplitTree {
  if (tree.kind === 'leaf') return tree.windows.includes(window) ? change(tree) : tree;
  if (contains(tree.a, window)) return split(tree.axis, tree.ratio, replacingLeaf(tree.a, window, change), tree.b);
  if (contains(tree.b, window)) return split(tree.axis, tree.ratio, tree.a, replacingLeaf(tree.b, window, change));
  return tree;
}

/** Puts `window` beside `target` (or into its tab group, for 'center'). A window already in the tree moves. */
export function docking(tree: SplitTree, window: WindowID, target: WindowID, edge: Edge, ratio = 0.5): SplitTree {
  if (window === target) return tree;
  const base = contains(tree, window) ? (removing(tree, window) ?? single(target)) : tree;
  if (!contains(base, target)) return base;
  return replacingLeaf(base, target, (node) => {
    if (node.kind !== 'leaf') return node;
    if (edge === 'center') {
      const ids = [...node.windows, window];
      return leaf(ids, ids.length - 1);
    }
    // A target inside a tab group: the whole group moves aside together.
    const added = single(window);
    return goesFirst(edge) ? split(edgeAxis(edge), ratio, added, node) : split(edgeAxis(edge), 1 - ratio, node, added);
  });
}

/** Without `window`; its sibling takes its place. Undefined when it was the last window. */
export function removing(tree: SplitTree, window: WindowID): SplitTree | undefined {
  if (tree.kind === 'leaf') {
    const index = tree.windows.indexOf(window);
    if (index < 0) return tree;
    const ids = tree.windows.filter((_, i) => i !== index);
    if (ids.length === 0) return undefined;
    const front = index < tree.active ? tree.active - 1 : Math.min(tree.active, ids.length - 1);
    return leaf(ids, front);
  }
  if (!contains(tree, window)) return tree;
  const na = removing(tree.a, window);
  const nb = removing(tree.b, window);
  if (!na && !nb) return undefined;
  if (na && !nb) return na;
  if (!na && nb) return nb;
  return split(tree.axis, tree.ratio, na!, nb!);
}

/** Brings `window` to the front of its tab group. */
export function activating(tree: SplitTree, window: WindowID): SplitTree {
  return replacingLeaf(tree, window, (node) => {
    if (node.kind !== 'leaf') return node;
    const index = node.windows.indexOf(window);
    return index < 0 ? node : leaf([...node.windows], index);
  });
}

function same(a: SplitTree, b: SplitTree): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

/** Moves the split nearest `window` on `axis` by `delta` (positive grows `window`). */
export function adjusting(tree: SplitTree, window: WindowID, axis: Axis, delta: number): SplitTree {
  if (tree.kind !== 'split' || !contains(tree, window)) return tree;
  const inFirst = contains(tree.a, window);
  // The deepest matching split wins: try inside first.
  const inner = inFirst ? adjusting(tree.a, window, axis, delta) : adjusting(tree.b, window, axis, delta);
  const changedInside = !same(inner, inFirst ? tree.a : tree.b);
  if (changedInside) return inFirst ? split(tree.axis, tree.ratio, inner, tree.b) : split(tree.axis, tree.ratio, tree.a, inner);
  if (tree.axis !== axis) return tree;
  return split(tree.axis, clamp(tree.ratio + (inFirst ? delta : -delta)), tree.a, tree.b);
}

/** Sets splits so `window` gets as close as possible to `wanted`, moving only the splits that border it. */
export function resizing(tree: SplitTree, window: WindowID, wanted: Rect, frame: Rect = unit): SplitTree {
  if (tree.kind !== 'split' || !contains(tree, window)) return tree;
  const inFirst = contains(tree.a, window);
  let ratio = tree.ratio;
  if (tree.axis === 'horizontal' && frame.width > 0) {
    const boundary = inFirst ? maxX(wanted) : wanted.x;
    ratio = clamp((boundary - frame.x) / frame.width);
  } else if (tree.axis === 'vertical' && frame.height > 0) {
    const boundary = inFirst ? maxY(wanted) : wanted.y;
    ratio = clamp((boundary - frame.y) / frame.height);
  }
  // Only move this split if the window's edge on this axis actually moved.
  const [oldFirst, oldSecond] = divide(frame, tree.axis, tree.ratio);
  const current = inFirst ? oldFirst : oldSecond;
  const moved =
    tree.axis === 'horizontal'
      ? Math.abs(inFirst ? maxX(current) - maxX(wanted) : current.x - wanted.x) > 0.005
      : Math.abs(inFirst ? maxY(current) - maxY(wanted) : current.y - wanted.y) > 0.005;
  if (!moved) ratio = tree.ratio;
  const [first, second] = divide(frame, tree.axis, ratio);
  const na = inFirst ? resizing(tree.a, window, wanted, first) : tree.a;
  const nb = inFirst ? tree.b : resizing(tree.b, window, wanted, second);
  return split(tree.axis, ratio, na, nb);
}

/** Every split back to an even share. */
export function balanced(tree: SplitTree): SplitTree {
  return tree.kind === 'leaf' ? tree : split(tree.axis, 0.5, balanced(tree.a), balanced(tree.b));
}

// MARK: Dock zones

/**
 * Where a dragged window would land on another: the outer `edgeShare` of each side docks on that
 * side; the rest is the middle (a tab group). Undefined when the point is outside `frame`.
 */
export function dockZone(x: number, y: number, frame: Rect, edgeShare = 0.4): Edge | undefined {
  if (frame.width <= 0 || frame.height <= 0 || !containsPoint(frame, x, y)) return undefined;
  const fx = (x - frame.x) / frame.width;
  const fy = (y - frame.y) / frame.height;
  const distances: [Edge, number][] = [['left', fx], ['right', 1 - fx], ['top', fy], ['bottom', 1 - fy]];
  // The first of equally near sides wins, as in the Swift core.
  let nearest = distances[0];
  for (const d of distances) if (d[1] < nearest[1]) nearest = d;
  return nearest[1] < edgeShare ? nearest[0] : 'center';
}

/** Matches the tree to `windows`: drops windows that left, docks new ones right of the last. */
export function reconciled(tree: SplitTree, list: WindowID[]): SplitTree | undefined {
  let t: SplitTree | undefined = tree;
  for (const window of windows(tree)) if (!list.includes(window) && t) t = removing(t, window);
  for (const window of list) {
    if (t && contains(t, window)) continue;
    const last = t ? windows(t).at(-1) : undefined;
    t = t && last !== undefined ? docking(t, window, last, 'right') : single(window);
  }
  return t;
}

/** A tree with the same tiles as a standard layout ('stack' runs down, anything else across). */
export function fromArrangement(list: WindowID[], arrangement: string): SplitTree | undefined {
  if (list.length === 0) return undefined;
  const axis: Axis = arrangement === 'stack' ? 'vertical' : 'horizontal';
  let t = single(list[0]);
  list.slice(1).forEach((window, i) => {
    // Even shares: each new window takes 1/n of the run so far.
    const share = 1 / (i + 2);
    t = split(axis, 1 - share, t, single(window));
  });
  return t;
}
