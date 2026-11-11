# Product Hunt launch kit: Monorail by Ashforde®

Everything needed to post Monorail on Product Hunt, copied straight into the form in the order it
asks. The images are in [`assets/launch/v17`](../../assets/launch/v17). Replies for the day are in
[REPLIES.md](REPLIES.md). For now, don't mention Keeper or the source code anywhere.

## The listing

**Name:** Monorail by Ashforde®

**The angle:** free vs paid. Every other window tool charges per Mac, per version or per job.
Monorail does all of it, free. Lead with that everywhere: tagline, first image, first comment.

**Tagline** (60 characters max). Pick one:
> Your whole Mac on one rail: windows, battery, focus. Free (57)

Alternatives:
- One free Mac app instead of five paid ones (42)
- Stop paying for window managers. This one does it all, free (59)

Alternatives:
- The window manager you'd pay for, free with every feature (57)
- Your Mac's windows on one endless strip. Free, every feature (59)

**Link:** https://monorail.ashforde.org/?ref=producthunt (the site then greets Product Hunt visitors)

**Launch tags:** Menu Bar Apps · Productivity · Mac

**Pricing:** Free

**Description** (Product Hunt allows 500 characters; this is 494):
> Stop paying for window tools. Monorail puts every window on one endless strip: new windows slide in
> beside you and nothing you're using ever shrinks. Drag a window onto another to dock or tab it,
> across any apps. Type "Slack and Mail side by side". Zoom out to every workspace, jump back to saved
> views, warm your screen with Evening Mode, keep your Mac awake and Teams Available. Brings your
> AeroSpace, yabai or Rectangle setup. Native, notarised, SIP stays on. Free, every feature, every Mac.

## Gallery

In [`assets/launch/v18`](../../assets/launch/v18), at 2540 × 1520 (Product Hunt's 1270 × 760 at double
resolution). **Delete the old images in the draft first** (one still says "Free and open source"), then
upload in this order:

| # | File | Says |
| --- | --- | --- |
| 1 | `01-hero.png` | Every window rides one rail · free, every Mac, Apple silicon and Intel, SIP stays on |
| 2 | `09-free.png` | Why pay for a window manager? No licence key, no per-Mac limit, no paid upgrades |
| 3 | `07-built-in.png` | The little apps you'd buy, already inside |
| 4 | `../v17/docking.gif` | Docking, live: edge, nested split, tab group, gap resize |
| 5 | `02-dock.png` | Drop a window where you want it |
| 6 | `03-tabs-resize.png` | Tab groups across apps; drag the gap to resize both |
| 7 | `04-overview.png` | Every workspace on one canvas, displays that remember |
| 8 | `05-say-it.png` | Type what you want; AI agent alerts |
| 9 | `06-evening-mode.png` | New: Evening Mode at a click from the menu bar |
| 10 | `08-saved-views.png` | Saved views, back and forward |
| 11 | `10-themes.png` | 27 themes |
| 12 | `11-native-private.png` | 0.15% of a core, no account, SIP stays on, notarised, scripting |
| 13 | `12-platforms.png` | Mac available; Windows and Linux in beta |
| 14 | `13-end.png` | monorail.ashforde.org, Homebrew |

The images are drawn by `scripts/launch/gallery.html` (open it with `?shot=1` … `?shot=13`).

**Thumbnail:** `assets/launch/v18/thumbnail-240.png` (480 px version alongside).

**Video:** `assets/launch/v17/monorail-demo.mp4` (85 s, 1080p). Product Hunt takes a YouTube link:
upload it to YouTube (unlisted is fine) and paste the link under **Add video**. Its last section calls
Windows and Linux "plans"; they're now in beta, which the gallery and comments say.

## Maker's first comment

> Hi Product Hunt! 👋
>
> Mac users pay again and again for window tools: a snapping app, a switcher, a layout app, a
> keep-awake app, a night-shift app, often per Mac and per major version. Monorail does all of it in
> one app, for free. No licence key, no trial clock, no paid upgrade next year.
>
> And it fixes the thing every tiling window manager gets wrong: open a new window and everything
> else shrinks. On a laptop that's maddening.
>
> Monorail does the opposite. Every window sits on a horizontal strip that runs past the edges of your
> screen. Open a window and it slides in next to the one you're using; nothing else changes size. Move
> along with ⌃⌥← →, a swipe or the slider, and quit any time: every window goes back where it was.
>
> A few things I'm proud of:
> - 🪟 **Dock anything.** Drag a window onto another's edge to split, or its middle to make a tab group,
>   across any apps and as deep as you like.
> - 🗣️ **Say it.** Type "Safari two thirds" or "Slack and Mail side by side". Understood on your Mac.
> - 🌙 **Evening Mode** at a click from the menu bar, **Stay Awake**, and **Keep me Available** for Teams
>   and Slack.
> - 🤖 **AI agent alerts:** a chime when your coding assistant is waiting for approval.
> - 🛡️ **Safe screen sharing:** private windows step aside when you share in Zoom, Teams or Meet.
> - 📦 **Switch in a minute:** imports your AeroSpace, yabai/skhd or Rectangle setup.
> - 🪶 **Light:** 0.15% of one core and about 55 MB when idle on battery.
>
> It's native Swift, signed and notarised by Apple, needs only the Accessibility permission (SIP stays
> on), and has no account. Monorail for Windows and for GNOME are in beta too.
>
> I'd love to hear how you arrange your windows, and what would make Monorail yours. 🙏

## Short posts

**X / Threads / Bluesky**
> Stop paying for Mac window tools. Monorail is live on Product Hunt 🚝
> One free app instead of five paid ones: a window manager where nothing ever shrinks.
> Dock or tab any apps, "Slack and Mail side by side", Evening Mode, Stay Awake. Free, every feature.
> → [Product Hunt link]

**LinkedIn**
> Today we're launching Monorail by Ashforde® on Product Hunt: a free window manager for macOS built
> around one idea, that new windows should never squeeze the ones you're using. Dock or tab any windows,
> type what you want in plain language, warm your screen in the evening, and bring your setup over from
> AeroSpace, yabai or Rectangle. Every feature is free, on Apple silicon and Intel. We'd love your
> support and feedback: [link]

## Launch checklist

- [ ] Schedule for 00:01 Pacific (Product Hunt's day starts then); a Tuesday to Thursday is busiest.
- [ ] Name, tagline, link, topics, pricing (Free), description, 10 gallery images, thumbnail, video.
- [ ] Maker comment posted the moment it goes live.
- [x] Latest release out, signed and notarised by Apple: 1.7.26, with checksums on the site.
- [x] Downloads, update checks and Homebrew all come from monorail.ashforde.org (repository private).
- [x] The site greets visitors from Product Hunt (`?ref=producthunt` or a Product Hunt referrer) with a
      one-line banner and a download button.
- [x] No Keeper, source-code or App Store mentions on the site ([SITE-HIDDEN.md](../SITE-HIDDEN.md)).
- [ ] Reply to every comment on the day ([REPLIES.md](REPLIES.md)).
- [ ] After the launch: add the Product Hunt badge to the site if you like it.
