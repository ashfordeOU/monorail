#!/bin/bash
# CI only: imports the Mac App Store certificates and provisioning profile into a temporary keychain
# and exports APP_SIGN_IDENTITY, INSTALLER_SIGN_IDENTITY and PROVISIONING_PROFILE for
# scripts/build-appstore.sh. Secrets (base64 .p12 / .provisionprofile):
#   MONORAIL_APPSTORE_CERT / MONORAIL_APPSTORE_PASSWORD             Apple Distribution
#   MONORAIL_APPSTORE_INSTALLER_CERT / _INSTALLER_PASSWORD          Mac Installer Distribution
#   MONORAIL_APPSTORE_PROFILE                                       Mac App Store Connect profile
set -euo pipefail
: "${MONORAIL_APPSTORE_CERT:?}" "${MONORAIL_APPSTORE_PASSWORD:?}" "${MONORAIL_APPSTORE_INSTALLER_CERT:?}" "${MONORAIL_APPSTORE_PROFILE:?}"
TMP="${RUNNER_TEMP:-$(mktemp -d)}"
KEYCHAIN="$TMP/appstore.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -hex 16)"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
printf '%s' "$MONORAIL_APPSTORE_CERT" | base64 --decode > "$TMP/app.p12"
printf '%s' "$MONORAIL_APPSTORE_INSTALLER_CERT" | base64 --decode > "$TMP/installer.p12"
security import "$TMP/app.p12" -k "$KEYCHAIN" -P "$MONORAIL_APPSTORE_PASSWORD" -T /usr/bin/codesign
security import "$TMP/installer.p12" -k "$KEYCHAIN" -P "${MONORAIL_APPSTORE_INSTALLER_PASSWORD:-$MONORAIL_APPSTORE_PASSWORD}" -T /usr/bin/productbuild
rm -f "$TMP/app.p12" "$TMP/installer.p12"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" > /dev/null
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')

identity() { security find-identity -p "$1" "$KEYCHAIN" | awk -v name="\"$2" 'index($0, name) {print $2; exit}'; }
APP="$(identity codesigning "Apple Distribution")"
[ -n "$APP" ] || APP="$(identity codesigning "3rd Party Mac Developer Application")"
INSTALLER="$(identity basic "3rd Party Mac Developer Installer")"
[ -n "$INSTALLER" ] || INSTALLER="$(identity basic "Mac Installer Distribution")"
[ -n "$APP" ] && [ -n "$INSTALLER" ] || { security find-identity "$KEYCHAIN"; echo "App Store identities not found" >&2; exit 1; }

PROFILE="$TMP/Monorail_App_Store.provisionprofile"
printf '%s' "$MONORAIL_APPSTORE_PROFILE" | base64 --decode > "$PROFILE"
# The profile must be for the App Store edition's identifier.
security cms -D -i "$PROFILE" > "$TMP/profile.plist"
/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.application-identifier" "$TMP/profile.plist" | grep -q "org.ashforde.monorail.appstore" \
    || { echo "The provisioning profile isn't for org.ashforde.monorail.appstore" >&2; exit 1; }

{
    echo "APP_SIGN_IDENTITY=$APP"
    echo "INSTALLER_SIGN_IDENTITY=$INSTALLER"
    echo "PROVISIONING_PROFILE=$PROFILE"
} >> "${GITHUB_ENV:-/dev/null}"
echo "Imported Apple Distribution ($APP), Mac Installer Distribution ($INSTALLER) and the App Store profile"
