# Launch-day replies

Ready answers for the questions that come up on Product Hunt, Hacker News, Reddit and X. Adjust the
wording to the person, keep it short, and link to the docs rather than pasting walls of text.

Facts to keep straight: macOS 13 or later, Apple silicon and Intel, free with every feature (no Pro
tier, no licence key, no per-Mac limit, no paid upgrades), one permission (Accessibility), SIP stays on,
no account, anonymous daily counts that can be turned off. Windows and Linux (GNOME) are in beta.
Don't mention Keeper or the source code for now.

## "Is it safe? Is it signed?"

> Yes. Every release is signed with our Apple Developer ID and notarised by Apple, so it opens without
> warnings. Every change is tested on macOS, Windows and Linux, and every download has a published SHA-256
> checksum. Check it yourself with `spctl -a -vvv -t open --context context:primary-signature Monorail-x.y.z.dmg`, which says
> "Notarized Developer ID".

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

## "Why not just buy a paid window manager?"

> You can, but you don't need to. Window managers are often sold per Mac and per major version, and
> each one does one job. Monorail does the strip, docking and tabs, snapping, a window switcher, saved
> layouts per display, Evening Mode and Stay Awake in one app, free, including every update.

## "What about battery and performance?"

> It's native Swift, with no Electron. Measured on a MacBook Pro on battery, idle: 0.15% of one core,
> no wake-ups, about 55 MB of memory. Background checks rest while the screen is asleep or locked and
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

> Not at the moment. Monorail is free to use, with every feature, at home or at work, under the
> Functional Source License. It's signed and notarised by Apple, and every download has a published
> checksum, so you can check exactly what you install.

## "What's the catch? How do you make money?"

> No catch: every feature is free, with no window limits, no Pro tier, no licence key and no paid
> upgrade next year. If Monorail helps you, telling a friend (and an upvote today) helps us most.

## "Windows / Linux?"

> Both are in beta: Windows 11 and 10 (a portable app, no installer or admin rights) and a GNOME
> extension for GNOME 45 or later, from monorail.ashforde.org. Same strip, same shortcuts, built
> natively for each. KDE is next. Tell us what you find: contact@ashforde.org.

## "App Store?"

> No. Apple's App Store sandbox doesn't let any new app move other apps' windows, so window managers
> like Monorail are distributed directly, signed and notarised by Apple. Homebrew works too:
> `brew tap ashfordeou/monorail && brew trust ashfordeou/monorail && brew install --cask monorail`.

## "A window ended up off screen / something looks wrong"

> Choose **Rescue Windows** from the menu bar icon: every window comes back on screen. Monorail also
> brings floating windows and dialogs back into view by itself when a display is unplugged. If it's
> still wrong, **Report a Problem…** in Settings starts an email with your Mac and Monorail versions
> filled in. Thank you!

## "How do I uninstall it?"

> Quit Monorail from its menu (windows are put back on screen) and drag it from Applications to the
> Bin. With Homebrew, `brew uninstall --cask monorail`.

## "I don't like the bar at the bottom"

> In Settings, set the slider bar to Always, While Moving (it fades away after you move) or Off. When
> it's always on, it steps aside by itself for full-screen apps and videos.

## Feature requests

> Love this, thanks! Could you send it to contact@ashforde.org (or **Send Feedback…** in Monorail's
> menu) so we can follow up? Requests from users decide what comes next.

## Criticism

Thank them, agree with what's fair, say what you'll do, and follow up in the thread when it ships.
Never argue about other apps; say what Monorail does instead.
