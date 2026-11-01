# The strip

## Slides and widths

- Each workspace on each display has one **strip**: an ordered row of slides that can be longer than
  the screen.
- A slide's **width** is a share of the usable width (the display's visible width minus the edge
  gaps), clamped to a minimum and maximum. A full-width slide uses the whole usable width and keeps
  its previous width to return to.
- Between slides there is a fixed **gap** (default 8 points), and the strip leaves an **edge gap** (default 8 points)
  at both screen edges.
- A slide holds up to six windows in one of the standard **arrangements**: side by side, up and down,
  grid, main + side, main + bottom, spiral, accordion, custom rows, or a **nested** split tree (see
  `docking.md`). A **tabbed** slide shows one window at a time under a tab bar. A **tall** slide gives
  each window nearly the full height and scrolls between them.

## Focus and scrolling

- One slide on the strip is **focused**; inside it, one window is **active**.
- Moving focus first moves between the windows of a slide, by their positions, then to the next
  slide in that direction.
- The strip **scrolls** only as far as needed to show the focused slide completely (**reveal**). With
  centring on, the focused slide is centred instead.
- Slides entirely off screen are **parked**: moved just past the screen edge, leaving at most a thin
  sliver visible (or none, with "whole slides only").

## Changes

- A new window opens as a new slide **beside the focused one** (or at the start or end, per settings
  and app rules), and the strip reveals it. Existing slides keep their widths.
- Removing the last window of a slide removes the slide; focus moves to its neighbour.
- Every change that rearranges the strip can be undone; the undo history keeps the last 40 steps.
