// Rectangles in points (or unit coordinates), y down: the same as MonorailCore's Rect.

export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export const rect = (x: number, y: number, width: number, height: number): Rect => ({ x, y, width, height });
export const unit: Rect = rect(0, 0, 1, 1);

export const maxX = (r: Rect) => r.x + r.width;
export const maxY = (r: Rect) => r.y + r.height;

/** Half-open, like the Swift core: the right and bottom edges are outside. */
export const containsPoint = (r: Rect, px: number, py: number) => px >= r.x && px < maxX(r) && py >= r.y && py < maxY(r);
