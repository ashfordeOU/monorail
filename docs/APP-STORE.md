# The Mac App Store edition

Monorail ships two ways: the **direct download** (the DMG, zip, pkg, Homebrew and the other
packages), and a **Mac App Store edition** for people who prefer the App Store. They're separate
apps with separate identifiers, so someone can switch between them.

## What's different

The App Store requires Apple's sandbox, so the App Store edition leaves out what the sandbox doesn't
allow. Everything else, including docking, saved views, themes, Stay Awake and the command palette,
is the same.

| Left out of the App Store edition | Why |
|---|---|
| The built-in updater | The App Store updates it |
| The Caps Lock key | Remapping keys system-wide isn't allowed in the sandbox |
| The local API, MCP server and phone remote | The sandbox doesn't allow apps to accept network connections this way |
| JavaScript scripts | Running code from a folder is restricted |
| Saving browser tabs in snapshots | Controlling other apps with AppleScript needs exceptions App Review rarely grants |
| The hold-and-release window switcher (⌘Tab / ⌥Tab) | It needs the event tap, and taking over ⌘Tab needs a private call |

The code for this is `Edition.isAppStore` (`Sources/Monorail/Edition.swift`), set by building with
`-DAPPSTORE`. CI checks that the edition compiles on every change.

**Before submitting, test on a real Mac** that moving and resizing other apps' windows works with the
sandbox on: it relies on Accessibility access, which App Store window managers such as Magnet and
Moom also use. Global shortcuts and the mouse and trackpad gestures need Input Monitoring; check
they work, and if App Review objects to the event tap, the edition can fall back to standard
system-wide hot keys.

## Steps (once the Apple Developer account is approved)

The automated way: add the App Store secrets listed at the top of `.github/workflows/appstore.yml`,
then run **App Store** from the Actions tab. It first checks on GitHub's Mac that the sandboxed
edition still sees and arranges real windows, then signs it and uploads it to App Store Connect,
where it appears in TestFlight. What to paste into App Store Connect is in
[APP-STORE-LISTING.md](APP-STORE-LISTING.md). The manual steps below do the same by hand.


1. **App Store Connect → Apps → +**: a new macOS app named "Monorail by Ashforde", bundle ID
   `org.ashforde.monorail.appstore`, SKU `monorail`.
2. **Certificates** (developer.apple.com → Certificates): create **Apple Distribution** and
   **Mac Installer Distribution** certificates, and a **Mac App Store** provisioning profile for
   `org.ashforde.monorail.appstore`. Install them on the Mac that builds.
3. **Build and package:**
   ```bash
   APP_SIGN_IDENTITY="Apple Distribution: Ashforde OU (D69G45342Y)" \
   INSTALLER_SIGN_IDENTITY="3rd Party Mac Developer Installer: Ashforde OU (D69G45342Y)" \
   PROVISIONING_PROFILE=~/Downloads/Monorail_App_Store.provisionprofile \
   scripts/build-appstore.sh
   ```
4. **Upload** `dist/AppStore/Monorail-<version>.pkg` with Apple's **Transporter** app.
5. **TestFlight**: add yourself as a tester and try it for a day: this is also how to run App Store
   betas later.
6. **Listing**: use the Product Hunt kit (`assets/launch/v17`) for screenshots (App Store sizes are
   2880 × 1800 or 1440 × 900; the gallery renders at any size from `scripts/launch/gallery.html`),
   the description from `docs/launch/PRODUCT_HUNT.md`, the privacy policy from the README's Privacy
   section, and **Productivity** as the category.
7. **App Review notes**: explain that Monorail needs Accessibility access to move and resize windows,
   that nothing leaves the Mac except anonymous usage counts the person can turn off, and include a
   short screen recording of the welcome tour.
8. **Pricing**: free.

## Lid-closed mode in the App Store edition (the Amphetamine way)

The sandbox doesn't let an App Store app change the system's sleep setting, so the first App Store
release leaves lid-closed mode out (plain Stay Awake is there). It comes back in an update the way
Amphetamine does it, in pieces that each stay inside Apple's rules:

1. **A script the person installs.** A sandboxed app may run scripts placed in its own folder,
   `~/Library/Application Scripts/org.ashforde.monorail.appstore/`, through `NSUserUnixTask`; it can't
   put them there itself, but the person can with an ordinary Save dialog. Settings → Stay Awake shows
   **Install the lid script…**: a Save panel opens on that folder with `monorail-lid.sh` ready, and one
   click on Save installs it. The script does what the download version does today: asks for the
   administrator password (or Touch ID) once per session, runs `pmset -a disablesleep 1`, and starts the
   watcher that puts sleep back when Monorail asks, quits or crashes. The same safety rules apply (heat,
   battery, Low Power Mode, plugged-in only).
2. **Ashforde Enhancer (optional).** A small notarised app on GitHub, not in the App Store, signed with
   Ashforde's Developer ID, like Amphetamine Enhancer and Power Protect. One setup installs a narrow
   `sudo` rule allowing only `pmset -a disablesleep 0|1`, so lid-closed mode stops asking for the
   password, and adds a fail-safe that restores sleep if neither app is running. The same Enhancer and
   script design serve Keeper's App Store edition.
3. **The download version** keeps its built-in lid-closed mode and needs neither.

Order: submit the App Store edition first without lid-closed mode, so the first review is simple;
add the script installer in an update once it's approved; then the Enhancer.

## Monorail and Keeper inside the sandbox

The App Store edition has no local network API, so Monorail and Keeper talk through a folder only
Ashforde's apps can open: the App Group `D69G45342Y.group.ashforde.suite` (agreed with Keeper,
`Sources/MonorailCore/SuiteChannel.swift`). Each app writes `hello/<app>.json` (who it is and what
it's doing), leaves requests in `requests/<to>/` and answers in `responses/<from>/`, and rings a
doorbell (the distributed notification `com.ashforde.suite.changed`, with no payload). Both editions of
both apps use it; the downloaded versions also keep the localhost API.

Keeper's App Store edition is being built in Keeper's own repository; both apps go to the App Store
together when it's ready.
