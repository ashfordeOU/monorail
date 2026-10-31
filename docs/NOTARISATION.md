# Notarising Monorail

Notarised builds open without the “can't verify the developer” warning. The release workflow already
notarises and staples every DMG as soon as these repository secrets exist, so this is a one-time setup.

## What you need

- An **Apple Developer Program** membership (99 USD a year) for Ashforde OÜ: https://developer.apple.com/programs/
- A Mac with Xcode (or Keychain Access) to create the certificate.

## Steps

1. **Create a Developer ID Application certificate.**
   In Xcode: **Settings → Accounts → (your team) → Manage Certificates → + → Developer ID Application**.
2. **Export it** from Keychain Access (My Certificates → right-click it → Export) as a `.p12` with a strong password.
3. **Replace the signing secrets** in GitHub → ashfordeOU/monorail → Settings → Secrets and variables → Actions:
   - `MACSLIDER_SIGNING_CERT`: the `.p12`, base64-encoded: `base64 -i DeveloperID.p12 | pbcopy`
   - `MACSLIDER_SIGNING_PASSWORD`: its password
4. **Add the notarisation secrets:**
   - `APPLE_ID`: the Apple ID email of the developer account
   - `APPLE_TEAM_ID`: the 10-character Team ID (developer.apple.com → Membership)
   - `APPLE_APP_PASSWORD`: an app-specific password from https://account.apple.com → Sign-In and Security → App-Specific Passwords
5. **Release as usual** (bump `VERSION`). The workflow signs with the Developer ID (hardened runtime, the
   entitlements in `Resources/Monorail.entitlements`), submits the DMG with `notarytool`, staples the ticket,
   and leaves the Gatekeeper note out of the release notes.

## After switching certificates

macOS ties Accessibility permission to the signing identity. The first notarised release asks users to allow
Accessibility once more (remove Monorail from Privacy & Security → Accessibility, then open it again). Every
release after that keeps the permission.

## Checking a build

```bash
spctl -a -vvv -t install Monorail-1.4.0.dmg     # "accepted, source=Notarized Developer ID"
xcrun stapler validate Monorail-1.4.0.dmg
```
