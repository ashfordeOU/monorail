#!/bin/bash
# Installs the latest Monorail release into /Applications, or into ~/Applications when
# /Applications isn't writable (a standard account on a managed Mac): no administrator needed.
#   curl -fsSL https://monorail.ashforde.org/install.sh | bash
set -euo pipefail

[ "$(uname -s)" = "Darwin" ] || { echo "Monorail runs on macOS only." >&2; exit 1; }

REPO="ashfordeOU/monorail"
DEST="/Applications"
if [ ! -w "$DEST" ] || { [ -e "$DEST/Monorail.app" ] && [ ! -w "$DEST/Monorail.app" ]; }; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
    echo "==> /Applications needs an administrator, so Monorail goes in your own Applications folder: $DEST"
    echo "    It works the same from there, and keeps itself up to date."
    [ -e "/Applications/Monorail.app" ] && echo "    An older copy stays in /Applications: ask an administrator to remove it, or update it there."
fi

echo "==> Finding the latest release"
URL="$(curl -fsSL "https://monorail.ashforde.org/releases/latest.json" \
    | grep -o '"browser_download_url": *"[^"]*/Monorail-[^"]*\.zip"' | head -n1 | sed 's/.*"\(https[^"]*\)"/\1/')"
[ -n "$URL" ] || { echo "No release found." >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "==> Downloading ${URL##*/}"
curl -fsSL "$URL" -o "$TMP/Monorail.zip"
ditto -x -k "$TMP/Monorail.zip" "$TMP"

for name in Monorail MacSlider; do
    if pgrep -xq "$name"; then
        echo "==> Quitting the running copy"
        { osascript -e "quit app id \"org.ashforde.monorail\"" 2>/dev/null; osascript -e "quit app id \"org.ashforde.macslider\"" 2>/dev/null; } || pkill -x "$name" || true
        sleep 1
    fi
done

echo "==> Installing to ${DEST}"
rm -rf "${DEST}/Monorail.app" "${DEST}/MacSlider.app"  # MacSlider was Monorail's earlier name
ditto "$TMP/Monorail.app" "${DEST}/Monorail.app"
xattr -dr com.apple.quarantine "${DEST}/Monorail.app" 2>/dev/null || true

echo "==> Opening Monorail"
open "${DEST}/Monorail.app"
echo "Done. To arrange every window, Monorail needs Accessibility (System Settings → Privacy & Security)."
echo "On a managed Mac, ask IT: https://monorail.ashforde.org/docs/it/"
echo "Stay Awake, Keep me Available, Evening Mode and the display controls work without it."
