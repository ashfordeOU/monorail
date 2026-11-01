# Launch-day replies

Ready answers for the questions that come up on Product Hunt, Hacker News, Reddit and X. Adjust the
wording to the person, keep it short, and link to the docs rather than pasting walls of text.

Facts to keep straight: macOS 13 or later, Apple silicon and Intel, free with no Pro tier, source on
GitHub under FSL-1.1-ALv2 (becomes Apache 2.0 after two years), one permission (Accessibility), no
account, anonymous daily counts that can be turned off.

## "macOS says it can't verify the developer"

> Sorry about that: the Apple notarisation is on its way. Until then, open System Settings → Privacy &
> Security and click **Open Anyway**, or install with Homebrew (`brew install --cask monorail` after
> `brew tap ashfordeOU/monorail https://github.com/ashfordeOU/monorail`), which skips the warning. Every
> release is code-signed and has a published SHA-256 checksum.

## "How is this different from AeroSpace / yabai / Amethyst?"

> Those are classic tilers: open a window and everything else shrinks to make room. Monorail scrolls
> instead. Every window gets a slide on a strip that runs past the screen edges, so a new window slides
> in beside the one you're using and nothing else changes size. It also does things tilers don't:
> drag-to-dock and tab groups across apps, plain-language commands, saved views. It doesn't need SIP
> turned off. If you're coming from AeroSpace or yabai/skhd, Monorail imports your config in a minute.

## "How is it different from Rectangle / Magnet?"

> Rectangle snaps one window at a time to halves and thirds. Monorail manages all of them: windows
> arrange themselves as they open, and you move along the strip with keys, a swipe or the slider bar.
> If you like Rectangle's shortcuts, Monorail imports them.

## "Isn't this just PaperWM / niri for Mac?"

> Same idea, yes, and they're great. Monorail brings the scrolling strip to macOS natively, without
> disabling SIP, and adds Mac-specific parts: it works with Spaces, Stage Manager and full screen, uses
> the Mac's own shortcuts, and has a menu bar and settings app.

## "Does it work with Spaces / multiple displays / Stage Manager?"

> Yes. Each display has its own strip and workspaces. Monorail's workspaces live alongside macOS
> Spaces, and native full-screen apps are left alone. Stage Manager also arranges windows, so Monorail tells
> you if it's on and asks you to turn it off in Control Centre.

## "What about battery and performance?"

> It's native Swift, with no Electron. Background checks rest while the screen is asleep or locked and
> run at half speed on battery or in Low Power Mode. Settings → About shows exactly how much CPU and
> memory it has used, and **Check Energy** measures it for 30 seconds.

## "What data do you collect?"

> No account, and no window titles, app names or files ever leave your Mac. Once a day it sends
> anonymous counts (a random install ID, Monorail and macOS versions, Mac type, number of displays,
> language, how often it was opened and which settings were changed) so we know how many Macs run it. Settings shows exactly
> what's sent under **What's Sent…**. Turn that off with **Share
> anonymous usage counts** in Settings. Everything else, like usage stats, stays on your Mac.

## "Why does it need Accessibility access?"

> That's how every window manager on macOS moves and resizes other apps' windows. It's the only
> permission Monorail needs. It doesn't record the screen or read keystrokes beyond its own shortcuts.

## "Is it open source?"

> The source is on GitHub, and you can read, build and change it for free, at home or at work. It's
> under the Functional Source License: the one thing it forbids is selling Monorail or a copy of it as
> a competing product. Each version becomes Apache 2.0 two years after release.

## "What's the catch? How do you make money?"

> No catch: every feature is free, with no window limits and no Pro tier. If Monorail helps you,
> starring the repo and telling a friend helps us most.

## "Windows / Linux?"

> Both are planned, with a Windows version first, then GNOME and KDE. They'll share the same strip,
> docking and file formats, built to feel native on each. The groundwork is already running in CI.
> There's a sign-up on the site under "Coming soon".

## "App Store?"

> A lighter, sandboxed App Store edition is coming once Apple approves the developer account. The
> download from the site stays the full version.

## "A window ended up off screen / something looks wrong"

> Choose **Rescue Windows** from the menu bar icon: every window comes back on screen. Monorail also
> brings floating windows and dialogs back into view by itself when a display is unplugged. If it's
> still wrong, **Send Feedback** in the menu opens a pre-filled issue with your Mac and Monorail
> versions. Thank you!

## "How do I uninstall it?"

> Quit Monorail from its menu (windows are put back on screen) and drag it from Applications to the
> Bin. With Homebrew, `brew uninstall --cask monorail`.

## "I don't like the bar at the bottom"

> In Settings, set the slider bar to Always, While Moving (it fades away after you move) or Off. When
> it's always on, it steps aside by itself for full-screen apps and videos.

## Feature requests

> Love this, thanks! Could you add it to GitHub Issues
> (https://github.com/ashfordeOU/monorail/issues/new/choose) so we can follow up? Upvotes there decide
> what comes next.

## Criticism

Thank them, agree with what's fair, say what you'll do, and follow up in the thread when it ships.
Never argue about other apps; say what Monorail does instead.
