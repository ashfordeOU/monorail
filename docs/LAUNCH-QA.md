# Launch test checklist

Run through this on a real Mac before a big launch. It takes about 30 minutes. Tick each box; anything
that fails goes in an issue (Monorail menu → **Send Feedback…** or Settings → Smart → **Report a
Problem…**).

**Before you start:** quit Monorail, delete `~/Library/Application Support/Monorail` from a *spare*
user account (System Settings → Users & Groups), log in to that account and install the latest
release from the website. Testing as a brand-new user is the point.

## 1. First run (5 min)
- [ ] The download opens without errors (once notarised: no "could not verify" warning).
- [ ] The welcome window explains Accessibility; allowing it continues without restarting.
- [ ] **Practice with demo windows** opens three windows; every practice step can be completed,
      including **Dock a window onto another**.
- [ ] The usage-counts notice appears once, a little after the welcome; **What's Sent…** shows the data.
- [ ] Settings opens on **Basics**; the sidebar groups and search work.

## 2. Everyday moves (5 min)
- [ ] Open Safari, Terminal (⌘N three times quickly) and Notes: every window joins the strip; none is left floating.
- [ ] ⌃⌥← → slides, ⌃⌥⇧← → moves, ⌃⌥R widths, ⌃⌥F full width, ⌃⌥O overview, ⌃⌥Z undo.
- [ ] ⌃⌥/ then "Safari and Notes side by side" works.
- [ ] Mouse Back/Forward buttons still go back and forward in Safari.

## 3. Docking (5 min)
- [ ] Drag a window onto another's left, right, top and bottom edges: the highlight matches where it lands.
- [ ] Drop on the middle: a tab group with a tab bar; clicking tabs switches; dragging a tab out tears it off.
- [ ] Dock onto a docked window (three levels deep), then drag the gaps: both sides resize.
- [ ] ⌃⌥⇧] gives a window its own slide; ⌃⌥G returns the slide to a normal layout; ⌃⌥Z undoes.
- [ ] Quit Monorail and reopen it: nested slides keep their shape.

## 4. Views, tags, import (5 min)
- [ ] ⌃⌥⌘⇧1 saves a view; move elsewhere; ⌃⌥⌘1 returns; ⌃⌥⌘[ and ] go back and forward.
- [ ] Menu bar → Views lists the saved view.
- [ ] Settings → Basics → Import Settings… (with an AeroSpace, yabai or Rectangle setup on the Mac) brings shortcuts over.
- [ ] Settings → Apps → Design Zones…: split a zone, save, use it from a slide's right-click menu.

## 5. Real life (5 min)
- [ ] Play a video in QuickTime and in Safari: the slider bar steps aside and comes back after.
- [ ] Make an app full screen: no slider bar on top of it.
- [ ] Plug in or unplug a second display: windows come back where they were.
- [ ] Close the lid or sleep for a minute; on wake the layout is intact.
- [ ] Start a screen share in Zoom/Meet with a private app open: it steps aside.

## 6. Leaving (2 min)
- [ ] Quit Monorail: every window is on screen, none half off the edge.
- [ ] Pause (⌃⌥Q) and resume: windows come back to their slides.
- [ ] Monorail menu → **Send Feedback…** opens the feedback form with the version filled in.

## 7. Energy (5 min)
- [ ] Run `bash scripts/measure-performance.sh` with the slider bar on "Always" and with "Only while
      sliding". Idle CPU should stay under about 0.1% and wake-ups near zero.

## 8. Website
- [ ] https://monorail.ashforde.org/?ref=producthunt shows the Product Hunt welcome bar.
- [ ] The download button downloads the DMG directly and shows the version and size.
- [ ] Light, dark and the text-size buttons work; the page fits a phone with no sideways scrolling.
