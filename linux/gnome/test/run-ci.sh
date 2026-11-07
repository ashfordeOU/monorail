#!/usr/bin/env bash
# Runs Monorail for GNOME (beta) in a real, headless GNOME Shell and tests it on real windows.
#
#   linux/gnome/test/run-ci.sh [output directory]
#
# Installs the built zip (linux/gnome/dist) for a throwaway user home, starts GNOME Shell on its
# own D-Bus session as a headless Wayland compositor with one 1280×800 virtual monitor and the
# test interface turned on (MONORAIL_TEST=1), then runs run-tests.js. Writes report.json,
# report.txt and gnome-shell.log to the output directory. Exits non-zero when anything fails.
#
# Needs gnome-shell (45 or later), gjs with GTK 4, dbus and, for the X11 check, Xwayland.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
gnome="$(cd "$here/.." && pwd)"
out="$(mkdir -p "${1:-$gnome/test-results}" && cd "${1:-$gnome/test-results}" && pwd)"
uuid="monorail@ashforde.org"
zip="$gnome/dist/$uuid.shell-extension.zip"

if [[ "${MONORAIL_INSIDE_SESSION:-}" != 1 ]]; then
    [[ -f "$zip" ]] || { echo "No $zip: run linux/gnome/build.sh first" >&2; exit 2; }
    # A clean home, so nothing from the machine's own GNOME settings or extensions gets in.
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' EXIT
    mkdir -p "$scratch/home" "$scratch/runtime"
    chmod 700 "$scratch/runtime"
    export HOME="$scratch/home" XDG_RUNTIME_DIR="$scratch/runtime"
    export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
    unset DISPLAY WAYLAND_DISPLAY
    export MONORAIL_INSIDE_SESSION=1
    exec dbus-run-session -- "$0" "$out"
fi

# Inside the private D-Bus session from here on.
report="$out/report.txt"
: > "$report"
say() { echo "$*" | tee -a "$report"; }

say "Monorail for GNOME (beta): UI test"
say "$(gnome-shell --version), $(gjs --version 2>/dev/null || echo 'gjs ?')"

gnome-extensions install --force "$zip"
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.shell enabled-extensions "['$uuid']"
# No welcome tour or other first-login windows getting in the way.
gsettings set org.gnome.shell welcome-dialog-last-shown-version '999' 2>/dev/null || true

export MONORAIL_TEST=1
export XDG_SESSION_TYPE=wayland
# Software rendering: the runners have no GPU.
export LIBGL_ALWAYS_SOFTWARE=1
gnome-shell --headless --wayland --virtual-monitor 1280x800 > "$out/gnome-shell.log" 2>&1 &
shell=$!
stop_shell() {
    kill "$shell" 2>/dev/null || true
    wait "$shell" 2>/dev/null || true
}
trap stop_shell EXIT

# Wait for the extension's test interface: that means the shell is up and the extension enabled.
ready=0
for _ in $(seq 1 120); do
    if gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.NameHasOwner org.ashforde.Monorail.Test 2>/dev/null | grep -q true; then
        ready=1
        break
    fi
    if ! kill -0 "$shell" 2>/dev/null; then break; fi
    sleep 0.5
done
if [[ $ready != 1 ]]; then
    say "FAIL  GNOME Shell started with the extension enabled (no test interface after 60 seconds)"
    gnome-extensions info "$uuid" 2>&1 | tee -a "$report" || true
    echo "--- gnome-shell.log ---"
    tail -n 80 "$out/gnome-shell.log"
    exit 1
fi
say "PASS  GNOME Shell started headless and the extension is enabled"
gnome-extensions info "$uuid" 2>&1 | tee -a "$report" || true

# Windows open on the shell's Wayland display (and its Xwayland for the X11 check).
export WAYLAND_DISPLAY=wayland-0
export GDK_BACKEND=wayland
export GTK_A11Y=none NO_AT_BRIDGE=1
# Mutter starts Xwayland when an X11 app first connects, on the display it chose at startup.
x11_display="$(grep -o 'Using public X11 display :[0-9]*' "$out/gnome-shell.log" | grep -o ':[0-9]*' | head -n 1 || true)"
export DISPLAY="${x11_display:-:0}"
# ...and only lets in apps with its key (normally handed out by gnome-session, which isn't running).
x11_auth="$(ls "$XDG_RUNTIME_DIR"/.mutter-Xwaylandauth.* 2>/dev/null | head -n 1 || true)"
[[ -n "$x11_auth" ]] && export XAUTHORITY="$x11_auth"
say "Wayland display $WAYLAND_DISPLAY, X11 display $DISPLAY"
status=0
gjs -m "$here/run-tests.js" --report "$out/report.json" 2>&1 | tee -a "$report" || status=$?

# Any error or warning from the extension fails the run, even when every check passed. GNOME
# Shell only names the extension's files in its log for those (in their stack traces).
if grep -n -B8 -A2 -E "monorail@ashforde\.org|org\.ashforde\.Monorail" "$out/gnome-shell.log" > "$out/extension-errors.txt"; then
    say "FAIL  the extension logged errors in GNOME Shell:"
    tee -a "$report" < "$out/extension-errors.txt"
    status=1
else
    say "PASS  no errors from the extension in GNOME Shell's log"
fi
exit "$status"
