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
    APP="dist/AppStore/Monorail.app"
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
    /usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.productivity" "$APP/Contents/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set :LSApplicationCategoryType public.app-category.productivity" "$APP/Contents/Info.plist"
    rm -f "$APP/Contents/Resources/monorail"
    if [ -n "${PROVISIONING_PROFILE:-}" ]; then cp "$PROVISIONING_PROFILE" "$APP/Contents/embedded.provisionprofile"; fi
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Icon"
# assets/icon.png is the 1024px master (re-render with scripts/render-icon.py).
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" assets/icon.png --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    double=$((size * 2))
    sips -z "$double" "$double" assets/icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Signing"
if [ -n "${SIGN_IDENTITY:-}" ]; then
    # Apple's timestamp server only serves Apple-issued certificates.
    TIMESTAMP="--timestamp=none"
    case "$SIGN_IDENTITY" in "Developer ID"*) TIMESTAMP="--timestamp" ;; esac
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
