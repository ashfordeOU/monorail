#!/bin/bash
# Builds the Mac App Store edition and the installer package App Store Connect takes.
#
#   APP_SIGN_IDENTITY="Apple Distribution: Ashforde OÜ (TEAMID)" \
#   INSTALLER_SIGN_IDENTITY="3rd Party Mac Developer Installer: Ashforde OÜ (TEAMID)" \
#   PROVISIONING_PROFILE=~/Downloads/Monorail_App_Store.provisionprofile \
#   scripts/build-appstore.sh
#
# Then upload dist/AppStore/Monorail-<version>.pkg with Transporter or:
#   xcrun altool --upload-app -f dist/AppStore/Monorail-<version>.pkg -t macos --apiKey … --apiIssuer …
# Without the identities it still builds (signed ad hoc), to check that the edition compiles.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(tr -d '[:space:]' < VERSION)"
APPSTORE=1 SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}" scripts/build-app.sh
PKG="dist/AppStore/Monorail-${VERSION}.pkg"
if [ -n "${INSTALLER_SIGN_IDENTITY:-}" ]; then
    productbuild --component dist/AppStore/Monorail.app /Applications --sign "$INSTALLER_SIGN_IDENTITY" "$PKG"
    echo "==> Ready to upload: $PKG"
else
    echo "==> Built dist/AppStore/Monorail.app (set INSTALLER_SIGN_IDENTITY to make the upload package)"
fi
