# Notarising Monorail

Notarised builds open without the “can't verify the developer” warning. The release workflow already
notarises and staples every DMG as soon as these repository secrets exist, so this is a one-time setup.

## What you need

- An **Apple Developer Program** membership (99 USD a year) for Ashforde OÜ: https://developer.apple.com/programs/
- A Mac with Xcode (or Keychain Access) to create the certificate.

## Steps

Team: **Ashforde OU**, Team ID **D69G45342Y**.

1. **Create both Developer ID certificates.**
   In Xcode: **Settings → Accounts → Ashforde OU → Manage Certificates → +**, once for
   **Developer ID Application** (signs the app) and once for **Developer ID Installer** (signs the pkg
   for MDM and Installomator).
2. **Export them together.** In Keychain Access → My Certificates, select both
   "Developer ID Application: Ashforde OU (D69G45342Y)" and "Developer ID Installer: Ashforde OU (D69G45342Y)"
   (each must have its private key underneath), right-click → **Export 2 items…** → `.p12` with a strong password.
3. **Wait for a bridge release to be out** (1.7.15 or later). Releases before it only accept updates
   signed with the old self-signed certificate; 1.7.15 also accepts Ashforde's Developer ID, so
   everyone can update to the first notarised build.
4. **Replace the signing secrets** in GitHub → ashfordeOU/monorail → Settings → Secrets and variables → Actions:
   - `MONORAIL_SIGNING_CERT`: the `.p12`, base64-encoded: `base64 -i DeveloperID.p12 | pbcopy`
   - `MONORAIL_SIGNING_PASSWORD`: its password
5. **Add the notarisation secrets:**
   - `APPLE_ID`: the Apple ID email of the developer account
   - `APPLE_TEAM_ID`: `D69G45342Y`
   - `APPLE_APP_PASSWORD`: an app-specific password from https://account.apple.com → Sign-In and Security → App-Specific Passwords
6. **Release as usual** (bump `VERSION`). `scripts/ci-import-signing-cert.sh` finds the Developer ID
   identities in the `.p12` (falling back to the old self-signed one when there are none), the app is
   signed with the hardened runtime and a secure timestamp, the pkg with the Installer identity, both
   are submitted with `notarytool` and stapled, and the Gatekeeper note leaves the release notes.

## After switching certificates

macOS ties Accessibility permission to the signing identity. The first notarised release asks users to allow
Accessibility once more (remove Monorail from Privacy & Security → Accessibility, then open it again). Every
release after that keeps the permission.

## Checking a build

```bash
spctl -a -vvv -t install Monorail-1.4.0.dmg     # "accepted, source=Notarized Developer ID"
xcrun stapler validate Monorail-1.4.0.dmg
```
