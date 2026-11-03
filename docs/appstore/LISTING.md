# Mac App Store listing: Monorail by Ashforde

Copy these into App Store Connect → the app → the version page. Character limits are Apple's.

| Field | Value |
|---|---|
| Name (30) | Monorail by Ashforde |
| Subtitle (30) | Scrolling window manager |
| Category | Productivity (secondary: Developer Tools) |
| Price | Free |
| Bundle ID | org.ashforde.monorail.appstore |
| SKU | monorail |
| Support URL | https://monorail.ashforde.org/support/ |
| Marketing URL | https://monorail.ashforde.org/ |
| Privacy policy URL | https://monorail.ashforde.org/privacy/ |
| Copyright | 2026 Ashforde OÜ |
| Age rating | 4+ (no objectionable content) |
| Screenshots (2880 × 1800) | `assets/appstore/01-hero.jpg` … `08-native-private.jpg`, in order |

## Promotional text (170)

New: Evening Mode warms your screen at night with a slider. Every window rides one rail: new windows slide in beside you, so nothing you're using ever shrinks.

## Keywords (100, comma-separated, no spaces after commas)

window manager,tiling,scroll,windows,split screen,workspaces,productivity,layout,niri,paperwm

## Description (4000)

Monorail is a scrolling window manager for your Mac. Every window gets a slide on a strip that runs past the edges of the screen, so a new window slides in beside the one you're using and nothing else changes size. Move along the strip with the keyboard, a swipe or the slider bar.

• Slides that fit how you work: windows of one app share a slide, or pair any two, in grids, main and side, tabs or tall slides.
• The overview: every workspace on one colourful canvas. Drag to pair, reorder, move or close.
• Say what you want: "Slack and Mail side by side on 2". The command palette understands sentences, on your Mac.
• Saved views: put a workspace back exactly as it was, with one key.
• Evening Mode: less blue light from every display at night, as warm as you like, on a schedule if you want.
• Stay Awake: keep your Mac awake for an hour, while something downloads, or whenever an app is open.
• Focus and deep work: dim everything but your slide and hide distracting apps.
• Displays that remember: unplug and replug, and every window goes back where it was.
• Safe screen sharing: private windows step aside when you share your screen.
• Coming from another app? Monorail imports your AeroSpace, yabai or Rectangle setup.
• 27 themes, nine languages, VoiceOver support.

Private by design: no account, and nothing about your windows, files or what you do leaves your Mac. Anonymous daily usage counts can be turned off, and the app shows exactly what's sent.

Monorail needs one permission, Accessibility, which macOS requires before any app can move other apps' windows.

## What's New (first version)

The first Mac App Store release of Monorail.

## App Review notes

Monorail is a window manager: it arranges the windows of other apps on a scrolling strip. To move and resize those windows it uses the Accessibility API (AXUIElement), the same way other window managers in the Mac App Store do; the person grants Accessibility in System Settings → Privacy & Security, and the welcome tour explains why before asking. It doesn't record the screen or read keystrokes beyond its own shortcuts.

To try it: open Monorail, allow Accessibility, then open two or three windows of any apps: they line up side by side. Press ⌃⌥→ and ⌃⌥← to move between them, ⌃⌥O for the overview. The welcome tour has demo windows to practise on.

Optional features ask for their own permission only when turned on: Screen Recording (live previews of windows), Calendars (opening video calls before they start), Microphone and Speech Recognition (voice commands), Camera (a camera tile). Nothing leaves the Mac except anonymous usage counts the person can turn off (Settings → Devices & Sharing → Trust), and a small list of app compatibility quirks.

The App Store edition has no updater, no command-line tool, no local network server and no scripts; those are only in the version downloaded from our website.

## App Privacy answers (App Store Connect → App Privacy)

- Does the app collect data? **Yes**: anonymous usage counts.
- **Usage Data → Product Interaction**: collected, **not linked** to the person, used for **Analytics**, not for tracking.
- **Identifiers → Device ID**: a random install ID, **not linked**, **Analytics**, not for tracking.
- **Diagnostics**: **not collected** (crash reports stay on the Mac unless the person sends them).
- Everything else (contact info, location, contents, browsing history, purchases): **not collected**.
- Tracking: **No**.
