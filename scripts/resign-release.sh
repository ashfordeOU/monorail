#!/bin/bash
# Re-signs one existing GitHub release with the Developer ID and notarises it, keeping its files
# (same names, the same app, the same styled DMG): zips, DMG and pkg. Then refreshes SHA256SUMS and
# takes the "not notarized" note out of the release. Needs SIGN_IDENTITY (Developer ID Application),
# optionally INSTALLER_IDENTITY, and APPLE_ID / APPLE_TEAM_ID / APPLE_APP_PASSWORD.
#   scripts/resign-release.sh v1.7.14
set -euo pipefail
TAG="$1"
: "${SIGN_IDENTITY:?}" "${APPLE_ID:?}" "${APPLE_TEAM_ID:?}" "${APPLE_APP_PASSWORD:?}"
[ "${SIGN_TIMESTAMP:-}" = "1" ] || { echo "SIGN_IDENTITY isn't a Developer ID" >&2; exit 1; }
WORK="$(mktemp -d)"; IN="$WORK/in"; OUT="$WORK/out"; mkdir -p "$IN" "$OUT"
gh release download "$TAG" -D "$IN" -p '*.zip' -p '*.dmg' -p '*.pkg'
ls -l "$IN"

notarise() {  # $1: file to submit. Fails unless Apple accepts it.
    local log; log="$(xcrun notarytool submit "$1" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait 2>&1)" || true
    echo "$log"
    if ! grep -q "status: Accepted" <<<"$log"; then
        local id; id="$(awk '/^  id:/ {print $2; exit}' <<<"$log")"
        [ -n "$id" ] && xcrun notarytool log "$id" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" || true
        echo "Apple did not accept $(basename "$1")" >&2
        return 1
    fi
}

sign_app() {  # $1: .app — re-signed with the Developer ID, hardened runtime, timestamp, its own entitlements
    local app="$1" ent="$WORK/entitlements.plist"
    codesign -d --entitlements - --xml "$app" > "$ent" 2>/dev/null || true
    if [ -s "$ent" ]; then
        codesign --force --options runtime --timestamp --entitlements "$ent" --sign "$SIGN_IDENTITY" "$app"
    else
        codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app"
    fi
    codesign --verify --strict --deep "$app"
}

STAPLED="$WORK/stapled"; mkdir -p "$STAPLED"  # signed, notarised, stapled copies, by app name

# Zips: each holds one app.
for zip in "$IN"/*.zip; do
    [ -e "$zip" ] || continue
    dir="$WORK/zip-$(basename "$zip" .zip)"; mkdir -p "$dir"
    ditto -x -k "$zip" "$dir"
    app="$(find "$dir" -maxdepth 1 -name '*.app' | head -n1)"
    [ -n "$app" ] || { echo "no app in $(basename "$zip")" >&2; exit 1; }
    sign_app "$app"
    ditto -c -k --keepParent "$app" "$WORK/submit.zip"
    notarise "$WORK/submit.zip"
    xcrun stapler staple "$app"
    ditto -c -k --sequesterRsrc --keepParent "$app" "$OUT/$(basename "$zip")"
    rm -rf "$STAPLED/$(basename "$app")"; ditto "$app" "$STAPLED/$(basename "$app")"
done

# DMGs: the same window and background, with the notarised app inside.
for dmg in "$IN"/*.dmg; do
    [ -e "$dmg" ] || continue
    rw="$WORK/rw.dmg"; rm -f "$rw"
    hdiutil convert "$dmg" -format UDRW -o "$rw" > /dev/null
    hdiutil resize -size 200m "$rw" > /dev/null || true
    mount="$(hdiutil attach "$rw" -nobrowse -noautoopen | awk -F '\t' '/\/Volumes\// {print $NF; exit}')"
    app="$(find "$mount" -maxdepth 1 -name '*.app' | head -n1)"
    name="$(basename "$app")"
    if [ -d "$STAPLED/$name" ]; then
        rm -rf "$app"; ditto "$STAPLED/$name" "$mount/$name"
    else
        sign_app "$app"
    fi
    sync; hdiutil detach "$mount" > /dev/null
    hdiutil convert "$rw" -format UDZO -imagekey zlib-level=9 -o "$OUT/$(basename "$dmg")" > /dev/null
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$OUT/$(basename "$dmg")"
    notarise "$OUT/$(basename "$dmg")"
    xcrun stapler staple "$OUT/$(basename "$dmg")"
done

# The pkg: rebuilt from the notarised app with the same identifier and version.
for pkg in "$IN"/*.pkg; do
    [ -e "$pkg" ] || continue
    [ -n "${INSTALLER_IDENTITY:-}" ] || { echo "no Developer ID Installer: $(basename "$pkg") stays as it is"; cp "$pkg" "$OUT/"; continue; }
    expanded="$WORK/pkg-expanded"; rm -rf "$expanded"
    pkgutil --expand "$pkg" "$expanded"
    info="$(find "$expanded" -name PackageInfo | head -n1)"
    id="$(sed -n 's/.*identifier="\([^"]*\)".*/\1/p' "$info" | head -n1)"
    version="$(sed -n 's/.*version="\([^"]*\)".*/\1/p' "$info" | head -n1)"
    app="$(find "$STAPLED" -maxdepth 1 -name 'Monorail.app' | head -n1)"
    [ -n "$app" ] || app="$(find "$STAPLED" -maxdepth 1 -name '*.app' | head -n1)"
    [ -n "$app" ] || { echo "no notarised app for the pkg" >&2; exit 1; }
    root="$WORK/pkg-root"; rm -rf "$root"; mkdir -p "$root"
    ditto "$app" "$root/$(basename "$app")"
    plist="$WORK/components.plist"
    pkgbuild --analyze --root "$root" "$plist" > /dev/null
    /usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$plist"
    pkgbuild --root "$root" --component-plist "$plist" --install-location /Applications \
        --identifier "$id" --version "$version" "$WORK/component.pkg" > /dev/null
    productbuild --package "$WORK/component.pkg" --sign "$INSTALLER_IDENTITY" --timestamp "$OUT/$(basename "$pkg")" > /dev/null
    notarise "$OUT/$(basename "$pkg")"
    xcrun stapler staple "$OUT/$(basename "$pkg")"
done

# Check every file the way macOS will.
for f in "$OUT"/*.dmg "$OUT"/*.pkg; do
    [ -e "$f" ] || continue
    spctl -a -vvv -t install "$f" 2>&1 | tee /dev/stderr | grep -q "Notarized Developer ID" || { echo "$(basename "$f") isn't accepted" >&2; exit 1; }
done
for app in "$STAPLED"/*.app; do
    [ -e "$app" ] || continue
    spctl -a -vvv -t exec "$app" 2>&1 | tee /dev/stderr | grep -q "Notarized Developer ID" || { echo "$(basename "$app") isn't accepted" >&2; exit 1; }
done

(cd "$OUT" && shasum -a 256 * > SHA256SUMS && cat SHA256SUMS)
gh release upload "$TAG" "$OUT"/* --clobber
gh release view "$TAG" --json body -q .body \
    | grep -v "This build is not notarized" \
    | sed 's/^Download \*\*\(.*\)\*\*, drag \(.*\) to Applications, then open it and allow Accessibility access\.$/Download **\1**, drag \2 to Applications, then open it and allow Accessibility access. Signed with Ashforde'"'"'s Developer ID and notarised by Apple./' \
    > "$WORK/notes.md"
gh release edit "$TAG" --notes-file "$WORK/notes.md"
echo "$TAG re-signed and notarised"
