#!/bin/bash
# CI only: imports the signing certificate(s) from MONORAIL_SIGNING_CERT /
# MONORAIL_SIGNING_PASSWORD into a temporary keychain and exports
#   SIGN_IDENTITY       for scripts/build-app.sh (Developer ID Application, else the self-signed one)
#   INSTALLER_IDENTITY  for scripts/package.sh (Developer ID Installer, when the .p12 has one)
# The .p12 may hold both Developer ID certificates (select both in Keychain Access and export them together),
# or the Installer one can come separately in MONORAIL_INSTALLER_CERT (/ MONORAIL_INSTALLER_PASSWORD,
# which defaults to MONORAIL_SIGNING_PASSWORD), e.g. when each was exported from Xcode on its own.
set -euo pipefail

: "${MONORAIL_SIGNING_CERT:?}" "${MONORAIL_SIGNING_PASSWORD:?}"
SELF_SIGNED="MacSlider Self-Signed"  # the old certificate's name, still used when there's no Developer ID
TMP="${RUNNER_TEMP:-$(mktemp -d)}"
KEYCHAIN="$TMP/signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -hex 16)"

printf '%s' "$MONORAIL_SIGNING_CERT" | base64 --decode > "$TMP/cert.p12"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$MONORAIL_SIGNING_PASSWORD" -T /usr/bin/codesign -T /usr/bin/productbuild
rm -f "$TMP/cert.p12"
if [ -n "${MONORAIL_INSTALLER_CERT:-}" ]; then
    printf '%s' "$MONORAIL_INSTALLER_CERT" | base64 --decode > "$TMP/installer.p12"
    security import "$TMP/installer.p12" -k "$KEYCHAIN" -P "${MONORAIL_INSTALLER_PASSWORD:-$MONORAIL_SIGNING_PASSWORD}" -T /usr/bin/productbuild
    rm -f "$TMP/installer.p12"
fi
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" > /dev/null
# Put the keychain on the search list so codesign and productbuild can find the identities.
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')

identity() {  # $1: policy, $2: name prefix → SHA-1 of the first matching identity
    security find-identity -p "$1" "$KEYCHAIN" | awk -v name="\"$2" 'index($0, name) {print $2; exit}'
}

HASH="$(identity codesigning "Developer ID Application")"
if [ -n "$HASH" ]; then
    echo "Imported Developer ID Application ($HASH)"
    # Notarisation needs a secure timestamp on every signature.
    echo "SIGN_TIMESTAMP=1" >> "${GITHUB_ENV:-/dev/null}"
else
    # The self-signed certificate needs trusting on this runner first.
    security find-certificate -c "$SELF_SIGNED" -p "$KEYCHAIN" > "$TMP/cert.pem"
    sudo security add-trusted-cert -d -r trustRoot -p codeSign -k /Library/Keychains/System.keychain "$TMP/cert.pem"
    HASH="$(identity codesigning "$SELF_SIGNED")"
    echo "Imported \"$SELF_SIGNED\" ($HASH)"
fi
[ -n "$HASH" ] || { security find-identity "$KEYCHAIN"; echo "Signing identity not found" >&2; exit 1; }
echo "SIGN_IDENTITY=$HASH" >> "${GITHUB_ENV:-/dev/null}"

INSTALLER="$(identity basic "Developer ID Installer")"
if [ -n "$INSTALLER" ]; then
    echo "INSTALLER_IDENTITY=$INSTALLER" >> "${GITHUB_ENV:-/dev/null}"
    echo "Imported Developer ID Installer ($INSTALLER): the pkg will be signed"
else
    echo "No Developer ID Installer certificate: the pkg stays unsigned"
fi
