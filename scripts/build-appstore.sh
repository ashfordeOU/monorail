#!/bin/bash
# Builds the Mac App Store edition and the installer package App Store Connect takes.
#
#   APP_SIGN_IDENTITY="Apple Distribution: Ashforde OU (D69G45342Y)" \
#   INSTALLER_SIGN_IDENTITY="3rd Party Mac Developer Installer: Ashforde OU (D69G45342Y)" \
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
    # Point it at the keychain with the installer key (CI sets APPSTORE_KEYCHAIN). App Store packages
    # need no timestamp, and asking Apple's timestamp server can stall.
    KEYCHAIN_ARGS=(); [ -n "${APPSTORE_KEYCHAIN:-}" ] && KEYCHAIN_ARGS=(--keychain "$APPSTORE_KEYCHAIN")
    productbuild --component dist/AppStore/Monorail.app /Applications \
        --sign "$INSTALLER_SIGN_IDENTITY" ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} --timestamp=none "$PKG"
    pkgutil --check-signature "$PKG"
    echo "==> Ready to upload: $PKG"
else
    echo "==> Built dist/AppStore/Monorail.app (set INSTALLER_SIGN_IDENTITY to make the upload package)"
fi
