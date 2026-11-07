# App Store Connect listing: what to paste where

Everything for the Mac App Store edition's page in App Store Connect, in the order the forms ask
for it. Character limits are Apple's; every text here fits. Steps around it: [APP-STORE.md](APP-STORE.md).

## App Information

| Field | Value |
|---|---|
| Name (30) | Monorail by Ashforde |
| Subtitle (30) | Windows side by side, no squeeze |
| Bundle ID | org.ashforde.monorail.appstore |
| SKU | monorail |
| Primary category | Productivity |
| Secondary category | Utilities |
| Content rights | Doesn't contain, show or access third-party content |
| Age rating | Answer "None" to every question → 4+ |

## Pricing and Availability

Free, every country and region.

## App Privacy

**Privacy policy URL:** https://monorail.ashforde.org/privacy/

**Data collection:** *Yes, we collect data*, then only this:

| Data type | Linked to the person? | Used for tracking? | Purpose |
|---|---|---|---|
| Usage Data → Product Interaction (which features are on) | No | No | Analytics |
| Diagnostics → Other Diagnostic Data (Monorail and macOS version, Mac model, chip, memory range, number of displays, language) | No | No | Analytics |

Notes for the form: the counts go once a day with a random install ID that isn't tied to the person,
their Apple ID or their Mac; the server keeps no IP addresses; one switch in Settings → Basics turns
them off. The optional assistant only sends a sentence when the person has added their own API key
and asked for it, so it isn't data the app collects.

## Version page (1.7.x)

**Promotional text (170)**
New windows slide in beside the one you're using, and nothing else ever shrinks. Scroll a strip of
windows with your keyboard or trackpad.

**Description (4000)**

Monorail is a scrolling window manager for your Mac.

Other tilers squeeze every new window into the space you already have. Monorail puts each window on
a strip that runs past the edges of your display, so nothing shrinks. Open a window and it slides in
next to the one you're using. Move focus and the strip glides just far enough to show it.

THE STRIP
• Every display, Space and workspace has its own strip
• Windows of the same app share a slide, side by side, in rows, main + side or tabs
• Cycle widths, go full width, or drag the gap between two windows to resize both
• Scroll with two fingers on the trackpad, the keyboard or the slider bar

DOCK AND GROUP
• Drag a window onto another to split the slide, as deep as you like
• Group windows from different apps into tabs
• Saved views and workspaces you can name

TELL IT WHAT YOU WANT
• Type "put Safari and Notes side by side" into the command palette
• Every action has a shortcut, and every shortcut can be changed

MORE
• Focus mode dims everything but the slide you're in
• Evening Mode warms every display at night
• Stay Awake keeps your Mac awake for a set time or while something downloads
• Keep me Available keeps chat apps showing you as available
• Safe screen sharing: private windows step aside when you share in a video call
• Works with multiple displays, projectors and Sidecar
• Every window comes back on screen if you quit

PRIVATE BY DESIGN
Window titles, contents and files never leave your Mac. There's no account. Monorail needs one
permission, Accessibility, so it can arrange windows; others only when you turn on a feature that
needs them.

Free, with every feature. From Ashforde.

**Keywords (100)**
window manager,tiling,tiler,scrolling,windows,split screen,workspace,productivity,keyboard,arrange

**Support URL:** https://monorail.ashforde.org/support/
**Marketing URL:** https://monorail.ashforde.org/
**Copyright:** © 2026 Ashforde OÜ

**What's New:** the top entry of [CHANGELOG.md](../CHANGELOG.md), shortened to the main points.

## Screenshots

Mac screenshots must be 1280 × 800, 1440 × 900, 2560 × 1600 or 2880 × 1800 (one to ten). Render them
at 2880 × 1800 from the launch gallery (`scripts/launch/gallery.html`, the kit in
`assets/launch/v17`), in this order:

1. The strip: windows side by side, one sliding in ("Nothing else shrinks")
2. Docking and tabs
3. The command palette with a sentence
4. The overview of workspaces
5. Focus mode and Evening Mode
6. Settings, showing it's free with every feature

## App Review Information

**Sign-in required:** No.

**Notes for the reviewer:**

> Monorail arranges the windows of other apps on a horizontal strip, like Magnet and Moom, so it
> needs Accessibility access (System Settings → Privacy & Security → Accessibility). The welcome
> window explains this and opens the right page; without it, Stay Awake, Evening Mode and the
> command palette still work.
>
> To try it: allow Accessibility, open three or four windows of any apps, and press ⌃⌥→ and ⌃⌥← to
> move along the strip; ⌃⌥R cycles a window’s width and ⌃⌥Space searches windows.
>
> Monorail collects only anonymous usage counts (no account, nothing linked to the person), which
> can be turned off in Settings → Basics. A short screen recording of the welcome tour is attached.

**Attachment:** a 30-second screen recording of the welcome tour and the first few shortcuts.

## Version release

*Manually release this version*, so it goes live when you choose after approval.
