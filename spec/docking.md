# Docking and nested slides

## Dock zones

Dropping a window onto another window (the **target**) chooses a zone from where the pointer is,
measured within the target's frame:

1. Work out the distance from the pointer to each of the four sides, as a share of the target's
   width (left and right) or height (top and bottom).
2. The **nearest side** wins. If its distance is **less than 0.4**, the zone is that side: left,
   right, top or bottom.
3. Otherwise the zone is the **centre**.
4. A pointer outside the target has no zone.

So the outer 40% of each side docks, and only the middle fifth makes a tab group.

The preview shown while dragging is the half of the target on that side, or the whole target for the
centre.

## Split trees

A nested slide is a **split tree**:

- A **leaf** holds one window, or several as a **tab group** with one front window.
- A **split** divides its area on an **axis** (horizontal: side by side; vertical: one above the
  other) at a **ratio**, the first part's share, clamped to 0.1…0.9.

Rules:

- **Docking** window W onto target T at a side replaces T's leaf with a split on that side's axis:
  W goes first for left and top, second for right and bottom, at ratio 0.5. A target inside a tab
  group moves aside with its whole group.
- **Docking at the centre** adds W to T's leaf as the new front tab.
- A window already in the tree is **removed first**, then docked.
- **Removing** a window collapses its split: the sibling takes the split's place. Removing the last
  window of a tab group removes the leaf; removing the front tab makes the next one front.
- **Resizing a window** moves only the splits that border the edge that actually moved.
- **Even out** sets every ratio to 0.5.
- When windows join or leave a nested slide by other means, the tree keeps its shape: departed
  windows are removed, and new ones dock to the right of the last window.

## Tearing off and undocking

- Tearing off a window gives it a slide of its own beside its old slide.
- Returning a slide to a standard arrangement discards its tree.
- Docking is one undo step.
