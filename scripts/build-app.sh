#!/bin/bash
# Builds dist/Monorail.app as a universal (Apple silicon + Intel) binary.
#
# Signing: set SIGN_IDENTITY to a codesigning identity (name or SHA-1) to
# sign with it, e.g. the "MacSlider Self-Signed" certificate CI imports or a
# "Developer ID Application: …" identity. Otherwise the app is signed ad hoc.
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP="dist/Monorail.app"
# APPSTORE=1 builds the Mac App Store edition (sandboxed, no self-updater; see docs/APP-STORE.md).
SWIFT_FLAGS=()
ENTITLEMENTS="Resources/Monorail.entitlements"
if [ "${APPSTORE:-0}" = "1" ]; then
    # The App Store edition is Station (docs/APP-STORE.md).
    APP="dist/AppStore/Station.app"
    SWIFT_FLAGS=(-Xswiftc -DAPPSTORE --scratch-path .build-appstore)
    ENTITLEMENTS="Resources/MonorailAppStore.entitlements"
fi

echo "==> Building Monorail ${VERSION} (${BUILD})${APPSTORE:+ for the App Store}"
swift build -c release --arch arm64 --arch x86_64 ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"}
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"} --show-bin-path)"

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Monorail" "$APP/Contents/MacOS/Monorail"
cp scripts/monorail "$APP/Contents/Resources/monorail"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp Resources/Monorail.sdef "$APP/Contents/Resources/Monorail.sdef"
cp CHANGELOG.md "$APP/Contents/Resources/CHANGELOG.md"
sed -e "s/__VERSION__/${VERSION}/" -e "s/__BUILD__/${BUILD}/" Resources/Info.plist > "$APP/Contents/Info.plist"
if [ "${APPSTORE:-0}" = "1" ]; then
    # Its own identifier: the App Store edition and the direct download are separate apps.
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier org.ashforde.monorail.appstore" "$APP/Contents/Info.plist"
    # Named Station wherever it shows: Finder, the Dock, the menu bar and the App Store.
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Station" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Station" "$APP/Contents/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Station" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.productivity" "$APP/Contents/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set :LSApplicationCategoryType public.app-category.productivity" "$APP/Contents/Info.plist"
    # Only standard HTTPS: no export compliance paperwork for each upload.
    /usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$APP/Contents/Info.plist" 2>/dev/null || true
    rm -f "$APP/Contents/Resources/monorail"
    if [ -n "${PROVISIONING_PROFILE:-}" ]; then
        cp "$PROVISIONING_PROFILE" "$APP/Contents/embedded.provisionprofile"
        # The App Store needs the app's identity in its signature (matching the profile).
        TEAM="${APPLE_TEAM_ID:-D69G45342Y}"
        SIGNED_ENTITLEMENTS="$(mktemp -d)/MonorailAppStore.entitlements"
        cp "$ENTITLEMENTS" "$SIGNED_ENTITLEMENTS"
        /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string ${TEAM}.org.ashforde.monorail.appstore" "$SIGNED_ENTITLEMENTS"
        /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string ${TEAM}" "$SIGNED_ENTITLEMENTS"
        ENTITLEMENTS="$SIGNED_ENTITLEMENTS"
    fi
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Icon"
# assets/icon.png is the 1024px master (re-render with scripts/render-icon.py); Station's is
# assets/station/icon.png (scripts/render-station-icon.py).
ICON_MASTER="assets/icon.png"
[ "${APPSTORE:-0}" = "1" ] && ICON_MASTER="assets/station/icon.png"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_MASTER" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ICON_MASTER" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# macOS 26 draws app icons itself from Icon Composer's format and puts any other icon on a
# grey plate. With Xcode 26 or later, compile assets/AppIcon.icon into Assets.car; macOS 13-15
# keep using AppIcon.icns. Without it (older Xcode, or actool refuses), the build goes on
# with the classic icon only.
if [ "${APPSTORE:-0}" = "1" ] && xcrun --find actool > /dev/null 2>&1; then
    # Station: the App Store wants the icon in an asset catalog (Assets.car), built from the PNGs.
    CATALOG="$(mktemp -d)/Station.xcassets"
    mkdir -p "$CATALOG/AppIcon.appiconset"
    cp "$ICONSET"/*.png "$CATALOG/AppIcon.appiconset/"
    python3 - "$CATALOG/AppIcon.appiconset/Contents.json" <<'PY'
import json, sys
images = []
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
        images.append({"idiom": "mac", "size": f"{size}x{size}", "scale": f"{scale}x", "filename": name})
json.dump({"images": images, "info": {"version": 1, "author": "xcode"}}, open(sys.argv[1], "w"), indent=1)
PY
    printf '{"info":{"version":1,"author":"xcode"}}' > "$CATALOG/Contents.json"
    ICON_OUT="$(mktemp -d)"
    if xcrun actool "$CATALOG" --compile "$ICON_OUT" --app-icon AppIcon --platform macosx --target-device mac \
        --minimum-deployment-target 13.0 --output-partial-info-plist "$ICON_OUT/partial.plist" > "$ICON_OUT/actool.log" 2>&1 \
        && [ -f "$ICON_OUT/Assets.car" ]
    then
        cp "$ICON_OUT/Assets.car" "$APP/Contents/Resources/Assets.car"
        /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$APP/Contents/Info.plist" > /dev/null 2>&1 || true
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP/Contents/Info.plist"
        echo "    Station icon compiled (Assets.car)"
    else
        echo "::error::Station's icon catalog didn't compile"; cat "$ICON_OUT/actool.log"; exit 1
    fi
elif [ -d assets/AppIcon.icon ] && xcrun --find actool > /dev/null 2>&1; then
    ICON_OUT="$(mktemp -d)"
    if xcrun actool assets/AppIcon.icon --compile "$ICON_OUT" --app-icon AppIcon \
        --platform macosx --target-device mac --minimum-deployment-target 13.0 \
        --output-partial-info-plist "$ICON_OUT/partial.plist" > "$ICON_OUT/actool.log" 2>&1 \
        && [ -f "$ICON_OUT/Assets.car" ]
    then
        cp "$ICON_OUT/Assets.car" "$APP/Contents/Resources/Assets.car"
        /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$APP/Contents/Info.plist" > /dev/null 2>&1 || true
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP/Contents/Info.plist"
        echo "    macOS 26 icon compiled (Assets.car)"
    else
        echo "::warning::macOS 26 icon not compiled (needs Xcode 26's actool); using AppIcon.icns only"
        cat "$ICON_OUT/actool.log" || true
    fi
fi

echo "==> Signing"
if [ -n "${SIGN_IDENTITY:-}" ]; then
    # Apple's timestamp server only serves Apple-issued certificates.
    TIMESTAMP="--timestamp=none"
    case "$SIGN_IDENTITY" in "Developer ID"*) TIMESTAMP="--timestamp" ;; esac
    # CI passes the identity as a SHA-1 and says separately that it's a Developer ID.
    [ "${SIGN_TIMESTAMP:-}" = "1" ] && TIMESTAMP="--timestamp"
    codesign --force --options runtime $TIMESTAMP --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
else
    codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP"
fi
codesign --verify --strict "$APP"
# The designated requirement is what macOS ties permissions to; a stable
# certificate keeps it the same across builds.
codesign --display --requirements - "$APP" 2>&1 | grep designated || true

echo "==> Done: $APP"
lipo -info "$APP/Contents/MacOS/Monorail"
