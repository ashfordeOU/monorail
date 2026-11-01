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

The code for this is `Edition.isAppStore` (`Sources/Monorail/Edition.swift`), set by building with
`-DAPPSTORE`. CI checks that the edition compiles on every change.

**Before submitting, test on a real Mac** that moving and resizing other apps' windows works with the
sandbox on: it relies on Accessibility access, which App Store window managers such as Magnet and
Moom also use. Global shortcuts and the mouse and trackpad gestures need Input Monitoring; check
they work, and if App Review objects to the event tap, the edition can fall back to standard
system-wide hot keys.

## Steps (once the Apple Developer account is approved)

1. **App Store Connect → Apps → +**: a new macOS app named "Monorail by Ashforde", bundle ID
   `org.ashforde.monorail.appstore`, SKU `monorail`.
2. **Certificates** (developer.apple.com → Certificates): create **Apple Distribution** and
   **Mac Installer Distribution** certificates, and a **Mac App Store** provisioning profile for
   `org.ashforde.monorail.appstore`. Install them on the Mac that builds.
3. **Build and package:**
   ```bash
   APP_SIGN_IDENTITY="Apple Distribution: Ashforde OÜ (TEAMID)" \
   INSTALLER_SIGN_IDENTITY="3rd Party Mac Developer Installer: Ashforde OÜ (TEAMID)" \
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
