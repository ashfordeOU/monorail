#!/bin/bash
# Measures Monorail on this Mac for one minute: CPU, idle wake-ups, memory and energy impact.
# Leave the Mac alone while it runs (that's the "idle" the site quotes). No admin needed.
#   curl -fsSL https://raw.githubusercontent.com/ashfordeOU/monorail/main/scripts/perf-check.sh | bash
set -euo pipefail
pid="$(pgrep -x Monorail | head -n1 || true)"
[ -n "$pid" ] || { echo "Monorail isn't running. Open it, then run this again."; exit 1; }
seconds="${1:-60}"
# The version of the copy that's running (not the one on disk, which may have been updated since).
app="$(ps -o comm= -p "$pid" | sed 's#/Contents/MacOS/.*##')"
version="$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "?")"
started="$(LC_ALL=C date -j -f '%a %b %d %T %Y' "$(ps -o lstart= -p "$pid" | xargs)" +%s 2>/dev/null || true)"
changed="$(stat -f %m "$app/Contents/Info.plist" 2>/dev/null || true)"
if [ -n "$started" ] && [ -n "$changed" ] && [ "$started" -lt "$changed" ]; then
  echo "Monorail was updated after it started: quit and reopen it, then run this again." >&2
  exit 1
fi
model="$(sysctl -n hw.model)"; cores="$(sysctl -n hw.ncpu)"
power="$(pmset -g batt | grep -q "Battery Power" && echo "on battery" || echo "on power")"
tosec() { awk -F'[:.]' '{ if (NF==3) print $1*60+$2+$3/100; else print $1*3600+$2*60+$3+$4/100 }'; }
before="$(ps -o time= -p "$pid" | tr -d ' ' | tosec)"
echo "Measuring Monorail $version for $seconds s on a $model ($cores cores), $power. Don't touch the Mac…"
# top in delta mode: the second sample covers exactly the interval.
sample="$(top -l 2 -s "$seconds" -d -pid "$pid" -stats pid,idlew,mem,power 2>/dev/null | awk -v p="$pid" '$1==p' | tail -n1)"
after="$(ps -o time= -p "$pid" | tr -d ' ' | tosec)"
cpu="$(awk -v a="$after" -v b="$before" -v s="$seconds" 'BEGIN { printf "%.2f", (a-b)/s*100 }')"
wakes="$(echo "$sample" | awk -v s="$seconds" '{ gsub(/\+/, "", $2); printf "%.1f", $2/s }')"
# Delta mode reports the change in memory; take the total from a plain sample.
mem="$(top -l 1 -pid "$pid" -stats pid,mem 2>/dev/null | awk -v p="$pid" '$1==p { print $2 }' | tail -n1)"
energy="$(echo "$sample" | awk '{ print $4 }')"
echo
echo "Monorail $version · $model · $power · idle ${seconds}s"
echo "  CPU:            ${cpu}% of one core"
echo "  Idle wake-ups:  ${wakes} a second"
echo "  Memory:         ${mem}"
echo "  Energy impact:  ${energy}"
