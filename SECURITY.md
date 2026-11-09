# Security

## Reporting a vulnerability

Please report security problems privately by email to
**[contact@ashforde.org](mailto:contact@ashforde.org?subject=Security)**. We reply within a few days, keep you updated while we fix it, and credit you in
the release notes if you'd like.

## Supported versions

Security fixes go into the newest release; Monorail updates itself (or through Homebrew), so please update before reporting.

## How releases are protected

- Signed with Ashforde OÜ's Apple Developer ID (Team `D69G45342Y`) with the hardened runtime, and
  notarised and stapled by Apple. The pkg is signed with the Developer ID Installer certificate.
- Built and signed by automated builds, never on a personal machine; every change to the source is
  signed.
- Every release publishes SHA-256 checksums (`SHA256SUMS`).
- The built-in updater installs a download only when its checksum matches and its code signature
  satisfies the running app's designated requirement (or Ashforde's Developer ID).

Check a download yourself:

```bash
shasum -a 256 -c SHA256SUMS --ignore-missing
spctl -a -vvv -t open --context context:primary-signature Monorail-*.dmg   # Notarized Developer ID
spctl -a -vvv -t install Monorail-*.pkg                                     # Notarized Developer ID
```
