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

## Plan: Monorail Station (November 2026)

Since the sandbox can't arrange windows (below), the App Store edition becomes **Station**: the
menu bar half of Monorail, complete on its own, with one card and its About page pointing to the
free Monorail. It isn't called "Lite" and has no locked features: Apple doesn't allow demos.

What Station may do is measured, not guessed: `Monorail --probe-sandbox` tries each capability
(battery and health, other apps' energy, Stay Awake, Keep me Available, Evening Mode, window frames,
hiding, quitting and opening apps, the clipboard, calendar, microphone in use, Bluetooth batteries,
Low Power Mode, a local server, and moving windows) and undoes what it changes. **App Store** in the
Actions tab runs it with the sandbox on and puts the results in the run's summary. Uploading to
TestFlight is a separate tick box.

## Measured: the features marked 🧪 (13 November 2026)

The probe ran on GitHub's Mac with the sandbox on and Screen Recording and Bluetooth recorded as
allowed in the permission database, as a person would allow them. 22 of 32 checks were allowed.

| Feature | Sandbox says | In Station |
|---|---|---|
| Mouse, keyboard and trackpad batteries | ✅ IORegistry lookup allowed | Built |
| AirPods battery (left, right, case) | ❌ the Bluetooth file is closed; the paired-device list waits on a Bluetooth prompt, and the levels themselves aren't public API | Monorail only (it reads macOS's Bluetooth report) |
| Load per core, drawn as your chip | ✅ per-core ticks readable | Built |
| Per-core temperatures | ❌ no SMC service visible; the other route is private API, which the App Store refuses | Heat as a state (normal, warm, hot) instead |
| Network speed and speed test | ✅ interface counters readable; 5 MB downloaded at 102 Mbit/s | Built |
| Scan your home folder | ✅ after you choose it once (closed without, as expected); security-scoped bookmark allowed, so it's remembered | Built: Choose Home Folder… |
| Clean-ups to the Trash | ✅ moving to the Trash allowed | Built, after that one choice |
| Text from the screen (OCR) | ✅ technically, with Screen Recording: captured the screen and read "Probe" from it. But Apple's review has refused screen capture for anything but recording or sharing (StepTwo, Color Picker, 1Password, 2019–20) | Built the allowed way: from a copied screenshot (⌃⇧⌘4) or a picture; Monorail selects on screen |
| QR codes on screen | ✅ Vision reads them; same review rule as OCR | Built the same way |

Precedents in the Mac App Store: ToothFairy (Bluetooth batteries), iStat Menus 7 (per-core load; no
fan control or full sensors), Network Inspector and NetTop (live speed), DaisyDisk (scans after
the folder is chosen), CleanMyMac's App Store edition (cleans, minus system areas), TextSniper
and QRSpell (screen OCR and QR, needing Screen Recording).

## Status: parked (November 2026)

**The sandboxed edition can't arrange windows, so it isn't submitted.** Tested on 9 November 2026
with TestFlight build 1.7.24 (340) on a real Mac. Accessibility was granted (Monorail's own check
showed the green tick), but the overview stayed empty. The system log showed the sandbox refusing
every request to another app:

    Sandbox: Monorail(62622) deny(1) mach-lookup com.apple.axserver (per-pid)

GitHub's Mac showed the same thing in `appstore.yml`.

This is Apple's rule, not a Monorail bug. [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
lists "use of accessibility APIs in assistive apps" as forbidden in the sandbox. Apple's developer
support confirmed in [thread 805556](https://developer.apple.com/forums/thread/805556) that a
window manager's only route is Developer ID distribution, which is the notarised download Monorail
already uses. Older store tilers such as Magnet date from before sandboxing was required and aren't
sandboxed. A new app can't do the same.

The one known workaround is Apple's Shortcuts app. A sandboxed app sends window frames to a
companion Shortcut, whose Move Window and Resize Window actions do the moving. That only gives
occasional, slow re-arrangement. It has no live strip, gestures, animation, or reaction to new
windows, so it wouldn't be Monorail.

What's ready, if Apple's rules change:
- The app record "Monorail by Ashforde" in App Store Connect.
- The distribution certificates, the profile and the GitHub secrets.
- `appstore.yml`, which builds, signs and uploads to TestFlight with one click.

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
4. **Upload** `dist/AppStore/Station-<version>.pkg` with Apple's **Transporter** app.
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
