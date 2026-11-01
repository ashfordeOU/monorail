#!/bin/bash
# Packages dist/Monorail.app into a .zip and a .dmg with SHA-256 checksums.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="$(tr -d '[:space:]' < VERSION)"
APP="dist/Monorail.app"
[ -d "$APP" ] || { echo "Run scripts/build-app.sh first" >&2; exit 1; }

ZIP="dist/Monorail-${VERSION}.zip"
DMG="dist/Monorail-${VERSION}.dmg"
PKG="dist/Monorail-${VERSION}.pkg"
# MacSlider 0.2.x updaters look for "MacSlider-*.zip" holding MacSlider.app.
LEGACY_ZIP="dist/MacSlider-${VERSION}.zip"
rm -f "$ZIP" "$DMG" "$PKG" "$LEGACY_ZIP" dist/SHA256SUMS

echo "==> $ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> $LEGACY_ZIP (for updating from MacSlider 0.2.x)"
LEGACY="$(mktemp -d)"
ditto "$APP" "$LEGACY/MacSlider.app"
ditto -c -k --sequesterRsrc --keepParent "$LEGACY/MacSlider.app" "$LEGACY_ZIP"
rm -rf "$LEGACY"

echo "==> $DMG"
if command -v dmgbuild > /dev/null; then
    # The styled installer: app and Applications side by side over a background
    # that says "drag Monorail into Applications".
    BACKGROUND="$(mktemp -d)/background.tiff"
    tiffutil -cathidpicheck assets/dmg/background.png assets/dmg/background@2x.png -out "$BACKGROUND" > /dev/null
    dmgbuild -s scripts/dmg-settings.py \
        -D app="$APP" -D background="$BACKGROUND" \
        -D volume_icon="$APP/Contents/Resources/AppIcon.icns" \
        "Monorail by Ashforde® ${VERSION}" "$DMG"
else
    echo "    (dmgbuild not found: making a plain disk image; pip install dmgbuild for the styled one)"
    STAGING="$(mktemp -d)"
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -volname "Monorail by Ashforde® ${VERSION}" -srcfolder "$STAGING" -ov -format UDZO "$DMG" > /dev/null
    rm -rf "$STAGING"
fi

echo "==> $PKG (for MDM: Jamf, Kandji, Mosyle, Intune, Munki)"
# Installs into /Applications. Signed when a Developer ID Installer identity is available.
PKG_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
UNSIGNED="$(mktemp -d)/Monorail.pkg"
# Always into /Applications, even if a copy sits elsewhere (installers "relocate" by default).
ROOT="$(mktemp -d)"
ditto "$APP" "$ROOT/Monorail.app"
COMPONENTS="$(mktemp -d)/components.plist"
pkgbuild --analyze --root "$ROOT" "$COMPONENTS" > /dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENTS"
pkgbuild --root "$ROOT" --component-plist "$COMPONENTS" --install-location /Applications \
    --identifier "$PKG_ID" --version "$VERSION" "$UNSIGNED" > /dev/null
rm -rf "$ROOT"
if [ -n "${INSTALLER_IDENTITY:-}" ]; then
    productbuild --package "$UNSIGNED" --sign "$INSTALLER_IDENTITY" --timestamp "$PKG" > /dev/null
else
    productbuild --package "$UNSIGNED" "$PKG" > /dev/null
fi

(cd dist && shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" "$(basename "$PKG")" "$(basename "$LEGACY_ZIP")" > SHA256SUMS)
cat dist/SHA256SUMS
