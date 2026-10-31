# Product Hunt launch kit: Monorail by Ashforde®

Everything needed to post Monorail 1.7 on Product Hunt. The images are in [`assets/launch`](../../assets/launch).

## The listing

**Name:** Monorail by Ashforde®

**Tagline** (60 characters max):
> The scrolling window manager for Mac that understands you

Alternatives:
- Every window rides one rail: a smarter way to use your Mac
- Your Mac's windows, on an endless strip that thinks with you

**Link:** https://ashfordeou.github.io/monorail/ (source: https://github.com/ashfordeOU/monorail)

**Topics:** Mac, Productivity, Developer Tools, Artificial Intelligence

**Pricing:** Free (source on GitHub, FSL-1.1-ALv2)

**Description** (260 characters max):
> Every window rides one endless strip, so new windows never squeeze the rest. Drag windows onto each other to dock or tab them, any apps. Type “Slack and Mail side by side”. Alerts when an AI agent waits. Imports AeroSpace, yabai and Rectangle setups. Free.

## Gallery

The images are in [`assets/launch/v17`](../../assets/launch/v17), at 2540 × 1520 (Product Hunt's 1270 × 760 at double resolution). Upload them in this order:

| # | File | Shows |
| --- | --- | --- |
| 1 | `01-hero.png` | Every window rides one rail |
| 2 | `docking.gif` | Docking, live: edge, nested split, tab group, gap resize |
| 3 | `02-dock.png` | Drop a window where you want it |
| 4 | `03-tabs-resize.png` | Tab groups across apps, and resizing two windows at once |
| 5 | `04-say-it.png` | Plain-language commands and AI agent alerts |
| 6 | `05-saved-views.png` | Saved views, back and forward |
| 7 | `06-import-free.png` | Import from AeroSpace, yabai or Rectangle; no Pro tier |
| 8 | `07-themes.png` | 27 themes |
| 9 | `08-native-private.png` | Native, light, private |
| 10 | `09-end.png` | End card with the download link |

Thumbnail: `assets/launch/thumbnail-240.png` (the app icon).

**Video.** [`monorail-demo.mp4`](../../assets/launch/v17/monorail-demo.mp4) (85 s, 1080p) walks through everything: opening windows,
gliding along the strip, pairing, plain-language commands, focus mode, the docking playground (edge, nested split, tab
group, gap resize), saved views, import, themes, privacy and the Windows and Linux plans. Product Hunt takes a YouTube
link: upload it to YouTube (unlisted is fine) and paste the link under **Add video**.

It's made from the website's interactive demos and the gallery cards, rebuilt with `scripts/launch/gallery.html`. Once
the signed build is out, a 30-second screen recording of the real app is worth adding as a second video: record with
**Show keystrokes and clicks** and **Demo zoom** on, and follow the same order.

## First comment (from the maker)

> Hi Product Hunt! 👋
>
> I built Monorail because every tiling window manager I tried did the same thing: open a new window and everything else shrinks. On a laptop that's maddening.
>
> Monorail does the opposite. Every window is a slide on a horizontal strip that runs past the edges of your screen. Open a window and it slides in next to the one you're using. Nothing else changes size. Move focus and the strip glides along.
>
> What's new lately:
> - 🪟 **Dock anything, nest anywhere.** Drag a window onto another window's edge to dock it beside, or onto its middle to make a tab group, across any apps and as deep as you like. Drag the gap between two windows to resize both.
> - 📍 **Saved views** (⌃⌥⌘1…9) and back/forward through where you've been, like a browser.
> - 📦 **Switch in a minute:** imports your AeroSpace, yabai/skhd or Rectangle setup.
> - 🗣️ **Say it.** Type “Safari two thirds” or “write the Q3 report” in the palette and Monorail does it, all on your Mac.
> - 🤖 **AI agent alerts.** Run Claude Code or Codex in a terminal and hear a chime the moment it's waiting for your approval.
> - 🛡️ **Safe screen sharing.** Private windows step aside as soon as you share in Zoom, Teams or Meet.
> - 🎤 **Share one slide** instead of your whole screen, plus a demo zoom, drawing on screen and presenter notes only you can see.
> - 🎨 **27 themes**, including Seasons, which changes through the year.
> - ⌨️ Vim mode, MIDI pads, game controllers, a phone remote, and a live event stream for SketchyBar and scripts.
> - 💸 **No paywall.** Every feature is free, with no window limits.
>
> It's native Swift and free, with the source on GitHub. There's no account, it only sends anonymous daily counts you can turn off, and the only permission it needs is Accessibility.
>
> I'd love to hear how you arrange your windows, and what would make Monorail yours. 🙏

## Short posts

**X / Threads / Bluesky**
> Monorail is live on Product Hunt 🚝
> A Mac window manager where nothing ever shrinks. Every window rides one endless strip.
> Drag to dock or tab any windows, saved views, “Slack and Mail side by side”, AI agent alerts, 27 themes. All free.
> Free for Mac → [Product Hunt link]

**LinkedIn**
> Today we're launching Monorail by Ashforde® on Product Hunt. It's a free window manager for macOS built around one idea: new windows should never squeeze the ones you're using. Drag windows onto each other to dock or tab them, type what you want in plain language, get an alert when an AI coding agent needs you, and bring your setup over from AeroSpace, yabai or Rectangle. Every feature is free. We'd love your support and feedback: [link]

## Launch checklist

- [ ] Post at 00:01 Pacific time (Product Hunt's day starts then).
- [ ] Tagline, description, topics, gallery (7 images), thumbnail and video uploaded.
- [ ] Maker comment posted straight away.
- [ ] The README links to the Product Hunt page (a badge from Product Hunt's embed page).
- [ ] The latest release is published, with a DMG and checksums, and notarised.
- [ ] Optional but worth it: a Developer ID and notarisation (add `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` and a Developer ID certificate as repository secrets), so first-time users don't see a Gatekeeper warning.
- [ ] Reply to every comment on the day.
